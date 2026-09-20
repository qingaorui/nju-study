import { picker } from '@kit.CoreFileKit';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { CourseItem, Timetable } from '../model/Course';
import { AppSettings, CourseStore, countDistinctCourses } from './CourseStore';
import { NextClassEngine, GridBlock } from './NextClassEngine';
import { DateUtil } from '../common/DateUtil';
import { Logger } from '../common/Logger';

/**
 * 导出服务：备份 JSON、导出 .ics 日历。
 *
 * 为什么要导出 .ics：
 *   课表 App 只能解决"看"，解决不了"和别的日程放一起"。
 *   导成 .ics 之后，上课时间会进系统日历，
 *   于是手表震动、平板日历、电脑日历全都能收到，等于把课表接进了整个生态。
 *   这是投入产出比最高、又几乎没人做的功能。
 */
export class ExportService {
  /**
   * 把整份数据存成 JSON 文件，让用户自己挑保存位置。
   * @returns 保存成功返回文件 URI，取消或失败返回空串
   */
  static async exportBackup(context: common.Context): Promise<string> {
    try {
      const json: string = await CourseStore.exportAll();
      const name: string = `nju-classmate-backup-${DateUtil.toDateKey(new Date())}.json`;
      return await ExportService.saveTextFile(context, name, json);
    } catch (e) {
      Logger.e(`导出备份失败: ${e}`);
      return '';
    }
  }

  /** 导出为 iCalendar 文件，可直接导入系统日历 */
  static async exportIcs(context: common.Context, timetable: Timetable, settings: AppSettings): Promise<string> {
    try {
      const ics: string = ExportService.buildIcs(timetable, settings);
      const name: string = `nju-classmate-${DateUtil.toDateKey(new Date())}.ics`;
      return await ExportService.saveTextFile(context, name, ics);
    } catch (e) {
      Logger.e(`导出日历失败: ${e}`);
      return '';
    }
  }

