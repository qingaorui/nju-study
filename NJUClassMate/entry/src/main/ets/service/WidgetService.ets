import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import { ClassOccurrence, ClassStatus, Timetable } from '../model/Course';
import { AppSettings, defaultSettings } from './CourseStore';
import { DaySchedule, NextClassEngine, NextClassResult } from './NextClassEngine';
import { DateUtil } from '../common/DateUtil';
import { Logger } from '../common/Logger';

const STORE_NAME: string = 'nju_classmate_store';
const KEY_TIMETABLE: string = 'timetable_json';
const KEY_SETTINGS: string = 'settings_json';

/** 卡片上"还没导入课表"的兜底文案 */
const PLACEHOLDER: Record<string, string> = {
  'hasClass': '0',
  'courseName': '还没有课表',
  'timeLine': '去 App 里一键导入',
  'location': '',
  'teacher': '',
  'remain': '',
  'statusLabel': '未导入',
  'weekLabel': '',
  'nextHint': '',
  'updatedAt': '',
  'accent': '#3D7EFF',
  'slotBadge': ''
};

/**
 * 卡片数据服务。
 *
 * 关键约束：FormExtensionAbility.onAddForm 是同步回调，必须立刻返回数据，
 * 所以这里刻意提供 buildSync()，用 preferences 的同步读接口把课表读出来算结果。
 * 异步的 refreshAllForms() 则用于课表变更后主动推更新。
 */
export class WidgetService {
  /** 同步读本地数据，供 onAddForm 使用 */
  private static loadSync(context: common.Context): SyncInput {
    const options: preferences.Options = { name: STORE_NAME };
    const prefs: preferences.Preferences = preferences.getPreferencesSync(context, options);
    const rawT: string = prefs.getSync(KEY_TIMETABLE, '') as string;
    const rawS: string = prefs.getSync(KEY_SETTINGS, '') as string;

    let timetable: Timetable = { name: '', semesterStartMonday: '', courses: [] };
    let settings: AppSettings = defaultSettings();
    try {
      if (rawT && rawT.length > 0) {
        timetable = JSON.parse(rawT) as Timetable;
      }
    } catch (e) {
      Logger.e(`卡片读取课表失败: ${e}`);
    }
    try {
      if (rawS && rawS.length > 0) {
        settings = JSON.parse(rawS) as AppSettings;
      }
    } catch (e) {
      settings = defaultSettings();
    }
    if (!settings.timeSlots || settings.timeSlots.length === 0) {
      settings = defaultSettings();
    }
    return { timetable: timetable, settings: settings };
  }

  /**
   * 生成卡片要绑定的数据。
   * 所有值都转成字符串：ArkTS 的 Record<string, string> 在卡片数据绑定里最稳，
   * 不用纠结 Object 装箱，也避免类型不一致导致绑定静默失效。
   */
  static buildSync(context: common.Context, variant: string): Record<string, string> {
    try {
      const input: SyncInput = WidgetService.loadSync(context);
      if (input.timetable.courses.length === 0) {
        return PLACEHOLDER;
      }
      if (!input.settings.semesterStartMonday) {
        // 没设开学日期就算不出周次，提示用户去设置
        const hint: Record<string, string> = { ...PLACEHOLDER };
        hint.courseName = input.timetable.name ? input.timetable.name : '课表已导入';
        hint.timeLine = '请设置开学第一周日期';
        hint.statusLabel = '待设置';
        return hint;
      }

      const now: Date = new Date();
      const result: NextClassResult = NextClassEngine.resolve(input.timetable, input.settings, now);
      return WidgetService.toWidgetData(input, result, now, variant);
    } catch (e) {
      Logger.e(`构建卡片数据失败: ${e}`);
      return PLACEHOLDER;
    }
  }

