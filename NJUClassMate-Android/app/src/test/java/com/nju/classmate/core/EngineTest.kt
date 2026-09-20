package com.nju.classmate.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * 「下一节课」计算引擎的单元测试。
 *
 * 跑在 JVM 上，不需要模拟器、不需要真机，一条命令秒级回归：
 *     gradlew :app:testDebugUnitTest
 *
 * 覆盖的是这个 App 里最核心、最容易出错的一块：
 * 现在几点 → 今天第几周 → 这节课要不要上 → 下一节是哪一节。
 * 这些边界在真机上根本守不完（你得等到某一节课正好开始才能验证一次状态翻转）。
 */
class EngineTest {

    // ---------------------------------------------------------------- 测试数据

    private val semStart = "2026-09-14"   // 2026-09-14 是周一，作为第 1 周周一

    private fun d(y: Int, m: Int, day: Int, hh: Int, mm: Int): LocalDateTime =
        LocalDateTime.of(y, m, day, hh, mm)

    private fun course(
        name: String,
        weekTime: Int,
        startSlot: Int,
        endSlot: Int,
        weeks: List<Int>,
        room: String,
        teacher: String,
        exam: String? = null
    ) = Course(
        name = name,
        classroom = room,
        classNumber = "$name-code",
        teacher = teacher,
        testTime = exam,
        weeks = weeks,
        weekTime = weekTime,
        startSlot = startSlot,
        endSlot = endSlot
    )

    private val allWeeks = (1..16).toList()
    private val firstHalf = (1..8).toList()
    private val oddWeeks = (1..16 step 2).toList()

    private val timetable = Timetable(
        name = "2026-2027学年 第1学期",
        semesterStartMonday = semStart,
        courses = listOf(
            // 周一 1-2 节，全周 —— 与下面那条在 1-8 周冲突
            course("高等数学", 1, 1, 2, allWeeks, "仙Ⅱ-304", "张三", "2027-01-05 14:00-16:00"),
            // 周一 1-2 节，仅 1-8 周
            course("数据结构", 1, 1, 2, firstHalf, "仙Ⅱ-305", "李四"),
            // 周三 5-6 节，单周
            course("大学物理", 3, 5, 6, oddWeeks, "仙1-216", "王五"),
            // 周五 9-10 节
            course("形势与政策", 5, 9, 10, allWeeks, "仙Ⅱ-201", "赵六", "2026-11-20 09:00-11:00"),
            // 自由时间课程
            course("毕业设计", 0, 0, 0, allWeeks, "自由地点", "孙七")
        )
    )

    private val settings = Settings(semesterStartMonday = semStart)

    // ---------------------------------------------------------------- 1. 周次

    @Test
    fun `周次计算`() {
        assertEquals(1, Engine.weekIndexOf(semStart, LocalDate.of(2026, 9, 14)))
        assertEquals(1, Engine.weekIndexOf(semStart, LocalDate.of(2026, 9, 20)))  // 周日仍属第 1 周
        assertEquals(2, Engine.weekIndexOf(semStart, LocalDate.of(2026, 9, 21)))
        assertEquals(3, Engine.weekIndexOf(semStart, LocalDate.of(2026, 9, 28)))
        assertEquals(0, Engine.weekIndexOf(semStart, LocalDate.of(2026, 9, 13)))  // 开学前一天
        assertEquals(10, Engine.weekIndexOf(semStart, LocalDate.of(2026, 11, 16)))
        assertEquals(0, Engine.weekIndexOf("", LocalDate.of(2026, 9, 14)))        // 未设置
    }

    // ---------------------------------------------------------------- 2. 单日课表

