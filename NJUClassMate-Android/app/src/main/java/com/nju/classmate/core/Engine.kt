package com.nju.classmate.core

import java.time.Duration
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import kotlin.math.roundToInt

/**
 * 「下一节课」计算引擎。
 *
 * 这是整个 App 最核心、也最容易出错的一块：
 * 现在几点 → 今天第几周 → 这节课要不要上 → 下一节是哪一节。
 * 边界多到在真机上根本守不完（你得等到某一节课正好开始才能验证一次状态翻转），
 * 所以它被刻意写成**纯函数、无副作用、不依赖任何 Android API**，
 * 这样可以直接在 JVM 上跑单元测试（见 EngineTest.kt）。
 *
 * 设计要点：
 *   1. 所有比较都换算成"绝对时间"再比，跨天跨周不会出错；
 *   2. 作息表（Settings.timeSlots）是唯一的"节次 → 时刻"映射来源，
 *      换校区/夏令时只要改这张表；
 *   3. 不区分"今天"和"以后"，统一扫一个时间窗，少写一堆边界分支。
 */
object Engine {

    /** 往前看多少天，超过就认为"暂时没课了" */
    private const val LOOKAHEAD_DAYS = 21

    private val DATE_FORMAT: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")

    // ---------------------------------------------------------------- 基础工具

    /** 解析 yyyy-MM-dd；失败返回 null */
    fun parseDate(key: String?): LocalDate? {
        if (key.isNullOrBlank() || key.length < 8) return null
        return try {
            LocalDate.parse(key.trim(), DATE_FORMAT)
        } catch (e: Exception) {
            null
        }
    }

    fun toDateKey(date: LocalDate): String = date.format(DATE_FORMAT)

    /** "HH:mm" → 当天第几分钟 */
    fun clockToMinutes(clock: String): Int {
        val parts = clock.split(":")
        if (parts.size < 2) return 0
        val h = parts[0].trim().toIntOrNull() ?: return 0
        val m = parts[1].trim().toIntOrNull() ?: return 0
        return h * 60 + m
    }

    fun minutesToClock(minutes: Int): String {
        val v = minutes.coerceIn(0, 24 * 60 - 1)
        return "%02d:%02d".format(v / 60, v % 60)
    }

    private fun slotOf(slots: List<TimeSlot>, index: Int): TimeSlot? =
        slots.firstOrNull { it.index == index }

    /** 该课程在某周是否要上 */
    fun isActiveInWeek(course: Course, weekIndex: Int): Boolean {
        if (weekIndex <= 0) return false
        return course.weeks.contains(weekIndex)
    }

    /**
     * 计算某天是学期第几周（第一周记为 1）。
     * 早于开学日返回 0（尚未开学），没设开学日期也返回 0。
     */
    fun weekIndexOf(semesterStartMonday: String?, date: LocalDate): Int {
        val start = parseDate(semesterStartMonday) ?: return 0
        val days = ChronoUnit.DAYS.between(start, date)
        if (days < 0) return 0
        return (days / 7).toInt() + 1
    }

    /** 某天所在那周的周一 */
    fun weekMonday(date: LocalDate): LocalDate =
        date.minusDays((date.dayOfWeek.value - 1).toLong())

    /**
     * 给定"参考日（通常是今天）是第 N 周"，反推开学第一周的周一。
     *
     * 这是「现在是第几周」功能的数学核心：学生知道"开学第三周了"，
     * 但不知道（也懒得找）开学那天到底是几号。这里直接反推。
     */
    fun semesterStartForWeek(weekIndex: Int, reference: LocalDate): LocalDate {
        val w = weekIndex.coerceAtLeast(1)
        return weekMonday(reference).minusWeeks((w - 1).toLong())
    }

    /** 把"还剩多少分钟"说成人话 */
    fun humanizeRemain(minutes: Int): String = when {
        minutes < 0 -> "已开始"
        minutes < 1 -> "即将开始"
        minutes < 60 -> "$minutes 分钟后"
        minutes < 60 * 24 -> {
            val h = minutes / 60
            val m = minutes % 60
            if (m == 0) "$h 小时后" else "$h 小时 $m 分后"
        }
        else -> "${minutes / (60 * 24)} 天后"
    }

    // ---------------------------------------------------------------- 单日课表

    /**
     * 计算某一天的课程。
     * @param now 用于判断状态的时间基准（测试时传固定值，生产传 LocalDateTime.now()）
     */
    fun daySchedule(
        timetable: Timetable,
        settings: Settings,
        date: LocalDate,
        now: LocalDateTime
    ): DaySchedule {
        val weekday = date.dayOfWeek.value           // 1=周一 ... 7=周日
        val weekIndex = weekIndexOf(settings.semesterStartMonday, date)
        val occurrences = ArrayList<ClassOccurrence>()

        for (course in timetable.courses) {
            if (course.weekTime != weekday) continue      // 自由时间的课没有固定星期
            if (!isActiveInWeek(course, weekIndex)) continue
            toOccurrence(course, settings, date, weekIndex, now)?.let { occurrences.add(it) }
        }

        occurrences.sortBy { it.minutesFromNow }
        return DaySchedule(date, weekIndex, occurrences)
    }

