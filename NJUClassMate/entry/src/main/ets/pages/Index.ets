import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { ClassOccurrence, ClassStatus, CourseItem, Timetable } from '../model/Course';
import { AppSettings, CourseStore, countDistinctCourses, defaultSettings } from '../service/CourseStore';
import { NextClassEngine, NextClassResult, DaySchedule, ExamEntry } from '../service/NextClassEngine';
import { AppBootstrap } from '../service/AppBootstrap';
import { ReminderService } from '../service/ReminderService';
import { WeekGrid } from '../view/WeekGrid';
import { DateUtil } from '../common/DateUtil';
import { Logger } from '../common/Logger';

/** 前台状态下刷新倒计时的间隔：30 秒足够，几乎不耗电 */
const TICK_MS: number = 30 * 1000;

const EMPTY_TIMETABLE: Timetable = { name: '', semesterStartMonday: '', courses: [] };

/**
 * 首页。
 *
 * 信息优先级（从上到下就是重要性排序）：
 *   1. 下一节课 —— 用户 90% 的打开动机
 *   2. 今天剩余 —— 出门前扫一眼
 *   3. 本周全貌 —— 规划用
 *   4. 考试倒计时 —— 低频但关键
 */
@Entry
@Component
struct Index {
  @State timetable: Timetable = EMPTY_TIMETABLE;
  @State settings: AppSettings = defaultSettings();
  @State result: NextClassResult | null = null;
  @State today: DaySchedule | null = null;
  @State exams: ExamEntry[] = [];
  @State tab: number = 0;
  @State viewingWeek: number = 0;
  @State loaded: boolean = false;
  @State remindCount: number = 0;

  private timerId: number = -1;
  private context: common.UIAbilityContext | null = null;

  aboutToAppear(): void {
    this.context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.reload().then(() => {
      this.startTick();
    });
  }

