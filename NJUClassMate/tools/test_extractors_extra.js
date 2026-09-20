/**
 * 另外三个课表抓取脚本的离线单测。
 *
 * 覆盖：本科生选课系统 / 研究生教务系统 / 研究生选课系统。
 *
 * 为什么必须测：
 *   这三份脚本的 DOM 选择器和接口格式都来自社区（我拿不到教务系统账号做真机验证），
 *   属于"照抄+改进"的代码，风险最高。
 *   而它们一旦出错，表现是"导入时说读不到数据"，用户在手机上完全没法排查。
 *
 * 运行：node tools/test_extractors_extra.js
 */
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const RAWFILE = process.env.NJU_EXTRACTOR_DIR
  || path.join(__dirname, '..', 'entry', 'src', 'main', 'resources', 'rawfile');

console.log('脚本目录: ' + path.relative(process.cwd(), RAWFILE));

let pass = 0;
let fail = 0;

function check(label, actual, expected) {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a === e) {
    pass++;
    console.log(`  \u2713 ${label}`);
  } else {
    fail++;
    console.log(`  \u2717 ${label}`);
    console.log(`      expected: ${e}`);
    console.log(`      actual:   ${a}`);
  }
}

function load(name) {
  return fs.readFileSync(path.join(RAWFILE, name), 'utf8');
}

/** 安全取课程数组：断言失败时不要因为 undefined 直接把测试进程打崩 */
function coursesOf(r) {
  return (r && r.data && r.data.courses) ? r.data.courses : [];
}

function run(scriptName, globals) {
  const sandbox = Object.assign({
    window: {},
    console: console
  }, globals);
  vm.createContext(sandbox);
  const out = vm.runInContext(load(scriptName), sandbox);
  return out ? JSON.parse(out) : null;
}

// ══════════════════════════════════════════════════════════
// 通用 DOM 小工具
// ══════════════════════════════════════════════════════════
function node(text, opts) {
  const o = opts || {};
  return {
    textContent: text,
    className: o.className || '',
    children: o.children || [],
    attributes: o.attributes || {}
  };
}

// ══════════════════════════════════════════════════════════
// 1. 本科生选课系统 njubksxk.js
// ══════════════════════════════════════════════════════════
console.log('\n[1] 本科生选课系统 njubksxk.js');

/** 造一个选课结果页面：表头 + 表体 */
function buildXuankeDom(bodyRows, headCells) {
  const head = {
    children: [
      {
        children: (headCells || ['序号', '课程名', '教师', '时间地点', '学分', '备注'])
          .map((t) => node(t))
      }
    ]
  };
  const body = { children: bodyRows };
  const doc = {
    getElementsByClassName(name) {
      if (name === 'currentTerm') return [node('2026-2027学年 第1学期')];
      if (name === 'course-head') return [head];
      if (name === 'course-body') return [body];
      return [];
    }
  };
  return { document: doc };
}

{
  // 一行课：时间地点列里有 2 个 div（= 2 段安排），备注挂在 title 属性上
  const row = node('', {
    className: 'course-tr',
    children: [
      node('1'),
      node('高等数学'),
      node('张三'),
      node('', {
        children: [
          node('周三 2-4节 1-16周 仙Ⅱ-304'),
          node('周五 1-2节 2-18周(双) 仙1-216')
        ]
      }),
      node('5'),
      node('', { attributes: { title: { value: '必修' } } })
    ]
  });

  const r = run('njubksxk.js', buildXuankeDom([row]));
  check('ok=true', r.ok, true);
  check('学期名', r.data.name, '2026-2027学年 第1学期');
  check('一行课拆成 2 段', r.data.courses.length, 2);
  check('第 1 段是周三第 2-4 节', {
    wt: r.data.courses[0].week_time,
    st: r.data.courses[0].start_time,
    tc: r.data.courses[0].time_count,
    room: r.data.courses[0].classroom
  }, { wt: 3, st: 2, tc: 2, room: '仙Ⅱ-304' });
  check('第 1 段周次 1-16 共 16 周', r.data.courses[0].weeks.length, 16);
  check('第 2 段是周五', r.data.courses[1].week_time, 5);
  check('第 2 段双周取到偶数周', [r.data.courses[1].weeks[0], r.data.courses[1].weeks[r.data.courses[1].weeks.length - 1]], [2, 18]);
  check('第 2 段双周共 9 周', r.data.courses[1].weeks.length, 9);
  check('备注从 title 属性读出', r.data.courses[0].info, '必修');
}