    private fun toOccurrence(
        course: Course,
        settings: Settings,
        date: LocalDate,
        weekIndex: Int,
        now: LocalDateTime
    ): ClassOccurrence? {
        val startSlot = slotOf(settings.timeSlots, course.startSlot)
            ?: return ClassOccurrence(
                course, date, weekIndex, course.startSlot, course.endSlot,
                "--:--", "--:--", 0, ClassStatus.UPCOMING
            )

        val endSlot = slotOf(settings.timeSlots, course.endSlot)
        val startClock = startSlot.start
        val endClock = endSlot?.end ?: startSlot.end

        val dayStart = date.atStartOfDay()
        val startAt = dayStart.plusMinutes(clockToMinutes(startClock).toLong())
        val endAt = dayStart.plusMinutes(clockToMinutes(endClock).toLong())

        val status = when {
            !now.isBefore(endAt) -> ClassStatus.FINISHED
            !now.isBefore(startAt) -> ClassStatus.ONGOING
            else -> ClassStatus.UPCOMING
        }

        val minutesFromNow =
            (ChronoUnit.SECONDS.between(now, startAt) / 60.0).roundToInt()

        return ClassOccurrence(
            course, date, weekIndex, course.startSlot, course.endSlot,
            startClock, endClock, minutesFromNow, status
        )
    }

    // ---------------------------------------------------------------- 下一节课

    /**
     * 算出"下一节课"。
     *
     * 同时返回 ongoing 和 next：正在上课时应该显示"正在上课·还剩 xx 分钟"，
     * 而不是傻乎乎地显示半天之后的下一门。
     */
    fun resolve(timetable: Timetable, settings: Settings, now: LocalDateTime): NextClassResult {
        val weekIndex = weekIndexOf(settings.semesterStartMonday, now.toLocalDate())

        val ongoing = ArrayList<ClassOccurrence>()
        val restOfToday = ArrayList<ClassOccurrence>()
        val upcoming = ArrayList<ClassOccurrence>()

        for (d in 0..LOOKAHEAD_DAYS) {
            val date = now.toLocalDate().plusDays(d.toLong())
            val day = daySchedule(timetable, settings, date, now)
            for (occ in day.occurrences) {
                when (occ.status) {
                    ClassStatus.ONGOING -> ongoing.add(occ)
                    ClassStatus.UPCOMING -> {
                        if (d == 0) restOfToday.add(occ)
                        upcoming.add(occ)
                    }
                    ClassStatus.FINISHED -> Unit
                }
            }
            // 找到未来的课之后再往后扫两天，避免"本周最后一节"被截断
            if (upcoming.isNotEmpty() && d > 2) break
        }

        restOfToday.sortBy { it.minutesFromNow }
        upcoming.sortBy { it.minutesFromNow }

        val next: ClassOccurrence? = restOfToday.firstOrNull() ?: upcoming.firstOrNull()

        return NextClassResult(
            ongoing = ongoing,
            next = next,
            restOfToday = restOfToday,
            weekIndex = weekIndex,
            timetableName = timetable.name,
            exhausted = next == null && ongoing.isEmpty()
        )
    }

    // ---------------------------------------------------------------- 周课表

    /**
     * 生成周课表的课程块。
     * 同一 (星期, 起始节次) 有多门课时标记 conflict —— 南大"免修不免考"的常见情况。
     */
    fun buildWeekBlocks(timetable: Timetable, weekIndex: Int): List<GridBlock> {
        val blocks = timetable.courses
            .filter { it.weekTime in 1..7 && isActiveInWeek(it, weekIndex) }
            .map {
                GridBlock(
                    course = it,
                    weekday = it.weekTime,
                    startSlot = it.startSlot,
                    endSlot = it.endSlot,
                    span = maxOf(1, it.endSlot - it.startSlot + 1),
                    conflict = false
                )
            }
            .toMutableList()

        for (i in blocks.indices) {
            for (j in i + 1 until blocks.size) {
                val a = blocks[i]
                val b = blocks[j]
                if (a.weekday != b.weekday) continue
                if (a.startSlot <= b.endSlot && b.startSlot <= a.endSlot) {
                    blocks[i] = a.copy(conflict = true)
                    blocks[j] = b.copy(conflict = true)
                }
            }
        }
        return blocks
    }

    /** 取出所有"自由时间"的课程（无固定时间地点） */
    fun freeTimeCourses(timetable: Timetable): List<Course> =
        timetable.courses.filter { it.weekTime < 1 }

