package com.nju.classmate.core

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * 本地持久化。
 *
 * 用 SharedPreferences 存 JSON 字符串，而不是 Room/SQLite：
 * 数据量极小（一份课表最多几百条），直接存字符串最省事、读写也够快，
 * 而且不需要引入任何数据库依赖。
 *
 * 序列化用 org.json（Android 自带，零依赖）。
 */
object Store {

    private const val PREFS = "nju_classmate"
    private const val KEY_TIMETABLE = "timetable_json"
    private const val KEY_SETTINGS = "settings_json"
    private const val KEY_EVENTS = "events_json"
    private const val KEY_LAST_SYNC = "last_sync_at"

    private fun prefs(ctx: Context) = ctx.applicationContext
        .getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    // ---------------------------------------------------------------- 课表

    fun loadTimetable(ctx: Context): Timetable {
        val raw = prefs(ctx).getString(KEY_TIMETABLE, null) ?: return Timetable()
        return try {
            parseTimetable(JSONObject(raw))
        } catch (e: Exception) {
            Timetable()
        }
    }

    fun saveTimetable(ctx: Context, t: Timetable) {
        prefs(ctx).edit()
            .putString(KEY_TIMETABLE, timetableToJson(t).toString())
            .putLong(KEY_LAST_SYNC, System.currentTimeMillis())
            .apply()
    }

    fun hasTimetable(ctx: Context): Boolean =
        !prefs(ctx).getString(KEY_TIMETABLE, null).isNullOrBlank()

    fun clearTimetable(ctx: Context) {
        prefs(ctx).edit().remove(KEY_TIMETABLE).apply()
    }

    fun lastSyncAt(ctx: Context): Long = prefs(ctx).getLong(KEY_LAST_SYNC, 0L)

    // ---------------------------------------------------------------- 设置

    fun loadSettings(ctx: Context): Settings {
        val raw = prefs(ctx).getString(KEY_SETTINGS, null) ?: return Settings()
        return try {
            parseSettings(JSONObject(raw))
        } catch (e: Exception) {
            Settings()
        }
    }

    fun saveSettings(ctx: Context, s: Settings) {
        prefs(ctx).edit().putString(KEY_SETTINGS, settingsToJson(s).toString()).apply()
    }

    // ---------------------------------------------------------------- 事件

