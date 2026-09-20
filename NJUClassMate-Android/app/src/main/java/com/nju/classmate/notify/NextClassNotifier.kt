package com.nju.classmate.notify

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.nju.classmate.MainActivity
import com.nju.classmate.R
import com.nju.classmate.core.LockScreenContent
import com.nju.classmate.core.Store
import com.nju.classmate.core.buildLockScreenContent
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * 锁屏常驻通知 —— 在锁屏上直接显示下一节课。
 *
 * ## 为什么用通知而不是锁屏小组件
 *
 * Android 从 5.0 起就删掉了锁屏小组件（Keyguard widget）这个能力，
 * 三方应用拿不到任何替代 API。**常驻通知是唯一能躺在锁屏上的东西**：
 * 只要带上 `VISIBILITY_PUBLIC`，通知内容就会原样显示在锁屏上，
 * 不需要解锁、不需要点亮应用。
 *
 * ## 三个关键设计
 *
 * 1. **自走秒倒计时。** "还剩 32 分钟"用的是 Chronometer 的 countDown 模式，
 *    由系统自己刷新，**不需要为了跳秒反复重发通知**。
 *    重发通知要唤醒进程、耗电，还会被系统限流——所以只在状态真正翻转时才重发：
 *       · 上课/下课的整点（ReminderScheduler 的 TYPE_REFRESH 闹钟已经排好了）
 *       · 开机、数据变更、用户手动下拉刷新
 *    这个组合让通知在两次重发之间也是准确的。
 *
 * 2. **不伪造重要性。** 渠道用 IMPORTANCE_DEFAULT + 静音（关声音、关振动）。
 *    不用 IMPORTANCE_LOW 是有代价的：国产 ROM（EMUI/鸿蒙）普遍把 LOW 归到
 *    "不重要通知"里折叠起来，锁屏上直接看不见——那就白做了。
 *    代价是它会出现在正常通知分组里，但它是静音的，不会打扰。
 *
 * 3. **状态和桌面小组件共用一份数据。** 「看明天」按钮改的是
 *    `todayCardForceTomorrow`，和小组件是同一个开关——两个视图说两套话才是 bug。
 */
object NextClassNotifier {

    /** 固定 id。提醒类通知用的是 2000~5000 段，这里是 9001，不会撞 */
    const val ID = 9001
    const val CHANNEL_ID = "class_lock_screen"

    /**
     * 倒计时超过 6 小时就不再走 Chronometer，退回静态文案。
     * 一直跳"还有 5 小时 59 分"既没信息量又费电。
     */
    private const val COUNTDOWN_MAX_MINUTES = 6 * 60

    private const val TAG = "NJUNotify"

    /** 动作按钮的 PendingIntent requestCode，固定值避免堆积 */
    private const val RC_REFRESH = 9101
    private const val RC_TOGGLE = 9102

    // ---------------------------------------------------------------- 渠道