    @Test
    fun `单日课表`() {
        val monday = Engine.daySchedule(timetable, settings, LocalDate.of(2026, 9, 14), d(2026, 9, 14, 7, 0))
        assertEquals("第 1 周周一应有 2 门", 2, monday.occurrences.size)
        assertEquals("08:00", monday.occurrences[0].startClock)
        assertEquals("09:50", monday.occurrences[0].endClock)

        val wed1 = Engine.daySchedule(timetable, settings, LocalDate.of(2026, 9, 16), d(2026, 9, 16, 7, 0))
        assertEquals("第 1 周周三有大学物理（单周）", 1, wed1.occurrences.size)

        val wed2 = Engine.daySchedule(timetable, settings, LocalDate.of(2026, 9, 23), d(2026, 9, 23, 7, 0))
        assertEquals("第 2 周周三没课（双周不上）", 0, wed2.occurrences.size)

        val mon10 = Engine.daySchedule(timetable, settings, LocalDate.of(2026, 11, 16), d(2026, 11, 16, 7, 0))
        assertEquals("第 10 周周一只剩高数", 1, mon10.occurrences.size)
        assertEquals("高等数学", mon10.occurrences[0].course.name)

        val before = Engine.daySchedule(timetable, settings, LocalDate.of(2026, 9, 7), d(2026, 9, 7, 7, 0))
        assertEquals("未开学时没有课", 0, before.occurrences.size)
    }

    // ---------------------------------------------------------------- 3. 上课前

    @Test
    fun `下一节课_上课前`() {
        val r = Engine.resolve(timetable, settings, d(2026, 9, 14, 7, 0))
        assertTrue(r.next != null)
        assertEquals("高等数学", r.next!!.course.name)
        assertEquals(60, r.next!!.minutesFromNow)
        assertEquals(ClassStatus.UPCOMING, r.next!!.status)
        assertEquals("此刻没有正在上的课", 0, r.ongoing.size)
        assertEquals("今天还有 2 节", 2, r.restOfToday.size)
        assertEquals(1, r.weekIndex)
    }

    // ---------------------------------------------------------------- 4. 正在上课（含同时段冲突）

    @Test
    fun `下一节课_正在上课`() {
        val r = Engine.resolve(timetable, settings, d(2026, 9, 14, 8, 30))
        assertEquals("检测到 2 门同时在上（免修不免考）", 2, r.ongoing.size)
        assertEquals(ClassStatus.ONGOING, r.ongoing[0].status)
        assertEquals("今天剩余课数为 0", 0, r.restOfToday.size)
        assertEquals("下一节顺延到周三大学物理", "大学物理", r.next!!.course.name)
        assertEquals(LocalDate.of(2026, 9, 16), r.next!!.date)
    }

    // ---------------------------------------------------------------- 5. 课间与跨天

    @Test
    fun `下一节课_课间与跨天`() {
        val after = Engine.resolve(timetable, settings, d(2026, 9, 14, 10, 0))
        assertEquals("上午上完后下一节是周三", "大学物理", after.next!!.course.name)
        assertEquals("13:30", after.next!!.startClock)
        assertEquals(5, after.next!!.startSlot)
        assertEquals(6, after.next!!.endSlot)

        val weekend = Engine.resolve(timetable, settings, d(2026, 9, 19, 10, 0))
        assertEquals("周六没有课，下一节回到下周一", "高等数学", weekend.next!!.course.name)
        assertEquals(LocalDate.of(2026, 9, 21), weekend.next!!.date)
        assertEquals("跨周后周次变为 2", 2, weekend.next!!.weekIndex)
    }

    // ---------------------------------------------------------------- 6. 晚上与学期末

    @Test
    fun `晚上与学期末`() {
        val night = Engine.resolve(timetable, settings, d(2026, 9, 18, 19, 40))
        assertEquals("周五 19:40 正上形势与政策", 1, night.ongoing.size)
        assertEquals(9, night.ongoing[0].startSlot)
        assertEquals(10, night.ongoing[0].endSlot)
        assertEquals("第 10 节下课是 20:20", "20:20", night.ongoing[0].endClock)

        val late = settings.copy(semesterStartMonday = "2027-09-13")
        val none = Engine.resolve(timetable, late, d(2026, 9, 14, 7, 0))
        assertNull("未开学时 next 为空", none.next)
        assertTrue("未开学时 exhausted", none.exhausted)
        assertEquals(0, none.weekIndex)
    }

    // ---------------------------------------------------------------- 7. 周课表块

