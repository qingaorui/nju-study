/**
 * 注入脚本的离线单元测试。
 *
 * 教务系统改版是我们最大的风险，而改版时最先坏的就是 DOM 选择器和正则。
 * 造一个假的 ehall 课表页面（列顺序、文案格式都按真实页面来），
 * 就能在不开模拟器、不登录的情况下验证解析逻辑，改脚本后秒级回归。
 *
 * 运行：node tools/test_extractor.js
 */
const fs = require('fs');
const path = require('path');
const vm = require('vm');

// 用 NJU_EXTRACTOR_DIR 指定脚本所在目录，
// 这样同一套断言可以同时验证 HarmonyOS 工程和 Android 工程里的脚本副本
// （两份必须完全一致，改了一份忘了同步另一份是很容易犯的错）。
const EXTRACTOR_DIR = process.env.NJU_EXTRACTOR_DIR
  || path.join(__dirname, '..', 'entry', 'src', 'main', 'resources', 'rawfile');
const SCRIPT = path.join(EXTRACTOR_DIR, 'njubksjw.js');

console.log('脚本目录: ' + path.relative(process.cwd(), EXTRACTOR_DIR));

/** 造一个最小的 DOM 节点 */
function el(text, children) {
  return {
    textContent: text,
    children: children || [],
    querySelectorAll(sel) {
      if (sel === 'td') return this.children;
      return [];
    }
  };
}

/** 造一行表格：列顺序与真实 ehall 页面一致 */
function row(cells) {
  return el(cells.join(''), cells.map((c) => el(c)));
}

function buildDom(semesterText, rows, opts) {
  const options = opts || {};
  const nameNode = el(semesterText);

  const tbody = {
    querySelectorAll(sel) {
      if (sel === 'tr') return rows;
      return [];
    }
  };

  const table = {
    querySelectorAll(sel) {
      if (sel === 'tbody') return [tbody];
      return [];
    },
    querySelector(sel) {
      if (sel === 'tbody') return tbody;
      return null;
    }
  };

  const document = {
    querySelector(sel) {
      if (sel === '#dqxnxqkclb') return options.hideSemester ? null : nameNode;
      if (sel === 'table tbody') return options.hideTable ? null : tbody;
      return null;
    },
    querySelectorAll(sel) {
      if (sel === 'iframe, frame') return [];
      if (sel === '*') return options.hideSemester ? [el('2026-2027学年 第1学期')] : [];
      return [];
    }
  };

  return { document };
}

/** 按真实列序拼一行：0序号 1课程号 2课程名 3学分 4教师 5周学时 6时间地点 7? 8备注 9? 10考试时间 */
function makeRow(seq, code, name, credit, teacher, hours, timeLoc, info, exam) {
  return row([
    seq, code, name, credit, teacher, hours, timeLoc,
    '', info, '', exam
  ]);
}

let pass = 0;
let fail = 0;

function check(label, actual, expected) {
  const ok = JSON.stringify(actual) === JSON.stringify(expected);
  if (ok) {
    pass++;
    console.log(`  ✓ ${label}`);
  } else {
    fail++;
    console.log(`  ✗ ${label}`);
    console.log(`      期望: ${JSON.stringify(expected)}`);
    console.log(`      实际: ${JSON.stringify(actual)}`);
  }
}

function run(dom) {
  const sandbox = {
    window: { njuBridge: null },
    document: dom.document,
    console: console
  };
  vm.createContext(sandbox);
  const out = vm.runInContext(fs.readFileSync(SCRIPT, 'utf8'), sandbox);
  return out ? JSON.parse(out) : null;
}

console.log('\n[1] 标准周次解析');
{
  const rows = [
    makeRow('1', '25010010', '高等数学（一）', '5', '张三', '6',
      '周一 1-2节 1-16周 仙Ⅱ-304', '必修', '2027-01-05 14:00-16:00'),
    makeRow('2', '25010020', '大学物理', '4', '李四', '4',
      '周三 5-6节 1-15周(单) 仙1-216', '', '2027-01-08 09:00-11:00')
  ];
  const r = run(buildDom('2026-2027学年 第1学期', rows));
  check('ok=true', r.ok, true);
  check('学期名', r.data.name, '2026-2027学年 第1学期');
  check('解析出 2 条', r.data.courses.length, 2);
  check('周一 1-2节', {
    weekday: r.data.courses[0].week_time,
    start: r.data.courses[0].start_time,
    count: r.data.courses[0].time_count,
    room: r.data.courses[0].classroom,
    weeks: r.data.courses[0].weeks.length
  }, { weekday: 1, start: 1, count: 1, room: '仙Ⅱ-304', weeks: 16 });
  check('单周过滤（1-15 单 → 8 周）', r.data.courses[1].weeks.length, 8);
  check('单周首项与末项', [r.data.courses[1].weeks[0], r.data.courses[1].weeks[7]], [1, 15]);
  check('考试时间带出', r.data.courses[0].test_time, '2027-01-05 14:00-16:00');
  check('备注带出', r.data.courses[0].info, '必修');
}

