import { formBindingData, formExtensionAbility, formInfo } from '@kit.FormKit';
import { Configuration, Want } from '@kit.AbilityKit';
import { CourseStore } from '../service/CourseStore';
import { WidgetService } from '../service/WidgetService';
import { FormIdentity, pushForm } from './FormCommon';
import { Logger } from '../common/Logger';

/**
 * 锁屏卡片提供方（1*1 / 1*2，需要 API 18+）。
 *
 * 和桌面卡片的差别：
 *   - form_config 里必须声明 renderingMode 和 supportDimensions；
 *   - 每次锁屏点亮都可能会刷新，所以刷新逻辑要足够轻：
 *     这里只是同步读 preferences + 纯计算，没有网络、没有磁盘写。
 */
export default class LockScreenFormAbility extends formExtensionAbility.FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    FormIdentity.record(want);
    const data: Record<string, string> = WidgetService.buildSync(this.context, 'lock');
    return formBindingData.createFormBindingData(data);
  }

  onUpdateForm(formId: string): void {
    pushForm(formId, WidgetService.buildSync(this.context, 'lock'));
  }

  onChangeFormVisibility(newStatus: Record<string, number>): void {
    const formIds: string[] = Object.keys(newStatus);
    for (let i = 0; i < formIds.length; i++) {
      const formId: string = formIds[i];
      if (newStatus[formId] === 1) {
        pushForm(formId, WidgetService.buildSync(this.context, 'lock'));
      }
    }
  }

  onFormEvent(formId: string, message: string): void {
    pushForm(formId, WidgetService.buildSync(this.context, 'lock'));
  }

  onRemoveForm(formId: string): void {
    CourseStore.removeFormId(formId).catch((e: Error) => {
      Logger.w(`清理锁屏卡片 id 失败: ${e.message}`);
    });
  }

  onCastToNormalForm(formId: string): void {
  }

  onConfigurationUpdate(newConfig: Configuration): void {
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }
}
