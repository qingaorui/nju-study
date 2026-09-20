import { common } from '@kit.AbilityKit';
import { CourseStore, AppSettings } from './CourseStore';
import { WidgetService } from './WidgetService';
import { ReminderService } from './ReminderService';
import { WorkSchedulerHelper } from './WorkSchedulerHelper';
import { Timetable } from '../model/Course';
import { Logger } from '../common/Logger';

/**
 * 启动引导。把"冷启动要干的事"收在一个地方，
 * EntryAbility / WorkScheduler / StaticSubscriber 三条入口共用，避免逻辑漂移。
 */
export class AppBootstrap {
  /** 任何入口的第一步 */
  static async init(context: common.Context): Promise<void> {
    await CourseStore.init(context);
    Logger.i('AppBootstrap 初始化完成');
  }

  /**
   * 课表导入/变更后统一收口：
   *   1. 立刻把新数据推给桌面和锁屏上的所有卡片；
   *   2. 按新课表重建课前提醒队列。
   */
  static async onTimetableChanged(context: common.Context): Promise<RefreshReport> {
    const timetable: Timetable = await CourseStore.loadTimetable();
    const settings: AppSettings = await CourseStore.loadSettings();
    const formIds: string[] = await CourseStore.loadFormIds();

    const widgets: number = await WidgetService.refreshAllForms(context, formIds);
    const reminders: number = await ReminderService.rebuild(context, timetable, settings);

    Logger.i(`课表变更处理完成：刷新卡片 ${widgets} 张、提醒 ${reminders} 条`);
    return { widgets: widgets, reminders: reminders };
  }

  /** 按用户设置启停后台定时任务 */
  static async syncBackgroundWork(context: common.Context): Promise<void> {
    const settings: AppSettings = await CourseStore.loadSettings();
    if (settings.autoRefreshEnabled) {
      await WorkSchedulerHelper.start();
    } else {
      await WorkSchedulerHelper.stop();
    }
  }

  /** 前台时把卡片刷一遍，保证用户切到桌面看到的是最新状态 */
  static async refreshWidgetsOnly(context: common.Context): Promise<number> {
    const formIds: string[] = await CourseStore.loadFormIds();
    return await WidgetService.refreshAllForms(context, formIds);
  }
}

/** 一次刷新动作的结果，给 UI 展示"已同步 N 张卡片"用 */
export interface RefreshReport {
  widgets: number;
  reminders: number;
}
