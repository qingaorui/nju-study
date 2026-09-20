import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { common } from '@kit.AbilityKit';
import { wantAgent, WantAgent } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ClassOccurrence, ClassStatus, Timetable } from '../model/Course';
import { AppSettings } from './CourseStore';
import { NextClassEngine, DaySchedule, ExamEntry } from './NextClassEngine';
import { DateUtil } from '../common/DateUtil';
import { Logger } from '../common/Logger';

const BUNDLE_NAME: string = 'cn.nju.classmate';
const ABILITY_NAME: string = 'EntryAbility';
/** 最多同时挂多少个提醒，避免刷爆系统提醒队列 */
const MAX_REMINDERS: number = 40;
/** 提前多久看课程（天） */
const SCHEDULE_WINDOW_DAYS: number = 7;

/**
 * 课前提醒服务。
 *
 * 用系统的 reminderAgentManager（提醒代理）而不是自建后台服务：
 * 提醒是系统级能力，应用被冻结、被杀死、甚至重启后依然会准时弹出，
 * 这也是"开机后课表提醒还能用"最可靠的实现路径——不用求开机广播。
 *
 * 每次课表或设置变化时，整体重建一遍提醒队列：
 * 先 cancelAllReminders 清空，再按新的课表重新排。
 * 这样比增量 diff 简单得多，而且不会残留脏数据。
 */
export class ReminderService {
  /**
   * 按当前课表重建未来一周的提醒。
   * @returns 成功排入的提醒条数
   */
  static async rebuild(context: common.Context, timetable: Timetable, settings: AppSettings): Promise<number> {
    if (!settings.remindEnabled) {
      await ReminderService.clearAll();
      Logger.i('课前提醒已关闭，清空提醒队列');
      return 0;
    }
    if (!settings.semesterStartMonday || timetable.courses.length === 0) {
      return 0;
    }

    await ReminderService.clearAll();

    const now: Date = new Date();
    let count: number = 0;

    // 1) 上课提醒
    for (let d = 0; d <= SCHEDULE_WINDOW_DAYS && count < MAX_REMINDERS; d++) {
      const date: Date = DateUtil.addDays(now, d);
      const day: DaySchedule = NextClassEngine.daySchedule(timetable, settings, date, now);
      for (let i = 0; i < day.occurrences.length; i++) {
        if (count >= MAX_REMINDERS) {
          break;
        }
        const occ: ClassOccurrence = day.occurrences[i];
        if (occ.status === ClassStatus.FINISHED) {
          continue;
        }
        const ok: boolean = await ReminderService.publishClassReminder(
          occ,
          settings.remindBeforeMinutes
        );
        if (ok) {
          count++;
        }
      }
    }

    // 2) 考试提醒：提前一天晚上 20:00 提醒一次
    if (count < MAX_REMINDERS) {
      const exams: ExamEntry[] = NextClassEngine.upcomingExams(timetable, now, 10);
      for (let i = 0; i < exams.length && count < MAX_REMINDERS; i++) {
        const exam: ExamEntry = exams[i];
        if (exam.at === 0) {
          continue;
        }
        const ok: boolean = await ReminderService.publishExamReminder(exam);
        if (ok) {
          count++;
        }
      }
    }

    Logger.i(`课前提醒已重建，共 ${count} 条`);
    return count;
  }

