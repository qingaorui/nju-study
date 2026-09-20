import { formBindingData, formExtensionAbility, formInfo } from '@kit.FormKit';
import { Configuration, Want } from '@kit.AbilityKit';
import { CourseStore } from '../service/CourseStore';
import { WidgetService } from '../service/WidgetService';
import { FormIdentity } from './FormCommon';
import { Logger } from '../common/Logger';

const VARIANT: string = 'next';

/**
 * 「下一节课」桌面卡片提供方。
 *
 * onAddForm 是同步回调，必须马上返回数据，
 * 所以用的是 WidgetService.buildSync（同步读 preferences），不能在这里 await 任何东西。
 */
export default class NextClassFormAbility extends formExtensionAbility.FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    FormIdentity.record(want);
    const data: Record<string, string> = WidgetService.buildSync(this.context, VARIANT);
    return formBindingData.createFormBindingData(data);
  }

  /** 系统按 form_config 里的 updateDuration / scheduledUpdateTime 回调到这里 */
  onUpdateForm(formId: string): void {
    WidgetService.refreshOne(this.context, formId, VARIANT).catch((e: Error) => {
      Logger.e(`onUpdateForm 失败: ${e.message}`);
    });
  }

  /** 卡片从不可见变可见时顺手刷一次，用户划到负一屏看到的就是新数据 */
  onChangeFormVisibility(newStatus: Record<string, number>): void {
    const formIds: string[] = Object.keys(newStatus);
    for (let i = 0; i < formIds.length; i++) {
      const formId: string = formIds[i];
      if (newStatus[formId] === 1) {
        WidgetService.refreshOne(this.context, formId, VARIANT).catch((e: Error) => {
          Logger.w(`可见性变化刷新失败: ${e.message}`);
        });
      }
    }
  }

  /**
   * 卡片上的按钮事件。
   * 目前只有一个「刷新」按钮（action = 'refresh'），
   * 语义正好就是"重新算一遍并推给这张卡片"，所以不需要分支判断——
   * 以后加别的按钮时，在这里按 message 里的关键字分流即可。
   */
  onFormEvent(formId: string, message: string): void {
    Logger.d(`卡片事件 formId=${formId} message=${message}`);
    WidgetService.refreshOne(this.context, formId, VARIANT).catch((e: Error) => {
      Logger.w(`卡片事件刷新失败: ${e.message}`);
    });
  }

  onRemoveForm(formId: string): void {
    CourseStore.removeFormId(formId).catch((e: Error) => {
      Logger.w(`清理卡片 id 失败: ${e.message}`);
    });
    Logger.i(`卡片已移除: ${formId}`);
  }

  onCastToNormalForm(formId: string): void {
    Logger.d(`临时卡片转常态: ${formId}`);
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    // 切换深色模式/语言时系统会回调，这里让卡片下一轮自然刷新即可
    Logger.d('卡片配置发生变化，等待下一次刷新');
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    // 通过 READY 让卡片添加时就能立刻显示内容，而不是先显示占位
    return formInfo.FormState.READY;
  }
}
