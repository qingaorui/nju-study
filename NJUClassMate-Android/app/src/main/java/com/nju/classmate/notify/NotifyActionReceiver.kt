package com.nju.classmate.notify

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.nju.classmate.core.Store
import com.nju.classmate.widget.WidgetUpdater

/**
 * 锁屏通知里两个按钮的落点。
 *
 * 之所以做成广播而不是直接 startActivity：用户在锁屏上点「刷新」时，
 * 期望的是**看一眼数字变了**，而不是被拽进应用里（那还得解锁）。
 *
 * 两个动作：
 *   · 刷新     —— 按当前时间重算一遍。系统时间被改过、或刚从时区切换回来时有用。
 *   · 看明天   —— 切到明天的安排，和桌面小组件上的按钮是同一个语义。
 */
class NotifyActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_REFRESH -> {
                Log.i(TAG, "锁屏通知：手动刷新")
                NextClassNotifier.update(context)
            }

            ACTION_TOGGLE_DAY -> {
                val settings = Store.loadSettings(context)
                Store.saveSettings(
                    context,
                    settings.copy(todayCardForceTomorrow = !settings.todayCardForceTomorrow)
                )
                // 走 updateAll 而不是只刷通知：桌面小组件和锁屏通知必须同步翻转，
                // 否则会出现"通知说看明天、卡片还停在今天"的矛盾状态
                WidgetUpdater.updateAll(context)
                Log.i(TAG, "锁屏通知：切换查看日")
            }
        }
    }

    companion object {
        const val ACTION_REFRESH = "com.nju.classmate.NOTIFY_REFRESH"
        const val ACTION_TOGGLE_DAY = "com.nju.classmate.NOTIFY_TOGGLE_DAY"
        private const val TAG = "NJUNotify"
    }
}