  private static toWidgetData(
    input: SyncInput,
    result: NextClassResult,
    now: Date,
    variant: string
  ): Record<string, string> {
    const data: Record<string, string> = { ...PLACEHOLDER };
    data.weekLabel = result.weekIndex > 0 ? `第 ${result.weekIndex} 周` : '假期';
    data.updatedAt = DateUtil.toClock(now);

    if (result.ongoing.length > 0) {
      // 正在上课
      const occ: ClassOccurrence = result.ongoing[0];
      const endMin: number = DateUtil.clockToMinutes(occ.endClock);
      const nowMin: number = now.getHours() * 60 + now.getMinutes();
      const left: number = Math.max(0, endMin - nowMin);
      data.hasClass = '1';
      data.courseName = occ.course.name;
      data.timeLine = WidgetService.formatTimeLine(occ);
      data.location = occ.course.classroom;
      data.teacher = occ.course.teacher;
      data.remain = left >= 60 ? `还剩 ${Math.floor(left / 60)} 小时 ${left % 60} 分` : `还剩 ${left} 分钟`;
      data.statusLabel = '正在上课';
      data.slotBadge = `第${occ.startSlot}-${occ.endSlot}节`;
      data.accent = '#F5A524';
      if (result.ongoing.length > 1) {
        data.nextHint = `同时段还有 ${result.ongoing.length - 1} 门（免修不免考）`;
      } else {
        data.nextHint = WidgetService.hintOfNext(result.next);
      }
      return data;
    }

    if (result.next !== null) {
      const occ: ClassOccurrence = result.next;
      data.hasClass = '1';
      data.courseName = occ.course.name;
      data.timeLine = WidgetService.formatTimeLine(occ);
      data.location = occ.course.classroom;
      data.teacher = occ.course.teacher;
      data.remain = DateUtil.humanizeRemain(occ.minutesFromNow);
      data.statusLabel = WidgetService.statusLabelOf(occ, now);
      data.slotBadge = `第${occ.startSlot}-${occ.endSlot}节`;
      data.accent = '#3D7EFF';

      if (result.restOfToday.length > 1) {
        data.nextHint = `今天还有 ${result.restOfToday.length - 1} 节`;
      } else if (variant === 'today' && input.settings.todayCardShowTomorrow) {
        data.nextHint = '今天的课结束啦';
      } else {
        data.nextHint = '';
      }
      return data;
    }

    // 一段时间内没课
    data.hasClass = '0';
    data.courseName = '最近没有课';
    data.timeLine = result.timetableName.length > 0 ? result.timetableName : '好好休息';
    data.statusLabel = '空闲';
    data.accent = '#8E8E93';
    return data;
  }

  private static statusLabelOf(occ: ClassOccurrence, now: Date): string {
    if (occ.status === ClassStatus.ONGOING) {
      return '正在上课';
    }
    const todayKey: string = DateUtil.toDateKey(now);
    if (occ.dateKey === todayKey) {
      return '今天';
    }
    const tomorrowKey: string = DateUtil.toDateKey(DateUtil.addDays(now, 1));
    if (occ.dateKey === tomorrowKey) {
      return '明天';
    }
    return `周${DateUtil.weekdayLabel(DateUtil.isoWeekday(new Date(occ.dateKey.replace(/-/g, '/'))))}`;
  }

  /** 统一成「周三 第2-4节 · 09:00-11:00」，卡片和列表共用一种说法 */
  static formatTimeLine(occ: ClassOccurrence): string {
    const wd: string = `周${DateUtil.weekdayLabel(DateUtil.isoWeekday(new Date(occ.dateKey.replace(/-/g, '/'))))}`;
    const slots: string = occ.startSlot === occ.endSlot ? `第${occ.startSlot}节` : `第${occ.startSlot}-${occ.endSlot}节`;
    return `${wd} ${slots} · ${occ.startClock}-${occ.endClock}`;
  }

  /** 卡片上"再下一节"的一行提示 */
  private static hintOfNext(next: ClassOccurrence | null): string {
    if (next === null) {
      return '';
    }
    const wd: string = `周${DateUtil.weekdayLabel(DateUtil.isoWeekday(new Date(next.dateKey.replace(/-/g, '/'))))}`;
    return `下一节 ${next.course.name} · ${wd} ${next.startClock}`;
  }

