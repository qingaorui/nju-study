package com.nju.classmate.core

/**
 * 手动录入课程时，把用户在表单里填的"周次/节次/星期"转成课程模型。
 *
 * 为什么要单独抽成纯函数：手动录入涉及一堆输入校验和换算
 * （"1-16 周单周"展开成 1,3,5,...,15、"第 3-4 节"转成 startSlot=3,endSlot=4），
 * 这些都是确定性的、容易写错的逻辑，值得在 JVM 上跑断言。
 *
 * 这一层不碰 Android API；真正去读/写 SharedPreferences 的是 WebBridge。
 */

/** 手动录课表单里"周次"这一项的三档 */
object WeekPattern {
    const val ALL = "all"    // 连续周：1-16 周
    const val ODD = "odd"    // 单周：1,3,5,...
    const val EVEN = "even"  // 双周：2,4,6,...
}

/**
 * 把起始周到结束周、按奇偶模式展开成周次列表。
 *
 * @param weekStart 起始周，越界会自动收敛到 1..30
 * @param weekEnd   结束周，小于起始周时取等于起始周
 * @param parity    WeekPattern 之一，其它值按 ALL 处理
 */
fun computeWeeks(weekStart: Int, weekEnd: Int, parity: String): List<Int> {
    val start = weekStart.coerceIn(1, 30)
    val end = maxOf(start, weekEnd.coerceIn(1, 30))
    return when (parity) {
        WeekPattern.ODD -> (start..end).filter { it % 2 == 1 }
        WeekPattern.EVEN -> (start..end).filter { it % 2 == 0 }
        else -> (start..end).toList()
    }
}

/**
 * 校验并归一化节次。
 *
 * 返回 (startSlot, endSlot)。结束节次小于起始时自动等于起始；
 * 越界（<1 或 >24）收敛到合法范围。
 */
fun normalizeSlots(startSlot: Int, endSlot: Int): Pair<Int, Int> {
    val s = startSlot.coerceIn(1, 24)
    val e = maxOf(s, endSlot.coerceIn(1, 24))
    return s to e
}

/**
 * 校验星期。1..7 直接通过；其它值（表单没选/传错）返回 null，
 * 由调用方给出明确报错，而不是静默存一个 0 进"自由时间"里。
 */
fun validWeekday(weekday: Int): Int? =
    if (weekday in 1..7) weekday else null

/**
 * 把表单字段组装成一个 Course。
 *
 * @param id 由调用方生成，用于"删除这一条"时精确匹配（classNumber 复用这个 id）
 */
fun buildManualCourse(
    id: String,
    name: String,
    weekday: Int,
    startSlot: Int,
    endSlot: Int,
    weekStart: Int,
    weekEnd: Int,
    parity: String,
    classroom: String,
    teacher: String,
    testTime: String
): Course {
    val (s, e) = normalizeSlots(startSlot, endSlot)
    return Course(
        name = name.trim(),
        classroom = classroom.trim(),
        classNumber = id,
        teacher = teacher.trim(),
        testTime = testTime.trim().ifBlank { null },
        weeks = computeWeeks(weekStart, weekEnd, parity),
        weekTime = validWeekday(weekday) ?: 0,
        startSlot = s,
        endSlot = e,
        // importType = 2 标记"手动录入"，用于和抓取来的课程区分（列表/删除用）
        importType = 2
    )
}
