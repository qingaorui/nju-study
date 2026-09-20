import { display } from '@kit.ArkUI';
import { CourseItem, Timetable } from '../model/Course';
import { TimeSlot } from '../constants/SchoolConfig';
import { NextClassEngine, GridBlock, DaySchedule } from '../service/NextClassEngine';
import { AppSettings } from '../service/CourseStore';
import { DateUtil } from '../common/DateUtil';

/** 左侧节次栏宽度 */
const TIME_COL_W: number = 34;
/** 单个节次格子的高度（vp） */
const CELL_H: number = 54;
/** 周课表左右内边距 */
const GRID_PADDING: number = 12;

/** 一个已经算好位置和大小的课程块 */
interface PlacedBlock {
  block: GridBlock;
  /** 同一时段有多门课时，本块占的宽度比例分母 */
  shareCount: number;
  /** 本块是第几列（0 开始） */
  shareIndex: number;
  colorIndex: number;
}

/**
 * 周课表视图。
 *
 * 为什么用绝对定位而不是纯 Flex：
 *   课程块要跨多节（占多行高度），而左侧时间栏是固定的每节一行，
 *   纯 Flex 会让"跨行块"和"时间栏"高度对不齐。
 *   绝对定位是这个场景最直接、最可控的做法。
 *
 * 冲突处理（免修不免考 / 同一时段两门课）：
 *   同一个 (星期, 起始节次) 上的多个块，按数量横向均分该列宽度。
 *   这是南大场景下覆盖率最高的做法——绝大多数冲突都是"同时段同节次"。
 */
@Component
export struct WeekGrid {
  @Prop timetable: Timetable;
  @Prop settings: AppSettings;
  @Prop weekIndex: number;
  /** 点击某个课程块的回调 */
  onBlockTap: (course: CourseItem) => void = () => {};

  @State private dayWidth: number = 44;
  @State private days: number[] = [1, 2, 3, 4, 5];
  @State private placed: PlacedBlock[] = [];
  @State private slots: TimeSlot[] = [];

  private palette: string[] = [
    '#5B8FF9', '#61DDAA', '#F6BD16', '#7262FD',
    '#78D3F8', '#9661BC', '#F6903D', '#008685',
    '#F08BB4', '#7F8FA6'
  ];

  aboutToAppear(): void {
    this.slots = this.settings.timeSlots;
    this.days = this.settings.showWeekend ? [1, 2, 3, 4, 5, 6, 7] : [1, 2, 3, 4, 5];
    this.recalc();
  }

  aboutToReuse(params: Record<string, Object>): void {
    this.recalc();
  }

  /** 根据屏幕宽度和列数重算格子宽度 */
  private recalc(): void {
    let totalWidth: number = 360;
    try {
      const info: display.Display = display.getDefaultDisplaySync();
      totalWidth = px2vp(info.width);
    } catch (e) {
      totalWidth = 360;
    }
    const usable: number = totalWidth - GRID_PADDING * 2 - TIME_COL_W;
    this.dayWidth = Math.max(28, usable / this.days.length);
    this.placed = this.place();
  }

  /** 把本周的课程块算成"带位置的块" */
  private place(): PlacedBlock[] {
    const blocks: GridBlock[] = NextClassEngine.buildWeekBlocks(this.timetable, this.weekIndex);
    const result: PlacedBlock[] = [];

    // 先统计每个 (星期, 起始节次) 上有几门课
    const groups: Map<string, GridBlock[]> = new Map<string, GridBlock[]>();
    for (let i = 0; i < blocks.length; i++) {
      const b: GridBlock = blocks[i];
      const key: string = `${b.weekday}#${b.startSlot}`;
      const list: GridBlock[] | undefined = groups.get(key);
      if (list === undefined) {
        groups.set(key, [b]);
      } else {
        list.push(b);
      }
    }

    const cursor: Map<string, number> = new Map<string, number>();
    for (let i = 0; i < blocks.length; i++) {
      const b: GridBlock = blocks[i];
      const key: string = `${b.weekday}#${b.startSlot}`;
      const list: GridBlock[] | undefined = groups.get(key);
      const total: number = list !== undefined ? list.length : 1;
      const idx: number = cursor.get(key) !== undefined ? (cursor.get(key) as number) : 0;
      cursor.set(key, idx + 1);

      result.push({
        block: b,
        shareCount: total,
        shareIndex: idx,
        colorIndex: this.colorIndexOf(b.course)
      });
    }
    return result;
  }

