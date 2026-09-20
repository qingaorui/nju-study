package com.nju.classmate.reminder

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.nju.classmate.core.ClassOccurrence
import com.nju.classmate.core.ClassStatus
import com.nju.classmate.core.Engine
import com.nju.classmate.core.ExamEntry
import com.nju.classmate.core.Settings
import com.nju.classmate.core.Store
import com.nju.classmate.core.Timetable
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * 上课提醒 + 小组件精确刷新。
 *
 * 为什么用 AlarmManager 而不是 WorkManager：
 *   WorkManager 只保证"最终会执行"，具体时刻由系统按电量/使用习惯优化，
 *   可能偏几分钟——用来做"课前 15 分钟提醒"是不能接受的。
 *   AlarmManager 的 setExactAndAllowWhileIdle 才能卡在整点上。
 *
 * 两条任务共用一个闹钟表：
 *   · type=remind  到点了发通知
 *   · type=refresh 到点了刷小组件（上课那一刻、下课那一刻）
 * 后者是刚需：小组件上的倒计时不会自己跳，
 * 必须在"状态即将变化"的整点主动推一次，否则用户看到的会是过期数据。
 *
 * Android 12+ 精确闹钟需要在系统设置里授权，
 * 未授权时自动降级为 setAndAllowWhileIdle（可能偏几分钟，但不会不响）。
 */
object ReminderScheduler {

    private const val TAG = "NJUReminder"

    private const val REMIND_BASE = 2000
    private const val REFRESH_START_BASE = 3000
    private const val REFRESH_END_BASE = 4000
    private const val EXAM_BASE = 5000

    /** 每个类别最多排多少个闹钟，避免刷爆系统闹钟队列 */
    private const val MAX_PER_KIND = 48
    private const val WINDOW_DAYS = 7

    const val TYPE_REMIND = "remind"
    const val TYPE_REFRESH = "refresh"

    fun rescheduleAll(ctx: Context) {
        val am = ctx.getSystemService(AlarmManager::class.java) ?: return
        cancelAll(ctx, am)

        val settings = Store.loadSettings(ctx)
        if (!settings.autoRefreshEnabled) {
            Log.i(TAG, "自动刷新已关闭，不排任何闹钟")
            return
        }
        if (settings.semesterStartMonday.isBlank()) {
            Log.i(TAG, "还没设置开学日期，不排闹钟")
            return
        }
        val timetable: Timetable = Store.loadTimetable(ctx)
        if (timetable.courses.isEmpty()) {
            Log.i(TAG, "还没有课表，不排闹钟")
            return
        }

        val now = LocalDateTime.now()
        var remindCount = 0
        var refreshCount = 0
        var i = 0

        for (d in 0..WINDOW_DAYS) {
            val day = Engine.daySchedule(timetable, settings, now.toLocalDate().plusDays(d.toLong()), now)
            for (occ in day.occurrences) {
                if (occ.status == ClassStatus.FINISHED) continue

                // 上课那一刻 / 下课那一刻，各刷一次小组件
                if (refreshCount < MAX_PER_KIND) {
                    val startAt = occurrenceTime(occ, occ.startClock)
                    if (startAt != null && startAt.isAfter(now)) {
                        schedule(ctx, am, REFRESH_START_BASE + refreshCount, startAt, TYPE_REFRESH, "", "", 0)
                        refreshCount++
                    }
                    val endAt = occurrenceTime(occ, occ.endClock)
                    if (endAt != null && endAt.isAfter(now) && refreshCount < MAX_PER_KIND) {
                        schedule(ctx, am, REFRESH_END_BASE + refreshCount, endAt, TYPE_REFRESH, "", "", 0)
                        refreshCount++
                    }
                }

                // 课前提醒
                if (settings.remindEnabled && remindCount < MAX_PER_KIND) {
                    val startAt = occurrenceTime(occ, occ.startClock)
                    if (startAt != null) {
                        val fireAt = startAt.minusMinutes(settings.remindBeforeMinutes.toLong())
                        if (fireAt.isAfter(now)) {
                            val teacher = if (occ.course.teacher.isNotBlank()) " · ${occ.course.teacher}" else ""
                            schedule(
                                ctx, am, REMIND_BASE + remindCount, fireAt, TYPE_REMIND,
                                "${settings.remindBeforeMinutes} 分钟后上课：${occ.course.name}",
                                "${occ.startClock}-${occ.endClock} · ${occ.course.classroom}$teacher",
                                REMIND_BASE + remindCount
                            )
                            remindCount++
                        }
                    }
                }
                i++
            }
        }

        // 考试提醒：提前一天 20:00
        val exams = Engine.upcomingExams(timetable, now, 8)
        var examScheduled = 0
        for (exam in exams) {
            if (examScheduled >= 8) break
            val at = examReminderTime(exam) ?: continue
            if (!at.isAfter(now)) continue
            val loc = if (exam.location.isBlank()) "" else " · ${exam.location}"
            schedule(
                ctx, am, EXAM_BASE + examScheduled, at, TYPE_REMIND,
                "明天考试：${exam.courseName}", "${exam.raw}$loc", EXAM_BASE + examScheduled
            )
            examScheduled++
        }

        Log.i(TAG, "排班完成：提醒 $remindCount 条、小组件刷新 $refreshCount 次（共扫 $i 节）")
    }