    @Test
    fun `周课表块与冲突标记`() {
        val w1 = Engine.buildWeekBlocks(timetable, 1)
        assertEquals("第 1 周有 4 个块（自由时间不计入）", 4, w1.size)
        val mon = w1.filter { it.weekday == 1 }
        assertEquals("周一有 2 个冲突块", 2, mon.size)
        assertTrue(mon[0].conflict)
        assertTrue(mon[1].conflict)
        assertEquals("span 计算正确（1-2 节）", 2, mon[0].span)

        // 第 10 周：高数(1-16)在，数据结构(1-8)结课，大学物理是单周课(第10周是双周)不上
        val w10 = Engine.buildWeekBlocks(timetable, 10)
        assertEquals("第 10 周剩 2 个块", 2, w10.size)
        assertFalse("第 10 周周一不再冲突", w10.first { it.weekday == 1 }.conflict)

        // 第 11 周是单周，大学物理回来
        val w11 = Engine.buildWeekBlocks(timetable, 11)
        assertEquals("第 11 周共 3 个块", 3, w11.size)
        assertEquals("第 11 周周三有大学物理", 1, w11.count { it.weekday == 3 })

        val w2 = Engine.buildWeekBlocks(timetable, 2)
        assertEquals("第 2 周周三无课", 0, w2.count { it.weekday == 3 })
    }

    // ---------------------------------------------------------------- 8. 自由时间

    @Test
    fun `自由时间课程`() {
        val free = Engine.freeTimeCourses(timetable)
        assertEquals(1, free.size)
        assertEquals("毕业设计", free[0].name)
    }

    // ---------------------------------------------------------------- 9. 考试

    @Test
    fun `考试安排`() {
        val exams = Engine.upcomingExams(timetable, d(2026, 9, 14, 7, 0), 10)
        assertEquals("解析出 2 场考试", 2, exams.size)
        assertEquals("最早的是形势与政策", "形势与政策", exams[0].courseName)
        assertTrue(exams[0].at != null)
        assertEquals("地点为空时是空串", "", exams[0].location)

        val jan = exams.first { it.courseName == "高等数学" }
        assertEquals(2027, jan.at!!.year)
        assertEquals(14, jan.at!!.hour)

        val later = Engine.upcomingExams(timetable, d(2027, 3, 1, 7, 0), 10)
        assertEquals("历史考试被过滤", 0, later.size)
    }

    // ---------------------------------------------------------------- 10. 总周数 / 门数

    @Test
    fun `总周数与门数`() {
        assertEquals("课程排到 16 周时兜底到 18", 18, Engine.totalWeeks(timetable))

        val long = Timetable(
            semesterStartMonday = semStart,
            courses = listOf(course("超长课程", 1, 1, 2, listOf(20, 21), "A101", "老师"))
        )
        assertEquals("排到第 21 周时取 21", 21, Engine.totalWeeks(long))

        assertEquals("空课表兜底 18 周", 18, Engine.totalWeeks(Timetable()))

        // timetable 里 5 门课的课程号各不相同，所以是 5 门
        assertEquals("5 门课", 5, Engine.countDistinctCourses(timetable.courses))

        // 真正要测的：同一门课因为多个时间段被拆成多条记录，仍然只算一门。
        // course() 用 "$name-code" 做课程号，所以同名课程号相同。
        val twoSegments = listOf(
            course("高等数学", 1, 1, 2, allWeeks, "仙Ⅱ-304", "张三"),
            course("高等数学", 3, 5, 6, allWeeks, "仙Ⅱ-306", "张三")
        )
        assertEquals("同一门课拆成 2 段仍只算 1 门", 1, Engine.countDistinctCourses(twoSegments))

        // 课程号缺失时退回用课程名去重
        val noNumber = listOf(
            course("A", 1, 1, 2, allWeeks, "R1", "T").copy(classNumber = ""),
            course("A", 3, 5, 6, allWeeks, "R2", "T").copy(classNumber = "")
        )
        assertEquals("没有课程号时按课程名去重", 1, Engine.countDistinctCourses(noNumber))
    }

    // ---------------------------------------------------------------- 11. 空课表

    @Test
    fun `空课表不崩`() {
        val r = Engine.resolve(Timetable(semesterStartMonday = semStart), settings, d(2026, 9, 14, 7, 0))
        assertNull(r.next)
        assertTrue(r.exhausted)
        assertTrue(r.ongoing.isEmpty())
    }

    // ---------------------------------------------------------------- 12. 归一化与格式化

