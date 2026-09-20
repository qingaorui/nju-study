package com.nju.classmate.export

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import com.nju.classmate.core.Course
import com.nju.classmate.core.Engine
import com.nju.classmate.core.Settings
import com.nju.classmate.core.Store
import com.nju.classmate.core.Timetable
import java.io.File
import java.io.OutputStream
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

/**
 * 导出为 iCalendar（.ics）。
 *
 * 为什么要做这个：课表 App 只能解决"看"，解决不了"和别的日程放一起"。
 * 导成 .ics 之后，上课时间会进系统日历，
 * 于是手表震动、平板日历、电脑日历全都能收到——等于把课表接进了整个生态。
 *
 * 每周重复的上课安排用 RRULE 表达，而不是展开成几十个事件，
 * 这样日历里干净，也不会把系统日历撑爆。
 */
object IcsExporter {

    private const val TAG = "NJUExport"

    private val STAMP = DateTimeFormatter.ofPattern("yyyyMMdd'T'HHmmss'Z'")
    private val DATE = DateTimeFormatter.ofPattern("yyyyMMdd")

    /**
     * 导出到系统「下载」目录。
     * @return 成功返回文件路径/URI 字符串，失败返回 null
     */
    fun exportToDownloads(ctx: Context): String? {
        val settings = Store.loadSettings(ctx)
        val timetable = Store.loadTimetable(ctx)
        if (timetable.courses.isEmpty()) return null

        val content = build(timetable, settings)
        val name = "nju-classmate-${LocalDate.now().format(DATE)}.ics"

        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                writeViaMediaStore(ctx, name, content)
            } else {
                writeToPublicDir(name, content)
            }
        } catch (e: Exception) {
            Log.e(TAG, "导出失败: ${e.message}")
            null
        }
    }

    private fun writeViaMediaStore(ctx: Context, name: String, content: String): String? {
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, "text/calendar")
            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
        }
        val uri: Uri = ctx.contentResolver.insert(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI, values
        ) ?: return null
        ctx.contentResolver.openOutputStream(uri)?.use { out: OutputStream ->
            out.write(content.toByteArray(Charsets.UTF_8))
        }
        Log.i(TAG, "已导出到 $uri")
        return uri.toString()
    }

    @Suppress("DEPRECATION")
    private fun writeToPublicDir(name: String, content: String): String? {
        val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!dir.exists() && !dir.mkdirs()) return null
        val file = File(dir, name)
        file.writeText(content, Charsets.UTF_8)
        return file.absolutePath
    }

    // ---------------------------------------------------------------- ICS 生成

    fun build(timetable: Timetable, settings: Settings): String {
        val lines = ArrayList<String>()
        val stamp = LocalDateTime.now(ZoneOffset.UTC).format(STAMP)

        lines += "BEGIN:VCALENDAR"
        lines += "VERSION:2.0"
        lines += "PRODID:-//NJU ClassMate//Timetable//CN"
        lines += "CALSCALE:GREGORIAN"
        lines += "METHOD:PUBLISH"
        lines += "X-WR-CALNAME:${escape(timetable.name.ifBlank { "南哪儿课表" })}"

        val startMonday: LocalDate? = Engine.parseDate(settings.semesterStartMonday)
        var seq = 0

        for (c in timetable.courses) {
            if (c.weekTime !in 1..7 || c.startSlot <= 0) continue   // 自由时间的课排不进日历
            val startClock = slotStart(settings, c.startSlot) ?: continue
            val endClock = slotEnd(settings, c.endSlot) ?: continue

            seq++
            lines += "BEGIN:VEVENT"
            lines += "UID:nju-classmate-$seq-${LocalDate.now().format(DATE)}@nju.local"
            lines += "DTSTAMP:$stamp"

            // 第一周的上课日 = 学期第一周周一 + (weekday-1) + (首个上课周-1)*7
            if (startMonday != null && c.weeks.isNotEmpty()) {
                val firstDate = startMonday
                    .plusDays((c.weekTime - 1).toLong())
                    .plusWeeks((c.weeks.first() - 1).toLong())
                lines += "DTSTART:${localStamp(firstDate, startClock)}"
                lines += "DTEND:${localStamp(firstDate, endClock)}"
            } else {
                // 没有开学日期就没法确定绝对日期，只能给个占位，日历里显示为"全天"
                lines += "DTSTART;VALUE=DATE:${LocalDate.now().format(DATE)}"
            }

            lines += "SUMMARY:${escape(c.name)}"
            val desc = ArrayList<String>()
            if (c.teacher.isNotBlank()) desc += "教师：${c.teacher}"
            if (c.classNumber.isNotBlank()) desc += "课程号：${c.classNumber}"
            desc += "周次：${Engine.weekText(c.weeks)}"
            c.info?.takeIf { it.isNotBlank() }?.let { desc += "备注：$it" }
            lines += "DESCRIPTION:${escape(desc.joinToString("\\n"))}"
            lines += "LOCATION:${escape(c.classroom)}"

            if (settings.remindEnabled) {
                lines += "BEGIN:VALARM"
                lines += "TRIGGER:-PT${settings.remindBeforeMinutes}M"
                lines += "ACTION:DISPLAY"
                lines += "DESCRIPTION:${escape(c.name)} 即将开始"
                lines += "END:VALARM"
            }
            lines += "END:VEVENT"
        }

        lines += "END:VCALENDAR"
        return lines.joinToString("\r\n")
    }

    private fun slotStart(settings: Settings, index: Int): String? =
        settings.timeSlots.firstOrNull { it.index == index }?.start

    private fun slotEnd(settings: Settings, index: Int): String? =
        settings.timeSlots.firstOrNull { it.index == index }?.end

    /** 本地时间戳（不带 Z，表示本地时区） */
    private fun localStamp(date: LocalDate, clock: String): String {
        val minutes = Engine.clockToMinutes(clock)
        val dt = date.atStartOfDay().plusMinutes(minutes.toLong())
        return "%04d%02d%02dT%02d%02d00".format(
            dt.year, dt.monthValue, dt.dayOfMonth, dt.hour, dt.minute
        )
    }

    /** iCalendar 的转义规则：反斜杠、分号、逗号、换行 */
    private fun escape(s: String): String = s
        .replace("\\", "\\\\")
        .replace(";", "\\;")
        .replace(",", "\\,")
        .replace("\n", "\\n")
}
