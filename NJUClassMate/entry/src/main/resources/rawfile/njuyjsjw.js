/**
 * 南京大学**研究生教务系统**（ehallapp.nju.edu.cn/gsapp/sys/wdkbapp）—— 课表抓取脚本
 *
 * 这份脚本和另外三份思路不同：它**不去读 DOM，而是直接调页面自己的 JSON 接口**。
 * 之所以可以这么干：这些接口是教务系统前端自己在用的，
 * 用户登录后浏览器里已经带了有效的会话 Cookie，
 * 我们用 XMLHttpRequest 发同样的请求，就能拿到结构化数据——比解析 HTML 稳得多。
 *
 * 用到的两个接口（都是 POST，靠页面会话鉴权）：
 *   kfdxnxqcx.do  →  可选学期列表（datas.kfdxnxqcx.rows，字段 XNXQDM / XNXQDM_DISPLAY / PX）
 *   xsjxrwcx.do   →  指定学期的教学任务即课表
 *                    参数 XNXQDM=<学期代码>
 *                    返回 datas.xsjxrwcx.rows，字段：
 *                      KCMC  课程名称
 *                      KCDM  课程代码
 *                      RKJS  任课教师
 *                      PKSJDD 排课时间地点
 *                      XKBZ  选课备注
 *
 * PKSJDD 的格式（分号分隔多段）：
 *   5-9单周,13-17单周 星期五[3-4节]仙Ⅰ-319;4-18周 星期一[3-4节];4-18双周 星期五[3-4节]
 *   null 表示自由时间课程
 *
 * 溯源：来自开源项目 NJU-Class-Shedule-Flutter 的 api/tools/njuyjsjw.js。本版本改了三处：
 *   1. 统一走 window.njuBridge 回传；
 *   2. **学期不再盲取 terms[0]**——原实现按 PX 升序取第一个，
 *      一旦 PX 方向变了就会抓到最老的那个学期。这里改成按「学年+学期序号」
 *      算出日期区间、选中包含今天的那个学期，选不中再按"从新到旧找第一个有课的"兜底；
 *   3. 单双周按奇偶对齐起点，并给每条记录加 try/catch。
 */