    fun loadEvents(ctx: Context): List<UserEvent> {
        val raw = prefs(ctx).getString(KEY_EVENTS, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).mapNotNull { i ->
                val o = arr.optJSONObject(i) ?: return@mapNotNull null
                UserEvent(
                    id = o.optString("id"),
                    title = o.optString("title"),
                    dueAt = o.optLong("dueAt"),
                    pinned = o.optBoolean("pinned"),
                    done = o.optBoolean("done"),
                    note = o.optString("note")
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun saveEvents(ctx: Context, list: List<UserEvent>) {
        val arr = JSONArray()
        list.forEach { e ->
            arr.put(
                JSONObject()
                    .put("id", e.id)
                    .put("title", e.title)
                    .put("dueAt", e.dueAt)
                    .put("pinned", e.pinned)
                    .put("done", e.done)
                    .put("note", e.note)
            )
        }
        prefs(ctx).edit().putString(KEY_EVENTS, arr.toString()).apply()
    }

    // ---------------------------------------------------------------- JSON 编解码

    fun timetableToJson(t: Timetable): JSONObject {
        val courses = JSONArray()
        t.courses.forEach { c ->
            courses.put(
                JSONObject()
                    .put("name", c.name)
                    .put("classroom", c.classroom)
                    .put("class_number", c.classNumber)
                    .put("teacher", c.teacher)
                    .put("test_time", c.testTime ?: JSONObject.NULL)
                    .put("test_location", c.testLocation ?: JSONObject.NULL)
                    .put("info", c.info ?: JSONObject.NULL)
                    .put("weeks", JSONArray(c.weeks))
                    .put("week_time", c.weekTime)
                    .put("start_slot", c.startSlot)
                    .put("end_slot", c.endSlot)
                    .put("import_type", c.importType)
            )
        }
        return JSONObject()
            .put("name", t.name)
            .put("semester_start_monday", t.semesterStartMonday)
            .put("courses", courses)
    }

    fun parseTimetable(o: JSONObject): Timetable {
        val arr = o.optJSONArray("courses")
        val list = ArrayList<Course>()
        if (arr != null) {
            for (i in 0 until arr.length()) {
                val c = arr.optJSONObject(i) ?: continue
                val weeksArr = c.optJSONArray("weeks")
                val weeks = ArrayList<Int>()
                if (weeksArr != null) {
                    for (j in 0 until weeksArr.length()) weeks.add(weeksArr.optInt(j))
                }
                list.add(
                    Course(
                        name = c.optString("name"),
                        classroom = c.optString("classroom"),
                        classNumber = c.optString("class_number"),
                        teacher = c.optString("teacher"),
                        testTime = c.optStringOrNull("test_time"),
                        testLocation = c.optStringOrNull("test_location"),
                        info = c.optStringOrNull("info"),
                        weeks = weeks,
                        weekTime = c.optInt("week_time"),
                        startSlot = c.optInt("start_slot"),
                        endSlot = c.optInt("end_slot"),
                        importType = c.optInt("import_type", 1)
                    )
                )
            }
        }
        return Timetable(
            name = o.optString("name"),
            semesterStartMonday = o.optString("semester_start_monday"),
            courses = Engine.normalize(list)
        )
    }

    fun settingsToJson(s: Settings): JSONObject {
        val slots = JSONArray()
        s.timeSlots.forEach {
            slots.put(JSONObject().put("index", it.index).put("start", it.start).put("end", it.end))
        }
        return JSONObject()
            .put("semester_start_monday", s.semesterStartMonday)
            .put("time_slots", slots)
            .put("remind_enabled", s.remindEnabled)
            .put("remind_before_minutes", s.remindBeforeMinutes)
            .put("show_weekend", s.showWeekend)
            .put("today_card_show_tomorrow", s.todayCardShowTomorrow)
            .put("today_card_force_tomorrow", s.todayCardForceTomorrow)
            .put("auto_refresh_enabled", s.autoRefreshEnabled)
    }

    fun parseSettings(o: JSONObject): Settings {
        val default = Settings()
        val slotsArr = o.optJSONArray("time_slots")
        val slots = ArrayList<TimeSlot>()
        if (slotsArr != null) {
            for (i in 0 until slotsArr.length()) {
                val s = slotsArr.optJSONObject(i) ?: continue
                slots.add(TimeSlot(s.optInt("index"), s.optString("start"), s.optString("end")))
            }
        }
        return Settings(
            semesterStartMonday = o.optString("semester_start_monday", default.semesterStartMonday),
            timeSlots = if (slots.isEmpty()) Defaults.TIME_SLOTS else slots,
            remindEnabled = o.optBoolean("remind_enabled", default.remindEnabled),
            remindBeforeMinutes = o.optInt("remind_before_minutes", default.remindBeforeMinutes),
            showWeekend = o.optBoolean("show_weekend", default.showWeekend),
            todayCardShowTomorrow = o.optBoolean("today_card_show_tomorrow", default.todayCardShowTomorrow),
            todayCardForceTomorrow = o.optBoolean("today_card_force_tomorrow", default.todayCardForceTomorrow),
            autoRefreshEnabled = o.optBoolean("auto_refresh_enabled", default.autoRefreshEnabled),
            lockNotificationEnabled = o.optBoolean("lock_notification_enabled", default.lockNotificationEnabled),
            lockNotificationShowTomorrow = o.optBoolean(
                "lock_notification_show_tomorrow", default.lockNotificationShowTomorrow
            )
        )
    }

    /** 把 JSON 里的 null 和缺失统一成 null，而不是字符串 "null" */
    private fun JSONObject.optStringOrNull(key: String): String? {
        if (isNull(key)) return null
        val v = optString(key, "")
        return v.ifBlank { null }
    }
}

/**
 * 把抓取脚本回传的原始 JSON 转成内部模型。
 *
 * 关键换算：脚本里的 time_count 是「末节 − 首节」（nju.app 的约定），
 * 这里还原成「末节（含）」。
 */
object ScriptResultParser {

    class ParseException(message: String) : Exception(message)

    fun parse(text: String): Timetable {
        val root = try {
            JSONObject(text)
        } catch (e: Exception) {
            throw ParseException("回传内容不是合法 JSON")
        }

        // 兼容两种外壳：本工程的 {ok, data:{name, courses}} 和 nju.app 的 {name, courses}
        val payload: JSONObject = if (root.has("ok") || root.has("data")) {
            if (!root.optBoolean("ok", false)) {
                throw ParseException(root.optString("message", "抓取失败（阶段：${root.optString("stage")}）"))
            }
            root.optJSONObject("data") ?: throw ParseException("回传数据里没有 data 字段")
        } else {
            root
        }

        val name = payload.optString("name", "当前学期")
        val arr = payload.optJSONArray("courses") ?: throw ParseException("回传数据里没有 courses 字段")

        val list = ArrayList<Course>()
        for (i in 0 until arr.length()) {
            val c = arr.optJSONObject(i) ?: continue
            val weeksArr = c.optJSONArray("weeks")
            val weeks = ArrayList<Int>()
            if (weeksArr != null) for (j in 0 until weeksArr.length()) weeks.add(weeksArr.optInt(j))

            val startSlot = c.optInt("start_time", 0)
            val timeCount = c.optInt("time_count", 0)

            list.add(
                Course(
                    name = c.optString("name"),
                    classroom = c.optString("classroom"),
                    classNumber = c.optString("class_number"),
                    teacher = c.optString("teacher"),
                    testTime = if (c.isNull("test_time")) null else c.optString("test_time").ifBlank { null },
                    testLocation = if (c.isNull("test_location")) null else c.optString("test_location").ifBlank { null },
                    info = if (c.isNull("info")) null else c.optString("info").ifBlank { null },
                    weeks = weeks,
                    weekTime = c.optInt("week_time", 0),
                    startSlot = startSlot,
                    endSlot = if (timeCount > 0) startSlot + timeCount else startSlot
                )
            )
        }

        val normalized = Engine.normalize(list)
        if (normalized.isEmpty()) throw ParseException("解析出的课表是空的")
        return Timetable(name = name, semesterStartMonday = "", courses = normalized)
    }
}
