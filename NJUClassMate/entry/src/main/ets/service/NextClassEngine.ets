import { ClassOccurrence, ClassStatus, CourseItem, Timetable } from '../model/Course';
import { TimeSlot } from '../constants/SchoolConfig';
import { AppSettings } from './CourseStore';
import { DateUtil } from '../common/DateUtil';

/** 某一天的课表 */
export interface DaySchedule {
  dateKey: string;
  /** 1-7 */
  weekday: number;
  /** 今天是第几周，0 表示还没开学 */
  weekIndex: number;
  isToday: boolean;
  /** 当天的课，按开始时间升序 */
  occurrences: ClassOccurrence[];
}

/** 「下一节课」的完整结果，卡片和首页都用它 */
export interface NextClassResult {
  /** 正在上的课（可能有多门，免修不免考场景），没有则为空数组 */
  ongoing: ClassOccurrence[];
  /** 严格意义上"接下来要上"的课，即开始时间晚于当前时间的第一门 */
  next: ClassOccurrence | null;
  /** 今天还剩的课 */
  restOfToday: ClassOccurrence[];
  /** 当前是第几周，0 表示未开学 */
  weekIndex: number;
  /** 学期名 */
  timetableName: string;
  /** 是否已经没有任何课了（比如学期结束） */
  exhausted: boolean;
  /** 计算时间戳 */
  asOf: number;
}

/** 周课表上的一个课程块 */
export interface GridBlock {
  course: CourseItem;
  weekday: number;
  startSlot: number;
  endSlot: number;
  /** 占几节，用于 UI 高度 */
  span: number;
  /** 该时段是否有多门课重叠 */
  conflict: boolean;
}

/** 即将到来的考试 */
export interface ExamEntry {
  courseName: string;
  /** 原始文本，解析不出来时直接展示 */
  raw: string;
  /** 解析出的时间戳，解析失败为 0 */
  at: number;
  location: string;
  daysLeft: number;
}

/**
 * 下一节课计算引擎。
 *
 * 设计要点：
 *   1. 所有时间都换算成绝对毫秒时间戳再比较，跨天、跨周不会错；
 *   2. 只依赖 settings.timeSlots 这张作息表，换校区/夏令时只要改表；
 *   3. 不区分"今天"和"以后"，统一扫一段时间窗，避免边界分支写错。
 */
export class NextClassEngine {
  /** 往前看多少天，超过这个范围就认为"暂时没课了" */
  private static readonly LOOKAHEAD_DAYS: number = 21;

  /** 从作息表里按节次取时间，取不到时返回 null */
  private static slotOf(slots: TimeSlot[], index: number): TimeSlot | null {
    for (let i = 0; i < slots.length; i++) {
      if (slots[i].index === index) {
        return slots[i];
      }
    }
    return null;
  }

  /** 该课程在某周是否要上 */
  static isActiveInWeek(course: CourseItem, weekIndex: number): boolean {
    if (weekIndex <= 0) {
      return false;
    }
    return course.weeks.indexOf(weekIndex) >= 0;
  }

  /**
   * 计算某一天的课程。
   * @param now 用于判断状态的时间基准
   */
  static daySchedule(
    timetable: Timetable,
    settings: AppSettings,
    date: Date,
    now: Date
  ): DaySchedule {
    const weekday: number = DateUtil.isoWeekday(date);
    const weekIndex: number = DateUtil.weekIndexOf(settings.semesterStartMonday, date);
    const dayStartTs: number = DateUtil.startOfDay(date).getTime();
    const nowTs: number = now.getTime();

    const occurrences: ClassOccurrence[] = [];
    for (let i = 0; i < timetable.courses.length; i++) {
      const c: CourseItem = timetable.courses[i];
      // 自由时间的课没有固定星期，不走这条路径
      if (c.weekTime !== weekday) {
        continue;
      }
      if (!NextClassEngine.isActiveInWeek(c, weekIndex)) {
        continue;
      }
      const occ: ClassOccurrence | null = NextClassEngine.toOccurrence(c, settings, dayStartTs, weekIndex, nowTs);
      if (occ !== null) {
        occurrences.push(occ);
      }
    }

    occurrences.sort((a: ClassOccurrence, b: ClassOccurrence): number => {
      return a.minutesFromNow - b.minutesFromNow;
    });

    return {
      dateKey: DateUtil.toDateKey(date),
      weekday: weekday,
      weekIndex: weekIndex,
      isToday: DateUtil.toDateKey(date) === DateUtil.toDateKey(now),
      occurrences: occurrences
    };
  }