    /** 某个 occurrence 在指定时刻的绝对时间 */
    private fun occurrenceTime(occ: ClassOccurrence, clock: String): LocalDateTime? = try {
        val minutes = Engine.clockToMinutes(clock)
        occ.date.atStartOfDay().plusMinutes(minutes.toLong())
    } catch (e: Exception) {
        null
    }

    /** 考试提醒定在考前一天 20:00 */
    private fun examReminderTime(exam: ExamEntry): LocalDateTime? =
        exam.at?.toLocalDate()?.minusDays(1)?.atTime(20, 0)

    private fun schedule(
        ctx: Context,
        am: AlarmManager,
        requestCode: Int,
        fireAt: LocalDateTime,
        type: String,
        title: String,
        content: String,
        notificationId: Int
    ) {
        val intent = Intent(ctx, ReminderReceiver::class.java).apply {
            putExtra("type", type)
            putExtra("title", title)
            putExtra("content", content)
            putExtra("notificationId", notificationId)
        }
        val pi = PendingIntent.getBroadcast(
            ctx, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val triggerAt = fireAt.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()

        try {
            if (canScheduleExact(am)) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            } else {
                // 降级：可能偏几分钟，但至少不会不响
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "排闹钟被拒（精确闹钟未授权），改用非精确: ${e.message}")
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
        }
    }

    private fun canScheduleExact(am: AlarmManager): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) am.canScheduleExactAlarms() else true

    /** 清掉之前排过的全部闹钟（数量固定，逐个 cancel 比记账简单可靠） */
    private fun cancelAll(ctx: Context, am: AlarmManager) {
        for (i in 0 until MAX_PER_KIND) {
            cancel(ctx, am, REMIND_BASE + i)
            cancel(ctx, am, REFRESH_START_BASE + i)
            cancel(ctx, am, REFRESH_END_BASE + i)
            if (i < 16) cancel(ctx, am, EXAM_BASE + i)
        }
    }

    private fun cancel(ctx: Context, am: AlarmManager, requestCode: Int) {
        val intent = Intent(ctx, ReminderReceiver::class.java)
        val pi = PendingIntent.getBroadcast(
            ctx, requestCode, intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        if (pi != null) {
            am.cancel(pi)
            pi.cancel()
        }
    }

    /** 当前排了多少个待触发的闹钟，设置页用来展示状态 */
    fun pendingCount(ctx: Context): Int {
        var n = 0
        for (i in 0 until MAX_PER_KIND) {
            if (exists(ctx, REMIND_BASE + i)) n++
            if (exists(ctx, REFRESH_START_BASE + i)) n++
            if (exists(ctx, REFRESH_END_BASE + i)) n++
        }
        return n
    }

    private fun exists(ctx: Context, requestCode: Int): Boolean =
        PendingIntent.getBroadcast(
            ctx, requestCode, Intent(ctx, ReminderReceiver::class.java),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        ) != null
}
