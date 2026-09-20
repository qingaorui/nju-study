import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { router } from '@kit.ArkUI';
import { Timetable } from '../model/Course';
import { AppSettings, CourseStore, defaultSettings } from '../service/CourseStore';
import { AppBootstrap } from '../service/AppBootstrap';
import { WorkSchedulerHelper } from '../service/WorkSchedulerHelper';
import { ReminderService } from '../service/ReminderService';
import { ExportService } from '../service/ExportService';
import { DateUtil } from '../common/DateUtil';
import { Logger } from '../common/Logger';

/** 提醒提前量可选项 */
const REMIND_OPTIONS: number[] = [5, 10, 15, 20, 30];

/**
 * 设置页。
 *
 * 分组原则：按"用户会什么时候来改"分组，而不是按数据结构分组。
 *   - 刚导完课表 → 改开学日期、校对上作息
 *   - 用一阵子  → 调提醒、调卡片
 *   - 换手机    → 备份、清空
 *
 * 说明：这里刻意没有用"传闭包给 @Builder 当容器"的写法，
 * 因为那种写法对编译版本挑剔、出错时又没有明确报错。
 * 改用 @Styles 统一卡片外观 + 显式 Column 包裹，啰嗦一点但绝对可靠。
 */
@Entry
@Component
struct SettingsPage {
  @State settings: AppSettings = defaultSettings();
  @State timetable: Timetable = { name: '', semesterStartMonday: '', courses: [] };
  @State bgWorkRunning: boolean = false;
  @State reminderCount: number = 0;
  @State loaded: boolean = false;

  private context: common.UIAbilityContext | null = null;

  @Styles
  groupCard() {
    .width('100%')
    .padding({ left: 14, right: 14 })
    .backgroundColor($r('sys.color.background_secondary'))
    .borderRadius(14)
  }

  aboutToAppear(): void {
    this.context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.reload();
  }

  private async reload(): Promise<void> {
    if (this.context !== null) {
      await CourseStore.init(this.context);
    }
    this.settings = await CourseStore.loadSettings();
    this.timetable = await CourseStore.loadTimetable();
    this.bgWorkRunning = await WorkSchedulerHelper.isRunning();
    this.reminderCount = await ReminderService.pendingCount();
    this.loaded = true;
  }

  private async commit(silent: boolean): Promise<void> {
    await CourseStore.saveSettings(this.settings);
    if (this.context !== null) {
      await AppBootstrap.syncBackgroundWork(this.context);
      await AppBootstrap.onTimetableChanged(this.context);
    }
    await this.reload();
    if (!silent) {
      this.toast('已保存');
    }
  }

