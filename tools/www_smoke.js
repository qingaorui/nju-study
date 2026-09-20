#!/usr/bin/env node
/**
 * 用假 DOM + 假桥，真实执行 assets/www/app.js，抓运行时异常。
 *
 * 背景：界面是一套网页，逻辑全在 app.js 里。它是 IIFE，加载时会立刻
 * 绑定一堆事件 + 调 refresh() 渲染。如果其中任何一步抛异常，后面的事件
 * 就全绑不上（表现为"按钮点了没反应"）、渲染也不完整（表现为"课表显示 bug"）。
 *
 * 这种错误 `node --check`（只查语法）和 `check_bridge.py`（只查方法名）都抓不到，
 * 只能真的跑一遍。这里用最小 DOM stub 让它在 Node 里跑起来。
 *
 * 用法：  node tools/www_smoke.js
 * 退出码：0 无异常；1 有异常（会打印异常位置和调用点）
 */
'use strict';
const fs = require('fs');
const path = require('path');

const WWW = path.join(__dirname, '..', 'NJUClassMate-Android', 'app', 'src', 'main', 'assets', 'www');
const JS = fs.readFileSync(path.join(WWW, 'app.js'), 'utf8');

// ---------------------------------------------------------------- 最小 DOM stub

function makeClassList() {
  const set = new Set();
  return {
    add: (...c) => c.forEach(x => set.add(x)),
    remove: (...c) => c.forEach(x => set.delete(x)),
    toggle: (c, force) => {
      if (force === undefined) { set.has(c) ? set.delete(c) : set.add(c); }
      else if (force) set.add(c); else set.delete(c);
    },
    contains: c => set.has(c),
    toString: () => [...set].join(' ')
  };
}

function makeEl(id) {
  const el = {
    id: id || '',
    textContent: '',
    innerHTML: '',
    checked: false,
    value: '',
    className: '',
    classList: makeClassList(),
    style: {},
    dataset: {},
    type: '',
    children: [],
    appendChild(c) { this.children.push(c); return c; },
    removeChild(c) { const i = this.children.indexOf(c); if (i >= 0) this.children.splice(i, 1); return c; },
    querySelectorAll: () => [],
    querySelector: () => makeEl(''),
    setAttribute() {},
    click() {},
  };
  return el;
}

const els = {}; // 缓存，让多次 getElementById 拿到同一个对象
function getEl(id) {
  if (!(id in els)) els[id] = makeEl(id);
  return els[id];
}

const document = {
  readyState: 'complete',
  visibilityState: 'visible',
  getElementById: getEl,
  createElement: () => makeEl(''),
  querySelectorAll: () => [],
  querySelector: () => makeEl(''),
  addEventListener: () => {},
  body: makeEl('body'),
};

