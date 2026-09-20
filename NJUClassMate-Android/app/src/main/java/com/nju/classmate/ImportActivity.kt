package com.nju.classmate

import android.annotation.SuppressLint
import android.content.res.Configuration
import android.os.Bundle
import android.view.View
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.ProgressBar
import android.widget.Spinner
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.nju.classmate.core.ScriptResultParser
import com.nju.classmate.core.Store
import com.nju.classmate.core.Timetable
import com.nju.classmate.imports.SchoolConfig
import com.nju.classmate.imports.SchoolProfile
import com.nju.classmate.widget.WidgetUpdater
import org.json.JSONObject

/**
 * 课表导入：内置浏览器 + 自动抓取。
 *
 * 完整链路：
 *   打开统一身份认证登录页 → 用户自己输账号密码 → 跳到课表页
 *   → onPageFinished 检测到 URL 命中目标 → 注入抓取脚本 → 回传 JSON
 *   → 落盘 → 让用户确认开学第一周 → 刷新小组件和提醒
 *
 * 关于账号安全：应用**不接触、不存储**用户的校园网账号密码。
 * 登录完全发生在 nju.edu.cn 域下的官方页面里，
 * 应用只是在页面渲染完成后读了一次 DOM。
 *
 * 复用了 HarmonyOS 版的四个抓取脚本，一行没改——
 * 因为 JS 接口名刻意保持同名（njuBridge），
 * 那 94 项注入脚本的断言在这里继续有效。
 */
class ImportActivity : AppCompatActivity() {

    private lateinit var webView: WebView
    private lateinit var statusText: TextView
    private lateinit var progress: ProgressBar
    private lateinit var btnExtract: Button
    private lateinit var entrySpinner: Spinner
    private lateinit var entryDesc: TextView

    private var profileIndex = 0
    private var importing = false
    /** 已经抓过的 URL，避免 SPA 反复触发 onPageFinished 时刷屏 */
    private var extractedForUrl = ""
    /** 抓取结果暂存，等用户确认开学日期后再落盘 */
    private var pendingTimetable: Timetable? = null

    private val profile: SchoolProfile get() = SchoolConfig.SCHOOL_LIST[profileIndex]

    /** 页面脚本通过它把结果送出来，名字必须和 JS 里的 window.njuBridge 一致 */
    private inner class Bridge {
        @JavascriptInterface
        fun postMessage(text: String) {
            runOnUiThread { onScriptResult(text) }
        }

        @JavascriptInterface
        fun postLog(msg: String) {
            android.util.Log.i(TAG, "[page] $msg")
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_import)

        statusText = findViewById(R.id.statusText)
        progress = findViewById(R.id.progress)
        btnExtract = findViewById(R.id.btnExtract)
        entrySpinner = findViewById(R.id.entrySpinner)
        entryDesc = findViewById(R.id.entryDesc)
        webView = findViewById(R.id.webView)

        entrySpinner.adapter = ArrayAdapter(
            this,
            android.R.layout.simple_spinner_dropdown_item,
            SchoolConfig.SCHOOL_LIST.map { it.title }
        )
        entrySpinner.setSelection(0, false)
        entrySpinner.onItemSelectedListener = object : android.widget.AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: android.widget.AdapterView<*>?, v: View?, position: Int, id: Long) {
                if (position == profileIndex) return
                switchProfile(position)
            }

