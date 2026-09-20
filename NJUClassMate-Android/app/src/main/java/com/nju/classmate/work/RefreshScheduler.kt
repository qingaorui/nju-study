package com.nju.classmate.work

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import com.nju.classmate.core.Store
import java.util.concurrent.TimeUnit

/**
 * 让"自动刷新"开关真正生效。
 *
 * 之前只有 App 启动时排一次，开关拨了没有任何动作：
 *   · 关掉它 → 15 分钟一次的兜底任务还在跑（只是 RefreshWorker 里 no-op）；
 *   · 开回来 → 没有任何东西重新排。
 * 这个 `sync` 由"设置保存"和"应用启动"两处调用，保证开关和调度一致。
 */
object RefreshScheduler {

    private const val INTERVAL_MINUTES = 15L

    fun sync(ctx: Context) {
        val wm = WorkManager.getInstance(ctx)
        if (Store.loadSettings(ctx).autoRefreshEnabled) {
            val request = PeriodicWorkRequestBuilder<RefreshWorker>(
                INTERVAL_MINUTES, TimeUnit.MINUTES
            )
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.NOT_REQUIRED)
                        .build()
                )
                .build()
            wm.enqueueUniquePeriodicWork(
                RefreshWorker.NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request
            )
        } else {
            wm.cancelUniqueWork(RefreshWorker.NAME)
        }
    }
}
