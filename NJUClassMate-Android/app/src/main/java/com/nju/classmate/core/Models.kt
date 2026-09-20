package com.nju.classmate.core

import java.time.LocalDate
import java.time.LocalDateTime

/**
 * 课表数据模型。
 *
 * 字段命名延续 HarmonyOS 版（以及 nju.app 的解析脚本输出），
 * 这样四个抓取脚本可以一行不改地复用。
 */

/** 一节大课的时间区间 */
data class TimeSlot(
    /** 第几节，1 开始 */
    val index: Int,
    /** 开始时间 HH:mm */
    val start: String,
    /** 结束时间 HH:mm */
    val end: String
)

/** 一条课程记录（= 某个"星期几 + 第几节 + 哪些周"的上课片段） */
data class Course(
    val name: String,
    val classroom: String,
    val classNumber: String,
    val teacher: String,
    val testTime: String? = null,
    val testLocation: String? = null,
    val info: String? = null,
    /** 上课周次，升序 */
    val weeks: List<Int>,
    /** 1=周一 ... 7=周日；0 表示"自由时间/未指定" */
    val weekTime: Int,
    /** 起始节次 */
    val startSlot: Int,
    /** 结束节次（含） */
    val endSlot: Int,
    val importType: Int = 1
)

/** 一份完整课表 */
data class Timetable(
    val name: String = "",
    /** 学期第一周的周一，yyyy-MM-dd。用来推算"今天是第几周" */
    val semesterStartMonday: String = "",
    val courses: List<Course> = emptyList()
)

/** 用户偏好 */
data class Settings(
    val semesterStartMonday: String = "",
    val timeSlots: List<TimeSlot> = Defaults.TIME_SLOTS,
    val remindEnabled: Boolean = true,
    val remindBeforeMinutes: Int = 15,
    val showWeekend: Boolean = false,
    /** 今天没课时是否自动顶上明天的安排 */
    val todayCardShowTomorrow: Boolean = true,
    /** 用户主动点了卡片上的「明天」——即使今天有课也显示明天 */
    val todayCardForceTomorrow: Boolean = false,
    val autoRefreshEnabled: Boolean = true,

    /**
     * 锁屏常驻通知：在锁屏上直接显示下一节课。
     *
     * Android 从 5.0 起删掉了锁屏小组件，常驻通知是唯一能"躺"在锁屏上的东西。
     * 默认开着，因为这是这个 App 最核心的价值；
     * 不想要的话在设置里一键关掉（关掉会立刻撤掉通知，不留残留）。
     */
    val lockNotificationEnabled: Boolean = true,
    /** 锁屏通知里，今天没课时是否自动顶上明天的安排 */
    val lockNotificationShowTomorrow: Boolean = true
)

/** 自定义事件（作业 DDL 等，用户手动添加） */
data class UserEvent(
    val id: String,
    val title: String,
    /** epoch millis */
    val dueAt: Long,
    val pinned: Boolean = false,
    val done: Boolean = false,
    val note: String = ""
)

/** 一节课相对当前时间的状态 */
enum class ClassStatus { UPCOMING, ONGOING, FINISHED }

/** 课程在某一周的具体一次上课 */
data class ClassOccurrence(
    val course: Course,
    val date: LocalDate,
    val weekIndex: Int,
    val startSlot: Int,
    val endSlot: Int,
    val startClock: String,
    val endClock: String,
    /** 距现在多少分钟，负数表示已开始 */
    val minutesFromNow: Int,
    val status: ClassStatus
)

/** 某一天的课表 */
data class DaySchedule(
    val date: LocalDate,
    val weekIndex: Int,
    val occurrences: List<ClassOccurrence>
)

/** 「下一节课」的完整结果 */
data class NextClassResult(
    /** 正在上的课（免修不免考时可能有多门） */
    val ongoing: List<ClassOccurrence>,
    /** 严格意义上"接下来要上"的那一门 */
    val next: ClassOccurrence?,
    /** 今天还剩的课 */
    val restOfToday: List<ClassOccurrence>,
    val weekIndex: Int,
    val timetableName: String,
    /** 一段时间内都没课了 */
    val exhausted: Boolean
)

/** 周课表上的一个课程块 */
data class GridBlock(
    val course: Course,
    val weekday: Int,
    val startSlot: Int,
    val endSlot: Int,
    /** 占几节，用于 UI 高度 */
    val span: Int,
    /** 该时段是否有多门课重叠 */
    val conflict: Boolean
)

/** 即将到来的考试 */
data class ExamEntry(
    val courseName: String,
    /** 原始文本，解析不出时间时直接展示 */
    val raw: String,
    /** 解析出的时间，解析失败为 null */
    val at: LocalDateTime?,
    val location: String,
    /** 距今天数，解析失败为 -1 */
    val daysLeft: Int
)

/** 南京大学默认作息（仙林/鼓楼本科常见班次）—— 用户可在设置里校准 */
object Defaults {
    val TIME_SLOTS: List<TimeSlot> = listOf(
        TimeSlot(1, "08:00", "08:50"),
        TimeSlot(2, "09:00", "09:50"),
        TimeSlot(3, "10:10", "11:00"),
        TimeSlot(4, "11:10", "12:00"),
        TimeSlot(5, "13:30", "14:20"),
        TimeSlot(6, "14:30", "15:20"),
        TimeSlot(7, "15:40", "16:30"),
        TimeSlot(8, "16:40", "17:30"),
        TimeSlot(9, "18:30", "19:20"),
        TimeSlot(10, "19:30", "20:20"),
        TimeSlot(11, "20:30", "21:20")
    )
}