            override fun onNothingSelected(parent: android.widget.AdapterView<*>?) = Unit
        }
        entryDesc.text = profile.description

        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            allowFileAccess = true
            mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
            useWideViewPort = true
            loadWithOverviewMode = true
            // 伪装成桌面浏览器：有些页面的移动版会把课表表格折叠起来
            userAgentString = SchoolConfig.DESKTOP_UA
        }
        webView.addJavascriptInterface(Bridge(), "njuBridge")
        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView, url: String) {
                handlePageFinished(url)
            }

            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                // 登录跳转、CAS 回跳都在这个 WebView 里走完，不放给外部浏览器
                return false
            }
        }
        webView.loadUrl(profile.initialUrl)

        findViewById<Button>(R.id.btnReload).setOnClickListener {
            webView.reload()
        }
        btnExtract.setOnClickListener { extract(manual = true) }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
    }

    // ---------------------------------------------------------------- 流程

    private fun switchProfile(index: Int) {
        profileIndex = index
        extractedForUrl = ""
        entryDesc.text = profile.description
        setStatus(getString(R.string.import_hint_login))
        progress.visibility = View.GONE
        webView.loadUrl(profile.initialUrl)
    }

    /**
     * 页面加载完成后判断要不要自动抓。
     * SPA 的 onPageFinished 可能触发得比表格渲染还早，所以自带重试。
     */
    private fun handlePageFinished(url: String) {
        if (url.isBlank()) return
        if (!url.contains(profile.targetUrlKeyword)) {
            setStatus(getString(R.string.import_hint_to_page))
            return
        }
        if (extractedForUrl == url) return
        extractedForUrl = url
        setStatus(getString(R.string.import_detected))
        extract(manual = false)
    }

    /**
     * 执行抓取。自动模式下最多重试 4 次，每次隔 1.2 秒——
     * 教务系统的表格是异步渲染的，onPageFinished 时往往还没出来。
     */
    private fun extract(manual: Boolean, attempt: Int = 0) {
        if (importing) return
        importing = true
        btnExtract.isEnabled = false

        val script = try {
            readAsset("www/extractors/${profile.scriptFile}")
        } catch (e: Exception) {
            importing = false
            btnExtract.isEnabled = true
            setStatus("这个入口的解析脚本（${profile.scriptFile}）没有打包进来，请换一个入口")
            return
        }

        if (profile.preExtractScript.isNotBlank()) {
            webView.evaluateJavascript(profile.preExtractScript, null)
        }

        webView.evaluateJavascript(script) { returned ->
            // 脚本优先走桥回传；桥没收到时退回返回值（兼容 nju.app 的原始脚本）
            if (returned != null && returned != "null" && returned.length > 2) {
                val text = if (returned.startsWith("\"") && returned.endsWith("\"")) {
                    unescapeJsString(returned)
                } else {
                    returned
                }
                onScriptResult(text)
            } else if (attempt < MAX_ATTEMPTS - 1 && !manual) {
                setStatus(getString(R.string.import_retrying, attempt + 2))
                webView.postDelayed({ extract(manual, attempt + 1) }, 1200)
            } else {
                finishAttempt("没有拿到任何数据，请确认页面停留在「我的课表」")
            }
        }
    }

    /** 桥或返回值拿到的原始 JSON */
    private fun onScriptResult(text: String) {
        if (!importing) return
        val timetable = try {
            ScriptResultParser.parse(text)
        } catch (e: ScriptResultParser.ParseException) {
            finishAttempt(e.message ?: "解析失败")
            return
        } catch (e: Exception) {
            finishAttempt("数据格式无法识别，可能是教务系统改版了")
            return
        }
        finishAttempt(null, timetable)
    }

    private fun finishAttempt(error: String?, timetable: Timetable? = null) {
        importing = false
        btnExtract.isEnabled = true
        progress.visibility = View.GONE

        if (error != null || timetable == null) {
            setStatus(error ?: "抓取失败")
            return
        }

        val settings = Store.loadSettings(this)
        val existing = settings.semesterStartMonday
        setStatus(getString(R.string.import_ok, timetable.name, timetable.courses.size))

        if (existing.isBlank()) {
            // 第一次导入必须校准开学日期，否则算不出"第几周"，小组件也就没有意义。
            // Android 这边用系统的 DatePickerDialog 选，默认猜"两周前的周一"。
            pendingTimetable = timetable
            showSemesterStartPicker()
        } else {
            commit(timetable.copy(semesterStartMonday = existing))
            finish()
        }
    }

    private fun showSemesterStartPicker() {
        val guess = java.time.LocalDate.now().minusWeeks(2)
        val monday = guess.minusDays((guess.dayOfWeek.value - 1).toLong())
        android.app.DatePickerDialog(
            this,
            { _, year, month, day ->
                val picked = java.time.LocalDate.of(year, month + 1, day)
                val pickedMonday = picked.minusDays((picked.dayOfWeek.value - 1).toLong())
                val t = pendingTimetable
                if (t != null) {
                    commit(t.copy(semesterStartMonday = pickedMonday.toString()))
                    finish()
                }
            },
            monday.year, monday.monthValue - 1, monday.dayOfMonth
        ).apply {
            setTitle(getString(R.string.pick_semester_start))
            setCancelable(false)
            show()
        }
    }

    /** 落盘 + 刷新小组件 + 重排提醒 */
    private fun commit(timetable: Timetable) {
        Store.saveTimetable(this, timetable)
        val settings = Store.loadSettings(this)
        Store.saveSettings(this, settings.copy(semesterStartMonday = timetable.semesterStartMonday))
        WidgetUpdater.updateAll(this)
        com.nju.classmate.reminder.ReminderScheduler.rescheduleAll(this)
        Toast.makeText(
            this,
            getString(R.string.import_saved, timetable.courses.size),
            Toast.LENGTH_LONG
        ).show()
    }

    // ---------------------------------------------------------------- 小工具

    private fun readAsset(path: String): String =
        assets.open(path).bufferedReader(Charsets.UTF_8).use { it.readText() }

    private fun setStatus(text: String) {
        statusText.text = text
    }

    private fun unescapeJsString(s: String): String = try {
        JSONObject("{\"v\":$s}").optString("v")
    } catch (e: Exception) {
        s.trim('"')
    }

    override fun onDestroy() {
        webView.destroy()
        super.onDestroy()
    }

    companion object {
        private const val TAG = "NJUImport"
        private const val MAX_ATTEMPTS = 4
    }
}
