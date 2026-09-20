/**
 * 课表数据模型
 *
 * 字段命名刻意保持与 nju.app(南哪课表) 的解析脚本输出一致，
 * 这样第三方脚本可以直接复用，也方便与社区互通导入导出。
 */

/** 单条课程记录（一条记录 = 某个"星期几 + 第几节 + 哪些周"的上课片段） */
export interface CourseItem {
  /** 课程名称 */
  name: string;
  /** 上课地点，如 "仙Ⅱ-304" */
  classroom: string;
  /** 课程号 */
  classNumber: string;
  /** 授课教师 */
  teacher: string;
  /** 考试时间，可能为空 */
  testTime: string | null;
  /** 考试地点，可能为空 */
  testLocation: string | null;
  /** 备注信息 */
  info: string | null;
  /** 上课周次列表，升序，例如 [1,2,3,4,5] 或单双周过滤后的 [2,4,6,8] */
  weeks: number[];
  /** 星期几，1=周一 ... 7=周日，0 表示"自由时间/未指定" */
  weekTime: number;
  /** 起始节次，如 2 表示第2节；0 表示未指定 */
  startSlot: number;
  /** 结束节次（含），如 4 表示第4节；等于 startSlot 表示只上1节 */
  endSlot: number;
  /** 导入来源标记：1=教务系统抓取 */
  importType: number;
}

/** 一份完整课表 */
export interface Timetable {
  /** 学期名，如 "2026-2027学年 第1学期" */
  name: string;
  /** 学期第一周的周一，格式 yyyy-MM-dd。用于推算"今天是第几周" */
  semesterStartMonday: string;
  /** 课程片段列表 */
  courses: CourseItem[];
}

/** 自定义事件（作业 DDL / 临时加课 / 讲座等，用户手动添加） */
export interface UserEvent {
  id: string;
  title: string;
  /** ISO 时间戳（毫秒） */
  dueAt: number;
  /** 是否置顶到卡片 */
  pinned: boolean;
  done: boolean;
  note: string;
}

/** 课程在某一周的具体一次上课（由 NextClassEngine 计算得出） */
export interface ClassOccurrence {
  course: CourseItem;
  /** 该次上课的日期，yyyy-MM-dd */
  dateKey: string;
  /** 第几周 */
  weekIndex: number;
  /** 起始节次 */
  startSlot: number;
  /** 结束节次（含） */
  endSlot: number;
  /** 开始时间 HH:mm */
  startClock: string;
  /** 结束时间 HH:mm */
  endClock: string;
  /** 距现在还有多少分钟（负数表示正在进行/已结束） */
  minutesFromNow: number;
  /** 状态 */
  status: ClassStatus;
}

/** 一节课相对当前时间的状态 */
export enum ClassStatus {
  /** 尚未开始 */
  UPCOMING = 0,
  /** 正在上课 */
  ONGOING = 1,
  /** 已结束 */
  FINISHED = 2
}

/** 解析脚本回传的原始结构（对应 nju.app 的 njubksjw2.js 输出） */
export interface RawScriptResult {
  name: string;
  courses: RawCourse[];
}

export interface RawCourse {
  name: string;
  classroom: string;
  class_number: string;
  teacher: string;
  test_time: string | null;
  test_location: string | null;
  link: string | null;
  weeks: number[];
  /** 星期几，1-7 */
  week_time: number;
  /** 起始节次 */
  start_time: number;
  /** 节数，注意 nju.app 的脚本里 time_count = endSlot - startSlot（不含末节） */
  time_count: number;
  import_type: number;
  info: string | null;
  data: string | null;
}
