package com.nju.classmate.work

import android.content.Context
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.nju.classmate.core.Store
import com.nju.classmate.reminder.ReminderScheduler
import com.nju.classmate.widget.WidgetUpdater

/**
 * 后台兜底刷新（WorkManager，15 分钟一次）。
 *
 * 定位是**兜底**，不是主力：
 *   · 主力是 AlarmManager 的精确闹钟（见 ReminderScheduler），它能卡在整点上；
 *   · WorkManager 只保证"最终会执行"，具体时刻由系统按电量和使用习惯优化。
 *
 * 它存在的意义是覆盖那些闹钟没排到的情况：
 *   · 跨周了，需要重算本周有哪些课；
 *   · 用户在系统设置里撤了精确闹钟权限，闹钟全降级了；
 *   · 手机重启后闹钟表被清空、而 BootReceiver 又没能重新排上。
 */
class RefreshWorker(
    context: Context,
    params: WorkerParameters
) : Worker(context, params) {

    override fun doWork(): Result {
        val ctx = applicationContext

        val settings = Store.loadSettings(ctx)
        if (!settings.autoRefreshEnabled) {
            Log.i(TAG, "自动刷新已关闭，跳过")
            return Result.success()
        }
        if (!Store.hasTimetable(ctx)) {
            Log.i(TAG, "还没有课表，跳过")
            return Result.success()
        }

        try {
            WidgetUpdater.updateAll(ctx)
            ReminderScheduler.rescheduleAll(ctx)
            Log.i(TAG, "兜底刷新完成")
            return Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "兜底刷新失败: ${e.message}")
            return Result.retry()
        }
    }

    companion object {
        const val NAME = "nju_classmate_periodic_refresh"
        private const val TAG = "NJURefresh"
    }
}