    /**
     * 建通知渠道。渠道一旦创建，重要性就只能由用户在系统设置里改，
     * 所以这里的取值必须一次到位（见类注释第 2 点）。
     */
    fun createChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = ctx.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            ctx.getString(R.string.channel_lock),
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = ctx.getString(R.string.channel_lock_desc)
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)      // 静音：这是一条"信息"通知，不是提醒
        }
        manager.createNotificationChannel(channel)
    }

    // ---------------------------------------------------------------- 发 / 撤

    /**
     * 按当前时间重算并更新锁屏通知。
     *
     * 这个是幂等的：重复调用只是把同一条通知覆盖一遍，不会堆出多条。
     */
    fun update(ctx: Context) {
        val settings = Store.loadSettings(ctx)
        val timetable = Store.loadTimetable(ctx)
        val now = LocalDateTime.now()
        val content = buildLockScreenContent(timetable, settings, now)

        // 关掉了开关、或者还没导入课表 —— 必须主动撤掉，不能留一条孤儿通知
        if (!content.visible) {
            cancel(ctx)
            return
        }

        if (!NotificationManagerCompat.from(ctx).areNotificationsEnabled()) {
            // 没权限时静默返回。网页那边有状态提示，不在这里骚扰用户
            Log.w(TAG, "通知权限未开启，跳过锁屏通知")
            return
        }

        try {
            NotificationManagerCompat.from(ctx).notify(ID, build(ctx, content, now))
        } catch (e: SecurityException) {
            Log.w(TAG, "发通知被拒（权限被撤销）: ${e.message}")
        } catch (e: Exception) {
            // 通知失败绝不能影响主流程（导入、小组件刷新都在同一条链路上）
            Log.e(TAG, "发通知失败: ${e.message}")
        }
    }

    /** 撤掉锁屏通知（用户关开关、清了课表时用） */
    fun cancel(ctx: Context) {
        try {
            NotificationManagerCompat.from(ctx).cancel(ID)
        } catch (e: Exception) {
            Log.w(TAG, "撤通知失败: ${e.message}")
        }
    }

    // ---------------------------------------------------------------- 组装

    private fun build(ctx: Context, c: LockScreenContent, now: LocalDateTime): Notification {
        val compact = bind(ctx, R.layout.notification_next_class, c, now)
        val big = bind(ctx, R.layout.notification_next_class_big, c, now)

        return NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            // 下面两行是给"安全锁屏"和辅助功能兜底的：
            // 某些系统在渲染锁屏时会先取这两个字段，不设会出现空白行
            .setContentTitle(c.title)
            .setContentText(c.timeLine)
            .setWhen(0)
            .setShowWhen(false)
            // ★ 这一行是锁屏能看见内容的唯一原因
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            // 常驻：不可划走。Android 没有前台服务时部分 ROM 仍允许清除，
            // 那种情况下由整点闹钟和 WorkManager 把它重新发出来。
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setColor(ctx.getColor(R.color.accent_blue))
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(compact)
            .setCustomBigContentView(big)
            .setContentIntent(openAppIntent(ctx))
            .addAction(
                R.drawable.ic_action_refresh,
                ctx.getString(R.string.notify_action_refresh),
                actionIntent(ctx, NotifyActionReceiver.ACTION_REFRESH, RC_REFRESH)
            )
            .addAction(
                R.drawable.ic_action_calendar,
                c.toggleLabel,
                actionIntent(ctx, NotifyActionReceiver.ACTION_TOGGLE_DAY, RC_TOGGLE)
            )
            .build()
    }

    /** 把内容塞进一个 RemoteViews 布局（收起态和展开态只差几个控件，共用这段） */
    private fun bind(
        ctx: Context,
        layout: Int,
        c: LockScreenContent,
        now: LocalDateTime
    ): RemoteViews {
        val rv = RemoteViews(ctx.packageName, layout)

        rv.setTextViewText(R.id.notifChip, c.chip)
        rv.setInt(
            R.id.notifChip, "setBackgroundResource",
            when {
                c.ongoing -> R.drawable.bg_chip_amber
                c.chip == "空闲" || c.chip == "假期" || c.chip == "待设置" ->
                    R.drawable.bg_chip_gray
                else -> R.drawable.bg_chip_blue
            }
        )
        rv.setTextViewText(R.id.notifTitle, c.title)
        rv.setTextViewText(R.id.notifTime, c.timeLine)

        // ---- 倒计时：能用 Chronometer 就用，用不了退回静态文案 ----
        val remainMs = deltaMillis(c.countdownTarget, now)
        val useCountdown = c.countdownLabel.isNotEmpty() &&
            remainMs > 0 &&
            remainMs <= COUNTDOWN_MAX_MINUTES * 60_000L

        if (useCountdown) {
            // Chronometer 走的是 elapsedRealtime（含深睡眠），
            // 所以息屏/休眠后回来时间仍然是对的
            val base = SystemClock.elapsedRealtime() + remainMs
            rv.setChronometerCountDown(R.id.notifCountdown, true)
            rv.setChronometer(R.id.notifCountdown, base, "${c.countdownLabel} %s", true)
            rv.setViewVisibility(R.id.notifCountdown, View.VISIBLE)
            rv.setViewVisibility(R.id.notifRemainStatic, View.GONE)
        } else {
            rv.setViewVisibility(R.id.notifCountdown, View.GONE)
            if (c.remainText.isBlank()) {
                rv.setViewVisibility(R.id.notifRemainStatic, View.GONE)
            } else {
                rv.setViewVisibility(R.id.notifRemainStatic, View.VISIBLE)
                rv.setTextViewText(R.id.notifRemainStatic, c.remainText)
            }
        }

        // ---- 展开态才有的两行 ----
        if (layout == R.layout.notification_next_class_big) {
            if (c.location.isBlank()) {
                rv.setViewVisibility(R.id.notifLocation, View.GONE)
            } else {
                rv.setViewVisibility(R.id.notifLocation, View.VISIBLE)
                rv.setTextViewText(R.id.notifLocation, c.location)
            }
            if (c.subLine.isBlank()) {
                rv.setViewVisibility(R.id.notifSub, View.GONE)
            } else {
                rv.setViewVisibility(R.id.notifSub, View.VISIBLE)
                rv.setTextViewText(R.id.notifSub, c.subLine)
            }
        }
        return rv
    }

    /** 目标时刻距 now 还有多少毫秒；目标为 null 时返回 -1（表示"没有倒计时"） */
    private fun deltaMillis(target: LocalDateTime?, now: LocalDateTime): Long {
        if (target == null) return -1
        val zone = ZoneId.systemDefault()
        return target.atZone(zone).toInstant().toEpochMilli() -
            now.atZone(zone).toInstant().toEpochMilli()
    }

    // ---------------------------------------------------------------- Intent

    private fun openAppIntent(ctx: Context): PendingIntent {
        val intent = Intent(ctx, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            ctx, RC_REFRESH, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun actionIntent(ctx: Context, action: String, rc: Int): PendingIntent {
        val intent = Intent(ctx, NotifyActionReceiver::class.java).apply {
            this.action = action
        }
        return PendingIntent.getBroadcast(
            ctx, rc, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