  aboutToDisappear(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  onPageShow(): void {
    // 从导入页返回时数据可能已经变了，重新读一遍
    this.reload();
  }

  private startTick(): void {
    if (this.timerId !== -1) {
      return;
    }
    this.timerId = setInterval(() => {
      this.recompute();
    }, TICK_MS);
  }

  private async reload(): Promise<void> {
    try {
      if (this.context !== null) {
        await AppBootstrap.init(this.context);
      }
      this.timetable = await CourseStore.loadTimetable();
      this.settings = await CourseStore.loadSettings();
      this.viewingWeek = DateUtil.weekIndexOf(this.settings.semesterStartMonday, new Date());
      if (this.viewingWeek === 0) {
        this.viewingWeek = 1;
      }
      this.recompute();
      this.loaded = true;
      this.remindCount = await ReminderService.pendingCount();
    } catch (e) {
      Logger.e(`首页加载失败: ${e}`);
      this.loaded = true;
    }
  }

  /** 只做纯计算，不碰 IO，给定时器高频调用 */
  private recompute(): void {
    if (this.timetable.courses.length === 0) {
      this.result = null;
      this.today = null;
      this.exams = [];
      return;
    }
    const now: Date = new Date();
    this.result = NextClassEngine.resolve(this.timetable, this.settings, now);
    this.today = NextClassEngine.daySchedule(this.timetable, this.settings, now, now);
    this.exams = NextClassEngine.upcomingExams(this.timetable, now, 8);
  }

  build() {
    Column() {
      // ---------------- 顶栏 ----------------
      this.header()

      if (this.loaded && this.timetable.courses.length === 0) {
        this.emptyState()
      } else {
        Scroll() {
          Column() {
            // 下一节课大卡片
            this.heroCard()

            // 分段切换
            this.segmented()

            if (this.tab === 0) {
              this.todaySection()
            } else if (this.tab === 1) {
              this.weekSection()
            } else {
              this.examSection()
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 24 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }

  // ==================== 顶栏 ====================
  @Builder
  header() {
    Row() {
      Column() {
        Text(this.settings.semesterStartMonday.length > 0 && this.result !== null
          ? (this.result.weekIndex > 0 ? `第 ${this.result.weekIndex} 周` : '假期中')
          : '南哪儿课表')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))

        Text(this.timetable.name.length > 0 ? this.timetable.name : '还没有导入课表')
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .margin({ top: 2 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 手动同步按钮
      Button('同步')
        .fontSize(13)
        .height(32)
        .backgroundColor('#3D7EFF1A')
        .fontColor('#3D7EFF')
        .onClick(() => {
          this.manualSync();
        })

      Button('设置')
        .fontSize(13)
        .height(32)
        .margin({ left: 8 })
        .backgroundColor($r('sys.color.background_secondary'))
        .fontColor($r('sys.color.font_primary'))
        .onClick(() => {
          router.pushUrl({ url: 'pages/SettingsPage' });
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
  }

  // ==================== 下一节课 ====================
  @Builder
  heroCard() {
    Column() {
      if (this.result !== null && this.result.ongoing.length > 0) {
        // 正在上课
        Column() {
          Text('正在上课')
            .fontSize(12)
            .fontColor('#F5A524')
          Text(this.result.ongoing[0].course.name)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .margin({ top: 6 })
            .maxLines(2)
          Text(`${this.result.ongoing[0].startClock}-${this.result.ongoing[0].endClock} · ${this.result.ongoing[0].course.classroom}`)
            .fontSize(13)
            .fontColor('#FFFFFFCC')
            .margin({ top: 6 })
          if (this.result.ongoing.length > 1) {
            Text(`同时段还有 ${this.result.ongoing.length - 1} 门课：${this.result.ongoing[1].course.name}`)
              .fontSize(11)
              .fontColor('#FFFFFF99')
              .margin({ top: 4 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      } else if (this.result !== null && this.result.next !== null) {
        Column() {
          Row() {
            Text(this.statusTextOf(this.result.next))
              .fontSize(12)
              .fontColor('#FFFFFFCC')
              .layoutWeight(1)
            Text(slotBadgeOf(this.result.next))
              .fontSize(11)
              .fontColor('#FFFFFFCC')
          }
          .width('100%')

          Text(this.result.next.course.name)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .margin({ top: 6 })
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(Display.timeLine(this.result.next))
            .fontSize(13)
            .fontColor('#FFFFFFCC')
            .margin({ top: 8 })

          Row() {
            Text(`${this.result.next.course.classroom}   ${this.result.next.course.teacher}`)
              .fontSize(13)
              .fontColor('#FFFFFFCC')
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(DateUtil.humanizeRemain(this.result.next.minutesFromNow))
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
          .width('100%')
          .margin({ top: 6 })

          if (this.result.restOfToday.length > 1) {
            Text(`今天还有 ${this.result.restOfToday.length - 1} 节 · ${this.remindCount > 0 ? `已设 ${this.remindCount} 条提醒` : '未开启提醒'}`)
              .fontSize(11)
              .fontColor('#FFFFFF99')
              .margin({ top: 8 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      } else {
        Column() {
          Text('最近没有课')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Text(this.exams.length > 0 ? `距离最近一场考试还有 ${this.exams[0].daysLeft} 天` : '享受空闲时间')
            .fontSize(13)
            .fontColor('#FFFFFFCC')
            .margin({ top: 6 })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      }
    }
    .width('100%')
    .padding(18)
    .borderRadius(18)
    .linearGradient({
      angle: 135,
      colors: [
        [this.heroColorStart(), 0.0],
        [this.heroColorEnd(), 1.0]
      ]
    })
    .margin({ top: 4 })
  }

  private heroColorStart(): string {
    if (this.result !== null && this.result.ongoing.length > 0) {
      return '#F5A524';
    }
    return '#3D7EFF';
  }

  private heroColorEnd(): string {
    if (this.result !== null && this.result.ongoing.length > 0) {
      return '#F57C00';
    }
    return '#7A5BFF';
  }

  private statusTextOf(occ: ClassOccurrence): string {
    if (occ.dateKey === DateUtil.toDateKey(new Date())) {
      return '下一节课 · 今天';
    }
    const tomorrow: string = DateUtil.toDateKey(DateUtil.addDays(new Date(), 1));
    return occ.dateKey === tomorrow ? '下一节课 · 明天' : `下一节课 · ${occ.dateKey}`;
  }

  // ==================== 分段控件 ====================
  @Builder
  segmented() {
    Row() {
      this.segmentItem(0, '今日')
      this.segmentItem(1, '本周')
      this.segmentItem(2, this.exams.length > 0 ? `考试 ${this.exams.length}` : '考试')
    }
    .width('100%')
    .padding(4)
    .backgroundColor($r('sys.color.background_secondary'))
    .borderRadius(12)
    .margin({ top: 14, bottom: 12 })
  }

  @Builder
  segmentItem(index: number, label: string) {
    Text(label)
      .fontSize(14)
      .fontWeight(this.tab === index ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.tab === index ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(34)
      .borderRadius(9)
      .backgroundColor(this.tab === index ? $r('sys.color.background_primary') : Color.Transparent)
      .onClick(() => {
        this.tab = index;
      })
  }

  // ==================== 今日 ====================
  @Builder
  todaySection() {
    Column() {
      if (this.today === null || this.today.occurrences.length === 0) {
        Column() {
          Text('今天没有课')
            .fontSize(15)
            .fontColor($r('sys.color.font_primary'))
          Text(this.settings.todayCardShowTomorrow ? '桌面卡片会自动显示明天的课' : '好好休息')
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .margin({ top: 6 })
        }
        .width('100%')
        .padding(24)
        .backgroundColor($r('sys.color.background_secondary'))
        .borderRadius(14)
      } else {
        ForEach(this.today.occurrences, (occ: ClassOccurrence) => {
          this.todayRow(occ)
        }, (occ: ClassOccurrence) => `today-${occ.startSlot}-${occ.course.classNumber}-${occ.course.name}`)
      }

      // 自由时间课程（无固定时间地点）
      if (this.freeTimeCourses().length > 0) {
        Column() {
          Text('自由时间安排')
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
          ForEach(this.freeTimeCourses(), (c: CourseItem) => {
            Text(`${c.name}  ${c.teacher}`)
              .fontSize(13)
              .fontColor($r('sys.color.font_primary'))
              .width('100%')
              .margin({ top: 6 })
          }, (c: CourseItem) => `free-${c.classNumber}-${c.name}`)
        }
        .width('100%')
        .padding(14)
        .margin({ top: 10 })
        .backgroundColor($r('sys.color.background_secondary'))
        .borderRadius(14)
      }
    }
    .width('100%')
  }

  private freeTimeCourses(): CourseItem[] {
    return NextClassEngine.freeTimeCourses(this.timetable);
  }

  @Builder
  todayRow(occ: ClassOccurrence) {
    Row() {
      // 左侧时间轴
      Column() {
        Text(occ.startClock)
          .fontSize(12)
          .fontColor(occ.status === ClassStatus.ONGOING ? '#3D7EFF' : $r('sys.color.font_secondary'))
        Text(occ.endClock)
          .fontSize(10)
          .fontColor($r('sys.color.font_tertiary'))
          .margin({ top: 2 })
      }
      .width(52)
      .alignItems(HorizontalAlign.Start)

      // 状态竖条
      Column()
        .width(3)
        .height(44)
        .borderRadius(2)
        .backgroundColor(occ.status === ClassStatus.FINISHED ? $r('sys.color.comp_divider')
          : (occ.status === ClassStatus.ONGOING ? '#F5A524' : '#3D7EFF'))
        .margin({ right: 12 })

      // 内容
      Column() {
        Row() {
          Text(occ.course.name)
            .fontSize(15)
            .fontWeight(occ.status === ClassStatus.ONGOING ? FontWeight.Bold : FontWeight.Medium)
            .fontColor(occ.status === ClassStatus.FINISHED
              ? $r('sys.color.font_tertiary') : $r('sys.color.font_primary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (occ.status === ClassStatus.ONGOING) {
            Text('进行中')
              .fontSize(10)
              .fontColor('#F5A524')
              .backgroundColor('#F5A5241A')
              .borderRadius(6)
              .padding({ left: 6, right: 6, top: 1, bottom: 1 })
          }
        }
        .width('100%')

        Text(`第${occ.startSlot}-${occ.endSlot}节 · ${occ.course.classroom}${occ.course.teacher.length > 0 ? ' · ' + occ.course.teacher : ''}`)
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
          .margin({ top: 4 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .opacity(occ.status === ClassStatus.FINISHED ? 0.5 : 1)
  }

  // ==================== 本周 ====================
  @Builder
  weekSection() {
    Column() {
      // 周次切换
      Row() {
        Button('‹')
          .fontSize(16)
          .width(36)
          .height(32)
          .backgroundColor($r('sys.color.background_secondary'))
          .fontColor($r('sys.color.font_primary'))
          .onClick(() => {
            if (this.viewingWeek > 1) {
              this.viewingWeek--;
            }
          })

        Text(`第 ${this.viewingWeek} 周`)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Button('›')
          .fontSize(16)
          .width(36)
          .height(32)
          .backgroundColor($r('sys.color.background_secondary'))
          .fontColor($r('sys.color.font_primary'))
          .onClick(() => {
            if (this.viewingWeek < NextClassEngine.totalWeeks(this.timetable)) {
              this.viewingWeek++;
            }
          })
      }
      .width('100%')
      .margin({ bottom: 10 })

      if (this.viewingWeek !== (this.result !== null ? this.result.weekIndex : 0)) {
        Text('正在查看非本周的课表')
          .fontSize(11)
          .fontColor('#F5A524')
          .width('100%')
          .margin({ bottom: 6 })
      }

      WeekGrid({
        timetable: this.timetable,
        settings: this.settings,
        weekIndex: this.viewingWeek,
        onBlockTap: (course: CourseItem) => {
          this.showCourseDetail(course);
        }
      })
        .width('100%')

      Text(`共 ${countDistinctCourses(this.timetable.courses)} 门课 · ${this.timetable.courses.length} 条安排 · 点击课程块查看详情`)
        .fontSize(11)
        .fontColor($r('sys.color.font_tertiary'))
        .width('100%')
        .margin({ top: 12 })
    }
    .width('100%')
  }

  // ==================== 考试 ====================
  @Builder
  examSection() {
    Column() {
      if (this.exams.length === 0) {
        Column() {
          Text('没有解析到考试安排')
            .fontSize(15)
            .fontColor($r('sys.color.font_primary'))
          Text('教务系统里填写了考试时间的课程才会出现在这里')
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .margin({ top: 6 })
        }
        .width('100%')
        .padding(24)
        .backgroundColor($r('sys.color.background_secondary'))
        .borderRadius(14)
      } else {
        ForEach(this.exams, (exam: ExamEntry) => {
          Row() {
            Column() {
              Text(exam.courseName)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary'))
                .maxLines(2)
                .width('100%')
              Text(`${exam.raw}${exam.location.length > 0 ? ' · ' + exam.location : ''}`)
                .fontSize(12)
                .fontColor($r('sys.color.font_secondary'))
                .margin({ top: 4 })
                .width('100%')
                .maxLines(2)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Text(exam.daysLeft >= 0 ? `${exam.daysLeft} 天` : '待定')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(exam.daysLeft >= 0 && exam.daysLeft <= 7 ? '#FF4D4F' : '#3D7EFF')
          }
          .width('100%')
          .padding(14)
          .margin({ bottom: 10 })
          .backgroundColor($r('sys.color.background_secondary'))
          .borderRadius(14)
          .alignItems(VerticalAlign.Center)
        }, (exam: ExamEntry) => `exam-${exam.courseName}-${exam.raw}`)
      }
    }
    .width('100%')
  }

  // ==================== 空状态 ====================
  @Builder
  emptyState() {
    Column() {
      Text('还没有课表')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))

      Text('应用内置浏览器打开南大教务系统，登录后自动读取课表，\n不需要手动录入，也不会拿到你的账号密码。')
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .margin({ top: 10 })
        .textAlign(TextAlign.Center)

      Button('一键导入课表')
        .width(200)
        .height(44)
        .margin({ top: 22 })
        .backgroundColor('#3D7EFF')
        .fontColor(Color.White)
        .onClick(() => {
          router.pushUrl({ url: 'pages/ImportPage' });
        })

      Text('导入后可以长按桌面图标 → 卡片，把「下一节课」和「今日课表」放到桌面或锁屏')
        .fontSize(11)
        .fontColor($r('sys.color.font_tertiary'))
        .margin({ top: 18 })
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding(32)
  }

  // ==================== 行为 ====================
  private async manualSync(): Promise<void> {
    if (this.context === null) {
      return;
    }
    try {
      const report = await AppBootstrap.onTimetableChanged(this.context);
      this.remindCount = await ReminderService.pendingCount();
      this.recompute();
      this.getUIContext().getPromptAction().showToast({
        message: `已同步：${report.widgets} 张卡片、${report.reminders} 条提醒`,
        duration: 2000
      });
    } catch (e) {
      Logger.e(`手动同步失败: ${e}`);
    }
  }

  private showCourseDetail(course: CourseItem): void {
    this.getUIContext().showAlertDialog({
      title: course.name,
      message: `课程号：${course.classNumber}\n教师：${course.teacher}\n地点：${course.classroom}\n`
        + `上课：每周${DateUtil.weekdayLabel(course.weekTime)} 第${course.startSlot}-${course.endSlot}节\n`
        + `周次：${WeekText.of(course.weeks)}\n`
        + `${course.testTime ? '考试：' + course.testTime + '\n' : ''}`
        + `${course.info ? '备注：' + course.info : ''}`,
      confirm: {
        value: '知道了',
        action: () => {}
      }
    });
  }
}

/** 给 hero 卡片用的展示格式化工具，避免把展示逻辑塞进计算引擎 */
class Display {
  static timeLine(occ: ClassOccurrence): string {
    const wd: string = `周${DateUtil.weekdayLabel(DateUtil.isoWeekday(new Date(occ.dateKey.replace(/-/g, '/'))))}`;
    const slots: string = occ.startSlot === occ.endSlot ? `第${occ.startSlot}节` : `第${occ.startSlot}-${occ.endSlot}节`;
    return `${wd} ${slots} · ${occ.startClock}-${occ.endClock}`;
  }
}

/** 把周次数组压缩成 "1-8, 10-16 周" 这种好读的写法 */
class WeekText {
  static of(weeks: number[]): string {
    if (weeks.length === 0) {
      return '未指定';
    }
    const sorted: number[] = weeks.slice().sort((a: number, b: number) => a - b);
    const parts: string[] = [];
    let start: number = sorted[0];
    let prev: number = sorted[0];
    for (let i = 1; i < sorted.length; i++) {
      const cur: number = sorted[i];
      if (cur === prev + 1) {
        prev = cur;
        continue;
      }
      parts.push(start === prev ? `${start}` : `${start}-${prev}`);
      start = cur;
      prev = cur;
    }
    parts.push(start === prev ? `${start}` : `${start}-${prev}`);
    return parts.join(', ') + ' 周';
  }
}

/** 卡片/列表共用的节次角标文案 */
function slotBadgeOf(occ: ClassOccurrence): string {
  return `第${occ.startSlot}-${occ.endSlot}节`;
}
