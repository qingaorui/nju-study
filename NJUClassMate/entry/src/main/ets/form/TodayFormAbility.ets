import { formBindingData, formExtensionAbility, formInfo } from '@kit.FormKit';
import { Configuration, Want } from '@kit.AbilityKit';
import { AppSettings, CourseStore } from '../service/CourseStore';
import { WidgetService } from '../service/WidgetService';
import { FormIdentity, pushForm } from './FormCommon';
import { Logger } from '../common/Logger';

/**
 * 「今日课表」桌面卡片提供方（2*4 / 4*4）。
 * 与「下一节课」卡片逻辑一致，只是换了数据构造方法。
 */
export default class TodayFormAbility extends formExtensionAbility.FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    FormIdentity.record(want);
    const data: Record<string, string> = WidgetService.buildTodaySync(this.context);
    return formBindingData.createFormBindingData(data);
  }

  onUpdateForm(formId: string): void {
    pushForm(formId, WidgetService.buildTodaySync(this.context));
  }

  onChangeFormVisibility(newStatus: Record<string, number>): void {
    const formIds: string[] = Object.keys(newStatus);
    for (let i = 0; i < formIds.length; i++) {
      const formId: string = formIds[i];
      if (newStatus[formId] === 1) {
        pushForm(formId, WidgetService.buildTodaySync(this.context));
      }
    }
  }

  /**
   * 卡片上的按钮点进来会走到这里。
   *
   * 这里刻意用「在原始 message 里找关键字」而不是 JSON.parse：
   * 卡片传过来的 message 就是 postCardAction 里 params 的序列化结果，
   * 结构极简，而 ArkTS 对 JSON.parse 得到的动态对象做类型收窄很啰嗦、
   * 还容易在严格模式下报错。直接字符串匹配最稳。
   * 未知事件一律当"刷新"处理，保证点了按钮至少有反馈。
   */
  onFormEvent(formId: string, message: string): void {
    Logger.d(`今日卡片事件 formId=${formId} message=${message}`);

    if (message.indexOf('toggleDay') >= 0) {
      this.toggleTodayTomorrow(formId);
      return;
    }
    pushForm(formId, WidgetService.buildTodaySync(this.context));
  }

  /**
   * 在「今天」和「明天」之间切换。
   * 因为这是一个全局偏好（不是每张卡片各自的），
   * 所以改完之后把所有已登记的卡片一起刷一遍，避免桌面上几张卡片显示不一致。
   */
  private toggleTodayTomorrow(fallbackFormId: string): void {
    const ctx = this.context;
    CourseStore.init(ctx)
      .then(() => CourseStore.loadSettings())
      .then((settings: AppSettings) => {
        settings.todayCardForceTomorrow = !settings.todayCardForceTomorrow;
        return CourseStore.saveSettings(settings);
      })
      .then(() => CourseStore.loadFormIds())
      .then((ids: string[]) => WidgetService.refreshAllForms(ctx, ids))
      .catch((e: Error) => {
        Logger.w(`切换今天/明天失败，退回只刷当前卡片: ${e.message}`);
        pushForm(fallbackFormId, WidgetService.buildTodaySync(ctx));
      });
  }

  onRemoveForm(formId: string): void {
    CourseStore.removeFormId(formId).catch((e: Error) => {
      Logger.w(`清理卡片 id 失败: ${e.message}`);
    });
  }

  onCastToNormalForm(formId: string): void {
    Logger.d(`临时卡片转常态: ${formId}`);
  }

  onConfigurationUpdate(newConfig: Configuration): void {
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }
}