{
  // 两个考点：
  //   ① 表头列顺序被打乱 —— 脚本应该动态识别，而不是硬编码下标
  //   ② 时间地点那一格是纯文本、没有子 div —— 也应该能解析，而不是丢掉整行
  const row = node('', {
    className: '',
    children: [
      node('1'),
      node('大学物理'),           // 课程名在 index 1
      node('李四'),               // 教师 index 2
      node('1'),
      node('周四 3-4节 1-8周 仙1-216'),  // 时间地点被挪到 index 4，且是纯文本格
      node('选修')
    ]
  });
  const dom = (() => {
    const head = {
      children: [{ children: ['序号', '课程名', '教师', '学分', '时间地点', '备注'].map((t) => node(t)) }]
    };
    return {
      document: {
        getElementsByClassName(name) {
          if (name === 'currentTerm') return [node('2026-2027学年 第1学期')];
          if (name === 'course-head') return [head];
          if (name === 'course-body') return [{ children: [row] }];
          return [];
        }
      }
    };
  })();
  const r = run('njubksxk.js', dom);
  const cs = coursesOf(r);
  check('列顺序打乱后仍能识别时间地点', r.ok, true);
  check('纯文本时间地点格也能解析', cs.length, 1);
  check('正确拿到地点', cs.length ? cs[0].classroom : null, '仙1-216');
  check('正确拿到星期', cs.length ? cs[0].week_time : null, 4);
  check('正确拿到节次', cs.length ? [cs[0].start_time, cs[0].time_count] : null, [3, 1]);
}

{
  // 单周：起止奇偶性不一致的情况（原实现会取错的经典 bug）
  const row = node('', {
    className: '',
    children: [
      node('1'), node('某某课'), node('王五'),
      node('', { children: [node('周二 5-8节 2-15周(单) 仙1-101')] }),
      node('2'), node('')
    ]
  });
  const r = run('njubksxk.js', buildXuankeDom([row]));
  check('2-15周(单) 取奇数周', r.data.courses[0].weeks, [3, 5, 7, 9, 11, 13, 15]);
  check('2-15周(单) 共 7 周', r.data.courses[0].weeks.length, 7);
}

{
  // 分组小计行应该被跳过
  const skipped = node('', { className: 'wdbm-course-tr', children: [node('合计')] });
  const normal = node('', {
    className: '',
    children: [
      node('1'), node('正常课'), node('老师'),
      node('', { children: [node('周一 1-2节 1-8周 A101')] }),
      node('1'), node('')
    ]
  });
  const r = run('njubksxk.js', buildXuankeDom([skipped, normal]));
  check('跳过 wdbm-course-tr 分组行', r.data.courses.length, 1);
  check('剩下的是正常课', r.data.courses[0].name, '正常课');
}

{
  const r = run('njubksxk.js', { document: { getElementsByClassName: () => [] } });
  check('找不到表格时报错', r.ok, false);
  check('错误阶段是 findHead', r.stage, 'findHead');
}

// ══════════════════════════════════════════════════════════
// 2. 研究生教务系统 njuyjsjw.js
// ══════════════════════════════════════════════════════════
console.log('\n[2] 研究生教务系统 njuyjsjw.js');

const TERMS = {
  datas: {
    kfdxnxqcx: {
      rows: [
        // 故意把"老学期"的 PX 设得更小：原实现按 PX 升序取 terms[0] 会拿到这个错的
        { XNXQDM: 'OLD-1', XNXQDM_DISPLAY: '2025-2026学年 第2学期', PX: 1 },
        { XNXQDM: 'NEW-1', XNXQDM_DISPLAY: '2026-2027学年 第1学期', PX: 2 }
      ]
    }
  }
};

function makeXhr(rowsByTerm, opts) {
  const o = opts || {};
  function XHR() {}
  XHR.prototype.open = function (m, url) { this._url = url; };
  XHR.prototype.setRequestHeader = function () {};
  XHR.prototype.send = function (body) {
    if (o.failTerms && this._url.indexOf('kfdxnxqcx') >= 0) {
      this.responseText = '';
      return;
    }
    if (this._url.indexOf('kfdxnxqcx') >= 0) {
      this.responseText = JSON.stringify(TERMS);
      return;
    }
    const m = String(body || '').match(/XNXQDM=([^&]*)/);
    const code = m ? decodeURIComponent(m[1]) : '';
    const rows = rowsByTerm[code] || [];
    this.responseText = JSON.stringify({ datas: { xsjxrwcx: { rows } } });
  };
  return XHR;
}

