package com.nju.classmate.web

import android.content.Context
import android.os.Build
import android.webkit.JavascriptInterface
import androidx.core.app.NotificationManagerCompat
import com.nju.classmate.MainActivity
import com.nju.classmate.core.AdaptTarget
import com.nju.classmate.core.ClassOccurrence
import com.nju.classmate.core.ClassStatus
import com.nju.classmate.core.Course
import com.nju.classmate.core.Engine
import com.nju.classmate.core.ExamEntry
import com.nju.classmate.core.GridBlock
import com.nju.classmate.core.NextClassResult
import com.nju.classmate.core.Settings
import com.nju.classmate.core.Store
import com.nju.classmate.core.Timetable
import com.nju.classmate.core.adaptationSummary
import com.nju.classmate.core.buildAdaptationPlan
import com.nju.classmate.core.buildManualCourse
import com.nju.classmate.core.validWeekday
import com.nju.classmate.device.DeviceCompat
import com.nju.classmate.widget.WidgetUpdater
import com.nju.classmate.work.RefreshScheduler
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDateTime

/**
 * 原生 ↔ 网页 的桥。
 *
 * 设计取舍：只暴露**一个** call(method, args) 入口，而不是给每个功能写一个
 * @JavascriptInterface 方法。原因：
 *   1. 桥方法名一旦发布就不能改（网页里到处引用），单个入口把这类耦合压到最小；
 *   2. 返回值统一是 JSON 字符串，加字段不用动两侧签名；
 *   3. 错误可以统一兜在一个 try/catch 里，不会因为某个方法抛异常把 WebView 搞崩。
 *
 * 安全提醒：addJavascriptInterface 会把桥暴露给该 WebView 加载的**任何**页面。
 * 所以 MainActivity 只加载本地 assets，并且在 shouldOverrideUrlLoading 里
 * 拦住一切外链（见 MainActivity）。这两条必须同时成立才安全。
 */
class WebBridge(private val activity: MainActivity) {

    @JavascriptInterface
    fun call(method: String, args: String): String {
        return try {
            when (method) {
                "state" -> stateJson()
                "week" -> weekJson(args.toIntOrNull() ?: currentWeek())
                "exams" -> examsJson()
                "settings" -> Store.settingsToJson(Store.loadSettings(activity)).toString()
                "saveSettings" -> saveSettings(args)
                "saveTimetable" -> saveTimetable(args)
                "clearTimetable" -> clearTimetable()
                "openImport" -> openImport()
                "refreshWidgets" -> refreshWidgets()
                "addEvent" -> addEvent(args)
                "removeEvent" -> removeEvent(args)
                "events" -> eventsJson()
                "exportIcs" -> exportIcs()
                "lockNotifyInfo" -> lockNotifyInfo()
                "pushLockNotify" -> pushLockNotify()
                "deviceInfo" -> deviceInfoJson()
                "openDeviceSetting" -> openDeviceSetting(args)
                "setCurrentWeek" -> setCurrentWeek(args)
                "addCourse" -> addCourse(args)
                "removeCourse" -> removeCourse(args)
                else -> errorJson("未知方法: $method")
            }
        } catch (e: Exception) {
            errorJson(e.message ?: e.toString())
        }
    }

    // ---------------------------------------------------------------- 状态

    private fun currentWeek(): Int =
        Engine.weekIndexOf(
            Store.loadSettings(activity).semesterStartMonday,
            java.time.LocalDate.now()
        )

    /** 首页一次性要的全部数据，避免来回多次跨语言调用 */
    private fun stateJson(): String {
        val ctx = activity
        val timetable: Timetable = Store.loadTimetable(ctx)
        val settings: Settings = Store.loadSettings(ctx)
        val now = LocalDateTime.now()
        val result: NextClassResult = Engine.resolve(timetable, settings, now)
        val today = Engine.daySchedule(timetable, settings, now.toLocalDate(), now)

        val o = JSONObject()
        o.put("hasTimetable", timetable.courses.isNotEmpty())
        o.put("timetableName", timetable.name)
        o.put("semesterStartMonday", settings.semesterStartMonday)
        o.put("weekIndex", result.weekIndex)
        o.put("totalWeeks", Engine.totalWeeks(timetable))
        o.put("distinctCourses", Engine.countDistinctCourses(timetable.courses))
        o.put("segmentCount", timetable.courses.size)
        o.put("lastSyncAt", Store.lastSyncAt(ctx))
        o.put("now", now.toString())
        o.put("next", result.next?.let { occurrenceJson(it) } ?: JSONObject.NULL)
        o.put("ongoing", occurrencesJson(result.ongoing))
        o.put("restOfToday", occurrencesJson(result.restOfToday))
        o.put("exhausted", result.exhausted)
        o.put("todayWeekIndex", today.weekIndex)
        o.put("today", occurrencesJson(today.occurrences))
        o.put("freeCourses", coursesJson(Engine.freeTimeCourses(timetable)))
        o.put("manualCourses", manualCoursesJson(timetable))
        o.put("settings", Store.settingsToJson(settings))
        o.put("exams", examsJsonArray(Engine.upcomingExams(timetable, now, 8)))
        return o.toString()
    }

