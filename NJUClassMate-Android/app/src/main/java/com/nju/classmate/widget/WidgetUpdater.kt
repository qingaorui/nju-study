package com.nju.classmate.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import com.nju.classmate.MainActivity
import com.nju.classmate.R
import com.nju.classmate.core.ClassOccurrence
import com.nju.classmate.core.ClassStatus
import com.nju.classmate.core.DaySchedule
import com.nju.classmate.core.Engine
import com.nju.classmate.core.Settings
import com.nju.classmate.core.Store
import com.nju.classmate.core.Timetable
import com.nju.classmate.notify.NextClassNotifier
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * 桌面小组件的渲染逻辑，两个 widget 共用。
 *
 * Android 的 RemoteViews 限制很多（只能用少数几种布局、不能自定义 View、
 * 不能跑任意逻辑），所以这里做两件事：
 *   1. 把 Engine 算出来的结果"翻译"成一组 TextView 的文字；
 *   2. 按小组件的实际尺寸决定显示几行、藏哪些次要信息。
 *
 * 尺寸自适应是必须的：用户可能把「下一节课」拉成 2x2 也可能拉成 4x2，
 * 不做处理的话小尺寸下文字会被压成一团。
 */
object WidgetUpdater {

    /** 小组件宽度小于这个值时认为是"小尺寸"，收掉次要信息 */
    private const val NARROW_DP = 200

    /**
     * 刷新**所有对外可见的界面**：两个桌面小组件 + 锁屏常驻通知。
     *
     * 名字虽然叫 WidgetUpdater，但它是"界面刷新"的统一入口——
     * 通知一起放在这里，是为了让所有现有调用点（开机自启、整点闹钟、
     * 后台兜底任务、数据变更）**自动**同步到通知，不会漏掉某一处。
     * 漏一个地方的后果是"桌面卡片说下一节是高数、锁屏还说形势与政策"，
     * 这种不一致比两个都不刷新更糟。
     */
    fun updateAll(ctx: Context) {
        updateNextClass(ctx)
        updateToday(ctx)
        NextClassNotifier.update(ctx)
    }

    // ---------------------------------------------------------------- 下一节课

    fun updateNextClass(ctx: Context) {
        val manager = AppWidgetManager.getInstance(ctx)
        val ids = manager.getAppWidgetIds(ComponentName(ctx, NextClassWidget::class.java))
        if (ids.isEmpty()) return

        val timetable = Store.loadTimetable(ctx)
        val settings = Store.loadSettings(ctx)
        val now = LocalDateTime.now()
        val result = Engine.resolve(timetable, settings, now)

        for (id in ids) {
            val rv = RemoteViews(ctx.packageName, R.layout.widget_next_class)
            val narrow = isNarrow(manager, id)

            bindNextClass(ctx, rv, timetable, settings, result.ongoing, result.next, now, narrow)
            rv.setOnClickPendingIntent(R.id.widgetRoot, openAppIntent(ctx))
            manager.updateAppWidget(id, rv)
        }
    }

