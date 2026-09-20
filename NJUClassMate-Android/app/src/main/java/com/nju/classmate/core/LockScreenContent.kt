package com.nju.classmate.core

import java.time.LocalDate
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit

/**
 * 锁屏常驻通知要显示的内容。
 *
 * 为什么单独抽出来：Android 不允许三方应用做锁屏小组件（5.0 起就没这个能力了），
 * 常驻通知是唯一能躺在锁屏上的东西。而"锁屏上到底该显示什么"这件事
 * 边界很多——正在上课 / 即将上课 / 今天没了 / 明天才有 / 假期 / 没导入 ——
 * 和「下一节课」引擎一样，它在真机上根本守不完。
 *
 * 所以这里刻意写成**纯函数、不碰任何 Android API**：
 * 可以直接在 JVM 上跑断言（见 EngineTest 里的「锁屏常驻通知」一节），
 * 而 NextClassNotifier 只负责把结果翻译成 RemoteViews。
 */
data class LockScreenContent(
    /** 是否应该显示这条通知。false 时调用方要主动撤掉，不能留残留 */
    val visible: Boolean,
    /** 左上角的小标签："正在上课" / "今天" / "明天" / "周四" / "空闲" */
    val chip: String,
    /** 主标题：课程名 */
    val title: String,
    /** 副标题："周三 第3-4节 · 10:10-12:00" */
    val timeLine: String,
    /** 地点 + 教师 */
    val location: String,
    /** 倒计时前缀："还剩" / "还有"；空表示不显示倒计时 */
    val countdownLabel: String,
    /**
     * 倒计时的目标时刻。
     *
     * 通知里用的是 Chronometer（countDown 模式），它自己会走秒，
     * 所以不需要为了"跳秒"频繁重发通知——只在状态真正翻转时重发。
     */
    val countdownTarget: LocalDateTime?,
    /** 静态兜底文案，倒计时不可用时显示（比如超过 6 小时） */
    val remainText: String,
    /** 展开后的一行：今天还有哪些课 / 最近一场考试 */
    val subLine: String,
    /** 按钮文案：点了切到另一天 */
    val toggleLabel: String,
    /** 是否处于"正在上课"状态（UI 用来选强调色） */
    val ongoing: Boolean = false
) {
    companion object {
        /** 不显示（关掉了开关，或还没导入课表） */
        val HIDDEN = LockScreenContent(
            visible = false,
            chip = "", title = "", timeLine = "", location = "",
            countdownLabel = "", countdownTarget = null, remainText = "",
            subLine = "", toggleLabel = "", ongoing = false
        )
    }
}

/**
 * 算出锁屏常驻通知该显示什么。
 *
 * @param now 时间基准（生产传 LocalDateTime.now()，测试传固定值）
 */