  build() {
    Column() {
      // ---------- 顶栏 ----------
      Row() {
        Button('‹')
          .fontSize(20)
          .width(36)
          .height(36)
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.font_primary'))
          .onClick(() => {
            router.back();
          })

        Text('设置')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)

        Text(`${this.reminderCount} 条提醒`)
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .padding({ left: 8, right: 16, top: 10, bottom: 10 })
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column() {
          // ================= 学期 =================
          this.groupTitle('学期');

          Column() {
            this.rowNav('开学第一周的周一',
              this.settings.semesterStartMonday.length > 0 ? this.settings.semesterStartMonday : '点这里选择',
              () => {
                this.pickSemesterStart();
              })

            this.divider()

            Column() {
              Row() {
                Text('作息时间表')
                  .fontSize(15)
                  .fontColor($r('sys.color.font_primary'))
                  .layoutWeight(1)
                Text(`${this.settings.timeSlots.length} 节`)
                  .fontSize(13)
                  .fontColor($r('sys.color.font_secondary'))
                Text('›')
                  .fontSize(16)
                  .fontColor($r('sys.color.font_tertiary'))
                  .margin({ left: 6 })
              }
              .width('100%')

              Text('各校区、夏令时、研究生班次都可能不同。如果卡片上的上课时间整体偏移，点这里校准。')
                .fontSize(11)
                .fontColor($r('sys.color.font_tertiary'))
                .margin({ top: 4 })
                .width('100%')

              Text(this.slotPreview())
                .fontSize(11)
                .fontColor($r('sys.color.font_secondary'))
                .margin({ top: 6 })
                .width('100%')
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
            .alignItems(HorizontalAlign.Start)
            .onClick(() => {
              router.pushUrl({ url: 'pages/SlotEditorPage' });
            })
          }
          .groupCard()

          // ================= 提醒 =================
          this.groupTitle('上课提醒');

          Column() {
            this.rowSwitch('开启课前提醒',
              '用系统提醒代理，应用退到后台也会准时弹出',
              this.settings.remindEnabled,
              (v: boolean) => {
                this.settings.remindEnabled = v;
                this.commit(false);
              })

            this.divider()

            Column() {
              Row() {
                Text('提前提醒')
                  .fontSize(15)
                  .fontColor($r('sys.color.font_primary'))
                  .layoutWeight(1)
                Text(`${this.settings.remindBeforeMinutes} 分钟`)
                  .fontSize(13)
                  .fontColor('#3D7EFF')
              }
              .width('100%')

              Row() {
                ForEach(REMIND_OPTIONS, (m: number) => {
                  Text(`${m} 分`)
                    .fontSize(12)
                    .fontColor(this.settings.remindBeforeMinutes === m ? Color.White : $r('sys.color.font_secondary'))
                    .backgroundColor(this.settings.remindBeforeMinutes === m ? '#3D7EFF' : $r('sys.color.background_primary'))
                    .borderRadius(12)
                    .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                    .margin({ right: 6 })
                    .onClick(() => {
                      this.settings.remindBeforeMinutes = m;
                      this.commit(true);
                    })
                }, (m: number) => `remind-${m}`)
              }
              .width('100%')
              .margin({ top: 8 })
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
          }
          .groupCard()

          // ================= 后台与自动刷新 =================
          this.groupTitle('后台与自动刷新');

          Column() {
            this.rowSwitch('启用后台自动刷新',
              '系统每 2 小时唤醒一次，重算周次并刷新卡片',
              this.settings.autoRefreshEnabled,
              (v: boolean) => {
                this.settings.autoRefreshEnabled = v;
                this.commit(false);
              })

            this.divider()
            this.rowInfo('后台任务状态', this.bgWorkRunning ? '已注册' : '未注册')
            this.divider()

            Column() {
              Text('关于「开机自启」')
                .fontSize(15)
                .fontColor($r('sys.color.font_primary'))
                .width('100%')

              Text('鸿蒙不允许三方应用监听开机广播，所以没有"开机自启"这个开关。'
                + '但开机后课表依然可用，原因是：\n'
                + '① 桌面卡片由系统恢复渲染，数据本来就在本地；\n'
                + '② 后台任务标记为持久化，重启后系统自动恢复；\n'
                + '③ 上课提醒走系统提醒代理，不依赖应用存活。\n\n'
                + '想更激进一点，可在「设置 → 应用启动管理 → 南哪儿课表」里'
                + '手动打开「允许自启动 / 允许关联启动 / 允许后台活动」。')
                .fontSize(11)
                .fontColor($r('sys.color.font_secondary'))
                .margin({ top: 6 })
                .width('100%')
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
            .alignItems(HorizontalAlign.Start)
          }
          .groupCard()

          // ================= 卡片 =================
          this.groupTitle('卡片显示');

          Column() {
            this.rowSwitch('周课表显示周末', '打开后周一到周日都显示',
              this.settings.showWeekend, (v: boolean) => {
                this.settings.showWeekend = v;
                this.commit(true);
              })
            this.divider()
            this.rowSwitch('今日卡片显示明天的课', '今天没课时自动顶上明天的安排',
              this.settings.todayCardShowTomorrow, (v: boolean) => {
                this.settings.todayCardShowTomorrow = v;
                this.commit(true);
              })
            this.divider()
            this.rowInfo('添加卡片的方法', '长按桌面图标 → 卡片')
          }
          .groupCard()

          // ================= 数据 =================
          this.groupTitle('数据');

          Column() {
            this.rowNav('重新导入课表', '回内置浏览器重新登录抓取', () => {
              router.pushUrl({ url: 'pages/ImportPage' });
            })
            this.divider()
            this.rowNav('导出备份文件', 'JSON 格式，换手机时用它恢复', () => {
              this.doExportBackup();
            })
            this.divider()
            this.rowNav('从备份恢复', '选择之前导出的 JSON 文件', () => {
              this.doImportBackup();
            })
            this.divider()
            this.rowNav('导出为日历 (.ics)', '导进系统日历，手表和电脑也能收到提醒', () => {
              this.doExportIcs();
            })
            this.divider()
            this.rowNavDanger('清空课表数据', '只删本地数据，不动教务系统', () => {
              this.confirmClear();
            })
          }
          .groupCard()

          // ================= 关于 =================
          this.groupTitle('关于');

          Column() {
            this.rowInfo('课表来源', '南京大学教务系统（内置浏览器抓取）')
            this.divider()
            this.rowInfo('数据存放', '仅保存在本机，不上传服务器')
            this.divider()
            this.rowInfo('账号安全', '登录在官方页面完成，应用不接触账号密码')
            this.divider()
            this.rowInfo('版本', '1.0.0')
          }
          .groupCard()

          Text('课表解析规则参考了开源项目「南哪课表 / NJU-Class-Shedule-Flutter」的公开实现，在此致谢。')
            .fontSize(10)
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
            .margin({ top: 16, bottom: 32 })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }

  // ==================== 通用小组件 ====================
  @Builder
  groupTitle(title: string) {
    Text(title)
      .fontSize(12)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
      .margin({ top: 16, bottom: 8 })
  }

  @Builder
  divider() {
    Divider()
      .strokeWidth(0.5)
      .color($r('sys.color.comp_divider'))
  }

  @Builder
  rowNav(title: string, value: string, action: () => void) {
    Row() {
      Text(title)
        .fontSize(15)
        .fontColor($r('sys.color.font_primary'))
        .layoutWeight(1)
      Text(value)
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ left: 8 })
      Text('›')
        .fontSize(16)
        .fontColor($r('sys.color.font_tertiary'))
        .margin({ left: 6 })
    }
    .width('100%')
    .height(52)
    .alignItems(VerticalAlign.Center)
    .onClick(action)
  }

  @Builder
  rowNavDanger(title: string, value: string, action: () => void) {
    Row() {
      Text(title)
        .fontSize(15)
        .fontColor('#FF4D4F')
        .layoutWeight(1)
      Text(value)
        .fontSize(13)
        .fontColor($r('sys.color.font_tertiary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ left: 8 })
    }
    .width('100%')
    .height(52)
    .alignItems(VerticalAlign.Center)
    .onClick(action)
  }

  @Builder
  rowInfo(title: string, value: string) {
    Row() {
      Text(title)
        .fontSize(15)
        .fontColor($r('sys.color.font_primary'))
        .layoutWeight(1)
      Text(value)
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ left: 8 })
    }
    .width('100%')
    .height(52)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  rowSwitch(title: string, desc: string, checked: boolean, onChange: (v: boolean) => void) {
    Row() {
      Column() {
        Text(title)
          .fontSize(15)
          .fontColor($r('sys.color.font_primary'))
          .width('100%')
        Text(desc)
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
          .margin({ top: 3 })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: checked })
        .selectedColor('#3D7EFF')
        .margin({ left: 10 })
        .onChange((isOn: boolean) => {
          onChange(isOn);
        })
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
  }

  private slotPreview(): string {
    const parts: string[] = [];
    for (let i = 0; i < this.settings.timeSlots.length && i < 4; i++) {
      const s = this.settings.timeSlots[i];
      parts.push(`${s.index}: ${s.start}`);
    }
    return parts.join('   ') + '  …';
  }

  // ==================== 行为 ====================
  private pickSemesterStart(): void {
    const now: Date = new Date();
    const current: Date | null = DateUtil.parseDateKey(this.settings.semesterStartMonday);
    const guess: Date = DateUtil.addDays(now, -14);
    const selected: Date = current !== null
      ? current
      : DateUtil.addDays(guess, -(DateUtil.isoWeekday(guess) - 1));

    this.getUIContext().showDatePickerDialog({
      start: new Date(now.getFullYear() - 1, 0, 1),
      end: new Date(now.getFullYear() + 1, 11, 31),
      selected: selected,
      onDateAccept: (value: Date) => {
        const monday: Date = DateUtil.addDays(value, -(DateUtil.isoWeekday(value) - 1));
        this.settings.semesterStartMonday = DateUtil.toDateKey(monday);
        this.timetable.semesterStartMonday = this.settings.semesterStartMonday;
        CourseStore.saveTimetable(this.timetable).then(() => {
          this.commit(false);
        }).catch((e: Error) => {
          Logger.e(`保存学期日期失败: ${e.message}`);
        });
      }
    });
  }

  private async doExportBackup(): Promise<void> {
    if (this.context === null) {
      return;
    }
    const uri: string = await ExportService.exportBackup(this.context);
    this.toast(uri.length > 0 ? '备份已导出' : '已取消');
  }

  private async doExportIcs(): Promise<void> {
    if (this.context === null) {
      return;
    }
    if (this.timetable.courses.length === 0) {
      this.toast('还没有课表可以导出');
      return;
    }
    const uri: string = await ExportService.exportIcs(this.context, this.timetable, this.settings);
    this.toast(uri.length > 0 ? '日历文件已导出，用系统日历打开即可导入' : '已取消');
  }

  private async doImportBackup(): Promise<void> {
    if (this.context === null) {
      return;
    }
    try {
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.context);
      const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      const uris: string[] = await documentPicker.select(options);
      if (uris === undefined || uris === null || uris.length === 0) {
        return;
      }
      const file: fileIo.File = fileIo.openSync(uris[0], fileIo.OpenMode.READ_ONLY);
      let content: string = '';
      try {
        const buffer: ArrayBuffer = new ArrayBuffer(1024 * 512);
        const len: number = fileIo.readSync(file.fd, buffer);
        const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
        content = decoder.decodeToString(new Uint8Array(buffer.slice(0, len)));
      } finally {
        fileIo.closeSync(file);
      }
      const ok: boolean = await CourseStore.importAll(content);
      if (ok) {
        await this.commit(true);
        this.toast('恢复成功');
      } else {
        this.toast('文件格式不对，恢复失败');
      }
    } catch (e) {
      Logger.e(`恢复备份失败: ${e}`);
      this.toast('恢复失败');
    }
  }

  private confirmClear(): void {
    this.getUIContext().showAlertDialog({
      title: '清空课表数据',
      message: '将删除本机保存的课表、提醒和卡片数据。教务系统里的选课不受影响，之后可以重新导入。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '确认清空',
        fontColor: '#FF4D4F',
        action: () => {
          this.doClear();
        }
      }
    });
  }

  private async doClear(): Promise<void> {
    try {
      await CourseStore.clearTimetable();
      await ReminderService.clearAll();
      this.settings.semesterStartMonday = '';
      await CourseStore.saveSettings(this.settings);
      if (this.context !== null) {
        await AppBootstrap.onTimetableChanged(this.context);
      }
      await this.reload();
      this.toast('已清空');
    } catch (e) {
      Logger.e(`清空失败: ${e}`);
      this.toast('清空失败');
    }
  }

  private toast(msg: string): void {
    this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1800 });
  }
}