    @Test
    fun `归一化会丢掉无效记录并排序`() {
        val messy = listOf(
            course("B课", 3, 5, 6, listOf(1, 2), "R1", "T"),
            course("", 1, 1, 2, listOf(1), "R2", "T"),           // 没名字 → 丢
            course("C课", 1, 1, 2, emptyList(), "R3", "T"),       // 没周次 → 丢
            course("A课", 1, 1, 2, listOf(1), "R4", "T")
        )
        val out = Engine.normalize(messy)
        assertEquals(2, out.size)
        assertEquals("周二之前的课排前面（周一=1）", "A课", out[0].name)
        assertEquals("B课", out[1].name)
    }

    @Test
    fun `周次文本压缩`() {
        assertEquals("1-3, 10-13 周", Engine.weekText(listOf(1, 2, 3, 10, 11, 12, 13)))
        assertEquals("1-16 周", Engine.weekText((1..16).toList()))
        assertEquals("5 周", Engine.weekText(listOf(5)))
        assertEquals("未指定", Engine.weekText(emptyList()))
    }

    @Test
    fun `倒计时文案`() {
        assertEquals("即将开始", Engine.humanizeRemain(0))
        assertEquals("25 分钟后", Engine.humanizeRemain(25))
        assertEquals("1 小时后", Engine.humanizeRemain(60))
        assertEquals("2 小时 5 分后", Engine.humanizeRemain(125))
        assertEquals("2 天后", Engine.humanizeRemain(60 * 24 * 2))
        assertEquals("已开始", Engine.humanizeRemain(-3))
    }

    // ---------------------------------------------------------------- 13. 锁屏常驻通知
    //
    // Android 没有锁屏小组件，锁屏显示靠常驻通知实现。
    // "锁屏上到底显示什么"的边界（上课中/课前/今天没了/明天才有/假期/没导入）
    // 在真机上同样守不完——你得恰好等到某一节课开始才能验证一次状态翻转。
    // 所以这块也做成了纯函数，在这里固定时间点回归。

    @Test
    fun `锁屏通知_开关与前置条件`() {
        val t = d(2026, 9, 14, 7, 0)
        assertFalse(
            "关掉开关就不该有通知（也不能留孤儿通知）",
            buildLockScreenContent(timetable, settings.copy(lockNotificationEnabled = false), t).visible
        )
        assertFalse(
            "没导入课表时不占着通知栏",
            buildLockScreenContent(Timetable(semesterStartMonday = semStart), settings, t).visible
        )
        assertTrue(buildLockScreenContent(timetable, settings, t).visible)
    }

    @Test
    fun `锁屏通知_正在上课`() {
        val c = buildLockScreenContent(timetable, settings, d(2026, 9, 14, 8, 30))
        assertEquals("正在上课", c.chip)
        assertEquals("高等数学", c.title)
        assertEquals("周一 第1-2节 · 08:00-09:50 · 同时段还有 1 门", c.timeLine)
        assertEquals("仙Ⅱ-304 · 张三", c.location)
        assertEquals("还剩", c.countdownLabel)
        assertEquals("倒计时目标是下课时刻", LocalDateTime.of(2026, 9, 14, 9, 50), c.countdownTarget)
        assertEquals("1 小时 20 分后", c.remainText)
        assertTrue("上课中要标记出来，UI 才好换强调色", c.ongoing)
        assertEquals("今天剩下的课已经上完了", "", c.subLine)
    }

    @Test
    fun `锁屏通知_即将上课`() {
        val c = buildLockScreenContent(timetable, settings, d(2026, 9, 14, 7, 0))
        assertEquals("今天", c.chip)
        assertEquals("高等数学", c.title)
        assertEquals("倒计时目标是上课时刻", LocalDateTime.of(2026, 9, 14, 8, 0), c.countdownTarget)
        assertEquals("1 小时后", c.remainText)
        assertEquals("今天还有 08:00 数据结构", c.subLine)
        assertEquals("看明天", c.toggleLabel)
        assertFalse(c.ongoing)
    }

    @Test
    fun `锁屏通知_点看明天会顶掉今天的课`() {
        val now = d(2026, 9, 14, 7, 0)
        val today = buildLockScreenContent(timetable, settings, now)
        assertEquals("今天", today.chip)
        assertEquals("高等数学", today.title)

        // 周一上午点「看明天」：周二没课，所以一路找到周三的大学物理。
        // 标签给的是"周三"而不是"明天"——课确实在周三，说"明天"是骗人。
        val shifted = buildLockScreenContent(
            timetable, settings.copy(todayCardForceTomorrow = true), now
        )
        assertEquals("周三", shifted.chip)
        assertEquals("大学物理", shifted.title)
        assertEquals("按钮要能切回去", "看今天", shifted.toggleLabel)
    }

