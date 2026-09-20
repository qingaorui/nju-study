import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { SCHOOL_LIST, SchoolProfile, VPN_TIP } from '../constants/SchoolConfig';
import { Extractor, ExtractOutcome, extractBridge } from '../service/Extractor';
import { AppSettings, CourseStore, countDistinctCourses, normalizeCourses } from '../service/CourseStore';
import { AppBootstrap } from '../service/AppBootstrap';
import { Timetable } from '../model/Course';
import { DateUtil } from '../common/DateUtil';
import { Logger } from '../common/Logger';

/** 打开教务系统时伪装成桌面浏览器：部分页面的移动版会把课表表格折叠起来 */
const DESKTOP_UA: string =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

/**
 * 课表导入页：内置浏览器 + 自动抓取。
 *
 * 完整链路：
 *   打开统一身份认证登录页 → 用户自己输账号密码 → 跳到课表页
 *   → onPageEnd 检测到 URL 命中目标 → 注入抓取脚本 → 回传 JSON
 *   → 存进本地 → 让用户确认开学第一周 → 刷新卡片和提醒
 *
 * 关于安全：应用不接触、不存储用户的校园网账号密码，
 * 登录完全发生在官方页面上，应用只是在页面渲染完成后读了一次 DOM。
 */
@Entry
@Component
struct ImportPage {
  @State private profileIndex: number = 0;
  @State statusText: string = '请在弹出的页面中登录教务系统';
  @State busy: boolean = false;
  @State progress: number = 0;
  @State pageTitle: string = '';
  @State currentUrl: string = '';
  @State importing: boolean = false;

  private controller: webview.WebviewController = new webview.WebviewController();
  /** 已经抓过就不再重复抓，避免 SPA 反复触发 onPageEnd 时刷屏 */
  private extractedForUrl: string = '';

  private get profile(): SchoolProfile {
    return SCHOOL_LIST[this.profileIndex];
  }

  private get uiContext(): UIContext {
    return this.getUIContext();
  }

