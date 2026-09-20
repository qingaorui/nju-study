/**
 * 南京大学本科生教务系统 —— 课表抓取脚本（注入到内置浏览器中执行）
 *
 * 原理解释：
 *   这本脚本不调用任何后端接口，纯粹在页面里读 DOM。
 *   之所以这么做，是因为教务系统是统一身份认证（CAS）之后才可见的，
 *   直接用 HTTP 请求需要自己处理票据、加密参数和风控，极其脆弱且容易失效；
 *   而让用户在真实浏览器里登录一次，再用 JS 读已经渲染好的表格，
 *   既绕开了密码托管问题，也不受接口改版影响（只要表格还在）。
 *
 * 这一版在 nju.app 的 njubksjw2.js 基础上做了三件事：
 *   1. 结果优先通过 window.njuBridge 回传（原生侧 javaScriptProxy 注册），
 *      回传失败时再 return 字符串，兼容 runJavaScript 模式；
 *   2. DOM 选择器加了多级兜底，教务系统换皮肤不至于直接崩；
 *   3. 解析全部包在 try/catch 里，出错时把原因回传，方便排查。
 *
 * 页面结构（2026 版）：
 *   #dqxnxqkclb         → 学期名称文字，如「2026-2027学年 第1学期」
 *   table tbody tr      → 每行一门课
 *     td[1] 课程号  td[2] 课程名  td[4] 教师
 *     td[6] 时间地点  td[8] 备注  td[10] 考试时间
 *   td[6] 的格式样例：
 *     「周三 2-4节 1-3周,10-13周 仙Ⅱ-304」
 *     「周二 5-8节 2-18周(双) 仙1-216」
 *     「周一 3-4节 1-16周 自由时间」
 */
