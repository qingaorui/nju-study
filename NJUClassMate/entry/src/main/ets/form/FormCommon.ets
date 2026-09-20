import { formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { CourseStore } from '../service/CourseStore';
import { Logger } from '../common/Logger';

/**
 * 三个 FormExtensionAbility 共用的工具。
 * 单独抽一个文件，避免卡片之间互相 import 造成耦合。
 */
export class FormIdentity {
  /**
   * 从 want 里取卡片 id。
   * IDENTITY_KEY 的值运行时是字符串，但声明类型是 Object，
   * 用 ArkTS 的 ESObject 做动态读取是官方推荐姿势。
   */
  static read(want: Want): string {
    const params: Record<string, Object> = want.parameters;
    if (params === undefined || params === null) {
      return '';
    }
    const raw: ESObject = params[formInfo.FormParam.IDENTITY_KEY];
    if (typeof raw === 'string') {
      return raw as string;
    }
    return '';
  }

  /** 登记卡片 id，应用在前台时靠它主动推刷新 */
  static record(want: Want): void {
    const id: string = FormIdentity.read(want);
    if (id.length === 0) {
      return;
    }
    CourseStore.recordFormId(id).catch((e: Error) => {
      Logger.w(`记录卡片 id 失败: ${e.message}`);
    });
  }
}

/** 异步下发卡片数据，避免在同步回调里做 IO */
export async function pushForm(formId: string, data: Record<string, string>): Promise<void> {
  try {
    const binding: formBindingData.FormBindingData = formBindingData.createFormBindingData(data);
    await formProvider.updateForm(formId, binding);
  } catch (e) {
    Logger.w(`下发卡片数据失败 formId=${formId}: ${e}`);
  }
}