  build() {
    Column() {
      // ---------- 顶部：入口选择 + 状态 ----------
      Column() {
        Row() {
          Text('导入课表')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .layoutWeight(1)

          Button('已导入过？去首页')
            .fontSize(13)
            .height(32)
            .backgroundColor(Color.Transparent)
            .fontColor('#3D7EFF')
            .onClick(() => {
              router.back();
            })
        }
        .width('100%')

        // 入口切换（本科教务 / 选课系统 / 研究生）
        Scroll() {
          Row() {
            ForEach(SCHOOL_LIST, (item: SchoolProfile, index: number) => {
              Text(item.title.replace('南京大学', ''))
                .fontSize(13)
                .fontColor(index === this.profileIndex ? '#3D7EFF' : $r('sys.color.font_secondary'))
                .backgroundColor(index === this.profileIndex ? '#3D7EFF1A' : Color.Transparent)
                .borderRadius(14)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .margin({ right: 8 })
                .onClick(() => {
                  if (this.busy) {
                    return;
                  }
                  this.switchProfile(index);
                })
            }, (item: SchoolProfile) => item.id)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .width('100%')
        .margin({ top: 10 })

        Text(this.profile.description)
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
          .margin({ top: 6 })

        Row() {
          Text(this.statusText)
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .layoutWeight(1)
            .maxLines(2)

          if (this.importing) {
            LoadingProgress()
              .width(18)
              .height(18)
              .color('#3D7EFF')
          }
        }
        .width('100%')
        .margin({ top: 8 })
        .alignItems(VerticalAlign.Center)

        if (this.progress > 0 && this.progress < 100) {
          Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
            .width('100%')
            .margin({ top: 6 })
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('sys.color.background_secondary'))

      // ---------- 内置浏览器 ----------
      Web({ src: this.profile.initialUrl, controller: this.controller })
        .layoutWeight(1)
        .width('100%')
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .fileAccess(true)
        .imageAccess(true)
        .onlineImageAccess(true)
        .mixedMode(MixedMode.All)
        .geolocationAccess(false)
        .zoomAccess(true)
        .javaScriptProxy({
          object: extractBridge,
          name: 'njuBridge',
          methodList: ['postMessage', 'postLog'],
          controller: this.controller
        })
        .onControllerAttached(() => {
          try {
            this.controller.setCustomUserAgent(DESKTOP_UA);
          } catch (e) {
            Logger.w(`设置 UA 失败: ${e}`);
          }
        })
        .onProgressChange((event) => {
          this.progress = event.newProgress;
        })
        .onTitleReceive((event) => {
          this.pageTitle = event.title;
        })
        .onPageEnd((event) => {
          this.currentUrl = event.url;
          this.handlePageFinished(event.url);
        })
        .onErrorReceive((event) => {
          if (event.error.getErrorCode() === 0) {
            return;
          }
          this.statusText = `页面加载失败（${event.error.getErrorCode()}）。${VPN_TIP}`;
        })

      // ---------- 底部操作条 ----------
      Row() {
        Button('重新加载')
          .fontSize(14)
          .height(40)
          .layoutWeight(1)
          .backgroundColor($r('sys.color.background_secondary'))
          .fontColor($r('sys.color.font_primary'))
          .onClick(() => {
            try {
              this.controller.refresh();
            } catch (e) {
              Logger.w(`刷新失败: ${e}`);
            }
          })

        Button(this.importing ? '正在读取…' : '手动读取当前页')
          .fontSize(14)
          .height(40)
          .layoutWeight(2)
          .margin({ left: 10 })
          .backgroundColor('#3D7EFF')
          .fontColor(Color.White)
          .enabled(!this.importing)
          .onClick(() => {
            this.doExtract(true);
          })
      }
      .width('100%')
      .padding(12)
      .backgroundColor($r('sys.color.background_secondary'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }

  private switchProfile(index: number): void {
    this.profileIndex = index;
    this.extractedForUrl = '';
    this.statusText = '请在弹出的页面中登录教务系统';
    this.progress = 0;
    try {
      this.controller.loadUrl(this.profile.initialUrl);
    } catch (e) {
      Logger.w(`切换入口失败: ${e}`);
    }
  }

  /**
   * 页面加载完成后判断要不要自动抓。
   * SPA 的 onPageEnd 可能触发得比表格渲染早，所以自带重试。
   */
  private handlePageFinished(url: string): void {
    if (!Extractor.isTargetPage(this.profile, url)) {
      this.statusText = '请完成登录，进入「我的课表」页面后会自动读取';
      return;
    }
    if (this.extractedForUrl === url) {
      return;
    }
    this.extractedForUrl = url;
    this.statusText = '检测到课表页面，正在自动读取…';
    this.doExtract(false);
  }

  /**
   * 执行抓取。
   * 自动模式下最多重试 4 次，每次隔 1.2 秒 —— 教务系统的表格是异步渲染的。
   */
  private async doExtract(manual: boolean): Promise<void> {
    if (this.importing) {
      return;
    }
    this.importing = true;
    const maxAttempts: number = manual ? 1 : 4;

    try {
      const context: common.UIAbilityContext = this.uiContext.getHostContext() as common.UIAbilityContext;

      // 先单独把脚本读出来：如果脚本文件缺失，要报"入口暂不可用"，
      // 而不是笼统地报"网络错误"——这两种情况的排查方向完全不同。
      let script: string = '';
      try {
        script = await Extractor.loadScript(context, this.profile.scriptFile);
      } catch (e) {
        Logger.e(`读取抓取脚本失败 ${this.profile.scriptFile}: ${e}`);
        this.statusText = `这个入口的解析脚本（${this.profile.scriptFile}）没有打包进来，请换一个入口导入`;
        this.importing = false;
        return;
      }
      if (!script || script.length === 0) {
        this.statusText = `解析脚本 ${this.profile.scriptFile} 是空的，请换一个入口导入`;
        this.importing = false;
        return;
      }

      let outcome: ExtractOutcome | null = null;
      for (let attempt = 0; attempt < maxAttempts; attempt++) {
        outcome = await Extractor.run(this.controller, this.profile, script, context);
        if (outcome.ok) {
          break;
        }
        if (manual) {
          break;
        }
        this.statusText = `第 ${attempt + 1} 次读取未成功，稍后重试…`;
        await Extractor.sleep(1200);
      }

      if (outcome === null || !outcome.ok) {
        this.statusText = outcome !== null ? outcome.message : '读取失败';
        this.importing = false;
        return;
      }

      await this.persist(outcome, context);
    } catch (e) {
      Logger.e(`导入流程异常: ${e}`);
      this.statusText = '导入过程出错，请检查网络后重试';
    } finally {
      this.importing = false;
    }
  }

  /** 落盘 + 问开学日期 + 刷新卡片和提醒 */
  private async persist(outcome: ExtractOutcome, context: common.UIAbilityContext): Promise<void> {
    const tt: Timetable | null = outcome.timetable;
    if (tt === null) {
      this.statusText = '没有解析出课表';
      return;
    }

    const settings: AppSettings = await CourseStore.loadSettings();
    tt.semesterStartMonday = settings.semesterStartMonday;

    const distinct: number = countDistinctCourses(tt.courses);
    this.statusText = `已读取《${tt.name}》：${distinct} 门课 / ${tt.courses.length} 条安排`;

    await CourseStore.saveTimetable(tt);

    if (!tt.semesterStartMonday) {
      // 第一次导入必须校准开学日期，否则算不出"第几周"，卡片也就没有意义
      this.askSemesterStart(tt, settings, context);
      return;
    }

    await AppBootstrap.onTimetableChanged(context);
    this.showSuccess(distinct);
    this.goHome();
  }

  /** 让用户选本学期第一周的周一 */
  private askSemesterStart(tt: Timetable, settings: AppSettings, context: common.UIAbilityContext): void {
    const now: Date = new Date();
    // 猜一个：当前是第 3 周 → 第一周周一大概是 2 周前的周一
    const guess: Date = DateUtil.addDays(now, -14);
    const monday: Date = DateUtil.addDays(guess, -(DateUtil.isoWeekday(guess) - 1));

    this.uiContext.showDatePickerDialog({
      start: new Date(now.getFullYear() - 1, 0, 1),
      end: new Date(now.getFullYear() + 1, 11, 31),
      selected: monday,
      onDateAccept: (value: Date) => {
        // 无论选的是哪天，都归到那一周的周一
        const chosenMonday: Date = DateUtil.addDays(value, -(DateUtil.isoWeekday(value) - 1));
        tt.semesterStartMonday = DateUtil.toDateKey(chosenMonday);
        settings.semesterStartMonday = tt.semesterStartMonday;
        CourseStore.saveTimetable(tt)
          .then(() => CourseStore.saveSettings(settings))
          .then(() => AppBootstrap.onTimetableChanged(context))
          .then(() => {
            this.showSuccess(countDistinctCourses(tt.courses));
            this.goHome();
          })
          .catch((e: Error) => {
            Logger.e(`保存开学日期失败: ${e.message}`);
            this.statusText = '保存失败，请重试';
          });
      }
    });
  }

  private showSuccess(distinct: number): void {
    this.uiContext.getPromptAction().showToast({
      message: `导入成功：${distinct} 门课，卡片已同步`,
      duration: 2200
    });
  }

  private goHome(): void {
    router.replaceUrl({ url: 'pages/Index' }).catch((e: Error) => {
      Logger.w(`返回首页失败: ${e.message}`);
    });
  }
}