  private static async publishClassReminder(occ: ClassOccurrence, beforeMinutes: number): Promise<boolean> {
    // 提醒时刻 = 上课时刻 - 提前量
    const dateParts: string[] = occ.dateKey.split('-');
    const clockParts: string[] = occ.startClock.split(':');
    if (dateParts.length !== 3 || clockParts.length !== 2) {
      return false;
    }
    const y: number = Number.parseInt(dateParts[0], 10);
    const mo: number = Number.parseInt(dateParts[1], 10);
    const d: number = Number.parseInt(dateParts[2], 10);
    const startMinutes: number = DateUtil.clockToMinutes(occ.startClock);
    const fireMinutes: number = startMinutes - beforeMinutes;

    // 提前量可能把时间推到前一天，这里用完整时间戳算，避免手工进位出错
    const startOfDay: Date = new Date(y, mo - 1, d);
    startOfDay.setHours(0, 0, 0, 0);
    const fireAt: Date = new Date(startOfDay.getTime() + fireMinutes * 60000);
    if (fireAt.getTime() <= Date.now()) {
      return false; // 已经过点了，不用提醒
    }

    const teacher: string = occ.course.teacher ? ` · ${occ.course.teacher}` : '';
    const reminder: reminderAgentManager.ReminderRequestCalendar = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
      dateTime: {
        year: fireAt.getFullYear(),
        month: fireAt.getMonth() + 1,
        day: fireAt.getDate(),
        hour: fireAt.getHours(),
        minute: fireAt.getMinutes(),
        second: 0
      },
      title: `${beforeMinutes} 分钟后上课：${occ.course.name}`,
      content: `${occ.startClock}-${occ.endClock} · ${occ.course.classroom}${teacher}`,
      expiredContent: `${occ.course.name} 的提醒已失效`,
      snoozeContent: '稍后提醒',
      notificationId: ReminderService.notificationId(occ.dateKey, occ.startSlot, occ.course.name),
      slotType: reminderAgentManager.SlotType.SOCIAL_COMMUNICATION,
      wantAgent: ReminderService.buildWantAgent(),
      actionButton: [
        {
          title: '知道了',
          type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE
        }
      ]
    };

    return ReminderService.publish(reminder);
  }

  private static async publishExamReminder(exam: ExamEntry): Promise<boolean> {
    // 提前一天 20:00 提醒
    const examDate: Date = new Date(exam.at);
    const fireAt: Date = DateUtil.addDays(examDate, -1);
    fireAt.setHours(20, 0, 0, 0);
    if (fireAt.getTime() <= Date.now()) {
      return false;
    }

    const reminder: reminderAgentManager.ReminderRequestCalendar = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
      dateTime: {
        year: fireAt.getFullYear(),
        month: fireAt.getMonth() + 1,
        day: fireAt.getDate(),
        hour: fireAt.getHours(),
        minute: fireAt.getMinutes(),
        second: 0
      },
      title: `明天考试：${exam.courseName}`,
      content: `${exam.raw}${exam.location ? ' · ' + exam.location : ''}`,
      expiredContent: '考试提醒已失效',
      snoozeContent: '稍后提醒',
      notificationId: ReminderService.notificationId('exam', 0, exam.courseName),
      slotType: reminderAgentManager.SlotType.SOCIAL_COMMUNICATION,
      wantAgent: ReminderService.buildWantAgent(),
      actionButton: [
        {
          title: '知道了',
          type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE
        }
      ]
    };

    return ReminderService.publish(reminder);
  }

  private static async publish(reminder: reminderAgentManager.ReminderRequestCalendar): Promise<boolean> {
    try {
      const id: number = await reminderAgentManager.publishReminder(reminder);
      Logger.d(`提醒已登记 id=${id}，标题=${reminder.title}`);
      return true;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      Logger.w(`登记提醒失败 code=${err.code} msg=${err.message}`);
      return false;
    }
  }

  private static buildWantAgent(): WantAgent {
    const info: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: BUNDLE_NAME,
          abilityName: ABILITY_NAME
        }
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    // 这个是同步接口，拿不到时返回一个占位值即可
    return wantAgent.getWantAgentSync(info);
  }

  /** 生成一个稳定的 notificationId，避免同一节课重复登记 */
  private static notificationId(seedA: string, seedB: number, seedC: string): number {
    const s: string = `${seedA}#${seedB}#${seedC}`;
    let hash: number = 0;
    for (let i = 0; i < s.length; i++) {
      hash = (hash * 31 + s.charCodeAt(i)) % 2147483647;
    }
    return hash % 100000;
  }

  /** 清空本应用登记过的全部提醒 */
  static async clearAll(): Promise<void> {
    try {
      await reminderAgentManager.cancelAllReminders();
    } catch (e) {
      Logger.w(`清空提醒失败: ${e}`);
    }
  }

  /** 当前还有多少条有效提醒，设置页用来展示状态 */
  static async pendingCount(): Promise<number> {
    try {
      const list: reminderAgentManager.ReminderRequest[] = await reminderAgentManager.getValidReminders();
      return list.length;
    } catch (e) {
      return 0;
    }
  }
}