  /** 用课程号做稳定哈希，保证同一门课每次打开颜色一样 */
  private colorIndexOf(course: CourseItem): number {
    const seed: string = course.classNumber.length > 0 ? course.classNumber : course.name;
    let hash: number = 0;
    for (let i = 0; i < seed.length; i++) {
      hash = (hash * 31 + seed.charCodeAt(i)) % 100000;
    }
    return hash % this.palette.length;
  }

  build() {
    Column() {
      // ---------- 表头：周一 ~ 周日 ----------
      Row() {
        Text('')
          .width(TIME_COL_W)
        ForEach(this.days, (d: number) => {
          Text(`周${DateUtil.weekdayLabel(d)}`)
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .width(this.dayWidth)
            .textAlign(TextAlign.Center)
        }, (d: number) => `head-${d}`)
      }
      .width('100%')
      .padding({ left: GRID_PADDING, right: GRID_PADDING, bottom: 6 })

      // ---------- 主体：网格 + 课程块 ----------
      Stack({ alignContent: Alignment.TopStart }) {
        // 第 1 层：时间栏 + 网格线
        Row() {
          Column() {
            ForEach(this.slots, (s: TimeSlot) => {
              Column() {
                Text(`${s.index}`)
                  .fontSize(11)
                  .fontColor($r('sys.color.font_tertiary'))
                Text(s.start)
                  .fontSize(9)
                  .fontColor($r('sys.color.font_tertiary'))
              }
              .width(TIME_COL_W)
              .height(CELL_H)
              .justifyContent(FlexAlign.Start)
              .alignItems(HorizontalAlign.Center)
            }, (s: TimeSlot) => `slot-${s.index}`)
          }

          ForEach(this.days, (d: number) => {
            Column() {
              ForEach(this.slots, (s: TimeSlot) => {
                Column()
                  .width('100%')
                  .height(CELL_H)
                  .border({ width: { top: 0.5, left: 0.5 }, color: $r('sys.color.comp_divider') })
              }, (s: TimeSlot) => `cell-${d}-${s.index}`)
            }
            .width(this.dayWidth)
          }, (d: number) => `col-${d}`)
        }
        .width('100%')
        .padding({ left: GRID_PADDING, right: GRID_PADDING })

        // 第 2 层：课程块
        ForEach(this.placed, (p: PlacedBlock) => {
          this.courseBlock(p)
        }, (p: PlacedBlock) => `blk-${p.block.weekday}-${p.block.startSlot}-${p.block.course.classNumber}-${p.shareIndex}`)
      }
      .width('100%')
      .height(CELL_H * this.slots.length)
    }
    .width('100%')
  }

  @Builder
  courseBlock(p: PlacedBlock) {
    Column() {
      Text(p.block.course.name)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      if (p.block.span > 1) {
        Text(p.block.course.classroom)
          .fontSize(9)
          .fontColor('#FFFFFFCC')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 2 })
      }

      if (p.block.conflict) {
        Text('冲')
          .fontSize(9)
          .fontColor('#FFFFFF')
          .backgroundColor('#FF4D4F')
          .borderRadius(4)
          .padding({ left: 3, right: 3 })
          .margin({ top: 2 })
      }
    }
    .width(this.dayWidth / p.shareCount - 2)
    .height(CELL_H * p.block.span - 4)
    .padding(4)
    .backgroundColor(this.palette[p.colorIndex])
    .borderRadius(6)
    .alignItems(HorizontalAlign.Start)
    .position({
      x: GRID_PADDING + TIME_COL_W + (p.block.weekday - 1) * this.dayWidth
        + (this.dayWidth / p.shareCount) * p.shareIndex + 1,
      y: (p.block.startSlot - 1) * CELL_H + 2
    })
    .onClick(() => {
      this.onBlockTap(p.block.course);
    })
  }
}
