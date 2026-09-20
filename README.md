<div align="center">

<img src="https://raw.githubusercontent.com/qingaorui/nju-study/main/NJUClassMate/AppScope/resources/base/media/app_icon.png" width="128" height="128" alt="nju-study">

# 🎓 nju-study

**南京大学 · 学习与效率工具箱**

<sub>用代码把学习里的重复劳动自动化 —— 几个自己写、自己用的小作品</sub>

<br>

<p>
  <img alt="Python" src="https://img.shields.io/badge/Python-3.12-3776AB?style=for-the-badge&logo=python&logoColor=white">
  <img alt="HarmonyOS" src="https://img.shields.io/badge/HarmonyOS-ArkTS-F5A623?style=for-the-badge">
  <img alt="Android" src="https://img.shields.io/badge/Android-Kotlin-3DDC84?style=for-the-badge&logo=android&logoColor=white">
</p>

<p>
  <img alt="last commit" src="https://img.shields.io/github/last-commit/qingaorui/nju-study?style=flat-square&label=%E6%9C%80%E8%BF%91%E6%8F%90%E4%BA%A4&color=8A63D2">
  <img alt="repo size" src="https://img.shields.io/github/repo-size/qingaorui/nju-study?style=flat-square&label=%E4%BB%93%E5%BA%93%E5%A4%A7%E5%B0%8F&color=8A63D2">
  <img alt="stars" src="https://img.shields.io/github/stars/qingaorui/nju-study?style=flat-square&label=Star&color=8A63D2">
</p>

</div>

> [!NOTE]
> 这里记录我的学习和 **vibe coding** 作品。每个目录都是一个**独立项目**，点进去看详细说明与部署方式。

---

## 🗂️ 项目一览

<table>
<tr>
<td width="50%" valign="top">

<h3>📚 Python 学习助手</h3>

面向初学者的 Python 学习桌面软件，参考《Python 编程从入门到实践 第 2 版》。

<code>Flask</code> · <code>PyWebView</code> · <code>Windows</code>

<a href="python_learner"><b>进入项目 →</b></a>

</td>
<td width="50%" valign="top">

<h3>✍️ 智能题目解答助手</h3>

截图题目 → 豆包视觉大模型 → 返回答案与思路。<b>单文件、免安装</b>。

<code>tkinter</code> · <code>火山方舟 API</code>

<a href="QuestionSolver"><b>进入项目 →</b></a>

</td>
</tr>
<tr>
<td width="50%" valign="top">

<h3>📱 南哪儿课表 · 鸿蒙版</h3>

南京大学课表，鸿蒙原生实现，支持锁屏卡片与桌面卡片。

<code>ArkTS</code> · <code>ArkUI</code> · <code>Form Kit</code>

<a href="NJUClassMate"><b>进入项目 →</b></a>

</td>
<td width="50%" valign="top">

<h3>🤖 南哪儿课表 · 安卓版</h3>

自签名 APK，可装到 HarmonyOS 1.0~4.x 及任意 Android 设备。

<code>Kotlin</code> · <code>WebView</code> · <code>RemoteViews</code>

<a href="NJUClassMate-Android"><b>进入项目 →</b></a>

</td>
</tr>
</table>

---

## 🎒 Python 学习助手

> 面向初学者的 Python 学习工具（Windows 桌面软件），参考书为《Python 编程从入门到实践 第 2 版》。

| 能力 | 说明 |
| :-- | :-- |
| 📖 **章节学习** | 第 1~11 章逐节学习：讲解 + 示例代码 + 原书 PDF 对应页 |
| ▶️ **内置编译器** | 示例和练习直接在软件内运行，无需切换编辑器 |
| 🧩 **70+ 道练习** | 覆盖书中经典「动手试一试」 |
| 🤖 **DeepSeek 网页批改** | 一键整理提示词并打开网页批改 |
| 📚 **PDF 阅读 · 大型项目 · 作业提交** | 完整覆盖学习闭环 |

👉 [**查看部署与打包说明 →**](python_learner)

---

## ✍️ 智能题目解答助手

> 一款**单文件、免安装**的 Windows 桌面软件：截图 → 自动识别题目 → 调用豆包（火山方舟）视觉大模型 → 返回答案、思路与步骤，一键复制。

- ✅ **零依赖**：双击即用，可放 U 盘或任意文件夹
- 🔑 **只需一个火山方舟 API Key**（软件内填写一次）

👉 [**查看使用说明 →**](QuestionSolver)

---

## 📱 南京大学课表（南哪儿课表）

> 内置浏览器登录南大教务系统 → 自动抓取课表 → 桌面小组件 + 锁屏显示下一节课 + 课前提醒。

<details open>
<summary><b>🔀 两个版本怎么选</b></summary>

<br>

| | 鸿蒙版 `NJUClassMate` | 安卓版 `NJUClassMate-Android` |
| :-- | :-- | :-- |
| **技术栈** | ArkTS · ArkUI · Form Kit | Kotlin · WebView · RemoteViews |
| **运行环境** | HarmonyOS NEXT（5.0+） | HarmonyOS 1.0~4.x / 任意 Android |
| **锁屏显示下一节课** | ✅ Form Kit 锁屏卡片（API 18+） | ✅ 常驻通知 + 自走秒倒计时 |
| **安装门槛** | 需 DevEco + 华为开发者账号 | ✅ **自签名 APK，零门槛** |

</details>

<details>
<summary><b>✨ 功能亮点</b></summary>

<br>

- ✅ 内置浏览器自动抓取课表（本科 / 研究生 × 教务 / 选课，**4 个入口**）
- ✅ 桌面小组件「下一节课」「今日课表」
- ✅ 锁屏显示下一节课 + **自走秒倒计时**（常驻通知）
- ✅ 课前提醒（精确闹钟）、考试倒计时、导出 `.ics`
- ✅ 「现在是第几周」自动设置、手动录课
- ✅ 开机自启 + 自动刷新 + 针对华为 ROM 的授权引导

</details>

<details>
<summary><b>🛠️ 构建与测试（安卓版，一条命令）</b></summary>

<br>

```bash
# 环境：JDK17 + Android SDK + Gradle（可自动安装）
python tools/setup_android_env.py        # 一次性安装工具链
bash  tools/build_apk.sh --release       # 跑单测 + 出签名 APK
bash  NJUClassMate/tools/run_tests.sh    # 全量 261 项断言
```

</details>

👉 [**安卓版详细说明 →**](NJUClassMate-Android) · [**鸿蒙版详细说明 →**](NJUClassMate)

---

## 🧭 目录结构

```text
nju-study/
├── python_learner/           # 📚 Python 学习助手
├── QuestionSolver/           # ✍️ 智能题目解答助手
├── NJUClassMate/             # 📱 南京大学课表（鸿蒙原生）
├── NJUClassMate-Android/     # 🤖 南京大学课表（安卓）
└── tools/                    # 🛠️ 构建 / 测试脚本（两个课表工程共用）
```

---

## 📮 说明

> [!IMPORTANT]
> 所有项目均为个人学习与自用作品，**仅供学习交流**。

> [!WARNING]
> 课表抓取脚本基于教务系统页面的 DOM 解析，**教务系统改版时可能失效**。
> 工程内带有离线测试，可快速回归定位。

如果对你有帮助，欢迎点个 **Star** ⭐，有问题提 Issue 反馈。

<p align="center">
  <sub>Made with ❤️ for NJU · 记录学习，也记录把想法变成工具的过程</sub>
</p>
