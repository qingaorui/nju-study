package com.nju.classmate.core

/**
 * 「本机适配」——这台手机上还需要用户去系统里补哪些授权。
 *
 * ## 为什么需要这个东西
 *
 * 这个 App 的三个核心承诺（课前提醒、锁屏通知、桌面小组件保持最新）
 * 全都依赖后台任务。而中国的手机 ROM——尤其是华为 EMUI / 鸿蒙——
 * 对三方应用的后台管控比原生 Android 严得多，**三项默认都是被压制的**：
 *
 *   1. **精确闹钟**：Android 12 起（`targetSdk >= 31`）必须用户授权，
 *      不授权就只能用非精确闹钟，Doze 下可能偏几分钟。
 *      对"课前 15 分钟提醒"来说，偏 5 分钟就是迟到。
 *   2. **电池优化**：EMUI 会直接冻结/杀掉后台应用，闹钟和
 *      WorkManager 都可能不执行。原生 Android 只是延迟，EMUI 是不跑。
 *   3. **应用启动管理**（EMUI 特有）：不开「自启动 / 关联启动 / 后台活动」，
 *      重启后闹钟表不会重建，通知也不会自己回来。
 *
 * 这三项都**不会**报错，只会表现为"提醒没响 / 数据是旧的"——
 * 用户根本无从判断。所以必须在设置页把它们摊开、逐项给出状态和跳转入口。
 *
 * ## 为什么这一层是纯函数
 *
 * 系统状态的读取（`canScheduleExactAlarms()`、`isIgnoringBatteryOptimizations()`）
 * 和跳转 Intent 都要 Android API，放在 `device/DeviceCompat.kt`。
 * 但**"这台机器该显示哪几行、哪行算不合格"是纯逻辑**，
 * 所以留在 core 里，能直接跑 JVM 断言（见 EngineTest 最后一节）。
 */
enum class AdaptTarget {
    /** 精确闹钟授权（Android 12+） */
    EXACT_ALARM,

    /** 忽略电池优化 */
    BATTERY,

    /** 华为「应用启动管理」——只能用户手动确认，读不到状态 */
    STARTUP,

    /** 通知权限 / 锁屏通知 */
    NOTIFICATION
}

data class DeviceInfo(
    /** 厂商，例如 "HUAWEI" */
    val brand: String,
    /** 机型，例如 "NOH-AN00" */
    val model: String,
    /** Android 版本号字符串，例如 "12"。鸿蒙 4 会报成 12 */
    val androidRelease: String,
    val sdkInt: Int,
    /**
     * 是不是华为系 ROM（EMUI / 鸿蒙 / 荣耀早期）。
     * 由平台层综合厂商、系统属性判断后传进来，纯逻辑层不碰系统 API。
     */
    val isHuaweiFamily: Boolean,
    val exactAlarmGranted: Boolean,
    val ignoringBatteryOptimizations: Boolean,
    val notificationsEnabled: Boolean
) {
    /** "华为 NOH-AN00 · Android 12（API 31）" */
    fun displayLine(): String =
        "${brandDisplayName(brand)} ${model.ifBlank { "未知机型" }} · Android $androidRelease（API $sdkInt）"
}

/**
 * 常见厂商的中文名。
 *
 * `Build.BRAND` 返回的是英文大写（"HUAWEI"），直接摆在中文界面的
 * 「当前设备」那一行很突兀。认不出来的**原样显示，不猜**——
 * 瞎映射比显示英文更糟。
 */
private val BRAND_CN = mapOf(
    "HUAWEI" to "华为",
    "HONOR" to "荣耀",
    "HIHONOR" to "荣耀",
    "XIAOMI" to "小米",
    "REDMI" to "红米",
    "POCO" to "POCO",
    "OPPO" to "OPPO",
    "VIVO" to "vivo",
    "IQOO" to "iQOO",
    "ONEPLUS" to "一加",
    "MEIZU" to "魅族",
    "REALME" to "realme",
    "SAMSUNG" to "三星",
    "GOOGLE" to "Google",
    "SONY" to "索尼",
    "NOKIA" to "诺基亚",
    "LENOVO" to "联想",
    "ZTE" to "中兴",
    "NUBIA" to "努比亚",
    "SMARTISAN" to "坚果",
    "BLACKSHARK" to "黑鲨"
)