    private fun bindNextClass(
        ctx: Context,
        rv: RemoteViews,
        timetable: Timetable,
        settings: Settings,
        ongoing: List<ClassOccurrence>,
        next: ClassOccurrence?,
        now: LocalDateTime,
        narrow: Boolean
    ) {
        val week = Engine.weekIndexOf(settings.semesterStartMonday, now.toLocalDate())
        rv.setTextViewText(
            R.id.weekLabel,
            if (week > 0) "第 $week 周" else if (timetable.courses.isEmpty()) "" else "假期"
        )

        if (timetable.courses.isEmpty()) {
            rv.setTextViewText(R.id.courseName, ctx.getString(R.string.widget_no_timetable))
            rv.setTextViewText(R.id.timeLine, ctx.getString(R.string.widget_go_import))
            rv.setTextViewText(R.id.statusChip, "未导入")
            rv.setTextViewText(R.id.location, "")
            rv.setTextViewText(R.id.remain, "")
            rv.setViewVisibility(R.id.nextHint, View.GONE)
            rv.setInt(R.id.statusChip, "setBackgroundResource", R.drawable.bg_chip_gray)
            return
        }

        if (settings.semesterStartMonday.isBlank()) {
            rv.setTextViewText(R.id.courseName, ctx.getString(R.string.widget_need_semester))
            rv.setTextViewText(R.id.timeLine, ctx.getString(R.string.widget_tap_to_set))
            rv.setTextViewText(R.id.statusChip, "待设置")
            rv.setInt(R.id.statusChip, "setBackgroundResource", R.drawable.bg_chip_amber)
            rv.setTextViewText(R.id.location, "")
            rv.setTextViewText(R.id.remain, "")
            rv.setViewVisibility(R.id.nextHint, View.GONE)
            return
        }

        // ---- 正在上课优先 ----
        if (ongoing.isNotEmpty()) {
            val occ = ongoing[0]
            val endMin = Engine.clockToMinutes(occ.endClock)
            val nowMin = now.hour * 60 + now.minute
            val left = (endMin - nowMin).coerceAtLeast(0)

            rv.setTextViewText(R.id.courseName, occ.course.name)
            rv.setTextViewText(R.id.timeLine, timeLineOf(occ))
            rv.setTextViewText(R.id.location, occ.course.classroom)
            rv.setTextViewText(
                R.id.remain,
                if (left >= 60) "还剩 ${left / 60} 小时 ${left % 60} 分" else "还剩 $left 分钟"
            )
            rv.setTextViewText(R.id.statusChip, "正在上课")
            rv.setInt(R.id.statusChip, "setBackgroundResource", R.drawable.bg_chip_amber)
            rv.setViewVisibility(R.id.nextHint, if (narrow) View.GONE else View.VISIBLE)
            rv.setTextViewText(
                R.id.nextHint,
                if (ongoing.size > 1) "同时段还有 ${ongoing.size - 1} 门课（免修不免考）"
                else hintOf(next)
            )
            return
        }

        // ---- 即将上课 ----
        if (next != null) {
            rv.setTextViewText(R.id.courseName, next.course.name)
            rv.setTextViewText(R.id.timeLine, timeLineOf(next))
            rv.setTextViewText(R.id.location, next.course.classroom)
            rv.setTextViewText(R.id.remain, Engine.humanizeRemain(next.minutesFromNow))
            rv.setTextViewText(R.id.statusChip, dayLabelOf(next, now))
            rv.setInt(R.id.statusChip, "setBackgroundResource", R.drawable.bg_chip_blue)
            rv.setViewVisibility(R.id.nextHint, if (narrow) View.GONE else View.VISIBLE)
            rv.setTextViewText(R.id.nextHint, hintOf(null))
            return
        }

        // ---- 一段时间的课都上完了 ----
        rv.setTextViewText(R.id.courseName, ctx.getString(R.string.widget_all_done))
        rv.setTextViewText(R.id.timeLine, timetable.name)
        rv.setTextViewText(R.id.statusChip, "空闲")
        rv.setInt(R.id.statusChip, "setBackgroundResource", R.drawable.bg_chip_gray)
        rv.setTextViewText(R.id.location, "")
        rv.setTextViewText(R.id.remain, "")
        rv.setViewVisibility(R.id.nextHint, View.GONE)
    }

    // ---------------------------------------------------------------- 今日课表

    /** 今日卡片最多显示几行 */
    private val TODAY_ROWS = intArrayOf(
        R.id.row0, R.id.row1, R.id.row2, R.id.row3, R.id.row4
    )

