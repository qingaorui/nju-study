package com.nju.classmate

import android.Manifest
import android.annotation.SuppressLint
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.ViewGroup
import android.webkit.ValueCallback
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.nju.classmate.notify.NextClassNotifier
import com.nju.classmate.web.WebBridge

/**
 * 主界面。
 *
 * 界面本身是一套本地 HTML/CSS/JS（assets/www），用 WebView 承载。
 * 这么选的原因：
 *   - 抓课表本来就要用 WebView（教务系统在浏览器里登录后注入 JS 读 DOM），
 *     共用同一套渲染栈不用引入第二套技术；
 *   - 逻辑只有一份 Kotlin（Engine.kt），网页通过 NJU.call() 拿结果来画，
 *     不存在"两套实现算出两个不同答案"的风险；
 *   - 换皮、改排版不用重编译。
 *
 * 安全上有一条硬约束：**这个 WebView 只能加载本地 assets**。
 * 因为 addJavascriptInterface 会把桥暴露给加载进来的任何页面，
 * 所以 shouldOverrideUrlLoading 里把外链全部丢给系统浏览器，绝不在本 WebView 打开。
 */
class MainActivity : AppCompatActivity() {

    private lateinit var webView: WebView
    private val bridge by lazy { WebBridge(this) }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val root = FrameLayout(this).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(ContextCompat.getColor(this@MainActivity, R.color.page_bg))
        }
        webView = WebView(this)
        root.addView(
            webView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )
        setContentView(root)

        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            allowFileAccess = true
            cacheMode = WebSettings.LOAD_DEFAULT
            mediaPlaybackRequiresUserGesture = false
        }
        webView.addJavascriptInterface(bridge, "NJU")
        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                val url = request.url.toString()
                // 本地页面放行（也就是页面内锚点、hash 跳转）
                if (url.startsWith("file://")) return false
                // 一切外链交给系统浏览器，绝不在带桥的 WebView 里打开
                return try {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                    true
                } catch (e: Exception) {
                    true
                }
            }
        }
        webView.loadUrl("file:///android_asset/www/index.html")

        askNotificationPermission()
    }

    override fun onResume() {
        super.onResume()
        // 从导入页回来、或从后台切回来时，让网页重新拉一次数据
        refreshWeb()
        // 顺手把锁屏通知也推一次：用户刚打开过应用，是最该保持一致的时刻
        NextClassNotifier.update(this)
    }

    fun refreshWeb() {
        webView.evaluateJavascript("window.NJUApp && window.NJUApp.refresh && window.NJUApp.refresh()", null)
    }

    fun startImport() {
        startActivity(Intent(this, ImportActivity::class.java))
    }

    /**
     * 返回键先交给网页判断（比如从"本周"退到"今日"、关掉弹出的面板），
     * 网页说没得退了才真的退出 App。
     *
     * 注意这里用 finish() 而不是 super.onBackPressed()：
     * Kotlin 不允许在 lambda 里写 super 调用，而 evaluateJavascript 的回调就是 lambda。
     * 对单 Activity 应用来说两者等价。
     */
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        webView.evaluateJavascript(
            "window.NJUApp && window.NJUApp.onBack ? window.NJUApp.onBack() : false"
        ) { value ->
            if (value != "true") {
                runOnUiThread { finish() }
            }
        }
    }

    private fun askNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
            == PackageManager.PERMISSION_GRANTED
        ) return
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_NOTIFICATION)
    }

    override fun onDestroy() {
        webView.destroy()
        super.onDestroy()
    }

    companion object {
        private const val REQ_NOTIFICATION = 1001
    }
}
