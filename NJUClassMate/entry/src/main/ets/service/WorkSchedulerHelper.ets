import { workScheduler } from '@kit.BackgroundTasksKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { CourseStore } from './CourseStore';
import { WidgetService } from './WidgetService';
import { ReminderService } from './ReminderService';
import { Logger } from '../common/Logger';

const WORK_ID: number = 1001;
const BUNDLE_NAME: string = 'cn.nju.classmate';
const ABILITY_NAME: string = 'RefreshWorkAbility';
/** 兜底刷新周期。三方应用的周期下限被系统限制得比较宽，2 小时是稳妥值 */
const REPEAT_CYCLE_MS: number = 2 * 60 * 60 * 1000;

/**
 * 后台定时任务。
 *
 * 为什么还需要它——卡片本身已经有 updateDuration 定时刷新了？
 * 因为卡片刷新只能"重新算一遍已有数据"，算不出新数据：
 *   - 到了新的一周，要重新判断本周有哪些课；
 *   - 用户可能在教务系统改了选课/调课，需要重新抓取（可由用户在设置里开启联网校验）；
 *   - 课前提醒队列需要按新的一周重排。
 * 这些都需要一次真正的"后台醒来干活"，所以用 WorkScheduler 兜底。
 *
 * 另外，isPersisted = true 意味着任务会写进系统，
 * 设备重启后系统会恢复该任务——这是"开机自启"里我们能拿到的、最实在的一环。
 */
export class WorkSchedulerHelper {
  static async start(): Promise<boolean> {
    const workInfo: workScheduler.WorkInfo = {
      workId: WORK_ID,
      bundleName: BUNDLE_NAME,
      abilityName: ABILITY_NAME,
      networkType: workScheduler.NetworkType.NETWORK_TYPE_ANY,
      isRepeat: true,
      repeatCycleTime: REPEAT_CYCLE_MS,
      isPersisted: true,
      parameters: {
        'reason': 'periodic refresh of timetable and widgets'
      }
    };
    try {
      await workScheduler.startWork(workInfo);
      Logger.i('后台定时刷新任务已注册');
      return true;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      Logger.w(`注册后台任务失败 code=${err.code} msg=${err.message}`);
      return false;
    }
  }

  static async stop(): Promise<void> {
    const workInfo: workScheduler.WorkInfo = {
      workId: WORK_ID,
      bundleName: BUNDLE_NAME,
      abilityName: ABILITY_NAME,
      isPersisted: true
    };
    try {
      await workScheduler.stopWork(workInfo, true);
      Logger.i('后台定时刷新任务已取消');
    } catch (e) {
      Logger.w(`取消失败（可能本就没注册）: ${e}`);
    }
  }

  static async isRunning(): Promise<boolean> {
    try {
      const works: workScheduler.WorkInfo[] = await workScheduler.getWorkStatus(WORK_ID);
      return works !== undefined && works !== null && works.length > 0;
    } catch (e) {
      return false;
    }
  }

  /**
   * 后台醒来后真正要做的事。
   * 注意这里只做"本地重算 + 卡片刷新 + 提醒重排"，不主动联网。
   * 教务系统的抓取必须依赖用户交互（统一身份认证），后台静默抓取既做不到也不合规。
   */
  static async doRefresh(context: common.Context): Promise<void> {
    try {
      await CourseStore.init(context);
      const settings = await CourseStore.loadSettings();
      if (!settings.autoRefreshEnabled) {
        Logger.i('自动刷新已关闭，跳过');
        return;
      }
      const timetable = await CourseStore.loadTimetable();
      const ids: string[] = await CourseStore.loadFormIds();
      const updated: number = await WidgetService.refreshAllForms(context, ids);
      const reminders: number = await ReminderService.rebuild(context, timetable, settings);
      Logger.i(`后台刷新完成：卡片 ${updated} 张，提醒 ${reminders} 条`);
    } catch (e) {
      Logger.e(`后台刷新出错: ${e}`);
    }
  }
}