    @Test
    fun `锁屏通知_关掉顶上明天就只说上完了`() {
        val now = d(2026, 9, 14, 20, 0)   // 周一晚上，今天的课都上完了

        // 默认：把周三的大学物理顶上来
        val jump = buildLockScreenContent(timetable, settings, now)
        assertEquals("周三", jump.chip)
        assertEquals("大学物理", jump.title)
        assertEquals("今天没有别的课了", jump.subLine)

        // 关掉之后：不透露后面的安排，避免"马上要上课"的错觉
        val noJump = buildLockScreenContent(
            timetable, settings.copy(lockNotificationShowTomorrow = false), now
        )
        assertEquals("空闲", noJump.chip)
        assertEquals("最近的课都上完了", noJump.title)
        assertEquals("第 1 周 · 2026-2027学年 第1学期", noJump.timeLine)
        assertEquals("没有倒计时", "", noJump.countdownLabel)
        assertNull(noJump.countdownTarget)
    }

    @Test
    fun `锁屏通知_未设开学日期与假期`() {
        val noSemester = buildLockScreenContent(
            timetable, settings.copy(semesterStartMonday = ""), d(2026, 9, 14, 7, 0)
        )
        assertEquals("待设置", noSemester.chip)
        assertEquals("请先设置开学第一周的周一", noSemester.title)
        assertEquals("这种情况不该给倒计时", "", noSemester.countdownLabel)

        // 学期在一年之后 → 现在是假期
        val vac = buildLockScreenContent(
            timetable, settings.copy(semesterStartMonday = "2027-09-13"), d(2026, 9, 14, 7, 0)
        )
        assertEquals("假期", vac.chip)
        assertEquals("不在学期内", vac.title)
        assertNull(vac.countdownTarget)
    }

    @Test
    fun `锁屏通知_地点教师缺失时不留多余分隔符`() {
        val c = buildLockScreenContent(timetable, settings, d(2026, 9, 14, 7, 0))
        assertEquals("仙Ⅱ-304 · 张三", c.location)

        val noTeacher = Timetable(
            semesterStartMonday = semStart,
            courses = listOf(course("无教师课", 1, 1, 2, allWeeks, "仙Ⅱ-101", ""))
        )
        assertEquals(
            "只有地点时不该出现孤零零的 ·",
            "仙Ⅱ-101",
            buildLockScreenContent(noTeacher, settings, d(2026, 9, 14, 7, 0)).location
        )

        val noRoom = Timetable(
            semesterStartMonday = semStart,
            courses = listOf(course("无地点课", 1, 1, 2, allWeeks, "", "李老师"))
        )
        assertEquals(
            "只有教师时同样",
            "李老师",
            buildLockScreenContent(noRoom, settings, d(2026, 9, 14, 7, 0)).location
        )
    }

    // ---------------------------------------------------------------- 14. 本机适配
    //
    // 这一节测的是"这台机器该提示用户补哪些授权"。
    // 它的重要性在于：这些授权缺了**不会报错**，只会表现为
    // "提醒没响 / 数据是旧的"，用户完全无从判断。
    // 所以"该显示哪几行、哪行算不合格"必须是确定的。

    /** 华为 Mate 40 Pro（NOH-AN00）的实际环境：鸿蒙 4 = Android 12 / API 31 */
    private fun mate40Pro(
        exactAlarm: Boolean = false,
        battery: Boolean = false,
        notifications: Boolean = true
    ) = DeviceInfo(
        brand = "HUAWEI",
        model = "NOH-AN00",
        androidRelease = "12",
        sdkInt = 31,
        isHuaweiFamily = true,
        exactAlarmGranted = exactAlarm,
        ignoringBatteryOptimizations = battery,
        notificationsEnabled = notifications
    )

