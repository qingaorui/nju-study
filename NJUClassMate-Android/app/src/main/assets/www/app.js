/* ============================================================
   南哪儿课表 —— 界面逻辑
   
   所有"算"的部分都在原生 Kotlin 里（Engine.kt），
   这里只负责把 NJU.call() 拿回来的 JSON 画到屏幕上。
   这样保证只有一份实现，不会出现"两套代码算出两个答案"。
   ============================================================ */

(function () {
  'use strict';

  var state = null;        // 原生返回的完整状态
  var currentTab = 'today';
  // 初始必须是 0 而不是 1：refresh() 里只对 <1 的值做"设为当前周"，
  // 初始成 1 的话「本周」就永远停在第 1 周，不管你实际第几周。
  var viewingWeek = 0;
  var palette = ['#5B8FF9', '#61DDAA', '#F6BD16', '#7262FD', '#78D3F8',
                 '#9661BC', '#F6903D', '#008685', '#F08BB4', '#7F8FA6'];

  // ---------------------------------------------------------------- 全局报错条
  //
  // 任何运行时错误都弹成顶部红条。没有它，"按钮点了没反应 / 页面空白"
  // 在真机上无从查起——你只能看到"坏了"，看不到为什么坏。
  function showError(msg) {
    var b = $('errBanner');
    if (!b) {
      b = document.createElement('div');
      b.id = 'errBanner';
      b.style.cssText = 'position:fixed;top:0;left:0;right:0;z-index:99999;' +
        'background:#B3261E;color:#fff;font-size:12px;padding:8px 12px;' +
        'line-height:1.45;word-break:break-all;box-shadow:0 2px 8px rgba(0,0,0,.2)';
      document.body.appendChild(b);
    }
    b.textContent = '运行出错：' + msg;
  }
  window.addEventListener('error', function (e) {
    showError((e.message || '未知错误') + '（' + (e.lineno || '?') + ' 行）');
  });
  window.addEventListener('unhandledrejection', function (e) {
    var r = e.reason;
    showError('未处理的 Promise：' + (r && r.message ? r.message : String(r)));
  });

  // ---------------------------------------------------------------- 原生桥

  function native(method, args) {
    try {
      if (!window.NJU) return null;
      var raw = window.NJU.call(method, JSON.stringify(args || {}));
      return raw ? JSON.parse(raw) : null;
    } catch (e) {
      console.error('native call failed:', method, e);
      return null;
    }
  }

  function $(id) { return document.getElementById(id); }

  function esc(s) {
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  // ---------------------------------------------------------------- 刷新

  function refresh() {
    var s = native('state');
    if (!s) return;
    state = s;

    $('weekLabel').textContent = s.hasTimetable
      ? (s.weekIndex > 0 ? '第 ' + s.weekIndex + ' 周' : '假期中')
      : '南哪儿课表';
    $('semesterName').textContent = s.hasTimetable
      ? s.timetableName
      : '还没有导入课表';

    if (!s.hasTimetable) {
      $('emptyState').classList.remove('hidden');
      $('content').classList.add('hidden');
      return;
    }
    $('emptyState').classList.add('hidden');
    $('content').classList.remove('hidden');

    if (viewingWeek < 1) viewingWeek = s.weekIndex > 0 ? s.weekIndex : 1;
    renderHero();
    renderToday();
    renderWeek();
    renderExam();
    applySettingsToSheet();
  }

  // ---------------------------------------------------------------- 下一节课

  function renderHero() {
    var el = $('hero');
    var s = state;
    var html;

    if (s.ongoing && s.ongoing.length) {
      var o = s.ongoing[0];
      var left = minutesUntilEnd(o);
      html =
        '<div class="hero-top"><span>正在上课 · 今天</span>' +
        '<span>第' + o.startSlot + '-' + o.endSlot + '节</span></div>' +
        '<div class="hero-title">' + esc(o.name) + '</div>' +
        '<div class="hero-line">' + esc(timeLineOf(o)) + '</div>' +
        '<div class="hero-bottom"><span class="hero-loc">' + esc(o.classroom) +
        (o.teacher ? ' · ' + esc(o.teacher) : '') + '</span>' +
        '<span class="hero-remain">还剩 ' + fmtMinutes(left) + '</span></div>' +
        (s.ongoing.length > 1
          ? '<div class="hero-hint">同时段还有 ' + (s.ongoing.length - 1) + ' 门课：' +
            esc(s.ongoing[1].name) + '</div>'
          : '');
      el.className = 'hero ongoing';

    } else if (s.next) {
      var n = s.next;
      var hint = '';
      if (s.restOfToday && s.restOfToday.length > 1) {
        hint = '今天还有 ' + (s.restOfToday.length - 1) + ' 节';
      }
      html =
        '<div class="hero-top"><span>下一节课 · ' + esc(dayLabel(n)) + '</span>' +
        '<span>第' + n.startSlot + '-' + n.endSlot + '节</span></div>' +
        '<div class="hero-title">' + esc(n.name) + '</div>' +
        '<div class="hero-line">' + esc(timeLineOf(n)) + '</div>' +
        '<div class="hero-bottom"><span class="hero-loc">' + esc(n.classroom) +
        (n.teacher ? ' · ' + esc(n.teacher) : '') + '</span>' +
        '<span class="hero-remain">' + esc(n.remainText) + '</span></div>' +
        (hint ? '<div class="hero-hint">' + hint + '</div>' : '');
      el.className = 'hero';

    } else {
      var examHint = (s.exams && s.exams.length)
        ? '距离最近一场考试还有 ' + s.exams[0].daysLeft + ' 天'
        : '享受空闲时间';
      html =
        '<div class="hero-title">最近的课都上完了</div>' +
        '<div class="hero-line">' + esc(examHint) + '</div>';
      el.className = 'hero idle';
    }
    el.innerHTML = html;
  }

  function timeLineOf(o) {
    var wd = '周' + '一二三四五六日'[o.weekday - 1];
    var slots = (o.startSlot === o.endSlot)
      ? '第' + o.startSlot + '节'
      : '第' + o.startSlot + '-' + o.endSlot + '节';
    return wd + ' ' + slots + ' · ' + o.startClock + '-' + o.endClock;
  }

  function dayLabel(o) {
    var today = state.now ? state.now.substring(0, 10) : '';
    if (o.dateKey === today) return '今天';
    return o.dateKey;
  }

  function minutesUntilEnd(o) {
    // 用原生给的 startClock/endClock 反推，避免 JS 侧再写一套日期逻辑
    var now = new Date();
    var nowMin = now.getHours() * 60 + now.getMinutes();
    return Math.max(0, clockToMin(o.endClock) - nowMin);
  }

  function clockToMin(c) {
    var p = String(c).split(':');
    return (parseInt(p[0], 10) || 0) * 60 + (parseInt(p[1], 10) || 0);
  }

  function fmtMinutes(m) {
    if (m < 60) return m + ' 分钟';
    var h = Math.floor(m / 60), r = m % 60;
    return r === 0 ? h + ' 小时' : h + ' 小时 ' + r + ' 分';
  }

  // ---------------------------------------------------------------- 今日

  function renderToday() {
    var el = $('tabToday');
    var list = state.today || [];
    var html = '';

    if (!list.length) {
      var idleHint = state.settings.lock_notification_enabled
        ? '锁屏通知和桌面小组件会显示明天的安排'
        : (state.settings.today_card_show_tomorrow
          ? '桌面小组件会自动显示明天的课' : '好好休息');
      html = '<div class="card"><div class="card-title">今天没有课</div>' +
             '<div class="card-sub">' + idleHint + '</div></div>';
    } else {
      list.forEach(function (o) {
        html +=
          '<div class="day-row ' + o.status + '">' +
          '<div class="day-time">' + esc(o.startClock) + '<small>' + esc(o.endClock) + '</small></div>' +
          '<div class="day-bar"></div>' +
          '<div class="day-body">' +
          '<div class="day-name">' + esc(o.name) +
          (o.status === 'ongoing' ? '<span class="badge-now">进行中</span>' : '') +
          '</div>' +
          '<div class="day-meta">第' + o.startSlot + '-' + o.endSlot + '节 · ' +
          esc(o.classroom) + (o.teacher ? ' · ' + esc(o.teacher) : '') + '</div>' +
          '</div></div>';
      });
    }

    if (state.freeCourses && state.freeCourses.length) {
      html += '<div class="card"><div class="card-title">自由时间安排</div>';
      state.freeCourses.forEach(function (c) {
        html += '<div class="card-sub">' + esc(c.name) +
                (c.teacher ? ' · ' + esc(c.teacher) : '') + '</div>';
      });
      html += '</div>';
    }

    html += '<div class="section-hint">' +
            '共 ' + state.distinctCourses + ' 门课 · ' + state.segmentCount + ' 条安排</div>';
    el.innerHTML = html;
  }

  // ---------------------------------------------------------------- 本周

  function renderWeek() {
    var el = $('tabWeek');
    var data = native('week', viewingWeek);
    if (!data) { el.innerHTML = ''; return; }

    var total = data.totalWeeks;
    var slots = data.slots;
    var days = state.settings.show_weekend ? [1, 2, 3, 4, 5, 6, 7] : [1, 2, 3, 4, 5];
    var cellH = 50;

    var html =
      '<div class="week-nav">' +
      '<button id="prevWeek" ' + (viewingWeek <= 1 ? 'disabled' : '') + '>‹</button>' +
      '<div class="week-current">第 ' + viewingWeek + ' 周</div>' +
      '<button id="nextWeek" ' + (viewingWeek >= total ? 'disabled' : '') + '>›</button>' +
      '</div>';

    if (viewingWeek !== state.weekIndex) {
      html += '<div class="week-warn">正在查看非本周的课表</div>';
    }

    // 表头
    html += '<div class="grid-wrap"><div class="grid">';
    html += '<div class="grid-head"><div class="g-time"></div>';
    days.forEach(function (d) {
      html += '<div class="g-day">周' + '一二三四五六日'[d - 1] + '</div>';
    });
    html += '</div>';

    // 网格 + 课程块
    html += '<div class="grid-body" style="height:' + (cellH * slots.length) + 'px">';
    html += '<div class="grid-bg" style="--cell-h:' + cellH + 'px"><div class="g-time-col">';
    slots.forEach(function (s) {
      html += '<div class="g-time-cell">' + s.index + '<br>' + esc(s.start) + '</div>';
    });
    html += '</div>';
    days.forEach(function () {
      html += '<div class="g-day-col">';
      slots.forEach(function () {
        html += '<div class="g-cell"></div>';
      });
      html += '</div>';
    });
    html += '</div>';

    // 只渲染"当前显示的这些天"里的课。
    // 不过滤的话，周末的课在关闭「显示周末」时 days.indexOf 会返回 -1，
    // 块被定位到负坐标、裁到屏幕外，还污染同格子的均分计算。
    var blocks = data.blocks.filter(function (b) { return days.indexOf(b.weekday) >= 0; });

    // 同一 (星期, 起始节次) 上的多门课横向均分
    var groups = {};
    blocks.forEach(function (b) {
      var k = b.weekday + '#' + b.startSlot;
      (groups[k] = groups[k] || []).push(b);
    });

    var dayCount = days.length;
    blocks.forEach(function (b) {
      var k = b.weekday + '#' + b.startSlot;
      var group = groups[k];
      var idx = group.indexOf(b);
      var share = 100 / dayCount / group.length;
      var left = (days.indexOf(b.weekday)) * (100 / dayCount) + idx * share;

      var top = (b.startSlot - 1) * cellH + 2;
      var height = cellH * b.span - 4;
      var color = palette[hashOf(b.classNumber || b.name) % palette.length];

      html +=
        '<div class="gblock" style="left:calc(34px + ' + left + '% - ' + (left * 34 / 100) +
        'px);width:calc(' + share + '% - ' + (share * 34 / 100) + 'px - 3px);top:' + top +
        'px;height:' + height + 'px;background:' + color + '"' +
        ' data-name="' + esc(b.name) + '" data-room="' + esc(b.classroom) + '"' +
        ' data-teacher="' + esc(b.teacher) + '" data-weeks="' + esc(b.weeks) + '"' +
        ' data-exam="' + esc(b.testTime || '') + '">' +
        '<b>' + esc(b.name) + '</b>' +
        (b.span > 1 ? '<i>' + esc(b.classroom) + '</i>' : '') +
        (b.conflict ? '<span class="flag">冲</span>' : '') +
        '</div>';
    });

    html += '</div></div></div>';
    html += '<div class="section-hint">点课程块看详情 · 同一格里的多门课是「免修不免考」冲突</div>';

    if (data.freeCourses && data.freeCourses.length) {
      html += '<div class="card" style="margin-top:12px"><div class="card-title">自由时间安排</div>';
      data.freeCourses.forEach(function (c) {
        html += '<div class="card-sub">' + esc(c.name) +
                (c.teacher ? ' · ' + esc(c.teacher) : '') + ' · ' + esc(c.weeks) + '</div>';
      });
      html += '</div>';
    }

    el.innerHTML = html;

    var prev = $('prevWeek');
    var next = $('nextWeek');
    if (prev) prev.onclick = function () { viewingWeek--; renderWeek(); };
    if (next) next.onclick = function () { viewingWeek++; renderWeek(); };

    Array.prototype.forEach.call(el.querySelectorAll('.gblock'), function (node) {
      node.onclick = function () {
        var d = node.dataset;
        alert(d.name + '\n\n地点：' + (d.room || '—') +
              '\n教师：' + (d.teacher || '—') +
              '\n周次：' + d.weeks +
              (d.exam ? '\n考试：' + d.exam : ''));
      };
    });
  }

  function hashOf(s) {
    var h = 0;
    for (var i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) % 100000;
    return h;
  }

  // ---------------------------------------------------------------- 考试

  function renderExam() {
    var el = $('tabExam');
    var list = state.exams || [];
    var html = '';

    if (!list.length) {
      html = '<div class="card"><div class="card-title">没有解析到考试安排</div>' +
             '<div class="card-sub">教务系统里填写了考试时间的课程才会出现在这里</div></div>';
    } else {
      list.forEach(function (e) {
        var urgent = e.daysLeft >= 0 && e.daysLeft <= 7;
        html +=
          '<div class="exam-row"><div class="exam-body">' +
          '<div class="exam-name">' + esc(e.courseName) + '</div>' +
          '<div class="exam-meta">' + esc(e.raw) +
          (e.location ? ' · ' + esc(e.location) : '') + '</div></div>' +
          '<div class="exam-days' + (urgent ? ' urgent' : '') + '">' +
          (e.daysLeft >= 0 ? e.daysLeft + ' 天' : '待定') + '</div></div>';
      });
    }
    el.innerHTML = html;
  }

  // ---------------------------------------------------------------- 分段切换

  Array.prototype.forEach.call(document.querySelectorAll('.seg-item'), function (btn) {
    btn.onclick = function () {
      currentTab = btn.dataset.tab;
      Array.prototype.forEach.call(document.querySelectorAll('.seg-item'), function (b) {
        b.classList.toggle('active', b === btn);
      });
      $('tabToday').classList.toggle('hidden', currentTab !== 'today');
      $('tabWeek').classList.toggle('hidden', currentTab !== 'week');
      $('tabExam').classList.toggle('hidden', currentTab !== 'exam');
      if (currentTab === 'week') renderWeek();
    };
  });

  // ---------------------------------------------------------------- 设置面板

  function openSheet(id, maskId) {
    $(id).classList.remove('hidden');
    $(maskId).classList.remove('hidden');
  }

  function closeSheet(id, maskId) {
    $(id).classList.add('hidden');
    $(maskId).classList.add('hidden');
  }

  $('btnSettings').onclick = function () {
    applySettingsToSheet();
    openSheet('settingsSheet', 'sheetMask');
  };
  $('btnCloseSheet').onclick = function () { closeSheet('settingsSheet', 'sheetMask'); };
  $('sheetMask').onclick = function () { closeSheet('settingsSheet', 'sheetMask'); };

  function applySettingsToSheet() {
    if (!state) return;
    var s = state.settings;
    $('swRemind').checked = !!s.remind_enabled;
    $('swAuto').checked = !!s.auto_refresh_enabled;
    $('swWeekend').checked = !!s.show_weekend;
    $('swTomorrow').checked = !!s.today_card_show_tomorrow;
    // 这两个漏初始化过：开关永远显示"关"，看着就像按钮坏了
    $('swLockNotify').checked = !!s.lock_notification_enabled;
    $('swLockTomorrow').checked = !!s.lock_notification_show_tomorrow;

    // 现在是第几周 步进器
    var wk = state.weekIndex > 0 ? state.weekIndex : 0;
    $('weekValue').textContent = wk > 0 ? wk : '—';
    $('valSemesterStart').textContent = s.semester_start_monday
      ? '开学第一周周一：' + s.semester_start_monday
      : '点 + 设置现在是第几周，自动反推开学日期';

    var syncAt = state.lastSyncAt ? new Date(state.lastSyncAt) : null;
    $('lastSync').textContent = syncAt
      ? '最近同步：' + syncAt.toLocaleString('zh-CN') + '（仅本机，不上传）'
      : '仅保存在本机，不上传服务器';

    // 提醒提前量
    var chips = $('remindChips');
    chips.innerHTML = '';
    [5, 10, 15, 20, 30].forEach(function (m) {
      var b = document.createElement('button');
      b.className = 'chip' + (s.remind_before_minutes === m ? ' active' : '');
      b.type = 'button';
      b.textContent = m + ' 分';
      b.onclick = function () { patchSettings({ remind_before_minutes: m }); };
      chips.appendChild(b);
    });

    // 本机适配状态跟着一起刷。
    // 用户点了某一项跳去系统设置、改完回来时，onResume → refresh() → 这里，
    // 状态就自动更新了，不需要轮询也不需要用户手动刷新。
    renderAdapt();
    // 锁屏通知权限状态也一起刷
    refreshNotifyStatus();
  }

  // ---------------------------------------------------------------- 本机适配

  /**
   * 这台手机上还需要补哪些授权。
   *
   * 数据全部来自原生（deviceInfo）：哪几项该显示、各自什么状态，
   * 由 core/DeviceAdapt.kt 的 buildAdaptationPlan() 决定，
   * 前端只负责画。这样"该提示什么"的规则能被 JVM 单测覆盖。
   */
  function renderAdapt() {
    var info = native('deviceInfo');
    var list = $('adaptList');

    if (!info) {
      $('deviceLine').textContent = '设备信息不可用';
      $('adaptTitle').textContent = '本机适配';
      list.innerHTML = '';
      return;
    }

    $('deviceLine').textContent = info.display || '';
    $('adaptTitle').textContent = '本机适配 · ' + (info.summary || '');

    var html = '';
    (info.items || []).forEach(function (it) {
      var mark, cls;
      if (it.ok === true) {
        mark = '✓'; cls = 'ok';
      } else if (it.ok === false) {
        // critical 的才标红：不处理会真的导致功能失效
        mark = '!'; cls = it.critical ? 'warn' : 'unknown';
      } else {
        // null = 系统没有公开接口，读不到，只能让用户自己去确认
        mark = '?'; cls = 'unknown';
      }
      html +=
        '<div class="row row-tap' + (it.ok === null ? ' adapt-unknown' : '') +
        '" data-target="' + esc(it.target) + '">' +
        '<div class="row-col">' +
        '<span class="row-label"><span class="adapt-dot ' + cls + '">' + mark + '</span> ' +
        esc(it.title) + '</span>' +
        '<span class="row-desc">' + esc(it.desc) + '</span>' +
        '</div><span class="row-chev">›</span></div>';
    });
    list.innerHTML = html;

    Array.prototype.forEach.call(list.querySelectorAll('.row-tap'), function (row) {
      row.onclick = function () { openAdapt(row.dataset.target); };
    });
  }

  function openAdapt(target) {
    var res = native('openDeviceSetting', { target: target });
    if (res && res.ok === false) {
      alert('打不开这个系统设置页：\n' + ((res && res.error) || '未知原因') +
            '\n\n请手动到「设置 → 应用 → 南哪儿课表」里检查这一项。');
    }
  }

  /**
   * 改设置：把当前设置整体回传，只覆盖改动的那一项。
   * 传全量而不是增量，是因为原生侧解析要构造完整 Settings 对象，
   * 缺字段会走默认值，反而容易把用户已有的设置重置掉。
   */
  function patchSettings(patch) {
    var s = state.settings;
    var next = {};
    Object.keys(s).forEach(function (k) { next[k] = s[k]; });
    Object.keys(patch).forEach(function (k) { next[k] = patch[k]; });
    var res = native('saveSettings', next);
    if (res && res.ok === false) {
      alert('保存失败：' + res.error);
      return;
    }
    refresh();
  }

  $('swRemind').onchange = function () { patchSettings({ remind_enabled: $('swRemind').checked }); };
  $('swAuto').onchange = function () { patchSettings({ auto_refresh_enabled: $('swAuto').checked }); };
  $('swWeekend').onchange = function () { patchSettings({ show_weekend: $('swWeekend').checked }); };
  $('swTomorrow').onchange = function () { patchSettings({ today_card_show_tomorrow: $('swTomorrow').checked }); };
  $('swLockNotify').onchange = function () {
    patchSettings({ lock_notification_enabled: $('swLockNotify').checked });
  };
  $('swLockTomorrow').onchange = function () {
    patchSettings({ lock_notification_show_tomorrow: $('swLockTomorrow').checked });
  };

  // ---------------------------------------------------------------- 锁屏通知

  /**
   * 常驻通知看不见时，原因几乎都不在 App 里，而是通知权限或系统锁屏设置。
   * 这两种情况用户自己看不出来，所以必须在这里明说，
   * 否则用户只会认为"这功能是坏的"。
   */
  function refreshNotifyStatus() {
    var el = $('notifyStatus');
    var info = native('lockNotifyInfo');
    if (!info) { el.textContent = '点这里立刻重发一次'; return; }

    if (!info.permissionGranted) {
      el.textContent = '⚠ 通知权限未开启，锁屏上看不到。点这里去系统设置里开启';
      el.style.color = '#E5484D';
      return;
    }
    if (info.channelBlocked) {
      el.textContent = '⚠ 「锁屏课表」通知渠道被关闭了，去系统设置里重新打开';
      el.style.color = '#E5484D';
      return;
    }
    el.style.color = '';
    el.textContent = '权限正常 · 若锁屏看不到，检查系统设置里的「锁屏通知」是否被关掉';
  }

  $('rowPushNotify').onclick = function () {
    var res = native('pushLockNotify');
    if (res && res.ok === false) {
      alert('推送失败：' + res.error);
      return;
    }
    refreshNotifyStatus();
    var info = native('lockNotifyInfo');
    if (info && !info.permissionGranted) {
      alert('锁屏显示需要通知权限，但当前没有开启。\n\n' +
            '请到「系统设置 → 通知和状态栏 → 南哪儿课表」里允许通知，\n' +
            '并确认「锁屏通知」没有被设为隐藏。');
    } else if (!state.settings.lock_notification_enabled) {
      alert('已推送，但「锁屏常驻通知」开关是关着的，所以现在没有显示。\n' +
            '打开上面的开关即可。');
    } else {
      alert('已推送。\n\n息屏看一眼锁屏，应该能看到下一节课和倒计时。\n' +
            '如果看不到，检查系统设置 → 通知 → 锁屏通知 是否被设为「不显示」。');
    }
  };

  // 「现在是第几周」步进器：设第 N 周，原生侧反推开学周一。
  // 比原来弹系统日期选择器可靠得多（WebView 里 date 选择器时灵时不灵）。
  function setWeek(n) {
    n = Math.max(1, Math.min(30, n));
    var res = native('setCurrentWeek', { week: n });
    if (res && res.ok === false) { alert('保存失败：' + res.error); return; }
    refresh();
  }

  $('weekMinus').onclick = function () {
    var cur = state.weekIndex > 0 ? state.weekIndex : 1;
    setWeek(cur - 1);
  };
  $('weekPlus').onclick = function () {
    var cur = state.weekIndex > 0 ? state.weekIndex : 0;
    setWeek(cur + 1);
  };

  function pad2(n) { return n < 10 ? '0' + n : '' + n; }

  $('rowReimport').onclick = function () {
    closeSheet('settingsSheet', 'sheetMask');
    native('openImport');
  };

  $('rowExportIcs').onclick = function () {
    var res = native('exportIcs');
    if (res && res.ok) {
      alert('日历文件已导出到「下载」目录：\n' + res.path +
            '\n\n用系统日历打开它即可把课程导进日历。');
    } else {
      alert('导出失败：' + ((res && res.error) || '未知错误'));
    }
  };

  $('rowClear').onclick = function () {
    if (!confirm('将删除本机保存的课表、提醒和小组件数据。\n教务系统里的选课不受影响，之后可以重新导入。\n\n确认清空？')) return;
    native('clearTimetable');
    closeSheet('settingsSheet', 'sheetMask');
    viewingWeek = 1;
    refresh();
  };

  $('btnImportEmpty').onclick = function () { native('openImport'); };

  // ---------------------------------------------------------------- 作息校准

  var editorSlots = [];

  $('rowSlotEditor').onclick = function () {
    editorSlots = (state.settings.time_slots || []).map(function (s) {
      return { index: s.index, start: s.start, end: s.end };
    });
    renderSlotEditor();
    openSheet('slotSheet', 'slotMask');
  };
  $('btnSlotDone').onclick = function () { closeSheet('slotSheet', 'slotMask'); };
  $('slotMask').onclick = function () { closeSheet('slotSheet', 'slotMask'); };

  function renderSlotEditor() {
    // 整体平移
    var chips = $('shiftChips');
    chips.innerHTML = '';
    [-10, -5, 5, 10].forEach(function (d) {
      var b = document.createElement('button');
      b.className = 'chip';
      b.type = 'button';
      b.textContent = d > 0 ? '延后 ' + d + ' 分' : '提前 ' + (-d) + ' 分';
      b.onclick = function () { shiftAll(d); };
      chips.appendChild(b);
    });

    // 逐节列表
    var list = $('slotList');
    list.innerHTML = '';
    editorSlots.forEach(function (s, i) {
      var dur = clockToMin(s.end) - clockToMin(s.start);
      var row = document.createElement('div');
      row.className = 'row slot-row';
      row.innerHTML =
        '<span class="slot-index">第 ' + s.index + ' 节</span>' +
        '<button class="slot-time" type="button" data-i="' + i + '" data-k="start">' + s.start + '</button>' +
        '<span style="color:var(--text-3)">–</span>' +
        '<button class="slot-time" type="button" data-i="' + i + '" data-k="end">' + s.end + '</button>' +
        '<span class="slot-dur' + (dur <= 0 ? ' bad' : '') + '">' +
        (dur <= 0 ? '时间不对' : dur + ' 分钟') + '</span>';
      list.appendChild(row);
    });

    Array.prototype.forEach.call(list.querySelectorAll('.slot-time'), function (btn) {
      btn.onclick = function () {
        pickTime(parseInt(btn.dataset.i, 10), btn.dataset.k);
      };
    });
  }

  function shiftAll(delta) {
    editorSlots = editorSlots.map(function (s) {
      return { index: s.index, start: shift(s.start, delta), end: shift(s.end, delta) };
    });
    persistSlots('已整体调整');
  }

  function shift(clock, delta) {
    var v = Math.max(0, Math.min(23 * 60 + 59, clockToMin(clock) + delta));
    return pad2(Math.floor(v / 60)) + ':' + pad2(v % 60);
  }

  function pickTime(index, kind) {
    var slot = editorSlots[index];
    $('timeTitle').textContent = '第 ' + slot.index + ' 节 · ' + (kind === 'start' ? '开始' : '结束') + '时间';
    var parts = String(slot[kind] || '08:00').split(':');
    $('timeHour').value = parseInt(parts[0], 10) || 0;
    $('timeMinute').value = parseInt(parts[1], 10) || 0;
    openSheet('timeSheet', 'timeMask');

    $('btnTimeOk').onclick = function () {
      var h = parseInt($('timeHour').value, 10);
      var m = parseInt($('timeMinute').value, 10);
      closeSheet('timeSheet', 'timeMask');
      if (isNaN(h) || isNaN(m)) return;
      h = Math.max(0, Math.min(23, h));
      m = Math.max(0, Math.min(59, m));
      editorSlots[index][kind] = pad2(h) + ':' + pad2(m);
      persistSlots('第 ' + slot.index + ' 节已更新');
    };
    $('btnTimeCancel').onclick = function () { closeSheet('timeSheet', 'timeMask'); };
    $('timeMask').onclick = function () { closeSheet('timeSheet', 'timeMask'); };
  }

  function persistSlots(msg) {
    var next = {};
    Object.keys(state.settings).forEach(function (k) { next[k] = state.settings[k]; });
    next.time_slots = editorSlots;
    native('saveSettings', next);
    refresh();
    renderSlotEditor();
    if (msg) {
      // 轻量反馈：不弹 alert，避免打断连续编辑
      var chips = $('shiftChips');
      var tip = document.createElement('span');
      tip.style.cssText = 'font-size:12px;color:var(--text-3);margin-left:6px';
      tip.textContent = msg;
      chips.appendChild(tip);
      setTimeout(function () { if (tip.parentNode) tip.parentNode.removeChild(tip); }, 1600);
    }
  }

  // ---------------------------------------------------------------- 手动录课

  var courseWeekday = 1;    // 1..7
  var courseParity = 'all'; // all / odd / even

  $('rowAddCourse').onclick = function () {
    renderManualForm();
    openSheet('courseSheet', 'courseMask');
  };
  $('btnCourseClose').onclick = function () { closeSheet('courseSheet', 'courseMask'); };
  $('courseMask').onclick = function () { closeSheet('courseSheet', 'courseMask'); };

  function renderManualForm() {
    // 星期 chips
    var wd = $('cWeekday');
    wd.innerHTML = '';
    ['一', '二', '三', '四', '五', '六', '日'].forEach(function (name, i) {
      var b = document.createElement('button');
      b.type = 'button';
      b.className = 'chip' + (courseWeekday === i + 1 ? ' active' : '');
      b.textContent = name;
      b.onclick = function () { courseWeekday = i + 1; renderManualForm(); };
      wd.appendChild(b);
    });

    // 周次模式 chips
    var pr = $('cParity');
    pr.innerHTML = '';
    [['all', '每周'], ['odd', '单周'], ['even', '双周']].forEach(function (p) {
      var b = document.createElement('button');
      b.type = 'button';
      b.className = 'chip' + (courseParity === p[0] ? ' active' : '');
      b.textContent = p[1];
      b.onclick = function () { courseParity = p[0]; renderManualForm(); };
      pr.appendChild(b);
    });

    renderManualList();
  }

  function renderManualList() {
    var list = $('manualList');
    var items = state.manualCourses || [];
    $('manualTitle').textContent = items.length ? '已手动添加（' + items.length + '）' : '已手动添加';
    if (!items.length) {
      list.innerHTML = '<div class="row"><div class="row-col">' +
        '<span class="row-desc">还没有手动添加的课程</span></div></div>';
      return;
    }
    list.innerHTML = '';
    items.forEach(function (c) {
      var wd = c.weekday ? '周' + '一二三四五六日'[c.weekday - 1] : '自由时间';
      var row = document.createElement('div');
      row.className = 'manual-item';
      row.innerHTML =
        '<div class="row-col">' +
        '<span class="row-label">' + esc(c.name) + '</span>' +
        '<span class="row-desc">' + wd + ' 第' + c.startSlot + '-' + c.endSlot + '节 · ' +
        esc(c.weeks) + (c.classroom ? ' · ' + esc(c.classroom) : '') + '</span>' +
        '</div>' +
        '<button class="manual-del" type="button" data-id="' + esc(c.classNumber) + '">删除</button>';
      list.appendChild(row);
    });
    Array.prototype.forEach.call(list.querySelectorAll('.manual-del'), function (btn) {
      btn.onclick = function () {
        if (!confirm('删除这门手动添加的课程？')) return;
        native('removeCourse', { classNumber: btn.dataset.id });
        refresh();
        renderManualForm();
      };
    });
  }

  $('btnCourseSave').onclick = function () {
    var name = $('cName').value.trim();
    var startSlot = parseInt($('cStartSlot').value, 10);
    var endSlot = parseInt($('cEndSlot').value, 10) || startSlot;
    var weekStart = parseInt($('cWeekStart').value, 10) || 1;
    var weekEnd = parseInt($('cWeekEnd').value, 10) || weekStart;

    if (!name) { alert('请填写课程名'); return; }
    if (isNaN(startSlot) || startSlot < 1) { alert('请填写起始节次（第 1 节起）'); return; }

    var res = native('addCourse', {
      name: name,
      weekday: courseWeekday,
      startSlot: startSlot,
      endSlot: endSlot,
      weekStart: weekStart,
      weekEnd: weekEnd,
      parity: courseParity,
      classroom: $('cClassroom').value,
      teacher: $('cTeacher').value,
      testTime: $('cTestTime').value
    });
    if (res && res.ok === false) { alert('保存失败：' + res.error); return; }

    // 清空表单，方便连续录
    $('cName').value = '';
    $('cClassroom').value = '';
    $('cTeacher').value = '';
    $('cTestTime').value = '';
    refresh();
    renderManualForm();
  };

  // ---------------------------------------------------------------- 返回键

  window.NJUApp = {
    refresh: refresh,
    /** 返回 true 表示"我处理了"，原生就不会退出 App */
    onBack: function () {
      if (!$('timeSheet').classList.contains('hidden')) { closeSheet('timeSheet', 'timeMask'); return true; }
      if (!$('slotSheet').classList.contains('hidden')) { closeSheet('slotSheet', 'slotMask'); return true; }
      if (!$('courseSheet').classList.contains('hidden')) { closeSheet('courseSheet', 'courseMask'); return true; }
      if (!$('settingsSheet').classList.contains('hidden')) { closeSheet('settingsSheet', 'sheetMask'); return true; }
      if (currentTab !== 'today') {
        document.querySelector('.seg-item[data-tab="today"]').click();
        return true;
      }
      return false;
    }
  };

  // ---------------------------------------------------------------- 启动

  // 前台每分钟重算一次倒计时（纯本地计算，不走原生）
  setInterval(function () {
    if (document.visibilityState === 'visible') refresh();
  }, 60000);

  document.addEventListener('visibilitychange', function () {
    if (document.visibilityState === 'visible') refresh();
  });

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', refresh);
  } else {
    refresh();
  }
})();
