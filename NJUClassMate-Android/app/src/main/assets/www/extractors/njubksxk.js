/**
 * 南京大学**本科生选课系统**（xk.nju.edu.cn）—— 课表抓取脚本
 *
 * 适合刚选完课的场景：选课结果页里已经列出了本学期所有课程。
 *
 * 与「本科生教务系统」那份脚本的差别：
 *   教务系统是标准 table，列顺序固定；
 *   选课系统是 div 布局，表头是 .course-head、表体是 .course-body，
 *   而且列顺序**不固定**，所以这里先从表头文字里动态找出各列的索引。
 *
 * 溯源：解析规则来自开源项目 NJU-Class-Shedule-Flutter 的 api/tools/njubksxk.js，
 * 本版本改了三处：
 *   1. 统一走 window.njuBridge 回传（失败时退回 return），与本工程其它脚本一致；
 *   2. 修了单双周的奇偶判断（原实现在"2-15周(单)"这类起止同奇偶性不一致时会取错周）；
 *   3. 每一行单独 try/catch，一行解析失败不影响整张表。
 *
 * 时间地点的原始格式（.course-body 行内每个 div 一段）：
 *   「周三 2-4节 1-3周,10-13周 仙Ⅱ-304」
 *   「周一 3-4节 1-16周 自由时间」
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

  /**
   * 单双周的正确取法：先按奇偶对齐起点，再按步长 2 走。
   * 原实现直接 `for (j = start; j <= end; j += 2)`，
   * 遇到"2-15周(单)"这种起点奇偶性不对的写法会取成偶数周。
   */
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

  /** "1-3周,10-13周" / "2-18周(双)" → [1,2,3,10,11,12,13] */
  function parseWeeks(raw) {
    var weeks = [];
    if (!raw) {
      return weeks;
    }
    var parts = String(raw).split(/[,，]/);
    for (var i = 0; i < parts.length; i++) {
      var seg = parts[i];
      var isSingle = seg.indexOf('单') >= 0;
      var isDouble = seg.indexOf('双') >= 0;
      var flag = isSingle ? 1 : (isDouble ? 2 : 0);
      var m = seg.match(/(\d{1,2})\s*-\s*(\d{1,2})\s*周/);
      if (m) {
        var list = expandWeeks(parseInt(m[1], 10), parseInt(m[2], 10), flag);
        for (var a = 0; a < list.length; a++) {
          weeks.push(list[a]);
        }
        continue;
      }
      var single = seg.match(/(\d{1,2})\s*周/);
      if (single) {
        weeks.push(parseInt(single[1], 10));
      }
    }
    weeks.sort(function (a, b) { return a - b; });
    var dedup = [];
    for (var k = 0; k < weeks.length; k++) {
      if (dedup.indexOf(weeks[k]) < 0) {
        dedup.push(weeks[k]);
      }
    }
    return dedup;
  }

  /** 取最后一个匹配的元素（页面上可能有多个 tab 各自的表） */
  function lastOf(list) {
    return list && list.length > 0 ? list[list.length - 1] : null;
  }

  function textOf(node) {
    return node && node.textContent ? node.textContent.trim() : '';
  }

  function run() {
    // ---------- 学期名 ----------
    var semesterName = '';
    try {
      var termNodes = document.getElementsByClassName('currentTerm');
      semesterName = textOf(termNodes[0]);
    } catch (e) {
      semesterName = '';
    }

    // ---------- 表头：动态定位各列 ----------
    var head = lastOf(document.getElementsByClassName('course-head'));
    if (!head) {
      return fail('findHead', '没找到选课结果表格（.course-head），请确认已经进入选课结果页面');
    }

    var body = lastOf(document.getElementsByClassName('course-body'));
    if (!body) {
      return fail('findBody', '没找到选课结果表格（.course-body），请确认已经进入选课结果页面');
    }

    var infoIndex = 3;
    var nameIndex = 1;
    var teacherIndex = 2;
    var noteIndex = 6;
    var rows;
    try {
      var headRow = head.children[0];
      var cells = headRow && headRow.children ? headRow.children : [];
      for (var h = 0; h < cells.length; h++) {
        var label = textOf(cells[h]);
        if (label.indexOf('时间地点') >= 0) {
          infoIndex = h;
        } else if (label.indexOf('课程名') >= 0) {
          nameIndex = h;
        } else if (label.indexOf('教师') >= 0) {
          teacherIndex = h;
        } else if (label.indexOf('备注') >= 0) {
          noteIndex = h;
        }
      }
      rows = body.children;
    } catch (e) {
      return fail('readHead', '读取表头失败，选课系统可能改版了');
    }

    if (!rows || rows.length === 0) {
      return fail('emptyRows', '选课结果表格是空的，可能是本学期还没选课');
    }

    // ---------- 逐行解析 ----------
    var courses = [];
    for (var i = 0; i < rows.length; i++) {
      try {
        var row = rows[i];
        // 分组/小计行用这个 class 标记，跳过
        if (row.className && String(row.className).indexOf('wdbm-course-tr') >= 0) {
          continue;
        }
        var tds = row.children;
        if (!tds || tds.length <= infoIndex) {
          continue;
        }

        var courseName = textOf(tds[nameIndex]);
        if (!courseName) {
          continue;
        }
        var teacher = teacherIndex < tds.length ? textOf(tds[teacherIndex]) : '';

        // 备注挂在 title 属性上，取不到就算了
        var note = null;
        try {
          if (noteIndex < tds.length) {
            var attr = tds[noteIndex].attributes;
            if (attr && attr['title'] && attr['title'].value) {
              note = attr['title'].value;
            }
          }
        } catch (e2) {
          note = null;
        }

        // 时间地点这一格通常是若干个 div，每个 div 是一段上课安排。
        // 但也遇到过这一格直接是纯文本（没有子元素）的情况——
        // 那就把整格当作一段来解析，而不是直接把这一行丢掉。
        var infoNodes = tds[infoIndex].children;
        if (!infoNodes || infoNodes.length === 0) {
          infoNodes = [tds[infoIndex]];
        }

        for (var j = 0; j < infoNodes.length; j++) {
          var info = textOf(infoNodes[j]);
          if (!info) {
            continue;
          }

          var weekTime = 0;
          var startTime = 0;
          var timeCount = 0;
          var weeks = [];
          var classroom = '';

          if (info.indexOf('自由时间') < 0) {
            // 星期几取前两个字："周三"
            var dayChar = info.substring(0, 2);
            for (var key in WEEK_MAP) {
              if ('周' + key === dayChar || key === dayChar) {
                weekTime = WEEK_MAP[key];
              }
            }
            if (dayChar.length >= 2 && dayChar.charAt(0) === '周') {
              var wd = WEEK_MAP[dayChar.charAt(1)];
              if (wd) {
                weekTime = wd;
              }
            }
          }

          var timeMatch = info.match(/(\d{1,2})\s*-\s*(\d{1,2})\s*节/);
          if (timeMatch) {
            startTime = parseInt(timeMatch[1], 10);
            timeCount = parseInt(timeMatch[2], 10) - startTime;
          }

          // 周次：切成若干段分别解析，比原实现只取 info.split(" ")[2] 更稳
          var weekPart = info.match(/([\d\-,，]+\s*周(?:\s*[（(]?\s*[单双]\s*[)）]?)?(?:[,，][\d\-,，]+\s*周(?:\s*[（(]?\s*[单双]\s*[)）]?)?)*)/);
          if (weekPart) {
            weeks = parseWeeks(weekPart[1]);
          }
          if (weeks.length === 0) {
            // 拿不到周次就按全学期处理，总比整门课丢掉好
            for (var w = 1; w <= 18; w++) {
              weeks.push(w);
            }
          }

          // 教室：取最后一段空白之后的内容，若以"周"结尾或含"自由时间"则视为无教室
          var pieces = info.split(/\s+/);
          var last = pieces.length > 0 ? pieces[pieces.length - 1] : '';
          if (last && !/(\d{1,2}|单|双)周$/.test(last) && last.indexOf('自由时间') < 0) {
            classroom = last;
          } else if (info.indexOf('自由时间') >= 0) {
            classroom = '自由地点';
          }

          courses.push({
            name: courseName,
            classroom: classroom,
            class_number: '',
            teacher: teacher,
            test_time: null,
            test_location: null,
            link: null,
            weeks: weeks,
            week_time: weekTime,
            start_time: startTime,
            time_count: timeCount,
            import_type: 1,
            info: note,
            data: null
          });
        }
      } catch (rowErr) {
        continue;
      }
    }

    if (courses.length === 0) {
      return fail('emptyCourses', '表格读到了但解析不出课程，选课系统可能改版了，请反馈页面截图');
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
