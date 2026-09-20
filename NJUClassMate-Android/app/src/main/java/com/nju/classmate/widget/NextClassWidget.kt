package com.nju.classmate.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Bundle

/**
 * 「下一节课」桌面小组件（默认 4x2，可缩到 2x2）。
 *
 * 刷新时机（按可靠性从高到低）：
 *   1. AlarmManager 在每节课上下课的整点触发 → 见 ReminderScheduler（最准）
 *   2. WorkManager 每 15 分钟兜底 → 见 RefreshWorker
 *   3. updatePeriodMillis = 30 分钟（系统最小周期）
 *   4. 用户从 App 里改了数据 → WidgetUpdater.updateAll()
 */
class NextClassWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        WidgetUpdater.updateNextClass(context)
    }

    /** 用户拖动改变了大小时会回调，重新按新尺寸排版 */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        WidgetUpdater.updateNextClass(context)
    }

    /** 桌面上第一个该类型小组件被添加时触发，顺手把数据刷一遍 */
    override fun onEnabled(context: Context) {
        WidgetUpdater.updateNextClass(context)
    }
}