    @Test
    fun `适配_华为机型的四项都在`() {
        val items = buildAdaptationPlan(mate40Pro())
        assertEquals("华为系应给出 4 项（含特有的启动管理）", 4, items.size)
        assertEquals(
            "顺序固定：闹钟 → 电池 → 启动管理 → 通知",
            listOf(
                AdaptTarget.EXACT_ALARM, AdaptTarget.BATTERY,
                AdaptTarget.STARTUP, AdaptTarget.NOTIFICATION
            ),
            items.map { it.target }
        )

        // 全新安装、什么都没授权时，前三项都该提示
        assertEquals(false, items.first { it.target == AdaptTarget.EXACT_ALARM }.ok)
        assertEquals(false, items.first { it.target == AdaptTarget.BATTERY }.ok)
        assertEquals(true, items.first { it.target == AdaptTarget.NOTIFICATION }.ok)

        // 「应用启动管理」系统没有公开接口，读不到状态 → 必须是 null 而不是 false，
        // 否则界面会把它画成一个永远消不掉的警告
        val startup = items.first { it.target == AdaptTarget.STARTUP }
        assertNull("读不到的状态要用 null 表达", startup.ok)
        assertFalse("读不到就不该标红", startup.critical)

        assertEquals("还有 2 项必须处理", adaptationSummary(items))
    }

    @Test
    fun `适配_低版本没有精确闹钟这道门`() {
        // Android 11（API 30）之前精确闹钟不需要授权，显示它纯属噪音
        val old = mate40Pro().copy(sdkInt = 30, androidRelease = "11", isHuaweiFamily = false)
        val targets = buildAdaptationPlan(old).map { it.target }
        assertFalse("API 30 上不该出现精确闹钟项", targets.contains(AdaptTarget.EXACT_ALARM))

        // 非华为 ROM 也不该出现「应用启动管理」——那是 EMUI 特有的东西，
        // 在别的系统上给用户一个跳不过去的按钮比不提示更糟
        assertFalse("非华为机型不该出现启动管理项", targets.contains(AdaptTarget.STARTUP))
        assertEquals("应剩 2 项", 2, targets.size)
    }

    @Test
    fun `适配_全部就绪时不报错`() {
        val good = mate40Pro(exactAlarm = true, battery = true, notifications = true)
        val items = buildAdaptationPlan(good)
        assertTrue(items.filter { it.target != AdaptTarget.STARTUP }.all { it.ok == true })
        assertEquals("有 1 项需手动确认", adaptationSummary(items))
    }

    @Test
    fun `适配_华为上电池优化算关键项`() {
        // 同一件事在华为和其他 ROM 上严重程度不同：
        // 原生 Android 只是延迟后台任务，EMUI 会直接把应用冻掉
        val huawei = buildAdaptationPlan(mate40Pro()).first { it.target == AdaptTarget.BATTERY }
        assertTrue("华为上不算通过会真的导致功能失效", huawei.critical)

        val stock = buildAdaptationPlan(
            mate40Pro().copy(isHuaweiFamily = false, brand = "GOOGLE", model = "Pixel")
        ).first { it.target == AdaptTarget.BATTERY }
        assertFalse("原生 Android 上只是提示，不该标红", stock.critical)

        // 两者文案也必须不同，否则等于没做机型适配
        assertTrue(huawei.desc != stock.desc)
    }

    @Test
    fun `适配_设备信息行`() {
        // Build.BRAND 给的是英文大写，中文界面上要换成中文名
        assertEquals("华为 NOH-AN00 · Android 12（API 31）", mate40Pro().displayLine())

        assertEquals(
            "厂商缺失时要有兜底文案",
            "未知厂商 未知机型 · Android 12（API 31）",
            mate40Pro().copy(brand = "", model = "").displayLine()
        )

        // 认不出来的厂商原样显示——瞎映射比显示英文更糟
        assertEquals(
            "未知品牌原样保留",
            "WALTON Primo · Android 12（API 31）",
            mate40Pro().copy(brand = "WALTON", model = "Primo").displayLine()
        )
        assertEquals("荣耀独立后的品牌名也要认", "荣耀 ANY-AN00", brandDisplayName("HIHONOR") + " ANY-AN00")
        assertEquals("小写也能匹配", "小米", brandDisplayName("xiaomi"))
    }

    // ---------------------------------------------------------------- 15. 周次反推（现在是第几周）

