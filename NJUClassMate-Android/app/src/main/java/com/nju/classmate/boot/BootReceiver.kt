package com.nju.classmate.boot

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.nju.classmate.core.Store
import com.nju.classmate.reminder.ReminderScheduler
import com.nju.classmate.widget.WidgetUpdater

/**
 * 开机自启。
 *
 * 这是 Android 相对鸿蒙最大的一个优势：三方应用**可以**监听开机广播，
 * 不需要开发者账号、不需要系统签名、不需要 MDM 托管。
 *
 * 重启后要做三件事：
 *   1. 刷新桌面小组件（系统会重建桌面，小组件的数据也得重算）；
 *   2. 重排上课提醒 —— AlarmManager 里的闹钟在重启后会全部丢失，必须重建；
 *   3. 重新注册 WorkManager 周期任务（系统通常会自动恢复，这里兜个底）。
 *
 * MY_PACKAGE_REPLACED 也要处理：应用更新（覆盖安装）后闹钟同样会丢。
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != "android.intent.action.QUICKBOOT_POWERON" &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }

        Log.i(TAG, "收到 $action，开始恢复")

        if (!Store.hasTimetable(context)) {
            Log.i(TAG, "还没有课表，跳过")
            return
        }

        val settings = Store.loadSettings(context)
        if (!settings.autoRefreshEnabled) {
            Log.i(TAG, "用户关闭了自动刷新，跳过")
            return
        }

        WidgetUpdater.updateAll(context)
        ReminderScheduler.rescheduleAll(context)

        Log.i(TAG, "恢复完成")
    }

    companion object {
        private const val TAG = "NJUBoot"
    }
}
