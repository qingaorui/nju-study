import { workScheduler } from '@kit.BackgroundTasksKit';
import { AppBootstrap } from '../service/AppBootstrap';
import { WorkSchedulerHelper } from '../service/WorkSchedulerHelper';
import { Logger } from '../common/Logger';

/**
 * 后台定时任务的能力实现。
 *
 * 系统按 WorkSchedulerHelper 注册的周期（2 小时）拉起这个 Ability，
 * 它只会活很短一段时间，干完活就被回收——所以这里不能做长耗时操作。
 *
 * 当前职责：本地重算下周次、刷新所有卡片、重排课前提醒。
 * 刻意不联网：教务系统需要统一身份认证，后台静默抓取既不可行也不合适。
 */
export default class RefreshWorkAbility extends workScheduler.WorkSchedulerExtensionAbility {
  onWorkStart(work: workScheduler.WorkInfo): void {
    Logger.i(`后台任务启动 workId=${work.workId}`);
    WorkSchedulerHelper.doRefresh(this.context).catch((e: Error) => {
      Logger.e(`后台刷新失败: ${e.message}`);
    });
  }

  onWorkStop(work: workScheduler.WorkInfo): void {
    Logger.i(`后台任务结束 workId=${work.workId}`);
    // 单次任务结束后，如果是周期性任务系统会自动排下一次，无需手工重排
  }
}
