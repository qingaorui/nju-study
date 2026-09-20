package com.nju.classmate.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle
import com.nju.classmate.core.Store

/**
 * 「今日课表」桌面小组件（默认 4x2，可拉到 4x4）。
 *
 * 带一个「明天 / 今天」切换按钮：点一下只走广播，不用打开 App。
 * 这是小组件相对于通知、快捷方式最实在的优势——
 * 用户晚上想看一眼明天的课，不该被迫先启动一个应用。
 */
class TodayWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        WidgetUpdater.updateToday(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        WidgetUpdater.updateToday(context)
    }

    override fun onEnabled(context: Context) {
        WidgetUpdater.updateToday(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_TOGGLE_DAY) {
            val settings = Store.loadSettings(context)
            Store.saveSettings(
                context,
                settings.copy(todayCardForceTomorrow = !settings.todayCardForceTomorrow)
            )
            WidgetUpdater.updateToday(context)
            return
        }
        super.onReceive(context, intent)
    }

    companion object {
        const val ACTION_TOGGLE_DAY = "com.nju.classmate.TOGGLE_DAY"

        /**
         * 构造切换按钮的 PendingIntent。
         * 用固定的 requestCode，保证每次更新都复用同一个（否则会堆一堆 PendingIntent）。
         */
        fun toggleIntent(context: Context): PendingIntent {
            val intent = Intent(context, TodayWidget::class.java).apply {
                action = ACTION_TOGGLE_DAY
            }
            return PendingIntent.getBroadcast(
                context, 1001, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
    }
}