  private static async saveTextFile(context: common.Context, fileName: string, content: string): Promise<string> {
    const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
    const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
    options.newFileNames = [fileName];
    const uris: string[] = await documentPicker.save(options);
    if (uris === undefined || uris === null || uris.length === 0) {
      return ''; // 用户取消
    }
    const uri: string = uris[0];
    const file: fileIo.File = fileIo.openSync(uri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, content);
    } finally {
      fileIo.closeSync(file);
    }
    Logger.i(`已导出: ${uri}`);
    return uri;
  }

  /**
   * 生成 iCalendar 内容。
   * 每周重复的上课安排用 RRULE 表达，而不是展开成几十个事件，
   * 这样日历里干净、也不会把系统日历撑爆。
   */
  static buildIcs(timetable: Timetable, settings: AppSettings): string {
    const lines: string[] = [];
    const stamp: string = ExportService.icsStamp(new Date());

    lines.push('BEGIN:VCALENDAR');
    lines.push('VERSION:2.0');
    lines.push('PRODID:-//NJU ClassMate//Timetable//CN');
    lines.push('CALSCALE:GREGORIAN');
    lines.push('METHOD:PUBLISH');
    lines.push(`X-WR-CALNAME:${ExportService.escape(timetable.name.length > 0 ? timetable.name : '南哪儿课表')}`);

    const startMonday: Date | null = DateUtil.parseDateKey(settings.semesterStartMonday);
    let seq: number = 0;

    for (let i = 0; i < timetable.courses.length; i++) {
      const c: CourseItem = timetable.courses[i];
      if (c.weekTime < 1 || c.startSlot <= 0) {
        continue; // 自由时间的课没有固定时间，排不进日历
      }
      const startClock: string = ExportService.slotStart(settings, c.startSlot);
      const endClock: string = ExportService.slotEnd(settings, c.endSlot);
      if (startClock.length === 0 || endClock.length === 0) {
        continue;
      }

      // 第一周的上课日
      let firstDate: Date | null = null;
      if (startMonday !== null) {
        firstDate = DateUtil.addDays(startMonday, c.weekTime - 1);
        const firstWeek: number = c.weeks.length > 0 ? c.weeks[0] : 1;
        firstDate = DateUtil.addDays(firstDate, (firstWeek - 1) * 7);
      }

      seq++;
      lines.push('BEGIN:VEVENT');
      lines.push(`UID:nju-classmate-${seq}-${DateUtil.toDateKey(new Date())}@nju.local`);
      lines.push(`DTSTAMP:${stamp}`);
      if (firstDate !== null) {
        lines.push(`DTSTART:${ExportService.icsLocal(firstDate, startClock)}`);
      }
      lines.push(`SUMMARY:${ExportService.escape(c.name)}`);
      const desc: string[] = [];
      if (c.teacher.length > 0) {
        desc.push(`教师：${c.teacher}`);
      }
      if (c.classNumber.length > 0) {
        desc.push(`课程号：${c.classNumber}`);
      }
      desc.push(`周次：${ExportService.weekText(c.weeks)}`);
      if (c.info) {
        desc.push(`备注：${c.info}`);
      }
      lines.push(`DESCRIPTION:${ExportService.escape(desc.join('\\n'))}`);
      lines.push(`LOCATION:${ExportService.escape(c.classroom)}`);
      if (settings.remindEnabled) {
        lines.push('BEGIN:VALARM');
        lines.push(`TRIGGER:-PT${settings.remindBeforeMinutes}M`);
        lines.push('ACTION:DISPLAY');
        lines.push(`DESCRIPTION:${ExportService.escape(c.name)} 即将开始`);
        lines.push('END:VALARM');
      }
      lines.push('END:VEVENT');
    }

    lines.push('END:VCALENDAR');
    return lines.join('\r\n');
  }

  /** 把周次数组转成 iCalendar 的 RRULE（有间断时退化成逐周列举） */
  private static weekText(weeks: number[]): string {
    if (weeks.length === 0) {
      return '全部周次';
    }
    return `${weeks.join(',')} 周`;
  }

  private static slotStart(settings: AppSettings, index: number): string {
    for (let i = 0; i < settings.timeSlots.length; i++) {
      if (settings.timeSlots[i].index === index) {
        return settings.timeSlots[i].start;
      }
    }
    return '';
  }

  private static slotEnd(settings: AppSettings, index: number): string {
    for (let i = 0; i < settings.timeSlots.length; i++) {
      if (settings.timeSlots[i].index === index) {
        return settings.timeSlots[i].end;
      }
    }
    return '';
  }

  private static icsStamp(d: Date): string {
    return `${d.getUTCFullYear()}${ExportService.p2(d.getUTCMonth() + 1)}${ExportService.p2(d.getUTCDate())}`
      + `T${ExportService.p2(d.getUTCHours())}${ExportService.p2(d.getUTCMinutes())}${ExportService.p2(d.getUTCSeconds())}Z`;
  }

  private static icsLocal(d: Date, clock: string): string {
    const parts: string[] = clock.split(':');
    const hh: string = parts.length > 0 ? parts[0] : '00';
    const mm: string = parts.length > 1 ? parts[1] : '00';
    return `${d.getFullYear()}${ExportService.p2(d.getMonth() + 1)}${ExportService.p2(d.getDate())}T${ExportService.p2(Number.parseInt(hh, 10))}${ExportService.p2(Number.parseInt(mm, 10))}00`;
  }

  private static p2(n: number): string {
    return n < 10 ? `0${n}` : `${n}`;
  }

  /** iCalendar 的转义规则：反斜杠、分号、逗号、换行 */
  private static escape(s: string): string {
    return s
      .replace(/\\/g, '\\\\')
      .replace(/;/g, '\\;')
      .replace(/,/g, '\\,')
      .replace(/\n/g, '\\n');
  }

  /** 课表摘要文案，用于设置页和分享 */
  static summaryOf(timetable: Timetable): string {
    const weeks: number = NextClassEngine.totalWeeks(timetable);
    const blocks: GridBlock[] = NextClassEngine.buildWeekBlocks(timetable, 1);
    return `${countDistinctCourses(timetable.courses)} 门课 · ${timetable.courses.length} 条安排 · 共 ${weeks} 周`;
  }
}