    private fun weekJson(weekIndex: Int): String {
        val timetable = Store.loadTimetable(activity)
        val blocks: List<GridBlock> = Engine.buildWeekBlocks(timetable, weekIndex)
        val arr = JSONArray()
        for (b in blocks) {
            arr.put(
                JSONObject()
                    .put("name", b.course.name)
                    .put("classroom", b.course.classroom)
                    .put("teacher", b.course.teacher)
                    .put("classNumber", b.course.classNumber)
                    .put("weekday", b.weekday)
                    .put("startSlot", b.startSlot)
                    .put("endSlot", b.endSlot)
                    .put("span", b.span)
                    .put("conflict", b.conflict)
                    .put("weeks", Engine.weekText(b.course.weeks))
                    .put("testTime", b.course.testTime ?: JSONObject.NULL)
                    .put("info", b.course.info ?: JSONObject.NULL)
            )
        }
        return JSONObject()
            .put("weekIndex", weekIndex)
            .put("totalWeeks", Engine.totalWeeks(timetable))
            .put("slots", slotsJson())
            .put("blocks", arr)
            .put("freeCourses", coursesJson(Engine.freeTimeCourses(timetable)))
            .toString()
    }

    private fun examsJson(): String = examsJsonArray(
        Engine.upcomingExams(Store.loadTimetable(activity), LocalDateTime.now(), 20)
    ).toString()

    private fun examsJsonArray(list: List<ExamEntry>): JSONArray {
        val arr = JSONArray()
        for (e in list) {
            arr.put(
                JSONObject()
                    .put("courseName", e.courseName)
                    .put("raw", e.raw)
                    .put("location", e.location)
                    .put("daysLeft", e.daysLeft)
                    .put("at", e.at?.toString() ?: JSONObject.NULL)
            )
        }
        return arr
    }

    private fun eventsJson(): String {
        val arr = JSONArray()
        Store.loadEvents(activity).forEach { e ->
            arr.put(
                JSONObject()
                    .put("id", e.id).put("title", e.title).put("dueAt", e.dueAt)
                    .put("pinned", e.pinned).put("done", e.done).put("note", e.note)
            )
        }
        return arr.toString()
    }

    // ---------------------------------------------------------------- 写操作

    private fun saveSettings(args: String): String {
        val o = JSONObject(args)
        val current = Store.loadSettings(activity)
        val next = Store.parseSettings(o).copy(
            // parseSettings 读不到的字段保留原值，避免网页只传部分字段时被重置
            semesterStartMonday = if (o.has("semester_start_monday")) o.optString("semester_start_monday") else current.semesterStartMonday
        )
        Store.saveSettings(activity, next)
        afterDataChanged()
        return okJson()
    }

    /**
     * 网页侧导入成功后把课表 JSON 交回原生落盘。
     * 数据本来就在网页里，没必要再跨一次进程。
     */
    private fun saveTimetable(args: String): String {
        val o = JSONObject(args)
        val timetable = Store.parseTimetable(o)
        Store.saveTimetable(activity, timetable)
        afterDataChanged()
        return JSONObject()
            .put("ok", true)
            .put("courses", timetable.courses.size)
            .toString()
    }

    private fun clearTimetable(): String {
        Store.clearTimetable(activity)
        afterDataChanged()
        return okJson()
    }

    private fun addEvent(args: String): String {
        val o = JSONObject(args)
        val e = com.nju.classmate.core.UserEvent(
            id = System.currentTimeMillis().toString(),
            title = o.optString("title"),
            dueAt = o.optLong("dueAt"),
            pinned = o.optBoolean("pinned"),
            note = o.optString("note")
        )
        Store.saveEvents(activity, Store.loadEvents(activity) + e)
        WidgetUpdater.updateAll(activity)
        return okJson()
    }

    private fun removeEvent(args: String): String {
        val id = JSONObject(args).optString("id")
        Store.saveEvents(activity, Store.loadEvents(activity).filterNot { it.id == id })
        WidgetUpdater.updateAll(activity)
        return okJson()
    }