    fun updateToday(ctx: Context) {
        val manager = AppWidgetManager.getInstance(ctx)
        val ids = manager.getAppWidgetIds(ComponentName(ctx, TodayWidget::class.java))
        if (ids.isEmpty()) return

        val timetable = Store.loadTimetable(ctx)
        val settings = Store.loadSettings(ctx)
        val now = LocalDateTime.now()

        // 今天没课时，按设置决定要不要把明天的安排顶上来
        var target: LocalDate = now.toLocalDate()
        var day: DaySchedule = Engine.daySchedule(timetable, settings, target, now)
        var prefix = ""
        if (settings.todayCardForceTomorrow) {
            target = target.plusDays(1)
            prefix = "明天 · "
            day = Engine.daySchedule(timetable, settings, target, now)
        } else if (day.occurrences.isEmpty() && settings.todayCardShowTomorrow) {
            val tomorrow = target.plusDays(1)
            val td = Engine.daySchedule(timetable, settings, tomorrow, now)
            if (td.occurrences.isNotEmpty()) {
                target = tomorrow
                prefix = "明天 · "
                day = td
            }
        }

        for (id in ids) {
            val rv = RemoteViews(ctx.packageName, R.layout.widget_today)
            val maxRows = if (isNarrow(manager, id)) 3 else TODAY_ROWS.size

            rv.setTextViewText(R.id.dateText, "$prefix${target.monthValue}月${target.dayOfMonth}日")
            rv.setTextViewText(
                R.id.weekLabel,
                if (day.weekIndex > 0) "第 ${day.weekIndex} 周" else "假期"
            )

            val items = day.occurrences.take(maxRows)
            for ((i, rowId) in TODAY_ROWS.withIndex()) {
                if (i < items.size) {
                    val occ = items[i]
                    val row = RemoteViews(ctx.packageName, R.layout.widget_today_row)
                    row.setTextViewText(R.id.rowTime, occ.startClock)
                    row.setTextViewText(R.id.rowName, occ.course.name)
                    row.setTextViewText(R.id.rowLoc, occ.course.classroom)
                    row.setTextColor(
                        R.id.rowName,
                        when (occ.status) {
                            ClassStatus.ONGOING -> ctx.getColor(R.color.accent_blue)
                            ClassStatus.FINISHED -> ctx.getColor(R.color.text_tertiary)
                            ClassStatus.UPCOMING -> ctx.getColor(R.color.text_primary)
                        }
                    )
                    rv.removeAllViews(rowId)
                    rv.addView(rowId, row)
                    rv.setViewVisibility(rowId, View.VISIBLE)
                } else {
                    rv.removeAllViews(rowId)
                    rv.setViewVisibility(rowId, View.GONE)
                }
            }

            val total = day.occurrences.size
            val nextStart = day.occurrences.firstOrNull { it.status == ClassStatus.UPCOMING }?.startClock
            rv.setTextViewText(
                R.id.footerText,
                when {
                    total == 0 -> "没有课"
                    nextStart != null -> "共 $total 节 · 下一节 $nextStart"
                    else -> "共 $total 节 · 都上完啦"
                }
            )

            // 「明天 / 今天」切换按钮：点了只走广播，不用打开 App
            rv.setTextViewText(
                R.id.toggleLabel,
                if (settings.todayCardForceTomorrow) "今天" else "明天"
            )
            rv.setOnClickPendingIntent(R.id.toggleLabel, TodayWidget.toggleIntent(ctx))
            rv.setOnClickPendingIntent(R.id.widgetRoot, openAppIntent(ctx))
            manager.updateAppWidget(id, rv)
        }
    }

    // ---------------------------------------------------------------- 小工具

    /** 小组件是不是小尺寸（宽度不够） */
    private fun isNarrow(manager: AppWidgetManager, id: Int): Boolean {
        val opts: Bundle = manager.getAppWidgetOptions(id)
        val w = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250)
        return w < NARROW_DP
    }

    private fun timeLineOf(occ: ClassOccurrence): String {
        val wd = "周" + "一二三四五六日"[occ.date.dayOfWeek.value - 1]
        val slots = if (occ.startSlot == occ.endSlot) "第${occ.startSlot}节"
        else "第${occ.startSlot}-${occ.endSlot}节"
        return "$wd $slots · ${occ.startClock}-${occ.endClock}"
    }

    private fun dayLabelOf(occ: ClassOccurrence, now: LocalDateTime): String {
        val today = now.toLocalDate()
        return when (occ.date) {
            today -> "今天"
            today.plusDays(1) -> "明天"
            else -> "周" + "一二三四五六日"[occ.date.dayOfWeek.value - 1]
        }
    }

    private fun hintOf(next: ClassOccurrence?): String {
        if (next == null) return ""
        return "下一节 ${next.course.name} · ${next.startClock}"
    }

    private fun openAppIntent(ctx: Context): PendingIntent {
        val intent = Intent(ctx, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            ctx, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
