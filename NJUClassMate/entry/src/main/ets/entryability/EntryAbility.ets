import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppBootstrap } from '../service/AppBootstrap';
import { Logger } from '../common/Logger';

/**
 * 应用主 Ability。
 *
 * 启动时做四件事（顺序有讲究）：
 *   1. 初始化本地存储 —— 后面所有逻辑都依赖它；
 *   2. 注册/恢复后台定时任务 —— 这是"离开应用后还能自动刷新"的基础；
 *   3. 刷新一次卡片 —— 用户从桌面卡片跳进来时，卡片数据往往已经过时；
 *   4. 处理路由参数 —— 卡片点击带过来的 page 参数。
 */
export default class EntryAbility extends UIAbility {
  private lastPage: string = '';

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    this.lastPage = EntryAbility.pageOf(want);

    AppBootstrap.init(this.context)
      .then(() => AppBootstrap.syncBackgroundWork(this.context))
      .then(() => AppBootstrap.refreshWidgetsOnly(this.context))
      .then((n: number) => {
        Logger.i(`启动流程完成，刷新了 ${n} 张卡片`);
      })
      .catch((e: Error) => {
        Logger.e(`启动流程出错: ${e.message}`);
      });
  }

  onDestroy(): void {
    Logger.i('EntryAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        Logger.e(`加载首页失败: ${JSON.stringify(err)}`);
        return;
      }
      Logger.i('首页加载完成');
    });
  }

  onWindowStageDestroy(): void {
  }

  onForeground(): void {
    // 回到前台时刷一次卡片，避免用户发现桌面卡片还停留在几小时前
    AppBootstrap.refreshWidgetsOnly(this.context).catch((e: Error) => {
      Logger.w(`前台刷新卡片失败: ${e.message}`);
    });
  }

  onBackground(): void {
  }

  /** 应用已在运行时，从卡片再次点进来只会走这里 */
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.lastPage = EntryAbility.pageOf(want);
    Logger.i(`onNewWant page=${this.lastPage}`);
  }

  /** 卡片点击可以带 page 参数，用来做"直达某个页面" */
  private static pageOf(want: Want): string {
    const params: Record<string, Object> = want.parameters;
    if (params === undefined || params === null) {
      return '';
    }
    const raw: ESObject = params['page'];
    if (typeof raw === 'string') {
      return raw as string;
    }
    return '';
  }

  /** 供页面读取最后一次的路由意图 */
  getPendingPage(): string {
    const p: string = this.lastPage;
    this.lastPage = '';
    return p;
  }
}
