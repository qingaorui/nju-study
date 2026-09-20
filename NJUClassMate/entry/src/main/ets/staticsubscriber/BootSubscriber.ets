import { commonEventManager, StaticSubscriberExtensionAbility } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { AppBootstrap } from '../service/AppBootstrap';
import { WorkSchedulerHelper } from '../service/WorkSchedulerHelper';
import { Logger } from '../common/Logger';

/**
 * 开机事件订阅者。
 *
 * ⚠️ 先把话说清楚：在 HarmonyOS NEXT 上，三方普通应用**不能**真正意义上"监听开机广播自启"。
 *    StaticSubscriberExtensionAbility 的静态订阅能力主要面向系统应用 / 企业 MDM 托管应用，
 *    普通三方应用即使按文档把 module.json5 配好，开机事件也不会派发给它。
 *    所以这个类不承担主要职责，只是"两条腿走路"里的备用腿：
 *      - 若设备是企业托管（MDM），或应用拿到了系统签名，装上它就能真正开机自启；
 *      - 普通设备上它不会被调用，留着不产生任何副作用。
 *
 * 真正让"开机后课表照常工作"的三条现实路径（详见 README「开机自启」一节）：
 *    1. 桌面卡片由系统在开机后自动恢复渲染 —— 卡片提供方被拉起，
 *       数据本来就在本地 preferences 里，卡片一渲染就是对的；
 *    2. WorkScheduler 的 isPersisted = true 任务会被系统在重启后恢复，
 *       到点拉起 RefreshWorkAbility 干活；
 *    3. reminderAgentManager 登记的上课提醒是系统级提醒，
 *       重启后依然准时弹出，完全不依赖应用存活。
 */
export default class BootSubscriber extends StaticSubscriberExtensionAbility {
  onReceiveEvent(event: commonEventManager.CommonEventData): void {
    Logger.i(`收到系统事件: ${event.event}`);
    if (event.event === commonEventManager.Support.COMMON_EVENT_BOOT_COMPLETED) {
      this.handleWakeUp('开机完成');
    } else if (event.event === commonEventManager.Support.COMMON_EVENT_USER_UNLOCKED) {
      // 解锁后用户数据分区才可用，preferences 这时才读得到
      this.handleWakeUp('用户解锁');
    }
  }

  private handleWakeUp(reason: string): void {
    const ctx: common.ExtensionContext = this.context;
    if (ctx === undefined || ctx === null) {
      Logger.w(`${reason}：拿不到 ExtensionContext，跳过初始化`);
      return;
    }
    AppBootstrap.init(ctx)
      .then(() => AppBootstrap.syncBackgroundWork(ctx))
      .then(() => WorkSchedulerHelper.doRefresh(ctx))
      .catch((e: Error) => {
        Logger.e(`${reason} 后的初始化失败: ${e.message}`);
      });
  }
}
