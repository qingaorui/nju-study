package com.nju.classmate.device

import android.app.AlarmManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import com.nju.classmate.core.AdaptTarget
import com.nju.classmate.core.DeviceInfo

/**
 * 读取本机状态、跳转到系统的相关设置页。
 *
 * 这一层负责所有碰 Android API 的部分；"该显示哪几行、哪行不合格"
 * 那些判断在 `core/DeviceAdapt.kt` 里（纯函数，能跑单测）。
 *
 * ## 跳转为什么要写得这么啰嗦
 *
 * 这些都是 **OEM 私有的设置页**，没有任何稳定契约：
 *   · 华为「应用启动管理」的类名在不同 EMUI 版本之间改过至少三次；
 *   · 有的版本把它藏在 `com.huawei.systemmanager` 里，荣耀又是另一个包名；
 *   · 部分 ROM 干脆把 Activity 设成不导出，跳过去直接抛异常。
 *
 * 所以每个跳转都是"一串候选 + 逐个试探 + 失败返回 false"，
 * 由界面如实告诉用户"跳转失败，请手动去设置里找"，而不是崩掉或者假装成功。
 */
object DeviceCompat {

    private const val TAG = "NJUDevice"

    // ---------------------------------------------------------------- 读取状态

    fun readDeviceInfo(ctx: Context): DeviceInfo = DeviceInfo(
        brand = Build.BRAND.orEmpty().ifBlank { Build.MANUFACTURER.orEmpty() }.uppercase(),
        model = Build.MODEL.orEmpty(),
        androidRelease = Build.VERSION.RELEASE.orEmpty(),
        sdkInt = Build.VERSION.SDK_INT,
        isHuaweiFamily = isHuaweiFamily(),
        exactAlarmGranted = isExactAlarmGranted(ctx),
        ignoringBatteryOptimizations = isIgnoringBatteryOptimizations(ctx),
        notificationsEnabled = NotificationManagerCompat.from(ctx).areNotificationsEnabled()
    )

    /**
     * 是不是华为系 ROM。
     *
     * 光看厂商不够：荣耀独立后品牌名换了，但系统还是同一套
     * `com.hihonor.systemmanager`；反过来有些代工厂机型 BRAND 是华为、
     * 实际跑的是 AOSP。所以再加两个系统属性一起判断。
     *
     * `android.os.SystemProperties` 是隐藏类，只能反射读——读不到就当不是，
     * 宁可少提示一行，也不要给用户一个跳不过去的按钮。
     */
    private fun isHuaweiFamily(): Boolean {
        val brand = (Build.BRAND.orEmpty() + " " + Build.MANUFACTURER.orEmpty()).uppercase()
        if (brand.contains("HUAWEI") || brand.contains("HONOR") ||
            brand.contains("HIHONOR") || brand.contains("HARMONY")
        ) {
            return true
        }
        val emui = systemProperty("ro.build.version.emui")
        if (!emui.isNullOrBlank()) return true
        val harmony = systemProperty("ro.build.version.harmony")
        if (!harmony.isNullOrBlank()) return true
        val osBrand = systemProperty("ro.product.brand").uppercase()
        return osBrand.contains("HUAWEI") || osBrand.contains("HONOR")
    }

    private fun systemProperty(key: String): String {
        return try {
            val cls = Class.forName("android.os.SystemProperties")
            val get = cls.getMethod("get", String::class.java)
            (get.invoke(null, key) as? String).orEmpty()
        } catch (e: Throwable) {
            ""
        }
    }

    private fun isExactAlarmGranted(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val am = ctx.getSystemService(AlarmManager::class.java) ?: return false
        return try {
            am.canScheduleExactAlarms()
        } catch (e: Exception) {
            false
        }
    }

    private fun isIgnoringBatteryOptimizations(ctx: Context): Boolean {
        val pm = ctx.getSystemService(PowerManager::class.java) ?: return false
        return try {
            pm.isIgnoringBatteryOptimizations(ctx.packageName)
        } catch (e: Exception) {
            false
        }
    }

    // ---------------------------------------------------------------- 跳转

    /**
     * 打开某一项对应的系统设置页。
     * @return 成功打开了返回 true；所有候选都失败返回 false
     */
    fun openTarget(ctx: Context, target: AdaptTarget): Boolean {
        val intents: List<Intent> = when (target) {
            AdaptTarget.EXACT_ALARM -> exactAlarmIntents(ctx)
            AdaptTarget.BATTERY -> batteryIntents(ctx)
            AdaptTarget.STARTUP -> startupIntents(ctx)
            AdaptTarget.NOTIFICATION -> notificationIntents(ctx)
        }
        for (intent in intents) {
            if (tryStart(ctx, intent)) return true
        }
        Log.w(TAG, "没有可用的设置页可跳转: $target")
        return false
    }

    /**
     * 逐个试探候选 Intent。
     *
     * 先 resolveActivity 判断能不能处理，再真的启动——第三方 ROM 上
     * 有些 Activity 存在但被设成不可导出，这种情况下 resolve 成功、启动照样抛异常，
     * 所以两个都包在 try 里。
     */
    private fun tryStart(ctx: Context, intent: Intent): Boolean {
        return try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (intent.resolveActivity(ctx.packageManager) == null) return false
            ctx.startActivity(intent)
            true
        } catch (e: Exception) {
            Log.d(TAG, "跳转失败，试下一个: ${intent.component?.className ?: intent.action} → ${e.message}")
            false
        }
    }

    // ---- 精确闹钟（Android 12+） ----
    private fun exactAlarmIntents(ctx: Context): List<Intent> {
        val list = ArrayList<Intent>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            list.add(
                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                    .setData(Uri.fromParts("package", ctx.packageName, null))
            )
        }
        list.add(appDetailsIntent(ctx))
        return list
    }

    // ---- 电池优化 ----
    private fun batteryIntents(ctx: Context): List<Intent> {
        val list = ArrayList<Intent>()
        // 直接弹出「是否允许忽略电池优化」的确认框，最省事
        list.add(
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                .setData(Uri.fromParts("package", ctx.packageName, null))
        )
        // 退一步：打开电池优化列表，用户自己去里面找
        list.add(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        list.add(appDetailsIntent(ctx))
        return list
    }

    // ---- 华为「应用启动管理」（只有华为系才有） ----
    private fun startupIntents(ctx: Context): List<Intent> {
        val candidates = listOf(
            // EMUI 9 ~ 鸿蒙 4 常见
            "com.huawei.systemmanager" to "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity",
            // EMUI 8 时代的入口，部分老机型仍在用
            "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            // 更老的「受保护应用」
            "com.huawei.systemmanager" to "com.huawei.systemmanager.optimize.process.ProtectActivity",
            // 荣耀独立后的包名
            "com.hihonor.systemmanager" to "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            "com.hihonor.systemmanager" to "com.hihonor.systemmanager.appcontrol.activity.StartupAppControlActivity"
        )
        val list: MutableList<Intent> =
            candidates.map { (pkg, cls) -> Intent().setComponent(ComponentName(pkg, cls)) }
                .toMutableList()
        // 全部失败时至少把应用详情页给用户，那里也能点进权限管理
        list.add(appDetailsIntent(ctx))
        return list
    }

    // ---- 通知设置 ----
    private fun notificationIntents(ctx: Context): List<Intent> {
        val list = ArrayList<Intent>()
        list.add(
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, ctx.packageName)
        )
        list.add(appDetailsIntent(ctx))
        return list
    }

    private fun appDetailsIntent(ctx: Context): Intent =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.fromParts("package", ctx.packageName, null))
}
