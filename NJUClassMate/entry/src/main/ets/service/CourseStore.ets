import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { CourseItem, Timetable, UserEvent } from '../model/Course';
import { DEFAULT_TIME_SLOTS, TimeSlot } from '../constants/SchoolConfig';
import { Logger } from '../common/Logger';

const STORE_NAME: string = 'nju_classmate_store';
const KEY_TIMETABLE: string = 'timetable_json';
const KEY_SETTINGS: string = 'settings_json';
const KEY_EVENTS: string = 'events_json';
const KEY_FORM_IDS: string = 'form_ids_json';
const KEY_LAST_SYNC: string = 'last_sync_at';

/** 用户偏好设置 */
export interface AppSettings {
  /** 学期第一周周一，yyyy-MM-dd */
  semesterStartMonday: string;
  /** 作息表（节次→时间），用户可在设置里校准 */
  timeSlots: TimeSlot[];
  /** 是否开启课前提醒 */
  remindEnabled: boolean;
  /** 提前几分钟提醒 */
  remindBeforeMinutes: number;
  /** 周课表是否显示周末 */
  showWeekend: boolean;
  /** 交错的连堂课是否用不同底色区分（同一时段多门课时） */
  highlightConflict: boolean;
  /** 是否在今日卡片底部显示明天的课 */
  todayCardShowTomorrow: boolean;
  /**
   * 今日卡片强制显示明天（由卡片上的「明天」按钮切换）。
   * 和 todayCardShowTomorrow 的区别：
   *   todayCardShowTomorrow 是"今天没课时自动顶上明天"；
   *   这个是"用户主动要求看明天"，即使今天有课也显示明天。
   */
  todayCardForceTomorrow: boolean;
  /** 自动刷新开关 */
  autoRefreshEnabled: boolean;
}

export function defaultSettings(): AppSettings {
  return {
    semesterStartMonday: '',
    timeSlots: DEFAULT_TIME_SLOTS,
    remindEnabled: true,
    remindBeforeMinutes: 15,
    showWeekend: false,
    highlightConflict: true,
    todayCardShowTomorrow: true,
    todayCardForceTomorrow: false,
    autoRefreshEnabled: true
  };
}

export function defaultEvents(): UserEvent[] {
  return [];
}

/**
 * 本地持久化。
 * 用 preferences 而不是关系型数据库：数据量很小（一份课表最多几百条），
 * 直接存 JSON 字符串最省事，读写也够快。
 */
export class CourseStore {
  private static prefs: preferences.Preferences | null = null;

  static async init(context: common.Context): Promise<void> {
    if (CourseStore.prefs !== null) {
      return;
    }
    const options: preferences.Options = { name: STORE_NAME };
    CourseStore.prefs = await preferences.getPreferences(context, options);
    Logger.i('CourseStore 初始化完成');
  }

  private static requirePrefs(): preferences.Preferences {
    if (CourseStore.prefs === null) {
      throw new Error('CourseStore 尚未初始化，请先调用 CourseStore.init(context)');
    }
    return CourseStore.prefs;
  }

  // ---------------- 课表 ----------------

  static async saveTimetable(t: Timetable): Promise<void> {
    const prefs: preferences.Preferences = CourseStore.requirePrefs();
    await prefs.put(KEY_TIMETABLE, JSON.stringify(t));
    await prefs.put(KEY_LAST_SYNC, Date.now());
    await prefs.flush();
    Logger.i(`课表已保存，共 ${t.courses.length} 条课程片段`);
  }

  static async loadTimetable(): Promise<Timetable> {
    const prefs: preferences.Preferences = CourseStore.requirePrefs();
    const raw: string = await prefs.get(KEY_TIMETABLE, '') as string;
    if (!raw) {
      return { name: '', semesterStartMonday: '', courses: [] };
    }
    try {
      const parsed: Timetable = JSON.parse(raw) as Timetable;
      if (!parsed.courses) {
        parsed.courses = [];
      }
      return parsed;
    } catch (e) {
      Logger.e(`课表 JSON 解析失败: ${e}`);
      return { name: '', semesterStartMonday: '', courses: [] };
    }
  }

