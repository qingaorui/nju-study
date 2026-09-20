import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { AppSettings, CourseStore, defaultSettings } from '../service/CourseStore';
import { AppBootstrap } from '../service/AppBootstrap';
import { DEFAULT_TIME_SLOTS, TimeSlot } from '../constants/SchoolConfig';
import { DateUtil } from '../common/DateUtil';
import { Logger } from '../common/Logger';

/**
 * 作息校准页。
 *
 * 这个页面存在的唯一理由：整个 App 最核心的产出是"下一节课几点开始"，
 * 而这个时间完全由这张作息表决定。作息一旦不对，卡片上的时间就整体偏移，
 * 但界面本身完全看不出来哪里错了——这是最难自查的一类问题。
 *
 * 所以这里给了两条修正路径：
 *   1. **整体平移**：如果课表时间整体早/晚了几分钟，一次点掉，不用逐节改。
 *      这是最常见的情况（夏令时、校区差异、班次微调通常都是常量偏移）。
 *   2. **逐节微调**：点某一节的开始/结束时间单独改。
 *
 * 改完立刻回写设置、重算卡片、重排提醒——用户不用再手动同步一次。
 */
@Entry
@Component
struct SlotEditorPage {
  @State settings: AppSettings = defaultSettings();
  @State slots: TimeSlot[] = [];
  @State dirty: boolean = false;