fun brandDisplayName(brand: String): String {
    val b = brand.trim()
    if (b.isEmpty()) return "未知厂商"
    return BRAND_CN[b.uppercase()] ?: b
}

data class AdaptItem(
    val target: AdaptTarget,
    /** 行标题 */
    val title: String,
    /** 为什么需要它 */
    val desc: String,
    /** 当前是否已满足。null 表示读不到状态，只能让用户自己去确认 */
    val ok: Boolean?,
    /**
     * 不满足时是否会导致功能失效。
     * true 会显示成警告（红），false 只是提示（灰）。
     */
    val critical: Boolean
)

/**
 * 这台机器上该显示哪些适配项、各自什么状态。
 *
 * 规则都是"针对具体系统和机型"的，不是通用清单：
 *   · 精确闹钟只在 Android 12+ 才需要授权，低版本显示它纯属噪音；
 *   · 「应用启动管理」只有华为系 ROM 有，别的系统上这一行不该出现；
 *   · 通知权限在 Android 13+ 才可能被拒，低版本默认就是开的。
 */
fun buildAdaptationPlan(info: DeviceInfo): List<AdaptItem> {
    val items = ArrayList<AdaptItem>()

    // ---- 精确闹钟：Android 12(S) 起才有这道门 ----
    if (info.sdkInt >= 31) {
        items.add(
            AdaptItem(
                target = AdaptTarget.EXACT_ALARM,
                title = "允许精确闹钟",
                desc = if (info.exactAlarmGranted) {
                    "已允许，课前提醒能卡在整点上"
                } else {
                    "未允许时只能用非精确闹钟，息屏久了提醒可能偏几分钟——" +
                        "对「课前 15 分钟」来说这就是迟到。点进去打开「闹钟和提醒」"
                },
                ok = info.exactAlarmGranted,
                critical = true
            )
        )
    }

    // ---- 电池优化：所有 ROM 都建议关，华为系上不关会真的被杀 ----
    items.add(
        AdaptItem(
            target = AdaptTarget.BATTERY,
            title = "允许后台运行（忽略电池优化）",
            desc = if (info.ignoringBatteryOptimizations) {
                "已加入白名单"
            } else if (info.isHuaweiFamily) {
                "华为系统会冻结后台应用：闹钟不响、小组件和锁屏通知停在旧数据。" +
                    "点进去选择「允许」"
            } else {
                "未加白名单时，系统在深度休眠下会推迟后台任务"
            },
            ok = info.ignoringBatteryOptimizations,
            critical = info.isHuaweiFamily
        )
    )

    // ---- 华为「应用启动管理」：只有华为系才有，且状态读不到 ----
    if (info.isHuaweiFamily) {
        items.add(
            AdaptItem(
                target = AdaptTarget.STARTUP,
                title = "应用启动管理：改为「手动管理」",
                desc = "这一项系统没有公开接口，App 读不到状态，所以只能你自己确认一次：" +
                    "把「自启动」「关联启动」「后台活动」三个开关都打开。" +
                    "不开的话，重启手机后闹钟表不会重建，锁屏通知也不会自己回来",
                // 读不到 → 不给 ✓ 也不给 ⚠，只让用户自己去确认
                ok = null,
                critical = false
            )
        )
    }

    // ---- 通知 / 锁屏通知 ----
    items.add(
        AdaptItem(
            target = AdaptTarget.NOTIFICATION,
            title = "通知与锁屏通知",
            desc = if (info.notificationsEnabled) {
                "通知已开启。若锁屏看不到，检查「锁屏通知」是否被设成不显示"
            } else {
                "通知被关闭了，锁屏上看不到下一节课。点进去允许通知"
            },
            ok = info.notificationsEnabled,
            critical = true
        )
    )

    return items
}

/** 一句话总结还差几项（设置页的分组标题右侧用） */
fun adaptationSummary(items: List<AdaptItem>): String {
    val bad = items.count { it.ok == false && it.critical }
    val unknown = items.count { it.ok == null }
    return when {
        bad > 0 -> "还有 $bad 项必须处理"
        unknown > 0 -> "有 $unknown 项需手动确认"
        else -> "全部就绪"
    }
}