  /**
   * 「今日课表」卡片的数据。
   * 用 6 个扁平槽位而不是数组绑定，原因见 TodayCard.ets 里的注释。
   */
  static buildTodaySync(context: common.Context): Record<string, string> {
    const data: Record<string, string> = {
      'dateText': '',
      'weekLabel': '',
      'countText': '',
      'footerText': '',
      /** 'today' | 'tomorrow'，卡片上的切换按钮靠它决定显示什么 */
      'mode': 'today',
      /** 切换按钮上的文字 */
      'toggleLabel': '明天'
    };
    for (let i = 0; i < 6; i++) {
      data[`s${i}Time`] = '';
      data[`s${i}Name`] = '';
      data[`s${i}Loc`] = '';
      data[`s${i}State`] = 'none';
    }

    try {
      const input: SyncInput = WidgetService.loadSync(context);
      if (input.timetable.courses.length === 0) {
        data.dateText = '今日课表';
        data.footerText = '去 App 里一键导入南大课表';
        return data;
      }
      if (!input.settings.semesterStartMonday) {
        data.dateText = '今日课表';
        data.footerText = '请先在设置里填写开学第一周的周一日期';
        return data;
      }

      const now: Date = new Date();
      let target: Date = now;
      let prefix: string = '';
      let mode: string = 'today';
      let day: DaySchedule = NextClassEngine.daySchedule(input.timetable, input.settings, target, now);

      if (input.settings.todayCardForceTomorrow) {
        // 用户在卡片上按了「明天」——不管今天有没有课，都显示明天
        const tomorrowForced: Date = DateUtil.addDays(now, 1);
        target = tomorrowForced;
        prefix = '明天 · ';
        mode = 'tomorrow';
        day = NextClassEngine.daySchedule(input.timetable, input.settings, tomorrowForced, now);
      } else if (day.occurrences.length === 0 && input.settings.todayCardShowTomorrow) {
        // 今天没课时自动顶上明天的安排
        const tomorrow: Date = DateUtil.addDays(now, 1);
        const tomorrowDay: DaySchedule = NextClassEngine.daySchedule(input.timetable, input.settings, tomorrow, now);
        if (tomorrowDay.occurrences.length > 0) {
          target = tomorrow;
          prefix = '明天 · ';
          mode = 'tomorrow';
          day = tomorrowDay;
        }
      }

      data.mode = mode;
      data.toggleLabel = mode === 'tomorrow' ? '今天' : '明天';
      data.dateText = `${prefix}${target.getMonth() + 1}月${target.getDate()}日`;
      data.weekLabel = day.weekIndex > 0 ? `第 ${day.weekIndex} 周` : '假期';

      const max: number = Math.min(6, day.occurrences.length);
      let nextStart: string = '';
      for (let i = 0; i < max; i++) {
        const occ: ClassOccurrence = day.occurrences[i];
        data[`s${i}Time`] = `${occ.startClock}`;
        data[`s${i}Name`] = occ.course.name;
        data[`s${i}Loc`] = occ.course.classroom;
        if (occ.status === ClassStatus.FINISHED) {
          data[`s${i}State`] = 'done';
        } else if (occ.status === ClassStatus.ONGOING) {
          data[`s${i}State`] = 'now';
        } else {
          data[`s${i}State`] = 'todo';
          if (nextStart.length === 0) {
            nextStart = occ.startClock;
          }
        }
      }

      const total: number = day.occurrences.length;
      // 显示的是哪天就说哪天，别在"明天"模式下写"今天没有课"
      const noun: string = mode === 'tomorrow' ? '明天' : '今天';
      if (total === 0) {
        data.footerText = `${noun}没有课`;
      } else if (nextStart.length > 0) {
        data.footerText = `共 ${total} 节 · 下一节 ${nextStart}`;
      } else {
        data.footerText = `共 ${total} 节 · ${noun}的课都上完啦`;
      }
      return data;
    } catch (e) {
      Logger.e(`构建今日卡片失败: ${e}`);
      data.dateText = '今日课表';
      data.footerText = '数据读取失败';
      return data;
    }
  }

