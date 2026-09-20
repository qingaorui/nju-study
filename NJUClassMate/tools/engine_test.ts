/**
 * NextClassEngine 离线单元测试。
 *
 * 运行：
 *   python tools/prepare_engine_test.py
 *   node --experimental-transform-types tools/engine_test.ts
 *
 * 覆盖的是这个 App 里最容易出错、又最难在真机上手工复现的部分：
 * "现在几点，下一节课是哪一节" —— 边界情况极多（课前/课中/课间/周末/跨周/未开学/双周）。
 * 用固定时间来跑，比在手机上守着一节课等它开始要靠谱得多。
 */
import { CourseItem, Timetable, ClassStatus } from './.engine-test/ets/model/Course.ts';
import { AppSettings, defaultSettings } from './.engine-test/ets/service/CourseStore.ts';
import { NextClassEngine, NextClassResult, DaySchedule, GridBlock, ExamEntry } from './.engine-test/ets/service/NextClassEngine.ts';
import { DateUtil } from './.engine-test/ets/common/DateUtil.ts';

let pass = 0;
let fail = 0;

function check(label: string, actual: unknown, expected: unknown): void {
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

function d(y: number, m: number, day: number, hh: number, mm: number): Date {
  return new Date(y, m - 1, day, hh, mm, 0, 0);
}

// ---------------- 测试数据 ----------------
// 2026-09-14 是周一，作为第 1 周周一
const SEM_START = '2026-09-14';

const ODD_WEEKS: number[] = [];
for (let w = 1; w <= 16; w += 2) {
  ODD_WEEKS.push(w);
}

function course(name: string, weekTime: number, startSlot: number, endSlot: number,
                weeks: number[], room: string, teacher: string, exam: string | null): CourseItem {
  return {
    name: name,
    classroom: room,
    classNumber: name + '-code',
    teacher: teacher,
    testTime: exam,
    testLocation: null,
    info: null,
    weeks: weeks,
    weekTime: weekTime,
    startSlot: startSlot,
    endSlot: endSlot,
    importType: 1
  };
}

const ALL_WEEKS: number[] = [];
for (let w = 1; w <= 16; w++) {
  ALL_WEEKS.push(w);
}
const FIRST_HALF: number[] = [];
for (let w = 1; w <= 8; w++) {
  FIRST_HALF.push(w);
}

const TIMETABLE: Timetable = {
  name: '2026-2027学年 第1学期',
  semesterStartMonday: SEM_START,
  courses: [
    // 周一 1-2 节，全周 —— 与下面那条在 1-8 周冲突
    course('高等数学', 1, 1, 2, ALL_WEEKS, '仙Ⅱ-304', '张三', '2027-01-05 14:00-16:00'),
    // 周一 1-2 节，仅 1-8 周
    course('数据结构', 1, 1, 2, FIRST_HALF, '仙Ⅱ-305', '李四', null),
    // 周三 5-6 节，单周
    course('大学物理', 3, 5, 6, ODD_WEEKS, '仙1-216', '王五', null),
    // 周五 9-10 节（晚上）
    course('形势与政策', 5, 9, 10, ALL_WEEKS, '仙Ⅱ-201', '赵六', '2026-11-20 09:00-11:00'),
    // 自由时间课程
    course('毕业设计', 0, 0, 0, ALL_WEEKS, '自由地点', '孙七', null)
  ]
};

const SETTINGS: AppSettings = defaultSettings();
SETTINGS.semesterStartMonday = SEM_START;

// ---------------- 1. 周次计算 ----------------
console.log('\n[1] 周次计算');
check('开学当天是第 1 周', DateUtil.weekIndexOf(SEM_START, d(2026, 9, 14, 8, 0)), 1);
check('周日仍属第 1 周', DateUtil.weekIndexOf(SEM_START, d(2026, 9, 20, 23, 0)), 1);
check('下周一进入第 2 周', DateUtil.weekIndexOf(SEM_START, d(2026, 9, 21, 0, 30)), 2);
check('第 3 周周一', DateUtil.weekIndexOf(SEM_START, d(2026, 9, 28, 12, 0)), 3);
check('开学前一天为第 0 周', DateUtil.weekIndexOf(SEM_START, d(2026, 9, 13, 12, 0)), 0);
check('学期中段（11-16）', DateUtil.weekIndexOf(SEM_START, d(2026, 11, 16, 12, 0)), 10);
check('未设置开学日期 → 0', DateUtil.weekIndexOf('', d(2026, 9, 14, 8, 0)), 0);

// ---------------- 2. 单日课表 ----------------
console.log('\n[2] 单日课表');
{
  const monday: DaySchedule = NextClassEngine.daySchedule(TIMETABLE, SETTINGS, d(2026, 9, 14, 7, 0), d(2026, 9, 14, 7, 0));
  check('周一第 1 周有 2 门（高数 + 数据结构）', monday.occurrences.length, 2);
  check('第 1 门是 08:00 开始', monday.occurrences[0].startClock, '08:00');
  check('第 2 节结束时间是 09:50', monday.occurrences[0].endClock, '09:50');

  const wed1: DaySchedule = NextClassEngine.daySchedule(TIMETABLE, SETTINGS, d(2026, 9, 16, 7, 0), d(2026, 9, 16, 7, 0));
  check('周三第 1 周有大学物理（单周）', wed1.occurrences.length, 1);

  const wed2: DaySchedule = NextClassEngine.daySchedule(TIMETABLE, SETTINGS, d(2026, 9, 23, 7, 0), d(2026, 9, 23, 7, 0));
  check('周三第 2 周没有课（双周不上）', wed2.occurrences.length, 0);

  const mon9: DaySchedule = NextClassEngine.daySchedule(TIMETABLE, SETTINGS, d(2026, 11, 16, 7, 0), d(2026, 11, 16, 7, 0));
  check('第 10 周周一只剩高数（数据结构已结课）', mon9.occurrences.length, 1);
  check('剩下的是高等数学', mon9.occurrences[0].course.name, '高等数学');

  const mon0: DaySchedule = NextClassEngine.daySchedule(TIMETABLE, SETTINGS, d(2026, 9, 7, 7, 0), d(2026, 9, 7, 7, 0));
  check('未开学时没有课', mon0.occurrences.length, 0);
}

// ---------------- 3. 下一节课：课前 ----------------
console.log('\n[3] 下一节课：上课前');
{
  const r: NextClassResult = NextClassEngine.resolve(TIMETABLE, SETTINGS, d(2026, 9, 14, 7, 0));
  check('有下一节课', r.next !== null, true);
  check('下一节是高等数学', r.next?.course.name, '高等数学');
  check('倒计时 60 分钟', r.next?.minutesFromNow, 60);
  check('状态为未开始', r.next?.status, ClassStatus.UPCOMING);
  check('此刻没有正在上的课', r.ongoing.length, 0);
  check('今天还有 2 节', r.restOfToday.length, 2);
  check('当前是第 1 周', r.weekIndex, 1);
}

// ---------------- 4. 下一节课：课中（含同时段冲突） ----------------
console.log('\n[4] 下一节课：正在上课');
{
  const r: NextClassResult = NextClassEngine.resolve(TIMETABLE, SETTINGS, d(2026, 9, 14, 8, 30));
  check('检测到 2 门同时在上（免修不免考）', r.ongoing.length, 2);
  check('状态为进行中', r.ongoing[0].status, ClassStatus.ONGOING);
  check('今天剩余课数为 0', r.restOfToday.length, 0);
  check('下一节顺延到周三大学物理', r.next?.course.name, '大学物理');
  check('下一节在第 3 天（周三）', r.next?.dateKey, '2026-09-16');
}

// ---------------- 5. 下一节课：课间 / 跨天 ----------------
console.log('\n[5] 下一节课：课间与跨天');
{
  const finished: NextClassResult = NextClassEngine.resolve(TIMETABLE, SETTINGS, d(2026, 9, 14, 10, 0));
  check('上午的课上完后下一节是周三', finished.next?.course.name, '大学物理');
  check('周三那节是 13:30 开始（第 5 节）', finished.next?.startClock, '13:30');
  check('周三那节是第 5-6 节', [finished.next?.startSlot, finished.next?.endSlot], [5, 6]);

  const weekend: NextClassResult = NextClassEngine.resolve(TIMETABLE, SETTINGS, d(2026, 9, 19, 10, 0));
  check('周六没有课，下一节回到下周一', weekend.next?.course.name, '高等数学');
  check('下一节日期是 09-21', weekend.next?.dateKey, '2026-09-21');
  check('跨周后周次变为 2', weekend.next?.weekIndex, 2);
}

// ---------------- 6. 晚上与学期末 ----------------
console.log('\n[6] 晚上与学期末');
{
  const night: NextClassResult = NextClassEngine.resolve(TIMETABLE, SETTINGS, d(2026, 9, 18, 19, 40));
  check('周五 19:40 正上形势与政策', night.ongoing.length, 1);
  check('该课是第 9-10 节', [night.ongoing[0].startSlot, night.ongoing[0].endSlot], [9, 10]);
  check('该课结束时间 20:20（第 10 节下课）', night.ongoing[0].endClock, '20:20');

  // 学期结束：把开学日期往后挪一年
  const late: AppSettings = defaultSettings();
  late.semesterStartMonday = '2027-09-13';
  const done: NextClassResult = NextClassEngine.resolve(TIMETABLE, late, d(2026, 9, 14, 7, 0));
  check('未开学时 next 为空', done.next, null);
  check('未开学时 exhausted', done.exhausted, true);
  check('未开学时 weekIndex 为 0', done.weekIndex, 0);
}

// ---------------- 7. 周课表块与冲突标记 ----------------
console.log('\n[7] 周课表块');
{
  const w1: GridBlock[] = NextClassEngine.buildWeekBlocks(TIMETABLE, 1);
  check('第 1 周有 4 个块（自由时间不计入）', w1.length, 4);
  const mon: GridBlock[] = w1.filter((b: GridBlock) => b.weekday === 1);
  check('周一有 2 个冲突块', mon.length, 2);
  check('两块都被标记为冲突', [mon[0].conflict, mon[1].conflict], [true, true]);
  check('span 计算正确（1-2 节 = 2 节）', mon[0].span, 2);

  const w10: GridBlock[] = NextClassEngine.buildWeekBlocks(TIMETABLE, 10);
  // 第 10 周：高数（1-16 周）在，数据结构（1-8 周）已结课，
  // 大学物理是单周课（第 10 周是双周）也不上，所以只剩高数 + 形势与政策
  check('第 10 周剩 2 个块', w10.length, 2);
  const mon10: GridBlock[] = w10.filter((b: GridBlock) => b.weekday === 1);
  check('第 10 周周一不再冲突', mon10[0].conflict, false);

  // 第 11 周是单周，大学物理回来了
  const w11: GridBlock[] = NextClassEngine.buildWeekBlocks(TIMETABLE, 11);
  check('第 11 周（单周）大学物理回来，共 3 个块', w11.length, 3);
  const wed11: GridBlock[] = w11.filter((b: GridBlock) => b.weekday === 3);
  check('第 11 周周三有大学物理', wed11.length, 1);

  const w2: GridBlock[] = NextClassEngine.buildWeekBlocks(TIMETABLE, 2);
  const wed2: GridBlock[] = w2.filter((b: GridBlock) => b.weekday === 3);
  check('第 2 周周三无课（单周课）', wed2.length, 0);
}

// ---------------- 8. 自由时间课程 ----------------
console.log('\n[8] 自由时间课程');
{
  const free: CourseItem[] = NextClassEngine.freeTimeCourses(TIMETABLE);
  check('识别出 1 门自由时间课程', free.length, 1);
  check('课程名正确', free[0].name, '毕业设计');
}

// ---------------- 9. 考试解析 ----------------
console.log('\n[9] 考试安排');
{
  const exams: ExamEntry[] = NextClassEngine.upcomingExams(TIMETABLE, d(2026, 9, 14, 7, 0), 10);
  check('解析出 2 场考试', exams.length, 2);
  check('按时间排序，最早的是形势与政策', exams[0].courseName, '形势与政策');
  check('时间戳解析成功', exams[0].at > 0, true);
  check('地点为空时是空串', exams[0].location, '');
  const jan: ExamEntry = exams.filter((e: ExamEntry) => e.courseName === '高等数学')[0];
  check('1 月考试在 2027 年', new Date(jan.at).getFullYear(), 2027);
  check('1 月考试是 14:00', new Date(jan.at).getHours(), 14);

  // 已过去的考试应该被过滤掉
  const later: ExamEntry[] = NextClassEngine.upcomingExams(TIMETABLE, d(2027, 3, 1, 7, 0), 10);
  check('2027-03 之后历史考试被过滤', later.length, 0);
}

// ---------------- 10. 总周数 ----------------
console.log('\n[10] 总周数');
{
  // 课程只排到第 16 周，但一学期默认按 18 周算，方便用户往后翻看考试周
  check('课程到 16 周时，总周数兜底到 18', NextClassEngine.totalWeeks(TIMETABLE), 18);

  const longTimetable: Timetable = {
    name: 'x',
    semesterStartMonday: SEM_START,
    courses: [course('超长课程', 1, 1, 2, [20, 21], 'A101', '老师', null)]
  };
  check('课程排到第 21 周时取 21', NextClassEngine.totalWeeks(longTimetable), 21);

  const short: Timetable = { name: 'x', semesterStartMonday: SEM_START, courses: [] };
  check('空课表兜底 18 周', NextClassEngine.totalWeeks(short), 18);
}

// ---------------- 11. 空课表不崩 ----------------
console.log('\n[11] 边界：空课表');
{
  const empty: Timetable = { name: '', semesterStartMonday: SEM_START, courses: [] };
  const r: NextClassResult = NextClassEngine.resolve(empty, SETTINGS, d(2026, 9, 14, 7, 0));
  check('空课表 next 为空', r.next, null);
  check('空课表 exhausted', r.exhausted, true);
  check('空课表不抛异常', r.ongoing.length, 0);
}

console.log(`\n结果：通过 ${pass}，失败 ${fail}\n`);
if (fail > 0) {
  process.exit(1);
}