  static async hasTimetable(): Promise<boolean> {
    const prefs: preferences.Preferences = CourseStore.requirePrefs();
    const raw: string = await prefs.get(KEY_TIMETABLE, '') as string;
    return raw.length > 0;
  }

  static async getLastSyncAt(): Promise<number> {
    const prefs: preferences.Preferences = CourseStore.requirePrefs();
    return await prefs.get(KEY_LAST_SYNC, 0) as number;
  }

  /** 清空课表（换学期 / 换账号时用） */
  static async clearTimetable(): Promise<void> {
    const prefs: preferences.Preferences = CourseStore.requirePrefs();
    await prefs.delete(KEY_TIMETABLE);
    await prefs.flush();
  }

  // ---------------- 设置 ----------------

  static async saveSettings(s: AppSettings): Promise<void> {
    const prefs: preferences.Preferences = CourseStore.requirePrefs();
    await prefs.put(KEY_SETTINGS, JSON.stringify(s));
    await prefs.flush();
  }

  static async loadSettings(): Promise<AppSettings> {
    const prefs: preferences.Preferences = CourseStore.requirePrefs();
    const raw: string = await prefs.get(KEY_SETTINGS, '') as string;
    const fallback: AppSettings = defaultSettings();
    if (!raw) {
      return fallback;
    }
    try {
      const parsed: AppSettings = JSON.parse(raw) as AppSettings;
      // 补齐后续版本新增的字段，避免旧数据读出来是 undefined
      if (!parsed.timeSlots || parsed.timeSlots.length === 0) {
        parsed.timeSlots = DEFAULT_TIME_SLOTS;
      }
      if (parsed.remindBeforeMinutes === undefined) {
        parsed.remindBeforeMinutes = 15;
      }
      if (parsed.remindEnabled === undefined) {
        parsed.remindEnabled = true;
      }
      if (parsed.showWeekend === undefined) {
        parsed.showWeekend = false;
      }
      if (parsed.highlightConflict === undefined) {
        parsed.highlightConflict = true;
      }
      if (parsed.todayCardShowTomorrow === undefined) {
        parsed.todayCardShowTomorrow = true;
      }
      if (parsed.todayCardForceTomorrow === undefined) {
        parsed.todayCardForceTomorrow = false;
      }
      if (parsed.autoRefreshEnabled === undefined) {
        parsed.autoRefreshEnabled = true;
      }
      return parsed;
    } catch (e) {
      Logger.e(`设置解析失败，回退默认值: ${e}`);
      return fallback;
    }
  }

  // ---------------- 自定义事件（DDL） ----------------

  static async saveEvents(list: UserEvent[]): Promise<void> {
    const prefs: preferences.Preferences = CourseStore.requirePrefs();
    await prefs.put(KEY_EVENTS, JSON.stringify(list));
    await prefs.flush();
  }

  static async loadEvents(): Promise<UserEvent[]> {
    const prefs: preferences.Preferences = CourseStore.requirePrefs();
    const raw: string = await prefs.get(KEY_EVENTS, '') as string;
    if (!raw) {
      return [];
    }
    try {
      return JSON.parse(raw) as UserEvent[];
    } catch (e) {
      return [];
    }
  }

  // ---------------- 已添加的卡片 id ----------------

  /**
   * 记下用户添加过的所有卡片 id。
   * 用途：应用在前台时想立刻刷新卡片，需要拿到 formId 调 updateForm。
   * 系统侧的定时刷新不需要这个，但前台即时刷新需要。
   */
  static async recordFormId(formId: string): Promise<void> {
    const ids: string[] = await CourseStore.loadFormIds();
    if (ids.indexOf(formId) < 0) {
      ids.push(formId);
      const prefs: preferences.Preferences = CourseStore.requirePrefs();
      await prefs.put(KEY_FORM_IDS, JSON.stringify(ids));
      await prefs.flush();
    }
  }