  // ---------------- 刷新 ----------------

  /**
   * 计算卡片的"下一次刷新时间"。
   *
   * 思路：卡片不会自己跳动，倒计时文字会变旧。
   * 与其每 5 分钟无脑刷一次（耗电、还有每天 50 次的配额），
   * 不如算准"状态即将发生变化"的那一刻：
   *   - 正在上课 → 下课时刷
   *   - 即将上课 → 上课时刻刷（这样卡片会从"还有 20 分钟"翻成"正在上课"）
   * 中间兜底靠 form_config 里的 updateDuration。
   */
  static nextRefreshMinutes(context: common.Context): number {
    const MIN: number = 5;
    const MAX: number = 30 * 4; // 与 updateDuration 的兜底周期对齐
    try {
      const input: SyncInput = WidgetService.loadSync(context);
      if (!input.settings.semesterStartMonday || input.timetable.courses.length === 0) {
        return MAX;
      }
      const now: Date = new Date();
      const result: NextClassResult = NextClassEngine.resolve(input.timetable, input.settings, now);

      if (result.ongoing.length > 0) {
        const occ: ClassOccurrence = result.ongoing[0];
        const endParts: string[] = occ.endClock.split(':');
        if (endParts.length !== 2) {
          return MIN;
        }
        const nowMin: number = now.getHours() * 60 + now.getMinutes();
        const endMin: number = DateUtil.clockToMinutes(occ.endClock);
        return WidgetService.clamp(endMin - nowMin, MIN, MAX);
      }

      if (result.next !== null) {
        const minutes: number = result.next.minutesFromNow;
        if (minutes <= 0) {
          return MIN;
        }
        return WidgetService.clamp(minutes, MIN, MAX);
      }
      return MAX;
    } catch (e) {
      return MAX;
    }
  }

  private static clamp(v: number, lo: number, hi: number): number {
    if (v < lo) {
      return lo;
    }
    if (v > hi) {
      return hi;
    }
    return v;
  }

  /**
   * 把新数据推给所有已添加的卡片。
   * 卡片可能已经被用户删掉了，updateForm 会报错，这时顺手把 formId 清掉。
   */
  static async refreshAllForms(context: common.Context, formIds: string[]): Promise<number> {
    let ok: number = 0;
    for (let i = 0; i < formIds.length; i++) {
      const formId: string = formIds[i];
      try {
        const data: Record<string, string> = WidgetService.buildSync(context, 'any');
        const binding: formBindingData.FormBindingData = formBindingData.createFormBindingData(data);
        await formProvider.updateForm(formId, binding);
        ok++;
        // 预约下一次精确刷新：越接近上课，卡片状态切换得越及时
        try {
          await formProvider.setFormNextRefreshTime(formId, WidgetService.nextRefreshMinutes(context));
        } catch (e) {
          Logger.w(`设置卡片下次刷新时间失败: ${e}`);
        }
      } catch (e) {
        Logger.w(`刷新卡片 ${formId} 失败（可能已被删除）: ${e}`);
      }
    }
    return ok;
  }

  /** 只刷新一张卡片，供 FormExtensionAbility.onUpdateForm 调用 */
  static async refreshOne(context: common.Context, formId: string, variant: string): Promise<void> {
    const data: Record<string, string> = WidgetService.buildSync(context, variant);
    const binding: formBindingData.FormBindingData = formBindingData.createFormBindingData(data);
    await formProvider.updateForm(formId, binding);
    try {
      await formProvider.setFormNextRefreshTime(formId, WidgetService.nextRefreshMinutes(context));
    } catch (e) {
      Logger.w(`预约下次刷新失败: ${e}`);
    }
  }
}

/** 同步读出来的原始输入 */
interface SyncInput {
  timetable: Timetable;
  settings: AppSettings;
}