{
  const rowsByTerm = {
    'OLD-1': [
      { KCMC: '上学期的高数', KCDM: 'OLD01', RKJS: '旧老师', PKSJDD: '1-8周 星期一[1-2节]仙Ⅰ-101', XKBZ: '' }
    ],
    'NEW-1': [
      { KCMC: '计量经济学', KCDM: 'NEW01', RKJS: '新老师', PKSJDD: '1-16周 星期二[3-4节]仙Ⅰ-201', XKBZ: '必修' },
      { KCMC: '学术英语', KCDM: 'NEW02', RKJS: '张老师', PKSJDD: '5-9单周,13-17单周 星期五[3-4节]仙Ⅰ-319;4-18周 星期一[3-4节];4-18双周 星期五[3-4节]', XKBZ: '' }
    ]
  };
  const r = run('njuyjsjw.js', { XMLHttpRequest: makeXhr(rowsByTerm) });
  check('ok=true', r.ok, true);
  check('选中的是当前学期（按日期，而不是 PX 排序）', r.data.name, '2026-2027学年 第1学期');
  check('没抓错到上学期', r.data.courses.filter((c) => c.name === '上学期的高数').length, 0);
  check('计量经济学 1 段', r.data.courses.filter((c) => c.name === '计量经济学').length, 1);
  check('第一段星期与节次', {
    wt: r.data.courses[0].week_time, st: r.data.courses[0].start_time, tc: r.data.courses[0].time_count
  }, { wt: 2, st: 3, tc: 1 });
  check('地点解析', r.data.courses[0].classroom, '仙Ⅰ-201');
  check('备注带出', r.data.courses[0].info, '必修');

  // 分号分隔的多段：5-9单周 + 4-18周 周一 + 4-18双周 周五 = 3 段
  const eng = r.data.courses.filter((c) => c.name === '学术英语');
  check('学术英语拆成 3 段', eng.length, 3);
  // 第一段是「5-9单周,13-17单周」，两段都是单周，所以是 5/7/9 和 13/15/17
  check('第 1 段（5-9 与 13-17 两个单周区间）', eng[0].weeks, [5, 7, 9, 13, 15, 17]);
  check('第 1 段共 6 周', eng[0].weeks.length, 6);
  check('第 2 段（4-18 全周）共 15 周', eng[1].weeks.length, 15);
  check('第 3 段（4-18 双周）取偶数周', eng[2].weeks, [4, 6, 8, 10, 12, 14, 16, 18]);
  check('第 3 段是周五', eng[2].week_time, 5);
}

{
  // PKSJDD 为 null = 自由时间课程，要保留而不是丢掉
  const rowsByTerm = {
    'OLD-1': [],
    'NEW-1': [
      { KCMC: '毕业论文', KCDM: 'THESIS', RKJS: '导师', PKSJDD: null, XKBZ: '自由时间' }
    ]
  };
  const r = run('njuyjsjw.js', { XMLHttpRequest: makeXhr(rowsByTerm) });
  check('自由时间课程被保留', r.data.courses.length, 1);
  check('地点标为自由地点', r.data.courses[0].classroom, '自由地点');
  check('week_time 为 0', r.data.courses[0].week_time, 0);
}

{
  // 第一个学期没课 → 应该继续往后试
  const rowsByTerm = {
    'OLD-1': [],
    'NEW-1': [{ KCMC: '有课的学期', KCDM: 'X', RKJS: 'T', PKSJDD: '1-4周 星期三[1-2节]A', XKBZ: '' }]
  };
  const r = run('njuyjsjw.js', { XMLHttpRequest: makeXhr(rowsByTerm) });
  check('自动跳到有课的学期', r.ok, true);
  check('拿到该学期课程', r.data.courses[0].name, '有课的学期');
}

{
  const r = run('njuyjsjw.js', { XMLHttpRequest: makeXhr({}, { failTerms: true }) });
  check('学期列表拿不到时报错', r.ok, false);
  check('错误阶段是 fetchTerms', r.stage, 'fetchTerms');
}

{
  const r = run('njuyjsjw.js', { XMLHttpRequest: makeXhr({ 'OLD-1': [], 'NEW-1': [] }) });
  check('所有学期都没课时报错', r.ok, false);
  check('错误阶段是 emptyCourses', r.stage, 'emptyCourses');
}

// ══════════════════════════════════════════════════════════
// 3. 研究生选课系统 njuyjsxk.js
// ══════════════════════════════════════════════════════════
console.log('\n[3] 研究生选课系统 njuyjsxk.js');

function buildBodyJsonDom(obj) {
  return {
    document: {
      body: {
        innerText: JSON.stringify(obj, null, 1),
        textContent: JSON.stringify(obj, null, 1)
      }
    }
  };
}

const XK_RESULT = {
  results: [
    // 上学期
    { XNXQMC: '2025-2026学年 第2学期', KCMC: '上学期课程', KCDM: 'O1', RKJS: '旧老师', XKBZ: '', PKSJDD: '1-8周 星期一[1-2节]仙Ⅰ-101' },
    // 当前学期
    { XNXQMC: '2026-2027学年 第1学期', KCMC: '高级算法', KCDM: 'N1', RKJS: '陈老师', XKBZ: '必修', PKSJDD: '1-16周 星期三[5-6节]仙Ⅰ-301' },
    { XNXQMC: '2026-2027学年 第1学期', KCMC: '论文写作', KCDM: 'N2', RKJS: '刘老师', XKBZ: '', PKSJDD: '2-16双周 星期五[7-8节]仙Ⅰ-402;3-15单周 星期四[9-10节]仙Ⅰ-403' }
  ]
};