(function () {
  'use strict';

  var WEEK_MAP = { 一: 1, 二: 2, 三: 3, 四: 4, 五: 5, 六: 6, 日: 7 };

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

  /** 同步请求，返回解析后的 JSON；失败返回 null */
  function postJson(url, body) {
    try {
      var xhr = new XMLHttpRequest();
      xhr.open('POST', url, false);
      if (body) {
        xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
      }
      xhr.send(body || null);
      if (!xhr.responseText) {
        return null;
      }
      return JSON.parse(xhr.responseText);
    } catch (e) {
      return null;
    }
  }

  /** "2026-2027学年 第1学期" → {year:2026, half:1}；解析不出返回 null */
  function termKey(display) {
    var m = String(display || '').match(/(\d{4})\s*[-—]\s*(\d{4})\s*学年\s*第?\s*([12])\s*学期/);
    if (!m) {
      return null;
    }
    return { year: parseInt(m[1], 10), half: parseInt(m[3], 10) };
  }

  /** 该学期的起始时刻：第 1 学期约 9 月 1 日，第 2 学期约次年 2 月 1 日 */
  function termStartTime(display) {
    var k = termKey(display);
    if (!k) {
      return null;
    }
    var d = k.half === 1 ? new Date(k.year, 8, 1) : new Date(k.year + 1, 1, 1);
    return d.getTime();
  }

  /** 从学期列表里挑出"包含今天"的那个 */
  function pickCurrentTerm(terms) {
    var now = Date.now();
    var best = null;
    var bestStart = -Infinity;
    for (var i = 0; i < terms.length; i++) {
      var st = termStartTime(terms[i].XNXQDM_DISPLAY);
      if (st === null) {
        continue;
      }
      if (st <= now && st > bestStart) {
        bestStart = st;
        best = terms[i];
      }
    }
    return best;
  }

  /** 解析 PKSJDD，返回若干段上课安排 */
  function parseSchedule(raw) {
    var result = [];
    if (raw === null || raw === undefined || raw === '') {
      // 自由时间课程：没有固定时间地点，但课本身要保留
      result.push({
        classroom: '自由地点',
        weeks: [1],
        week_time: 0,
        start_time: 0,
        time_count: 0
      });
      return result;
    }

    var segments = String(raw).split(';');
    for (var i = 0; i < segments.length; i++) {
      var seg = segments[i].trim();
      if (!seg) {
        continue;
      }
      // 「5-9单周,13-17单周 星期五[3-4节]仙Ⅰ-319」
      // 接口返回的是「星期X」，但历史上也见过「周X」的写法，两种都接受。
      var m = seg.match(/(.+?周)\s*(?:星期|周)\s*(.+?)\s*\[(.+?)节\](.*)/);
      if (!m) {
        continue;
      }
      var weekPart = m[1];
      var dayPart = m[2].trim();
      var timePart = m[3];
      var classroom = (m[4] || '').trim();

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

      var weekTime = WEEK_MAP[dayPart] || 0;

      var startTime = 0;
      var timeCount = 0;
      var times = timePart.match(/(\d{1,2})\s*-\s*(\d{1,2})/);
      if (times) {
        startTime = parseInt(times[1], 10);
        timeCount = parseInt(times[2], 10) - startTime;
      } else {
        var single = timePart.match(/(\d{1,2})/);
        if (single) {
          startTime = parseInt(single[1], 10);
          timeCount = 0;
        }
      }

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

  var TERM_LIST_URL = 'https://ehallapp.nju.edu.cn/gsapp/sys/wdkbapp/modules/xskcb/kfdxnxqcx.do';
  var TIMETABLE_URL = 'https://ehallapp.nju.edu.cn/gsapp/sys/wdkbapp/modules/xskcb/xsjxrwcx.do';

  function run() {
    // ---------- 1. 学期列表 ----------
    var termResp = postJson(TERM_LIST_URL, null);
    var terms = null;
    try {
      terms = termResp.datas.kfdxnxqcx.rows;
    } catch (e) {
      terms = null;
    }
    if (!terms || terms.length === 0) {
      return fail('fetchTerms', '拿不到学期列表，通常是尚未登录或会话已过期，请重新登录后再试');
    }

    // ---------- 2. 选出当前学期 ----------
    var chosen = pickCurrentTerm(terms);
    var candidates = [];
    if (chosen) {
      candidates.push(chosen);
    }
    // 兜底顺序：按 PX 从大到小、再从小到大各试一遍，覆盖 PX 方向不确定的情况
    var byPxDesc = terms.slice().sort(function (a, b) { return (b.PX || 0) - (a.PX || 0); });
    var byPxAsc = terms.slice().sort(function (a, b) { return (a.PX || 0) - (b.PX || 0); });
    var i;
    for (i = 0; i < byPxDesc.length; i++) {
      candidates.push(byPxDesc[i]);
    }
    for (i = 0; i < byPxAsc.length; i++) {
      candidates.push(byPxAsc[i]);
    }

    // ---------- 3. 取第一个真正有课的学期 ----------
    var courses = [];
    var usedName = '';
    var tried = {};
    for (i = 0; i < candidates.length; i++) {
      var term = candidates[i];
      var code = term.XNXQDM;
      if (!code || tried[code]) {
        continue;
      }
      tried[code] = true;

      var resp = postJson(TIMETABLE_URL, 'XNXQDM=' + encodeURIComponent(code));
      var rows = null;
      try {
        rows = resp.datas.xsjxrwcx.rows;
      } catch (e2) {
        rows = null;
      }
      if (!rows || rows.length === 0) {
        continue;
      }

      var list = [];
      for (var r = 0; r < rows.length; r++) {
        try {
          var row = rows[r];
          var segs = parseSchedule(row.PKSJDD);
          for (var s = 0; s < segs.length; s++) {
            var seg = segs[s];
            list.push({
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

      if (list.length > 0) {
        courses = list;
        usedName = term.XNXQDM_DISPLAY || '';
        break;
      }
    }

    if (courses.length === 0) {
      return fail('emptyCourses', '接口通了但所有学期都没有课程数据，可能本学期还没排课');
    }

    return emit({
      ok: true,
      data: {
        name: usedName || '当前学期',
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