  /** 把一条课程记录 + 某一天，变成一个具体的"这次上课" */
  private static toOccurrence(
    c: CourseItem,
    settings: AppSettings,
    dayStartTs: number,
    weekIndex: number,
    nowTs: number
  ): ClassOccurrence | null {
    const startSlot: TimeSlot | null = NextClassEngine.slotOf(settings.timeSlots, c.startSlot);
    const endSlot: TimeSlot | null = NextClassEngine.slotOf(settings.timeSlots, c.endSlot);
    if (startSlot === null) {
      // 作息表里找不到这一节，说明作息被改过，退化成占位时间
      const startClockFallback: string = '--:--';
      return {
        course: c,
        dateKey: DateUtil.toDateKey(new Date(dayStartTs)),
        weekIndex: weekIndex,
        startSlot: c.startSlot,
        endSlot: c.endSlot,
        startClock: startClockFallback,
        endClock: startClockFallback,
        minutesFromNow: 0,
        status: ClassStatus.UPCOMING
      };
    }

    const startMin: number = DateUtil.clockToMinutes(startSlot.start);
    const endMin: number = DateUtil.clockToMinutes(
      endSlot !== null ? endSlot.end : startSlot.end
    );
    const startTs: number = dayStartTs + startMin * 60000;
    const endTs: number = dayStartTs + endMin * 60000;

    let status: ClassStatus = ClassStatus.UPCOMING;
    if (nowTs >= endTs) {
      status = ClassStatus.FINISHED;
    } else if (nowTs >= startTs) {
      status = ClassStatus.ONGOING;
    }

    return {
      course: c,
      dateKey: DateUtil.toDateKey(new Date(dayStartTs)),
      weekIndex: weekIndex,
      startSlot: c.startSlot,
      endSlot: c.endSlot,
      startClock: startSlot.start,
      endClock: endSlot !== null ? endSlot.end : startSlot.end,
      minutesFromNow: Math.round((startTs - nowTs) / 60000),
      status: status
    };
  }

  /**
   * 算出"下一节课"。
   *
   * 注意：这里同时返回 ongoing 和 next。
   * 卡片上如果正在上课，应该显示"正在上课 · 还剩 xx 分钟"，
   * 而不是傻乎乎地显示半天之后的下一门。
   */
  static resolve(timetable: Timetable, settings: AppSettings, now: Date): NextClassResult {
    const weekIndex: number = DateUtil.weekIndexOf(settings.semesterStartMonday, now);

    const ongoing: ClassOccurrence[] = [];
    const restOfToday: ClassOccurrence[] = [];
    const upcoming: ClassOccurrence[] = [];

    for (let d = 0; d <= NextClassEngine.LOOKAHEAD_DAYS; d++) {
      const date: Date = DateUtil.addDays(now, d);
      const day: DaySchedule = NextClassEngine.daySchedule(timetable, settings, date, now);
      for (let i = 0; i < day.occurrences.length; i++) {
        const occ: ClassOccurrence = day.occurrences[i];
        if (occ.status === ClassStatus.ONGOING) {
          ongoing.push(occ);
        } else if (occ.status === ClassStatus.UPCOMING) {
          if (d === 0) {
            restOfToday.push(occ);
          }
          upcoming.push(occ);
        }
      }
      // 找到未来的课之后就再多扫两天，避免"本周最后一节"被截断
      if (upcoming.length > 0 && d > 2) {
        break;
      }
    }

    restOfToday.sort((a: ClassOccurrence, b: ClassOccurrence): number => {
      return a.minutesFromNow - b.minutesFromNow;
    });
    upcoming.sort((a: ClassOccurrence, b: ClassOccurrence): number => {
      return a.minutesFromNow - b.minutesFromNow;
    });

    // 今天还有课就优先显示今天的，否则顺延到后面的日子
    let next: ClassOccurrence | null = null;
    if (restOfToday.length > 0) {
      next = restOfToday[0];
    } else if (upcoming.length > 0) {
      next = upcoming[0];
    }

    return {
      ongoing: ongoing,
      next: next,
      restOfToday: restOfToday,
      weekIndex: weekIndex,
      timetableName: timetable.name,
      exhausted: next === null && ongoing.length === 0,
      asOf: now.getTime()
    };
  }