{
  const r = run('njuyjsxk.js', buildBodyJsonDom(XK_RESULT));
  check('ok=true', r.ok, true);
  check('选中的是当前学期', r.data.name, '2026-2027学年 第1学期');
  check('只返回当前学期的课', r.data.courses.filter((c) => c.name === '上学期课程').length, 0);
  check('courses 是数组而不是字符串', Array.isArray(r.data.courses), true);
  check('课程条数（1 + 2 段）', r.data.courses.length, 3);
  check('高级算法解析', {
    wt: r.data.courses[0].week_time, st: r.data.courses[0].start_time, tc: r.data.courses[0].time_count,
    room: r.data.courses[0].classroom, weeks: r.data.courses[0].weeks.length
  }, { wt: 3, st: 5, tc: 1, room: '仙Ⅰ-301', weeks: 16 });
  check('论文写作双周段', r.data.courses[1].weeks, [2, 4, 6, 8, 10, 12, 14, 16]);
  check('论文写作单周段', r.data.courses[2].weeks, [3, 5, 7, 9, 11, 13, 15]);
  check('论文写作单周段是周四第 9-10 节', {
    wt: r.data.courses[2].week_time, st: r.data.courses[2].start_time, tc: r.data.courses[2].time_count
  }, { wt: 4, st: 9, tc: 1 });
}

{
  // 页面不是 JSON（比如用户停在了登录页）
  const r = run('njuyjsxk.js', { document: { body: { innerText: '请先登录', textContent: '请先登录' } } });
  check('非 JSON 页面报错', r.ok, false);
  check('错误阶段是 readBody', r.stage, 'readBody');
}

{
  // 只有未知格式的学期名时，退回"最后一个学期"
  const obj = {
    results: [
      { XNXQMC: '奇怪的学期名', KCMC: '课A', KCDM: 'A', RKJS: 'T', XKBZ: '', PKSJDD: '1-4周 星期一[1-2节]A101' }
    ]
  };
  const r = run('njuyjsxk.js', buildBodyJsonDom(obj));
  check('学期名解析不出时仍能用最后一个学期', r.ok, true);
  check('拿到课程', r.data.courses[0].name, '课A');
}

{
  // PKSJDD 为空 → 自由时间
  const obj = {
    results: [
      { XNXQMC: '2026-2027学年 第1学期', KCMC: '实习', KCDM: 'S', RKJS: 'T', XKBZ: '', PKSJDD: '' }
    ]
  };
  const r = run('njuyjsxk.js', buildBodyJsonDom(obj));
  check('空 PKSJDD 视为自由时间', r.data.courses[0].classroom, '自由地点');
  check('自由时间周次填充为 18 周', r.data.courses[0].weeks.length, 18);
}

// ══════════════════════════════════════════════════════════
// 4. bridge 回传通道（三个新脚本都要支持）
// ══════════════════════════════════════════════════════════
console.log('\n[4] 三个新脚本的 njuBridge 通道');

{
  const cases = [
    { file: 'njubksxk.js', globals: (captured) => {
        const row = node('', {
          className: '',
          children: [
            node('1'), node('课'), node('师'),
            node('', { children: [node('周一 1-2节 1-4周 A101')] }),
            node('1'), node('')
          ]
        });
        return Object.assign(buildXuankeDom([row]), { window: { njuBridge: { postMessage: (t) => captured.push(t) } } });
      } },
    { file: 'njuyjsjw.js', globals: (captured) => ({
        XMLHttpRequest: makeXhr({ 'OLD-1': [], 'NEW-1': [{ KCMC: '课', KCDM: 'C', RKJS: 'T', PKSJDD: '1-4周 周一[1-2节]A', XKBZ: '' }] }),
        window: { njuBridge: { postMessage: (t) => captured.push(t) } }
      }) },
    { file: 'njuyjsxk.js', globals: (captured) => Object.assign(buildBodyJsonDom(XK_RESULT), {
        window: { njuBridge: { postMessage: (t) => captured.push(t) } }
      }) }
  ];

  for (const c of cases) {
    const captured = [];
    const out = run(c.file, c.globals(captured));
    check(`${c.file} 走 bridge 时返回空串`, out, null);
    check(`${c.file} bridge 收到 1 条`, captured.length, 1);
    check(`${c.file} bridge 内容是合法 JSON`, (() => {
      try { return JSON.parse(captured[0]).ok === true; } catch (e) { return false; }
    })(), true);
  }
}

console.log(`\n结果：通过 ${pass}，失败 ${fail}\n`);
process.exit(fail === 0 ? 0 : 1);
