/**
 * 南京大学**研究生选课系统**（yjsxk.nju.edu.cn）—— 课表抓取脚本
 *
 * 这个入口最特殊：页面本身就是一段 JSON。
 * 登录后跳转到 loadStdCourseInfo.do，服务端直接把选课结果以 JSON 吐出来，
 * 浏览器把它当纯文本渲染，所以读 document.body.innerText 再 JSON.parse 就行。
 *
 * JSON 结构（关键字段）：
 *   results: [
 *     { XNXQMC: "2026-2027学年 第1学期",   // 学期
 *       KCMC:   "课程名称",
 *       KCDM:   "课程代码",
 *       RKJS:   "任课教师",
 *       XKBZ:   "选课备注",
 *       PKSJDD: "1-16周 星期一[1-2节]仙Ⅰ-101" }
 *   ]
 *
 * PKSJDD 用分号分隔多段，单段格式：
 *   1-16周 星期一[1-2节]仙Ⅰ-101
 *   5-9单周,13-17单周 星期五[3-4节]仙Ⅰ-319
 *
 * 溯源：来自开源项目 NJU-Class-Shedule-Flutter 的 api/tools/njuyjsxk.js。本版本改了三处：
 *   1. 统一走 window.njuBridge 回传；
 *   2. **修了一个会直接导致导入失败的 bug**——原实现最后有一行
 *      `rst["courses"] = JSON.stringify(rst["courses"])`，把数组序列化成了字符串，
 *      这里返回正常数组；
 *   3. 学期选取改成"包含今天的那个"，选不中再退回最后一个有课的学期。
 */