  static async removeFormId(formId: string): Promise<void> {
    const ids: string[] = await CourseStore.loadFormIds();
    const next: string[] = ids.filter((x: string) => x !== formId);
    const prefs: preferences.Preferences = CourseStore.requirePrefs();
    await prefs.put(KEY_FORM_IDS, JSON.stringify(next));
    await prefs.flush();
  }

  static async loadFormIds(): Promise<string[]> {
    if (CourseStore.prefs === null) {
      return [];
    }
    const prefs: preferences.Preferences = CourseStore.prefs;
    const raw: string = await prefs.get(KEY_FORM_IDS, '') as string;
    if (!raw) {
      return [];
    }
    try {
      return JSON.parse(raw) as string[];
    } catch (e) {
      return [];
    }
  }

  // ---------------- 备份 / 恢复 ----------------

  /** 导出全部数据为可分享的 JSON 字符串 */
  static async exportAll(): Promise<string> {
    const timetable: Timetable = await CourseStore.loadTimetable();
    const settings: AppSettings = await CourseStore.loadSettings();
    const events: UserEvent[] = await CourseStore.loadEvents();
    const bundle: BackupBundle = {
      version: 1,
      exportedAt: Date.now(),
      timetable: timetable,
      settings: settings,
      events: events
    };
    return JSON.stringify(bundle);
  }

  /** 从备份 JSON 恢复，成功返回 true */
  static async importAll(json: string): Promise<boolean> {
    try {
      const bundle: BackupBundle = JSON.parse(json) as BackupBundle;
      if (bundle.timetable && bundle.timetable.courses) {
        await CourseStore.saveTimetable(bundle.timetable);
      }
      if (bundle.settings) {
        await CourseStore.saveSettings(bundle.settings);
      }
      if (bundle.events) {
        await CourseStore.saveEvents(bundle.events);
      }
      return true;
    } catch (err) {
      Logger.e(`备份恢复失败: ${err}`);
      return false;
    }
  }
}

/** 备份文件结构，换机迁移用 */
export interface BackupBundle {
  version: number;
  exportedAt: number;
  timetable: Timetable;
  settings: AppSettings;
  events: UserEvent[];
}

/**
 * 把教务系统抓来的课程片段做一次规范化：
 * - 把 nju.app 语义的 time_count 换算成 endSlot
 * - 过滤掉明显无效的记录
 * - 按 星期 → 节次 → 课程名 排序，方便 UI 直接渲染
 */
export function normalizeCourses(raw: CourseItem[]): CourseItem[] {
  const out: CourseItem[] = [];
  for (let i = 0; i < raw.length; i++) {
    const c: CourseItem = raw[i];
    if (!c.name) {
      continue;
    }
    if (c.weekTime < 1 || c.weekTime > 7) {
      // 自由时间的课没有固定星期，仍然保留，但排在最后
      c.weekTime = 0;
    }
    if (c.weeks.length === 0) {
      continue;
    }
    c.startSlot = Math.max(0, c.startSlot);
    c.endSlot = Math.max(c.startSlot, c.endSlot);
    out.push(c);
  }
  out.sort((a: CourseItem, b: CourseItem): number => {
    if (a.weekTime !== b.weekTime) {
      return a.weekTime - b.weekTime;
    }
    if (a.startSlot !== b.startSlot) {
      return a.startSlot - b.startSlot;
    }
    return a.name.localeCompare(b.name);
  });
  return out;
}

/** 统计课程门数（同一课程号只算一门） */
export function countDistinctCourses(courses: CourseItem[]): number {
  const set: Set<string> = new Set<string>();
  for (let i = 0; i < courses.length; i++) {
    const c: CourseItem = courses[i];
    set.add(c.classNumber && c.classNumber.length > 0 ? c.classNumber : c.name);
  }
  return set.size;
}