    private fun openImport(): String {
        activity.runOnUiThread { activity.startImport() }
        return okJson()
    }

    private fun refreshWidgets(): String {
        WidgetUpdater.updateAll(activity)
        return okJson()
    }

    /** 导出 .ics：写进外部存储的 Downloads，再用系统分享发出去 */
    private fun exportIcs(): String {
        val path = com.nju.classmate.export.IcsExporter.exportToDownloads(activity)
        return if (path != null) {
            JSONObject().put("ok", true).put("path", path).toString()
        } else {
            errorJson("导出失败：没有存储权限或写入出错")
        }
    }

    /** 数据变了：刷小组件 + 刷锁屏通知 + 重排提醒 + 按开关重排后台兜底任务 */
    private fun afterDataChanged() {
        WidgetUpdater.updateAll(activity)
        com.nju.classmate.reminder.ReminderScheduler.rescheduleAll(activity)
        RefreshScheduler.sync(activity)
    }

    // ---------------------------------------------------------------- 学期（第几周）

    /**
     * 用户说"现在是第 N 周"，反推开学的周一并保存。
     * 数学在 Engine.semesterStartForWeek 里（纯函数，可单测）。
     */
    private fun setCurrentWeek(args: String): String {
        val week = JSONObject(args).optInt("week", 0).coerceIn(1, 30)
        val start = Engine.semesterStartForWeek(week, java.time.LocalDate.now())
        val key = Engine.toDateKey(start)
        val s = Store.loadSettings(activity)
        Store.saveSettings(activity, s.copy(semesterStartMonday = key))
        afterDataChanged()
        return JSONObject()
            .put("ok", true)
            .put("semester_start_monday", key)
            .put("week", week)
            .toString()
    }

    // ---------------------------------------------------------------- 手动录入课程

    private fun addCourse(args: String): String {
        val o = JSONObject(args)
        val name = o.optString("name").trim()
        if (name.isEmpty()) return errorJson("课程名不能为空")

        val weekday = o.optInt("weekday", 0)
        if (validWeekday(weekday) == null) return errorJson("请选择星期几")

        val startSlot = o.optInt("startSlot", 0)
        if (startSlot < 1) return errorJson("请填写起始节次")

        val course = buildManualCourse(
            id = "manual-" + System.currentTimeMillis(),
            name = name,
            weekday = weekday,
            startSlot = startSlot,
            endSlot = o.optInt("endSlot", startSlot),
            weekStart = o.optInt("weekStart", 1),
            weekEnd = o.optInt("weekEnd", 18),
            parity = o.optString("parity", "all"),
            classroom = o.optString("classroom"),
            teacher = o.optString("teacher"),
            testTime = o.optString("testTime")
        )
        if (course.weeks.isEmpty()) return errorJson("周次设置有误")

        val timetable = Store.loadTimetable(activity)
        Store.saveTimetable(activity, timetable.copy(courses = Engine.normalize(timetable.courses + course)))
        afterDataChanged()
        return JSONObject().put("ok", true).put("courses", timetable.courses.size + 1).toString()
    }

    private fun removeCourse(args: String): String {
        val id = JSONObject(args).optString("classNumber")
        if (id.isEmpty()) return errorJson("缺少课程标识")
        val timetable = Store.loadTimetable(activity)
        Store.saveTimetable(activity, timetable.copy(courses = timetable.courses.filterNot { it.classNumber == id }))
        afterDataChanged()
        return okJson()
    }

    /** 只序列化"手动录入"的课程（importType == 2），供列表/删除用 */
    private fun manualCoursesJson(timetable: Timetable): JSONArray {
        val arr = JSONArray()
        timetable.courses.filter { it.importType == 2 }.forEach { c ->
            arr.put(
                JSONObject()
                    .put("classNumber", c.classNumber)
                    .put("name", c.name)
                    .put("classroom", c.classroom)
                    .put("teacher", c.teacher)
                    .put("weekday", c.weekTime)
                    .put("startSlot", c.startSlot)
                    .put("endSlot", c.endSlot)
                    .put("weeks", Engine.weekText(c.weeks))
            )
        }
        return arr
    }

    // ---------------------------------------------------------------- 锁屏通知