  /**
   * 生成周课表的课程块。
   * 同一 (weekday, startSlot) 有多门课时标记 conflict = true，
   * 让 UI 可以并排显示或者打上角标（南大免修不免考的常见情况）。
   */
  static buildWeekBlocks(timetable: Timetable, weekIndex: number): GridBlock[] {
    const blocks: GridBlock[] = [];
    for (let i = 0; i < timetable.courses.length; i++) {
      const c: CourseItem = timetable.courses[i];
      if (c.weekTime < 1 || c.weekTime > 7) {
        continue;
      }
      if (!NextClassEngine.isActiveInWeek(c, weekIndex)) {
        continue;
      }
      blocks.push({
        course: c,
        weekday: c.weekTime,
        startSlot: c.startSlot,
        endSlot: c.endSlot,
        span: Math.max(1, c.endSlot - c.startSlot + 1),
        conflict: false
      });
    }

    // 标记冲突
    for (let i = 0; i < blocks.length; i++) {
      for (let j = i + 1; j < blocks.length; j++) {
        const a: GridBlock = blocks[i];
        const b: GridBlock = blocks[j];
        if (a.weekday !== b.weekday) {
          continue;
        }
        const overlap: boolean = a.startSlot <= b.endSlot && b.startSlot <= a.endSlot;
        if (overlap) {
          a.conflict = true;
          b.conflict = true;
        }
      }
    }
    return blocks;
  }

  /** 取出所有"自由时间"的课程（无固定教室/时间） */
  static freeTimeCourses(timetable: Timetable): CourseItem[] {
    const out: CourseItem[] = [];
    for (let i = 0; i < timetable.courses.length; i++) {
      if (timetable.courses[i].weekTime < 1) {
        out.push(timetable.courses[i]);
      }
    }
    return out;
  }

  /**
   * 解析考试时间。
   * 教务系统里考试时间的写法不统一，这里尽量宽松地抽取
   * 「yyyy-MM-dd」+「HH:mm」，抽不到就原样展示。
   */
  static upcomingExams(timetable: Timetable, now: Date, limit: number): ExamEntry[] {
    const out: ExamEntry[] = [];
    const seen: Set<string> = new Set<string>();

    for (let i = 0; i < timetable.courses.length; i++) {
      const c: CourseItem = timetable.courses[i];
      if (!c.testTime || c.testTime.length === 0) {
        continue;
      }
      if (seen.has(c.testTime + '|' + c.name)) {
        continue;
      }
      seen.add(c.testTime + '|' + c.name);

      const entry: ExamEntry = NextClassEngine.parseExam(c.name, c.testTime, c.testLocation, now);
      if (entry.at === 0 || entry.at >= now.getTime()) {
        out.push(entry);
      }
    }

    out.sort((a: ExamEntry, b: ExamEntry): number => {
      if (a.at === 0) {
        return 1;
      }
      if (b.at === 0) {
        return -1;
      }
      return a.at - b.at;
    });
    return out.slice(0, limit);
  }

  private static parseExam(courseName: string, raw: string, location: string | null, now: Date): ExamEntry {
    const dateMatch: RegExpMatchArray | null = raw.match(/(\d{4})[-/年](\d{1,2})[-/月](\d{1,2})/);
    const timeMatch: RegExpMatchArray | null = raw.match(/(\d{1,2}):(\d{2})/);

    let at: number = 0;
    if (dateMatch !== null) {
      const y: number = Number.parseInt(dateMatch[1], 10);
      const m: number = Number.parseInt(dateMatch[2], 10);
      const d: number = Number.parseInt(dateMatch[3], 10);
      let hh: number = 0;
      let mm: number = 0;
      if (timeMatch !== null) {
        hh = Number.parseInt(timeMatch[1], 10);
        mm = Number.parseInt(timeMatch[2], 10);
      }
      const dt: Date = new Date(y, m - 1, d, hh, mm);
      at = dt.getTime();
    }

    const daysLeft: number = at === 0 ? -1 : DateUtil.diffDays(now, new Date(at));
    return {
      courseName: courseName,
      raw: raw,
      at: at,
      location: location !== null ? location : '',
      daysLeft: daysLeft
    };
  }

  /** 学年里一共有多少周（取所有课程周次的最大值，至少 18 周） */
  static totalWeeks(timetable: Timetable): number {
    let max: number = 18;
    for (let i = 0; i < timetable.courses.length; i++) {
      const weeks: number[] = timetable.courses[i].weeks;
      for (let j = 0; j < weeks.length; j++) {
        if (weeks[j] > max) {
          max = weeks[j];
        }
      }
    }
    return max;
  }
}