(function () {
  'use strict';

  var WEEK_MAP = { 一: 1, 二: 2, 三: 3, 四: 4, 五: 5, 六: 6, 日: 7 };
  var FULL_WEEKS = 18;

  function emit(payload) {
    var text = JSON.stringify(payload);
    try {
      if (window.njuBridge && typeof window.njuBridge.postMessage === 'function') {
        window.njuBridge.postMessage(text);
        return '';
      }
    } catch (e) {
      /* 走 return */
    }
    return text;
  }

  function fail(stage, err) {
    return emit({
      ok: false,
      stage: stage,
      message: (err && err.message) ? err.message : String(err)
    });
  }

  function expandWeeks(start, end, flag) {
    var out = [];
    var from = start;
    if (flag === 1) {
      from = start % 2 === 1 ? start : start + 1;
    } else if (flag === 2) {
      from = start % 2 === 0 ? start : start + 1;
    }
    var step = flag === 0 ? 1 : 2;
    for (var w = from; w <= end; w += step) {
      out.push(w);
    }
    return out;
  }

  /** "2026-2027学年 第1学期" → 起始时间戳；解析不出返回 null */
  function termStartTime(display) {
    var m = String(display || '').match(/(\d{4})\s*[-—]\s*(\d{4})\s*学年\s*第?\s*([12])\s*学期/);
    if (!m) {
      return null;
    }
    var year = parseInt(m[1], 10);
    var half = parseInt(m[3], 10);
    var d = half === 1 ? new Date(year, 8, 1) : new Date(year + 1, 1, 1);
    return d.getTime();
  }

  /** 把一行 PKSJDD 解析成若干段安排 */
  function parseSchedule(raw) {
    var result = [];
    var text = raw === null || raw === undefined ? '' : String(raw);
    if (text === '') {
      result.push({
        classroom: '自由地点',
        weeks: fullWeeks(),
        week_time: 0,
        start_time: 0,
        time_count: 0
      });
      return result;
    }

    var segments = text.split(';');
    for (var i = 0; i < segments.length; i++) {
      var seg = segments[i].trim();
      if (!seg) {
        continue;
      }
      // 「5-9单周,13-17单周 星期五[3-4节]仙Ⅰ-319」
      // 正常是「星期X」，但兼容「周X」的写法，避免一种格式变了就整份课表读不出来。
      var m = seg.match(/^(.*?周)\s*(?:星期|周)\s*(.)\s*\[(\d{1,2})(?:\s*-\s*(\d{1,2}))?节\](.*)$/);
      if (!m) {
        continue;
      }

      var weekPart = m[1];
      var weekTime = WEEK_MAP[m[2]] || 0;
      var startTime = parseInt(m[3], 10);
      var timeCount = m[4] ? parseInt(m[4], 10) - startTime : 0;
      var classroom = (m[5] || '').trim();

      var weeks = [];
      var chunks = weekPart.split(/[,，]/);
      for (var c = 0; c < chunks.length; c++) {
        var chunk = chunks[c];
        var flag = chunk.indexOf('单') >= 0 ? 1 : (chunk.indexOf('双') >= 0 ? 2 : 0);
        var range = chunk.match(/(\d{1,2})\s*-\s*(\d{1,2})/);
        if (range) {
          var list = expandWeeks(parseInt(range[1], 10), parseInt(range[2], 10), flag);
          for (var a = 0; a < list.length; a++) {
            weeks.push(list[a]);
          }
        } else {
          var one = chunk.match(/(\d{1,2})/);
          if (one) {
            weeks.push(parseInt(one[1], 10));
          }
        }
      }
      weeks.sort(function (x, y) { return x - y; });

      result.push({
        classroom: classroom,
        weeks: weeks,
        week_time: weekTime,
        start_time: startTime,
        time_count: timeCount
      });
    }
    return result;
  }

  function fullWeeks() {
    var out = [];
    for (var w = 1; w <= FULL_WEEKS; w++) {
      out.push(w);
    }
    return out;
  }

  /** 页面正文其实就是 JSON，容错地读出来 */
  function readBodyJson() {
    var text = '';
    try {
      text = document.body ? document.body.innerText : '';
    } catch (e) {
      text = '';
    }
    if (!text || text.indexOf('{') < 0) {
      try {
        text = document.body ? document.body.textContent : '';
      } catch (e2) {
        text = '';
      }
    }
    if (!text) {
      return null;
    }
    // 去掉可能存在的多余换行/行首缩进，JSON 本身允许，但有些页面会塞进 <pre> 里带前后空白
    var trimmed = text.replace(/^\s+|\s+$/g, '');
    var braceAt = trimmed.indexOf('{');
    if (braceAt < 0) {
      return null;
    }
    var lastBrace = trimmed.lastIndexOf('}');
    if (lastBrace <= braceAt) {
      return null;
    }
    try {
      return JSON.parse(trimmed.substring(braceAt, lastBrace + 1));
    } catch (e3) {
      return null;
    }
  }

  function run() {
    var data = readBodyJson();
    if (!data || !data.results || !data.results.length) {
      return fail('readBody', '当前页面不是选课结果的 JSON。请确认已登录并跳到选课结果页（loadStdCourseInfo.do）后重试');
    }

    var results = data.results;

    // ---------- 按学期分组 ----------
    var groups = {};
    var order = [];
    for (var i = 0; i < results.length; i++) {
      var term = results[i].XNXQMC || '未知学期';
      if (!groups[term]) {
        groups[term] = [];
        order.push(term);
      }
      groups[term].push(results[i]);
    }

    // ---------- 选学期：优先"包含今天"的那个 ----------
    var now = Date.now();
    var chosenTerm = '';
    var bestStart = -Infinity;
    for (var g = 0; g < order.length; g++) {
      var st = termStartTime(order[g]);
      if (st === null) {
        continue;
      }
      if (st <= now && st > bestStart) {
        bestStart = st;
        chosenTerm = order[g];
      }
    }
    // 选不中就用最后一个学期（原实现的做法）
    if (!chosenTerm) {
      chosenTerm = order[order.length - 1];
    }

    var rows = groups[chosenTerm] || [];
    var courses = [];
    for (var r = 0; r < rows.length; r++) {
      try {
        var row = rows[r];
        if (!row.KCMC) {
          continue;
        }
        var segs = parseSchedule(row.PKSJDD);
        for (var s = 0; s < segs.length; s++) {
          var seg = segs[s];
          courses.push({
            name: row.KCMC,
            classroom: seg.classroom,
            class_number: row.KCDM,
            teacher: row.RKJS,
            test_time: null,
            test_location: null,
            link: null,
            weeks: seg.weeks,
            week_time: seg.week_time,
            start_time: seg.start_time,
            time_count: seg.time_count,
            import_type: 1,
            info: row.XKBZ || null,
            data: null
          });
        }
      } catch (rowErr) {
        continue;
      }
    }

    if (courses.length === 0) {
      return fail('emptyCourses', '选课结果里没有课程数据，可能该学期还没选课');
    }

    return emit({
      ok: true,
      data: {
        name: chosenTerm,
        courses: courses
      }
    });
  }

  try {
    return run();
  } catch (e) {
    return fail('fatal', e);
  }
})();