    /**
     * 锁屏通知的状态。
     *
     * 为什么要在网页里显示这些：常驻通知看不见的时候，原因通常不在 App 里，
     * 而是（a）通知权限没给，或（b）系统把锁屏通知关掉了。
     * 这两种情况用户自己完全看不出来，只能靠这里明说，
     * 否则用户只会觉得"这功能是坏的"。
     */
    private fun lockNotifyInfo(): String {
        val enabled = NotificationManagerCompat.from(activity).areNotificationsEnabled()
        val channel = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val m = activity.getSystemService(android.app.NotificationManager::class.java)
            m?.getNotificationChannel(com.nju.classmate.notify.NextClassNotifier.CHANNEL_ID)
                ?.importance ?: -1
        } else {
            0
        }
        return JSONObject()
            .put("permissionGranted", enabled)
            .put("channelImportance", channel)
            .put(
                "channelBlocked",
                channel == android.app.NotificationManager.IMPORTANCE_NONE
            )
            .toString()
    }

    /** 立刻重发一次锁屏通知（设置页的「预览」按钮用） */
    private fun pushLockNotify(): String {
        com.nju.classmate.notify.NextClassNotifier.update(activity)
        return okJson()
    }

    // ---------------------------------------------------------------- 本机适配

    /**
     * 这台手机上还需要补哪些系统授权。
     *
     * "哪几项该显示、哪项算不合格"的规则在 core/DeviceAdapt.kt（纯函数，可单测），
     * 这里只负责把系统状态读出来再拼成 JSON。
     */
    private fun deviceInfoJson(): String {
        val info = DeviceCompat.readDeviceInfo(activity)
        val items = buildAdaptationPlan(info)
        val arr = JSONArray()
        for (item in items) {
            arr.put(
                JSONObject()
                    .put("target", item.target.name)
                    .put("title", item.title)
                    .put("desc", item.desc)
                    // null 表示"系统读不到状态"，前端要画成问号而不是叉
                    .put("ok", item.ok ?: JSONObject.NULL)
                    .put("critical", item.critical)
            )
        }
        return JSONObject()
            .put("brand", info.brand)
            .put("model", info.model)
            .put("androidRelease", info.androidRelease)
            .put("sdkInt", info.sdkInt)
            .put("huaweiFamily", info.isHuaweiFamily)
            .put("display", info.displayLine())
            .put("summary", adaptationSummary(items))
            .put("items", arr)
            .toString()
    }

    /** 跳到某一项对应的系统设置页；跳不过去就如实报错，让界面提示用户手动找 */
    private fun openDeviceSetting(args: String): String {
        val name = JSONObject(args).optString("target")
        val target = try {
            AdaptTarget.valueOf(name)
        } catch (e: Exception) {
            return errorJson("未知的适配项: $name")
        }
        return if (DeviceCompat.openTarget(activity, target)) {
            okJson()
        } else {
            errorJson("系统里没找到这个设置页（该 ROM 可能改了入口）")
        }
    }

    // ---------------------------------------------------------------- JSON 小工具

    private fun occurrencesJson(list: List<ClassOccurrence>): JSONArray {
        val arr = JSONArray()
        list.forEach { arr.put(occurrenceJson(it)) }
        return arr
    }

    private fun occurrenceJson(o: ClassOccurrence): JSONObject = JSONObject()
        .put("name", o.course.name)
        .put("classroom", o.course.classroom)
        .put("teacher", o.course.teacher)
        .put("classNumber", o.course.classNumber)
        .put("dateKey", Engine.toDateKey(o.date))
        .put("weekday", o.date.dayOfWeek.value)
        .put("weekIndex", o.weekIndex)
        .put("startSlot", o.startSlot)
        .put("endSlot", o.endSlot)
        .put("startClock", o.startClock)
        .put("endClock", o.endClock)
        .put("minutesFromNow", o.minutesFromNow)
        .put("remainText", Engine.humanizeRemain(o.minutesFromNow))
        .put(
            "status",
            when (o.status) {
                ClassStatus.ONGOING -> "ongoing"
                ClassStatus.FINISHED -> "finished"
                ClassStatus.UPCOMING -> "upcoming"
            }
        )

    private fun coursesJson(list: List<Course>): JSONArray {
        val arr = JSONArray()
        list.forEach {
            arr.put(
                JSONObject()
                    .put("name", it.name).put("classroom", it.classroom)
                    .put("teacher", it.teacher).put("weeks", Engine.weekText(it.weeks))
            )
        }
        return arr
    }

    private fun slotsJson(): JSONArray {
        val arr = JSONArray()
        Store.loadSettings(activity).timeSlots.forEach {
            arr.put(JSONObject().put("index", it.index).put("start", it.start).put("end", it.end))
        }
        return arr
    }

    private fun okJson(): String = JSONObject().put("ok", true).toString()

    private fun errorJson(msg: String): String =
        JSONObject().put("ok", false).put("error", msg).toString()
}