console.log('\n[2] 双周 / 多段周次 / 一门课多个时间段');
{
  const rows = [
    makeRow('1', '25030010', '数据结构', '4', '王五', '4',
      '周二 5-8节 2-18周(双) 仙1-216', '', ''),
    makeRow('2', '25030020', '线性代数', '3', '赵六', '3',
      '周三 2-4节 1-3周,10-13周 基础实验楼丙405', '', ''),
    makeRow('3', '25030030', '英语', '2', '钱七', '2',
      '周四 3-4节 1-16周 仙Ⅱ-201,周五 5-6节 1-16周 仙Ⅱ-202', '', '')
  ];
  const r = run(buildDom('2026-2027学年 第1学期', rows));
  check('双周首项/末项', [r.data.courses[0].weeks[0], r.data.courses[0].weeks[r.data.courses[0].weeks.length - 1]], [2, 18]);
  check('双周有多少周', r.data.courses[0].weeks.length, 9);
  check('双周 5-8 节 → count=3', r.data.courses[0].time_count, 3);
  check('间断周次 1-3,10-13 → 7 周', r.data.courses[1].weeks.length, 7);
  check('间断周次内容', r.data.courses[1].weeks, [1, 2, 3, 10, 11, 12, 13]);
  check('一门课拆成 2 条', r.data.courses.length, 4);
  check('第 2 条是周四', r.data.courses[2].week_time, 4);
  check('第 3 条是周五', r.data.courses[3].week_time, 5);
}

console.log('\n[3] 自由时间课程');
{
  const rows = [
    makeRow('1', '25040010', '毕业设计', '8', '孙八', '0',
      '周一 3-4节 1-16周 自由时间', '', '')
  ];
  const r = run(buildDom('2026-2027学年 第1学期', rows));
  check('地点写成"自由地点"', r.data.courses[0].classroom, '自由地点');
  check('week_time=0', r.data.courses[0].week_time, 0);
  check('周次仍保留', r.data.courses[0].weeks.length, 16);
}

console.log('\n[4] 异常与兜底');
{
  // 没进课表页
  const r1 = run(buildDom('x', [], { hideTable: true }));
  check('找不到表格时报错', r1.ok, false);
  check('错误阶段是 findTable', r1.stage, 'findTable');

  // 表格为空
  const r2 = run(buildDom('2026-2027学年 第1学期', []));
  check('空表报错', r2.ok, false);
  check('错误阶段是 emptyTable', r2.stage, 'emptyTable');

  // 学期名节点找不到 → 用页面文本兜底
  const r3 = run(buildDom('', [makeRow('1', '1', '课程A', '1', '老师', '2', '周一 1-2节 1-8周 A101', '', '')],
    { hideSemester: true }));
  check('学期名兜底成功', r3.data.name, '2026-2027学年第1学期');

  // 表头行（列数不足）应被跳过
  const r4 = run(buildDom('2026-2027学年 第1学期', [
    el('课程号课程名'),
    makeRow('1', '1', '课程B', '1', '老师', '2', '周一 1-2节 1-8周 A101', '', '')
  ]));
  check('表头被跳过', r4.data.courses.length, 1);
}

console.log('\n[5] bridge 回传通道');
{
  const captured = [];
  const dom = buildDom('2026-2027学年 第1学期', [
    makeRow('1', '1', '课程C', '1', '老师', '2', '周二 1-2节 1-8周 B201', '', '')
  ]);
  const sandbox = {
    window: {
      njuBridge: {
        postMessage(t) { captured.push(t); }
      }
    },
    document: dom.document,
    console: console
  };
  vm.createContext(sandbox);
  const ret = vm.runInContext(fs.readFileSync(SCRIPT, 'utf8'), sandbox);
  check('走 bridge 时返回空串', ret, '');
  check('bridge 收到 1 条', captured.length, 1);
  check('bridge 内容可解析', JSON.parse(captured[0]).data.courses.length, 1);
}

console.log(`\n结果：通过 ${pass}，失败 ${fail}\n`);
process.exit(fail === 0 ? 0 : 1);