fun buildLockScreenContent(
    timetable: Timetable,
    settings: Settings,
    now: LocalDateTime
): LockScreenContent {
    // 关掉了开关，或者还没导入课表 —— 都不该占着通知栏
    if (!settings.lockNotificationEnabled) return LockScreenContent.HIDDEN
    if (timetable.courses.isEmpty()) return LockScreenContent.HIDDEN

    // 「看明天 / 看今天」和桌面小组件共用同一个开关。
    // 不另开一个字段，是因为它是同一个语义（用户主动要看哪天）；
    // 两个字段会算出互相矛盾的状态——通知说明天、卡片说今天，那才是 bug。
    val toggleLabel = if (settings.todayCardForceTomorrow) "看今天" else "看明天"

    // 没设开学日期就算不出第几周，也就不知道哪些课要上
    if (settings.semesterStartMonday.isBlank()) {
        return LockScreenContent(
            visible = true,
            chip = "待设置",
            title = "请先设置开学第一周的周一",
            timeLine = "设好之后才知道今天是第几周、哪些课要上",
            location = "",
            countdownLabel = "",
            countdownTarget = null,
            remainText = "",
            subLine = "",
            toggleLabel = toggleLabel
        )
    }

    // 用户主动要看明天时，跳过今天直接算明天的课
    var result = Engine.resolve(timetable, settings, now)
    var dayShifted = false
    if (settings.todayCardForceTomorrow) {
        val tomorrow = now.plusDays(1)
        val r2 = Engine.resolve(timetable, settings, tomorrow)
        // 明天也没课就老实显示今天的状态，别给一张空的通知
        if (r2.ongoing.isNotEmpty() || r2.next != null) {
            result = r2
            dayShifted = true
        }
    }

    // ---- 正在上课：这种情况优先级最高，一切为它让路 ----
    if (result.ongoing.isNotEmpty()) {
        val occ = result.ongoing[0]
        val others = result.ongoing.size - 1
        return LockScreenContent(
            visible = true,
            chip = "正在上课",
            title = occ.course.name,
            timeLine = timeLineOf(occ) + if (others > 0) " · 同时段还有 $others 门" else "",
            location = locationOf(occ),
            countdownLabel = "还剩",
            countdownTarget = clockAt(occ.date, occ.endClock),
            remainText = remainToEndOf(occ, now),
            subLine = restLine(result.restOfToday, exclude = null),
            toggleLabel = toggleLabel,
            ongoing = true
        )
    }

    // ---- 即将上课 ----
    //
    // 三种情况下才把"另一天"的课顶上来：
    //   1. 那就是今天还剩的课（next.date == today）；
    //   2. 用户打开了「今天没课时显示明天」（默认开）；
    //   3. 用户主动点了「看明天」——这是明确的意图，优先级高于设置项。
    // 都不满足时，说明今天确实没课了，老老实实显示"上完了"，
    // 而不是甩一个三天后的课过来（那会让人以为马上要上课）。
    val next = result.next
    val onAnotherDay = next != null && next.date != now.toLocalDate()
    val allowJump = settings.lockNotificationShowTomorrow || dayShifted
    if (next != null && (!onAnotherDay || allowJump)) {
        val rest = restLine(result.restOfToday, exclude = next)
        return LockScreenContent(
            visible = true,
            chip = dayLabelOf(next.date, now),
            title = next.course.name,
            timeLine = timeLineOf(next),
            location = locationOf(next),
            countdownLabel = "还有",
            countdownTarget = clockAt(next.date, next.startClock),
            remainText = Engine.humanizeRemain(next.minutesFromNow),
            // 顶上来的是另一天的课时，说明今天已经结束了——直说，
            // 比留一行空白更清楚
            subLine = if (rest.isNotBlank()) rest
            else if (onAnotherDay) "今天没有别的课了" else "",
            toggleLabel = toggleLabel
        )
    }

    // ---- 一段时间内都没课了 ----
    val exam = Engine.upcomingExams(timetable, now, 1).firstOrNull()
    val sub = when {
        exam?.at != null && exam.daysLeft >= 0 ->
            "距离「${exam.courseName}」考试还有 ${exam.daysLeft} 天"
        exam != null -> "有考试安排：${exam.raw}"
        else -> Engine.weekText(timetable.courses.flatMap { it.weeks })
    }

    // 走到这里有两种可能：
    //   · 真的没课了（学期结束、假期、课表过期）；
    //   · 今天没课了，但用户关掉了「今天没课时显示明天」——
    //     这时故意不透露后面的安排，避免"马上要上课"的错觉。
    val inVacation = result.weekIndex <= 0

    return LockScreenContent(
        visible = true,
        chip = if (inVacation) "假期" else "空闲",
        title = if (inVacation) "不在学期内" else "最近的课都上完了",
        timeLine = if (inVacation) result.timetableName
        else "第 ${result.weekIndex} 周 · ${result.timetableName}",
        location = "",
        countdownLabel = "",
        countdownTarget = null,
        remainText = "",
        subLine = sub,
        toggleLabel = toggleLabel
    )
}

// ---------------------------------------------------------------- 小工具

/** "周三 第3-4节 · 10:10-12:00" */
fun timeLineOf(occ: ClassOccurrence): String {
    val wd = "周" + "一二三四五六日"[occ.date.dayOfWeek.value - 1]
    val slots = if (occ.startSlot == occ.endSlot) "第${occ.startSlot}节"
    else "第${occ.startSlot}-${occ.endSlot}节"
    return "$wd $slots · ${occ.startClock}-${occ.endClock}"
}

/** "仙Ⅱ-304 · 张三"，缺哪个就去掉哪个 */
fun locationOf(occ: ClassOccurrence): String = when {
    occ.course.classroom.isNotBlank() && occ.course.teacher.isNotBlank() ->
        "${occ.course.classroom} · ${occ.course.teacher}"
    occ.course.classroom.isNotBlank() -> occ.course.classroom
    else -> occ.course.teacher
}

/** 某天的某个时刻 */
fun clockAt(date: LocalDate, clock: String): LocalDateTime =
    date.atStartOfDay().plusMinutes(Engine.clockToMinutes(clock).toLong())

/** "今天" / "明天" / "周四" */
fun dayLabelOf(date: LocalDate, now: LocalDateTime): String {
    val today = now.toLocalDate()
    return when (date) {
        today -> "今天"
        today.plusDays(1) -> "明天"
        else -> "周" + "一二三四五六日"[date.dayOfWeek.value - 1]
    }
}

private fun remainToEndOf(occ: ClassOccurrence, now: LocalDateTime): String {
    val endAt = clockAt(occ.date, occ.endClock)
    val minutes = ChronoUnit.MINUTES.between(now, endAt).toInt()
    return if (minutes <= 0) "即将下课" else Engine.humanizeRemain(minutes)
}

/**
 * 展开后的那一行：今天还有哪些课。
 *
 * exclude 是已经显示在主标题里的那一节，别重复写一遍。
 */
private fun restLine(rest: List<ClassOccurrence>, exclude: ClassOccurrence?): String {
    val others = rest.filter { it != exclude }
    if (others.isEmpty()) return ""
    val head = others.take(3).joinToString("、") { "${it.startClock} ${it.course.name}" }
    return if (others.size > 3) "今天还有 $head 等 ${others.size} 节" else "今天还有 $head"
}