    @Test
    fun `周次反推_开学的周一`() {
        // 2026-09-18 是周五
        assertEquals("周五归到本周周一", LocalDate.of(2026, 9, 14), Engine.weekMonday(LocalDate.of(2026, 9, 18)))
        assertEquals("周一本身不变", LocalDate.of(2026, 9, 14), Engine.weekMonday(LocalDate.of(2026, 9, 14)))

        val ref = LocalDate.of(2026, 9, 18)
        assertEquals("第 1 周 → 本周周一", LocalDate.of(2026, 9, 14), Engine.semesterStartForWeek(1, ref))
        assertEquals("第 3 周 → 往前推 2 周", LocalDate.of(2026, 8, 31), Engine.semesterStartForWeek(3, ref))
        assertEquals("第 0 周当第 1 周处理", LocalDate.of(2026, 9, 14), Engine.semesterStartForWeek(0, ref))

        // 反推回去还能对得上：weekIndexOf(反推结果) == 设的周数
        val n = 5
        val start = Engine.semesterStartForWeek(n, ref)
        assertEquals("反推结果能回读", n, Engine.weekIndexOf(Engine.toDateKey(start), ref))
    }

    // ---------------------------------------------------------------- 16. 手动录课：周次/节次换算

    @Test
    fun `周次奇偶展开`() {
        assertEquals("全周", (1..16).toList(), computeWeeks(1, 16, "all"))
        assertEquals("单周取奇数", listOf(1, 3, 5, 7, 9, 11, 13, 15), computeWeeks(1, 16, "odd"))
        assertEquals("双周取偶数", listOf(2, 4, 6, 8, 10, 12, 14, 16), computeWeeks(1, 16, "even"))
        // 从第 2 周开始的单周：起点本身就是偶数，所以是 3,5,7...（奇偶按周次本身判断）
        assertEquals("起始周影响奇偶", listOf(3, 5, 7, 9, 11, 13, 15), computeWeeks(2, 15, "odd"))
        // 结束周小于起始周 → 收敛成只上起始那一周
        assertEquals("结束周小于起始周", listOf(10), computeWeeks(10, 3, "all"))
        // 非法输入收敛到合法范围
        assertEquals("越界收敛", listOf(1), computeWeeks(0, -5, "all"))
    }

    @Test
    fun `节次归一化`() {
        assertEquals(3 to 4, normalizeSlots(3, 4))
        assertEquals("结束小于起始时等于起始", 4 to 4, normalizeSlots(4, 3))
        assertEquals("低于下限收敛到 1", 1 to 2, normalizeSlots(0, 2))
        assertEquals("高于上限收敛到 24", 20 to 24, normalizeSlots(20, 30))
    }

    @Test
    fun `手动课程构建`() {
        val c = buildManualCourse(
            id = "manual-1", name = " 物理实验 ", weekday = 3,
            startSlot = 5, endSlot = 6, weekStart = 1, weekEnd = 16, parity = "odd",
            classroom = " 实验室 ", teacher = "王老师", testTime = "  "
        )
        assertEquals("名字去掉首尾空格", "物理实验", c.name)
        assertEquals("地点去掉首尾空格", "实验室", c.classroom)
        assertEquals("星期", 3, c.weekTime)
        assertEquals("节次", 5, c.startSlot)
        assertEquals(6, c.endSlot)
        assertEquals("单周展开", listOf(1, 3, 5, 7, 9, 11, 13, 15), c.weeks)
        assertEquals("手动标记 importType=2", 2, c.importType)
        assertEquals("id 存进 classNumber 用于删除", "manual-1", c.classNumber)
        assertNull("空白考试时间归一成 null", c.testTime)

        val withExam = buildManualCourse(
            "m2", "线性代数", 1, 1, 2, 1, 8, "all", "", "", "2026-11-01 09:00"
        )
        assertEquals("非空考试时间保留", "2026-11-01 09:00", withExam.testTime)
        assertEquals("全周 1-8", (1..8).toList(), withExam.weeks)
    }

    @Test
    fun `星期校验`() {
        assertEquals(1, validWeekday(1))
        assertEquals(7, validWeekday(7))
        assertNull("0 不是合法星期", validWeekday(0))
        assertNull("8 不是合法星期", validWeekday(8))
    }
}