(function () {
  'use strict';

  var WEEK_MAP = { 一: 1, 二: 2, 三: 3, 四: 4, 五: 5, 六: 6, 日: 7 };

  /** 统一的回传出口：优先走原生 bridge，其次走 return */
  function emit(payload) {
    var text = JSON.stringify(payload);
    try {
      if (window.njuBridge && typeof window.njuBridge.postMessage === 'function') {
        window.njuBridge.postMessage(text);
        return '';
      }
    } catch (e) {
      /* 走下面的 return */
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

  /** 在当前文档及其同源 iframe 里找一个非空的元素 */
  function deepQuery(selector) {
    var doc = document;
    var found = null;
    try {
      found = doc.querySelector(selector);
    } catch (e) {
      /* ignore */
    }
    if (found) {
      return found;
    }
    // 教务系统部分页面把内容塞在 iframe 里，这里逐个试探
    var frames = document.querySelectorAll('iframe, frame');
    for (var i = 0; i < frames.length; i++) {
      try {
        var sub = frames[i].contentDocument;
        if (!sub) {
          continue;
        }
        var el = sub.querySelector(selector);
        if (el) {
          return el;
        }
      } catch (e) {
        // 跨域，忽略
      }
    }
    return null;
  }

  /**
   * 解析周次字符串，例如：
   *   "1-3周,10-13周"       → [1,2,3,10,11,12,13]
   *   "2-18周(双)"          → [2,4,6,...,18]
   *   "1-15周(单)"          → [1,3,5,...,15]
   */
  function parseWeeks(weekStr) {
    var weeks = [];
    if (!weekStr) {
      return weeks;
    }
    var parts = String(weekStr).split(/[,，]/);
    for (var i = 0; i < parts.length; i++) {
      var part = parts[i];
      var isSingle = part.indexOf('(单)') >= 0 || part.indexOf('（单）') >= 0;
      var isDouble = part.indexOf('(双)') >= 0 || part.indexOf('（双）') >= 0;
      var clean = part
        .replace(/周/g, '')
        .replace(/[（(]\s*单\s*[)）]/g, '')
        .replace(/[（(]\s*双\s*[)）]/g, '')
        .trim();
      if (!clean) {
        continue;
      }
      if (clean.indexOf('-') >= 0) {
        var range = clean.split('-');
        var start = parseInt(range[0], 10);
        var end = parseInt(range[1], 10);
        if (isNaN(start) || isNaN(end)) {
          continue;
        }
        var cur = start;
        var step = 1;
        if (isSingle) {
          cur = start % 2 === 1 ? start : start + 1;
          step = 2;
        } else if (isDouble) {
          cur = start % 2 === 0 ? start : start + 1;
          step = 2;
        }
        for (var w = cur; w <= end; w += step) {
          weeks.push(w);
        }
      } else {
        var single = parseInt(clean, 10);
        if (!isNaN(single)) {
          weeks.push(single);
        }
      }
    }
    // 去重 + 升序
    weeks.sort(function (a, b) { return a - b; });
    var dedup = [];
    for (var k = 0; k < weeks.length; k++) {
      if (dedup.indexOf(weeks[k]) < 0) {
        dedup.push(weeks[k]);
      }
    }
    return dedup;
  }

  /** 读学期名，多个兜底策略 */
  function readSemesterName() {
    var el = deepQuery('#dqxnxqkclb');
    if (el && el.textContent && el.textContent.trim()) {
      return el.textContent.trim();
    }
    // 兜底：在页面上搜「20xx-20xx学年」
    var all = document.querySelectorAll('*');
    for (var i = 0; i < all.length && i < 4000; i++) {
      var t = all[i].textContent;
      if (t && t.length < 40) {
        var m = t.match(/\d{4}\s*-\s*\d{4}\s*学年.{0,10}学期/);
        if (m) {
          return m[0].replace(/\s+/g, '');
        }
      }
    }
    return '';
  }

  function run() {
    var courses = [];
    var semesterName = '';

    try {
      semesterName = readSemesterName();
    } catch (e) {
      semesterName = '';
    }

    var body = deepQuery('table tbody');
    if (!body) {
      return fail('findTable', '没找到课表表格，请确认已进入「我的课表」页面并完成登录');
    }

    var rows = body.querySelectorAll('tr');
    if (!rows || rows.length === 0) {
      return fail('emptyTable', '课表表格是空的，可能是本学期还没有选课');
    }

    for (var r = 0; r < rows.length; r++) {
      try {
        var tds = rows[r].querySelectorAll('td');
        if (tds.length < 7) {
          continue; // 表头或分组行
        }
        var classNumber = (tds[1].textContent || '').trim();
        var courseName = (tds[2].textContent || '').trim();
        if (!courseName) {
          continue;
        }
        var teacher = tds.length > 4 ? (tds[4].textContent || '').trim() : '';
        var timeLocFull = (tds[6].textContent || '').trim();
        var testTime = tds.length > 10 ? (tds[10].textContent || '').trim() || null : null;
        var info = tds.length > 8 ? (tds[8].textContent || '').trim() || null : null;

        if (!timeLocFull) {
          continue;
        }

        // 一门课可能有多个时间段，用「,周」或「，」切分
        var segments = timeLocFull.split(/,周|，/);
        for (var s = 0; s < segments.length; s++) {
          var seg = segments[s].trim();
          if (!seg) {
            continue;
          }

          // 情况一：自由时间（无固定教室）
          if (/自由时间/.test(seg)) {
            var freeMatch = seg.match(/([\d\-,，]+)周/);
            courses.push({
              name: courseName,
              classroom: '自由地点',
              class_number: classNumber,
              teacher: teacher,
              test_time: testTime,
              test_location: null,
              link: null,
              weeks: parseWeeks(freeMatch ? freeMatch[1] : '1-18'),
              week_time: 0,
              start_time: 0,
              time_count: 0,
              import_type: 1,
              info: info,
              data: null
            });
            continue;
          }

          // 情况二：标准格式「周三 2-4节 1-3周,10-13周 仙Ⅱ-304」
          var m = seg.match(
            /([一二三四五六日])\s*(?:周)?\s*(\d+)\s*-\s*(\d+)\s*节\s*([\d\-,，周]+(?:[（(]\s*[单双]\s*[)）])?)\s*(.+)/
          );
          if (!m) {
            continue;
          }
          var weekDay = WEEK_MAP[m[1]];
          var startSlot = parseInt(m[2], 10);
          var endSlot = parseInt(m[3], 10);
          var classroom = (m[5] || '').trim();
          var weeks = parseWeeks(m[4]);
          if (!weekDay || isNaN(startSlot) || isNaN(endSlot) || weeks.length === 0) {
            continue;
          }

          courses.push({
            name: courseName,
            classroom: classroom,
            class_number: classNumber,
            teacher: teacher,
            test_time: testTime,
            test_location: null,
            link: null,
            weeks: weeks,
            week_time: weekDay,
            start_time: startSlot,
            // 与 nju.app 保持一致的语义：time_count = 末节 - 首节
            time_count: endSlot - startSlot,
            import_type: 1,
            info: info,
            data: null
          });
        }
      } catch (rowErr) {
        // 单行出错不影响整体
        continue;
      }
    }

    if (courses.length === 0) {
      return fail('emptyCourses', '表格读到了但解析不出课程，教务系统可能改版了，请反馈页面截图');
    }

    return emit({
      ok: true,
      data: {
        name: semesterName || '当前学期',
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
