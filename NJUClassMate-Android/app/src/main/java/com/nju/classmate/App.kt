package com.nju.classmate

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import com.nju.classmate.notify.NextClassNotifier
import com.nju.classmate.notify.ScreenStateReceiver
import com.nju.classmate.reminder.ReminderScheduler
import com.nju.classmate.work.RefreshScheduler

class App : Application() {

    /** 息屏接收器。动态注册，所以要在进程级别持有引用，否则会被回收 */
    private var screenReceiver: ScreenStateReceiver? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
        registerScreenReceiver()
        // 按「自动刷新」开关排/撤 WorkManager 兜底任务 + 重排精确闹钟
        RefreshScheduler.sync(this)
        ReminderScheduler.rescheduleAll(this)
        // 进程刚起来的时候重发一次锁屏通知。
        // 冷启动、被系统杀掉后自动重启、用户点开应用 —— 都会走到这里。
        NextClassNotifier.update(this)
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return

        val reminder = NotificationChannel(
            CHANNEL_REMINDER,
            getString(R.string.channel_reminder),
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = getString(R.string.channel_reminder_desc)
            enableVibration(true)
        }
        manager.createNotificationChannel(reminder)

        // 锁屏常驻通知的渠道由 NextClassNotifier 建（它知道该用什么重要性，注释也写在那）
        NextClassNotifier.createChannel(this)
    }

    /**
     * 监听息屏，息屏时把锁屏通知重算一遍。
     *
     * ACTION_SCREEN_OFF 从 Android 8 起就不能静态注册了，只能动态注册。
     * 放在 Application 里注册是合适的：进程活着的时候它就一直有效，
     * 而进程死了本来也无从刷新（那时靠整点闹钟和 WorkManager 兜底）。
     *
     * targetSdk 34 要求注册时显式声明导出标志。这里用 NOT_EXPORTED：
     * ACTION_SCREEN_OFF 是系统保护广播，三方应用根本发不出来，
     * 所以不可能被外部伪造触发。
     */
    private fun registerScreenReceiver() {
        if (screenReceiver != null) return
        val receiver = ScreenStateReceiver()
        try {
            ContextCompat.registerReceiver(
                this,
                receiver,
                IntentFilter(Intent.ACTION_SCREEN_OFF),
                ContextCompat.RECEIVER_NOT_EXPORTED
            )
            screenReceiver = receiver
        } catch (e: Exception) {
            // 注册失败不影响其它功能，只是少了"息屏补一次刷新"这个优化
            Log.w("NJUApp", "注册息屏接收器失败: ${e.message}")
        }
    }

    companion object {
        const val CHANNEL_REMINDER = "class_reminder"
    }
}