    /** 学年里一共有多少周（取所有课程周次的最大值，至少 18 周） */
    fun totalWeeks(timetable: Timetable): Int =
        maxOf(18, timetable.courses.flatMap { it.weeks }.maxOrNull() ?: 18)

    /** 统计课程门数（同一课程号只算一门） */
    fun countDistinctCourses(courses: List<Course>): Int =
        courses.map { if (it.classNumber.isNotBlank()) it.classNumber else it.name }.toSet().size

    // ---------------------------------------------------------------- 考试

    private val EXAM_DATE = Regex("""(\d{4})[-/年](\d{1,2})[-/月](\d{1,2})""")
    private val EXAM_TIME = Regex("""(\d{1,2}):(\d{2})""")

    /**
     * 解析出即将到来的考试。
     * 教务系统里考试时间写法不统一，这里宽松地抽「yyyy-MM-dd」+「HH:mm」，
     * 抽不到就原样展示（at = null）。
     */
    fun upcomingExams(timetable: Timetable, now: LocalDateTime, limit: Int): List<ExamEntry> {
        val out = ArrayList<ExamEntry>()
        val seen = HashSet<String>()

        for (c in timetable.courses) {
            val raw = c.testTime
            if (raw.isNullOrBlank()) continue
            if (!seen.add("$raw|${c.name}")) continue

            val entry = parseExam(c.name, raw, c.testLocation, now)
            if (entry.at == null || !entry.at.isBefore(now)) out.add(entry)
        }

        out.sortWith(
            compareBy<ExamEntry> { it.at == null }          // 解析不出时间的排最后
                .thenBy { it.at ?: LocalDateTime.MAX }      // 其余按时间升序
        )
        return out.take(limit)
    }

    private fun parseExam(
        courseName: String,
        raw: String,
        location: String?,
        now: LocalDateTime
    ): ExamEntry {
        val dm = EXAM_DATE.find(raw)
        var at: LocalDateTime? = null

        if (dm != null) {
            val y = dm.groupValues[1].toInt()
            val mo = dm.groupValues[2].toInt()
            val d = dm.groupValues[3].toInt()
            val tm = EXAM_TIME.find(raw)
            val hh = tm?.groupValues?.get(1)?.toIntOrNull() ?: 0
            val mm = tm?.groupValues?.get(2)?.toIntOrNull() ?: 0
            at = try {
                LocalDateTime.of(y, mo, d, hh, mm)
            } catch (e: Exception) {
                null
            }
        }

        val daysLeft = at?.let { ChronoUnit.DAYS.between(now.toLocalDate(), it.toLocalDate()).toInt() } ?: -1

        return ExamEntry(
            courseName = courseName,
            raw = raw,
            at = at,
            location = location ?: "",
            daysLeft = daysLeft
        )
    }

    // ---------------------------------------------------------------- 归一化

    /**
     * 规范化从教务系统抓来的课程片段：
     *   - 把 nju.app 语义的 time_count（末节 − 首节）已经在解析处换算成 endSlot；
     *   - 丢掉明显无效的记录；
     *   - 按 星期 → 节次 → 课程名 排序，UI 可以直接渲染。
     */
    fun normalize(courses: List<Course>): List<Course> {
        val out = ArrayList<Course>()
        for (c in courses) {
            if (c.name.isBlank()) continue
            if (c.weeks.isEmpty()) continue
            val weekTime = if (c.weekTime in 1..7) c.weekTime else 0
            val start = maxOf(0, c.startSlot)
            out.add(
                c.copy(
                    weekTime = weekTime,
                    startSlot = start,
                    endSlot = maxOf(start, c.endSlot)
                )
            )
        }
        return out.sortedWith(
            compareBy({ it.weekTime }, { it.startSlot }, { it.name })
        )
    }

    /** 把周次数组压成 "1-8, 10-16 周" 这种好读的写法 */
    fun weekText(weeks: List<Int>): String {
        if (weeks.isEmpty()) return "未指定"
        val sorted = weeks.distinct().sorted()
        val parts = ArrayList<String>()
        var start = sorted[0]
        var prev = sorted[0]
        for (i in 1 until sorted.size) {
            val cur = sorted[i]
            if (cur == prev + 1) {
                prev = cur
                continue
            }
            parts.add(if (start == prev) "$start" else "$start-$prev")
            start = cur
            prev = cur
        }
        parts.add(if (start == prev) "$start" else "$start-$prev")
        return parts.joinToString(", ") + " 周"
    }

    /** 两个时间点之间的天数差（按日期算，不受时分秒影响） */
    fun daysBetween(from: LocalDateTime, to: LocalDateTime): Long =
        ChronoUnit.DAYS.between(from.toLocalDate(), to.toLocalDate())

    /** 供 UI 展示"距今多久" */
    fun humanizeDuration(d: Duration): String {
        val m = d.toMinutes()
        return humanizeRemain(m.toInt())
    }
}