let intervalCb = null;
let lastWeekArg = -1;   // 记录最近一次 renderWeek 传入的周数（供断言用）
const window = {
  document,
  addEventListener: () => {},
  NJU: makeFakeBridge(),
};
function makeFakeBridge() {
  const settings = {
    semester_start_monday: '2026-09-14',
    time_slots: [1, 2, 3, 4, 5].map(i => ({ index: i, start: '08:00', end: '08:50' })),
    remind_enabled: true, remind_before_minutes: 15,
    show_weekend: false, today_card_show_tomorrow: true, today_card_force_tomorrow: false,
    auto_refresh_enabled: true, lock_notification_enabled: true, lock_notification_show_tomorrow: true,
  };
  const occ = (name, weekday, ss, se, sc, ec, status) => ({
    name, classroom: '仙Ⅱ-304', teacher: '张三', classNumber: name + '-code',
    dateKey: '2026-09-14', weekday, weekIndex: 1, startSlot: ss, endSlot: se,
    startClock: sc, endClock: ec, minutesFromNow: 60, remainText: '1 小时后', status,
  });
  const state = {
    hasTimetable: true, timetableName: '2026-2027学年 第1学期', semesterStartMonday: '2026-09-14',
    weekIndex: 5, totalWeeks: 18, distinctCourses: 2, segmentCount: 2, lastSyncAt: Date.now(),
    now: '2026-09-14T07:00:00',
    next: occ('高等数学', 1, 1, 2, '08:00', '09:50', 'upcoming'),
    ongoing: [], restOfToday: [occ('高等数学', 1, 1, 2, '08:00', '09:50', 'upcoming')],
    exhausted: false, todayWeekIndex: 5,
    today: [occ('高等数学', 1, 1, 2, '08:00', '09:50', 'upcoming')],
    freeCourses: [], manualCourses: [],
    settings,
    exams: [{ courseName: '高等数学', raw: '2026-11-20 14:00', location: '仙Ⅱ-304', daysLeft: 67, at: '2026-11-20T14:00' }],
  };
  const week = {
    totalWeeks: 18,
    slots: [1, 2, 3, 4, 5].map(i => ({ index: i, start: '08:00', end: '08:50' })),
    blocks: [
      { name: '高等数学', classroom: '仙Ⅱ-304', teacher: '张三', classNumber: 'x',
        weekday: 1, startSlot: 1, endSlot: 2, span: 2, conflict: false,
        weeks: '1-16 周', testTime: '2026-11-20 14:00', info: null },
      // 周末补课：show_weekend 关闭时不应出现在网格里（否则定位到负坐标）
      { name: '周末补课', classroom: '仙Ⅱ-101', teacher: '', classNumber: 'y',
        weekday: 6, startSlot: 1, endSlot: 2, span: 2, conflict: false,
        weeks: '3 周', testTime: null, info: null },
    ],
    freeCourses: [],
  };
  const handlers = {
    state: () => state,
    week: (arg) => { lastWeekArg = arg; return week; },
    deviceInfo: () => ({ display: '华为 NOH-AN00 · Android 12（API 31）', summary: '全部就绪', items: [] }),
    lockNotifyInfo: () => ({ permissionGranted: true, channelBlocked: false, channelImportance: 3 }),
  };
  return {
    call(method, args) {
      const fn = handlers[method];
      if (fn) {
        const parsed = args ? JSON.parse(args) : {};
        return JSON.stringify(fn(parsed));
      }
      return JSON.stringify({ ok: true });
    }
  };
}

// ---------------------------------------------------------------- 执行

let threw = false;
try {
  const sandbox = {
    window, document, setInterval: (fn) => { intervalCb = fn; return 1; },
    setTimeout: (fn) => 1,
    clearInterval: () => {},
    console,
  };
  const vm = require('vm');
  const script = new vm.Script(JS, { filename: 'app.js' });
  vm.createContext(sandbox);
  script.runInContext(sandbox);

  // 再主动触发一次 refresh（模拟 onResume）
  if (sandbox.window.NJUApp && sandbox.window.NJUApp.refresh) {
    sandbox.window.NJUApp.refresh();
  }

  // ---------------- 行为断言 ----------------
  const failures = [];
  const assert = (cond, msg) => { if (!cond) failures.push(msg); };

  // 1. 「本周」必须默认落在当前周（曾经初始成 1，永远显示第 1 周）
  assert(lastWeekArg === 5, `本周渲染传了第 ${lastWeekArg} 周，应为当前第 5 周`);

  // 2. 关闭「显示周末」时，周末的课不该出现在网格里
  const weekHtml = els['tabWeek'].innerHTML || '';
  assert(weekHtml.indexOf('周末补课') === -1, '周末课程仍被渲染进网格（会被定位到负坐标）');
  assert(weekHtml.indexOf('高等数学') !== -1, '正常课程没有渲染进网格');

  if (failures.length) {
    threw = true;
    console.log('✗ app.js 执行无异常，但行为断言失败：');
    failures.forEach(f => console.log('  · ' + f));
  } else {
    console.log('✓ app.js 加载并渲染完成，行为断言全部通过');
    console.log('  （本周落在当前第 5 周 / 周末课被正确过滤）');
  }
} catch (e) {
  threw = true;
  console.log('✗ app.js 运行时抛异常：');
  console.log('  ' + (e.name || 'Error') + ': ' + e.message);
  if (e.stack) {
    const lines = e.stack.split('\n').slice(0, 6);
    lines.forEach(l => console.log('    ' + l.trim()));
  }
}

process.exit(threw ? 1 : 0);
