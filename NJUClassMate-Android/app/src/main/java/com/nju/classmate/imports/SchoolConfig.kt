package com.nju.classmate.imports

/**
 * 可导入的教务站点。
 *
 * URL 与 nju.app（南哪课表）的官方配置逐字对齐，改动前请先确认教务系统是否改版。
 * 想支持别的学校（东南、上交……），加一条记录 + 放一个抓取脚本即可，主流程不用动。
 */
data class SchoolProfile(
    val id: String,
    val title: String,
    val description: String,
    /** 内置浏览器打开的登录页 */
    val initialUrl: String,
    /**
     * 目标页 URL 关键字。
     * 当 WebView 加载的 URL 里包含它时，说明用户已经登录成功进到了课表页，
     * 此时才注入抓取脚本。
     */
    val targetUrlKeyword: String,
    /** 抓取脚本在 assets/www/extractors 下的文件名 */
    val scriptFile: String,
    /** 注入前的预处理脚本（可选，用于自动展开面板） */
    val preExtractScript: String = ""
)

object SchoolConfig {

    val SCHOOL_LIST: List<SchoolProfile> = listOf(
        SchoolProfile(
            id = "nju_bks_jw",
            title = "本科生教务系统",
            description = "通过「我的课表」导入，推荐本科生使用",
            initialUrl = "https://authserver.nju.edu.cn/authserver/login?service=" +
                "https%3A%2F%2Fehallapp.nju.edu.cn%2Fjwapp%2Fsys%2Fwdkb%2F*default%2Findex.do%23%2Fxskcb",
            targetUrlKeyword = "ehallapp.nju.edu.cn/jwapp/sys/wdkb",
            scriptFile = "njubksjw.js"
        ),
        SchoolProfile(
            id = "nju_bks_xk",
            title = "本科生选课系统",
            description = "通过选课结果导入，适合刚选完课的场景",
            initialUrl = "https://xk.nju.edu.cn",
            targetUrlKeyword = "xk.nju.edu.cn/xsxkapp",
            scriptFile = "njubksxk.js"
        ),
        SchoolProfile(
            id = "nju_yjs_jw",
            title = "研究生教务系统",
            description = "研究生请走这个入口（研院有独立的课表界面）",
            initialUrl = "https://authserver.nju.edu.cn/authserver/login?service=" +
                "https%3A%2F%2Fehallapp.nju.edu.cn%2Fgsapp%2Fsys%2Fwdkbapp%2F*default%2Findex.do%23%2Fxskcb",
            targetUrlKeyword = "ehallapp.nju.edu.cn/gsapp/sys/wdkbapp",
            scriptFile = "njuyjsjw.js"
        ),
        SchoolProfile(
            id = "nju_yjs_xk",
            title = "研究生选课系统",
            description = "研究生同学的另一种导入方式",
            initialUrl = "https://yjsxk.nju.edu.cn/yjsxkapp/sys/xsxkapp/index_nju.html",
            targetUrlKeyword = "yjsxk.nju.edu.cn",
            scriptFile = "njuyjsxk.js"
        )
    )

    const val VPN_TIP: String =
        "加载失败时请先连接南京大学 VPN（ztna.nju.edu.cn）再试。教务系统偶发抽风，多刷几次通常就好了。"

    /** 打开教务系统时伪装成桌面浏览器：部分页面的移动版会把课表表格折叠起来 */
    const val DESKTOP_UA: String =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
            "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
}
