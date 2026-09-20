package com.nju.classmate.reminder

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat
import com.nju.classmate.App
import com.nju.classmate.MainActivity
import com.nju.classmate.R
import com.nju.classmate.widget.WidgetUpdater

/**
 * 闹钟到点后的落点。
 *
 * 两种任务共用一个接收器（见 ReminderScheduler）：
 *   · type=remind  弹通知
 *   · type=refresh 刷小组件
 */
class ReminderReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.getStringExtra("type")) {
            ReminderScheduler.TYPE_REFRESH -> {
                // 上课/下课的整点，把小组件推到最新状态
                WidgetUpdater.updateAll(context)
                Log.i(TAG, "整点刷新小组件")
            }

            ReminderScheduler.TYPE_REMIND -> {
                val title = intent.getStringExtra("title") ?: return
                val content = intent.getStringExtra("content") ?: ""
                val id = intent.getIntExtra("notificationId", 1)
                postNotification(context, id, title, content)
            }
        }
    }

    private fun postNotification(context: Context, id: Int, title: String, content: String) {
        val tapIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val tapPi = PendingIntent.getActivity(
            context, id, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, App.CHANNEL_REMINDER)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(content)
            .setStyle(NotificationCompat.BigTextStyle().bigText(content))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(tapPi)
            .build()

        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        try {
            manager.notify(id, notification)
            Log.i(TAG, "已发通知: $title")
        } catch (e: SecurityException) {
            // Android 13+ 未授予通知权限时会走到这里
            Log.w(TAG, "没有通知权限，提醒被丢弃: ${e.message}")
        }
    }

    companion object {
        private const val TAG = "NJUReminder"
    }
}