  private context: common.UIAbilityContext | null = null;
  /** 整体平移的档位（分钟） */
  private shiftOptions: number[] = [-10, -5, 5, 10];

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
    // 深拷贝一份，编辑过程中不直接改原对象，避免"取消"无从实现
    this.slots = this.settings.timeSlots.map((s: TimeSlot): TimeSlot => {
      return { index: s.index, start: s.start, end: s.end };
    });
    this.dirty = false;
  }

  /** 写回并触发全链路刷新 */
  private async commit(): Promise<void> {
    this.settings.timeSlots = this.slots;
    await CourseStore.saveSettings(this.settings);
    if (this.context !== null) {
      await AppBootstrap.onTimetableChanged(this.context);
    }
    this.dirty = false;
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

        Text('作息校准')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)

        Button('恢复默认')
          .fontSize(13)
          .height(32)
          .backgroundColor('#3D7EFF1A')
          .fontColor('#3D7EFF')
          .onClick(() => {
            this.restoreDefault();
          })
      }
      .width('100%')
      .padding({ left: 8, right: 16, top: 10, bottom: 10 })
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column() {
          // ---------- 说明 ----------
          Column() {
            Text('为什么需要校准')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
              .width('100%')

            Text('课表里存的是"第几节"，卡片上显示的几点几分是用下面这张表换算出来的。'
              + '各校区、夏令时、研究生班次都可能不一样，所以请对着你的课表核一次。\n\n'
              + '判断方法：随便挑一节今天/明天的课，看下面的时间对不对得上。'
              + '如果**所有课都整体早或晚了几分钟**，用「整体平移」一次改掉；'
              + '只有某一节不对，再单独点它。')
              .fontSize(12.5)
              .fontColor($r('sys.color.font_secondary'))
              .margin({ top: 6 })
              .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#EEF2FB')
          .borderRadius(14)

          // ---------- 整体平移 ----------
          Text('整体平移')
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
            .margin({ top: 16, bottom: 8 })

          Column() {
            Text('如果所有课的时间都偏了同一个量，用它一次修好')
              .fontSize(12.5)
              .fontColor($r('sys.color.font_tertiary'))
              .width('100%')
              .margin({ bottom: 10 })

            Row() {
              ForEach(this.shiftOptions, (delta: number) => {
                Button(delta > 0 ? `延后 ${delta} 分` : `提前 ${-delta} 分`)
                  .fontSize(12.5)
                  .height(32)
                  .layoutWeight(1)
                  .margin({ right: 8 })
                  .backgroundColor($r('sys.color.background_primary'))
                  .fontColor($r('sys.color.font_primary'))
                  .onClick(() => {
                    this.shiftAll(delta);
                  })
              }, (delta: number) => `shift-${delta}`)
            }
            .width('100%')
          }
          .groupCard()
          .padding({ top: 14, bottom: 14 })

          // ---------- 逐节编辑 ----------
          Text('逐节微调')
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
            .margin({ top: 16, bottom: 8 })

          Column() {
            ForEach(this.slots, (slot: TimeSlot, index: number) => {
              Column() {
                Row() {
                  Text(`第 ${slot.index} 节`)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('sys.color.font_primary'))
                    .width(62)

                  // 开始时间
                  Text(slot.start)
                    .fontSize(14)
                    .fontColor('#3D7EFF')
                    .backgroundColor('#3D7EFF14')
                    .borderRadius(8)
                    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                    .onClick(() => {
                      this.pickTime(index, true);
                    })

                  Text('–')
                    .fontSize(14)
                    .fontColor($r('sys.color.font_tertiary'))
                    .margin({ left: 8, right: 8 })

                  // 结束时间
                  Text(slot.end)
                    .fontSize(14)
                    .fontColor('#3D7EFF')
                    .backgroundColor('#3D7EFF14')
                    .borderRadius(8)
                    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                    .onClick(() => {
                      this.pickTime(index, false);
                    })

                  Blank()

                  Text(this.durationOf(slot))
                    .fontSize(11)
                    .fontColor(this.isValid(slot) ? $r('sys.color.font_tertiary') : '#FF4D4F')
                }
                .width('100%')
                .height(54)
                .alignItems(VerticalAlign.Center)

                if (index < this.slots.length - 1) {
                  Divider()
                    .strokeWidth(0.5)
                    .color($r('sys.color.comp_divider'))
                }
              }
              .width('100%')
            }, (slot: TimeSlot) => `slot-${slot.index}-${slot.start}-${slot.end}`)
          }
          .groupCard()

          // ---------- 预览 ----------
          Text('预览')
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
            .margin({ top: 16, bottom: 8 })

          Column() {
            Text(this.previewText())
              .fontSize(12)
              .fontColor($r('sys.color.font_secondary'))
              .width('100%')
          }
          .groupCard()
          .padding({ top: 14, bottom: 14 })

          // ---------- 底部提示 ----------
          Text('改完立刻生效：卡片会重新算一遍，课前提醒也会按新时间重排。')
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
            .margin({ top: 14, bottom: 40 })
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

  // ==================== 行为 ====================

  /** 弹出时间选择器改某一节的开始或结束 */
  private pickTime(index: number, isStart: boolean): void {
    const slot: TimeSlot = this.slots[index];
    const current: string = isStart ? slot.start : slot.end;
    const minutes: number = DateUtil.clockToMinutes(current);
    const hh: number = Math.floor(minutes / 60) % 24;
    const mm: number = minutes % 60;

    this.getUIContext().showTimePickerDialog({
      selected: new Date(2026, 0, 1, hh, mm),
      useMilitaryTime: true,
      onAccept: (value: TimePickerResult) => {
        const clock: string = `${DateUtil.pad2(value.hour)}:${DateUtil.pad2(value.minute)}`;
        const next: TimeSlot[] = this.slots.slice();
        next[index] = {
          index: slot.index,
          start: isStart ? clock : slot.start,
          end: isStart ? slot.end : clock
        };
        this.slots = next;
        this.dirty = true;
        this.commit();
        this.toast(`第 ${slot.index} 节已更新`);
      }
    });
  }

  /** 整体平移：所有节次的起止时间一起加 delta 分钟 */
  private shiftAll(delta: number): void {
    const next: TimeSlot[] = this.slots.map((s: TimeSlot): TimeSlot => {
      return {
        index: s.index,
        start: this.shiftClock(s.start, delta),
        end: this.shiftClock(s.end, delta)
      };
    });
    this.slots = next;
    this.dirty = true;
    this.commit();
    this.toast(delta > 0 ? `全部延后 ${delta} 分钟` : `全部提前 ${-delta} 分钟`);
  }

  private shiftClock(clock: string, delta: number): string {
    const base: number = DateUtil.clockToMinutes(clock);
    let v: number = base + delta;
    if (v < 0) {
      v = 0;
    }
    if (v > 23 * 60 + 59) {
      v = 23 * 60 + 59;
    }
    return DateUtil.minutesToClock(v);
  }

  private restoreDefault(): void {
    this.getUIContext().showAlertDialog({
      title: '恢复默认作息',
      message: '会把上表恢复成南京大学本科的常见班次，你做的所有修改都会丢失。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '恢复',
        action: () => {
          this.slots = DEFAULT_TIME_SLOTS.map((s: TimeSlot): TimeSlot => {
            return { index: s.index, start: s.start, end: s.end };
          });
          this.dirty = true;
          this.commit();
          this.toast('已恢复默认作息');
        }
      }
    });
  }

  // ==================== 展示辅助 ====================

  private durationOf(slot: TimeSlot): string {
    const d: number = DateUtil.clockToMinutes(slot.end) - DateUtil.clockToMinutes(slot.start);
    if (d <= 0) {
      return '时间不对';
    }
    return `${d} 分钟`;
  }

  private isValid(slot: TimeSlot): boolean {
    return DateUtil.clockToMinutes(slot.end) > DateUtil.clockToMinutes(slot.start);
  }

  /** 把整张表压成一行预览，方便一眼看出有没有明显错位 */
  private previewText(): string {
    const parts: string[] = [];
    for (let i = 0; i < this.slots.length; i++) {
      parts.push(`${this.slots[i].index}: ${this.slots[i].start}`);
    }
    return parts.join('　');
  }

  private toast(msg: string): void {
    this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1500 });
  }
}
