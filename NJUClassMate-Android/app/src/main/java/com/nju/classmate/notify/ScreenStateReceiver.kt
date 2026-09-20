package com.nju.classmate.notify

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * 息屏时重发一次锁屏通知。
 *
 * 为什么需要它：`Chronometer` 会自己走秒，所以**倒计时**不会过期；
 * 但**状态**（下一节 / 正在上课 / 上完了）只有在整点闹钟触发时才会翻转。
 * 如果闹钟被系统清掉（国产 ROM 常见）、或通知被用户划走，
 * 那么用户下次看锁屏时拿到的就是旧内容。
 *
 * 息屏这一瞬间是"用户即将看锁屏"最可靠的信号，成本又几乎为零，
 * 所以在这里补一次重算。
 *
 * 注意是**动态注册**（见 App.onCreate），不是清单里声明：
 * ACTION_SCREEN_OFF 从 Android 8 起就不允许隐式广播静态注册了。
 */
class ScreenStateReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_SCREEN_OFF) return
        try {
            NextClassNotifier.update(context)
        } catch (e: Exception) {
            Log.w(TAG, "息屏刷新锁屏通知失败: ${e.message}")
        }
    }

    companion object {
        private const val TAG = "NJUNotify"
    }
}
