<div align="center">

# 🎓 nju-study

**南京大学 · 学习与效率工具箱**

用代码把学习里的重复劳动自动化 —— 几个自己写、自己用的小作品。

<p>
  <img alt="Python" src="https://img.shields.io/badge/Python-3.12-3776AB?style=flat-square&logo=python&logoColor=white">
  <img alt="HarmonyOS" src="https://img.shields.io/badge/HarmonyOS-ArkTS-F5A623?style=flat-square">
  <img alt="Android" src="https://img.shields.io/badge/Android-Kotlin-3DDC84?style=flat-square&logo=android&logoColor=white">
  <img alt="last commit" src="https://img.shields.io/github/last-commit/qingaorui/nju-study?style=flat-square&color=8A63D2">
</p>

</div>

> 📌 这里记录我的学习和 **vibe coding** 作品。每个目录都是一个独立项目，点进去看详细说明与部署方式。

---

## 🗂️ 项目一览

| 项目 | 一句话 | 技术栈 |
| --- | --- | --- |
| 📚 [Python 学习助手](python_learner) | 面向初学者的 Python 学习桌面软件，参考《Python编程从入门到实践》 | `Flask` · `PyWebView` |
| ✍️ [智能题目解答助手](QuestionSolver) | 截图题目 → 豆包视觉大模型 → 答案 + 思路，单文件免安装 | `tkinter` · `火山方舟 API` |
| 📱 [南哪儿课表 · 鸿蒙版](NJUClassMate) | 南京大学课表，鸿蒙原生（锁屏卡片 / 桌面卡片 / 提醒） | `ArkTS` · `Form Kit` |
| 🤖 [南哪儿课表 · 安卓版](NJUClassMate-Android) | 南京大学课表，自签名 APK，可装到 HarmonyOS 1.0~4.x 及 Android | `Kotlin` · `WebView` |

---

## 🎒 Python 学习助手

面向初学者的 Python 学习工具（Windows 桌面软件），参考书为
《Python 编程从入门到实践 第 2 版》。

- **章节学习**：第 1~11 章逐节学习（讲解 + 示例代码 + 原书 PDF 对应页）
- **内置编译器**：示例和练习直接在软件内运行
- **70+ 道练习**：覆盖书中经典「动手试一试」
- **DeepSeek 网页批改**：一键整理提示词并打开网页批改
- **PDF 阅读 · 大型项目 · 作业提交**

👉 [查看部署与打包说明 →](python_learner)

---

## ✍️ 智能题目解答助手

一款**单文件、免安装**的 Windows 桌面软件：截图 → 自动识别题目 →
调用豆包（火山方舟）视觉大模型 → 返回答案、思路与步骤，一键复制。

- 零依赖，双击即用，可放 U 盘 / 任意文件夹
- 只需一个火山方舟 API Key（软件内填写一次）

👉 [查看使用说明 →](QuestionSolver)

---

## 📱 南京大学课表（南哪儿课表）

> 内置浏览器登录南大教务系统 → 自动抓取课表 → 桌面小组件 + 锁屏显示下一节课 + 课前提醒。

**两个版本，同一套抓取脚本、同一套算法思路：**

| | 鸿蒙版 `NJUClassMate` | 安卓版 `NJUClassMate-Android` |
| --- | --- | --- |
| 技术栈 | ArkTS · ArkUI · Form Kit | Kotlin · WebView · RemoteViews |
| 运行环境 | HarmonyOS NEXT（5.0+） | HarmonyOS 1.0~4.x / 任意 Android |
| 安装门槛 | 需 DevEco + 华为开发者账号 | **自签名 APK，零门槛** |

**功能亮点**

- ✅ 内置浏览器自动抓取课表（本科/研究生 × 教务/选课，4 个入口）
- ✅ 桌面小组件「下一节课」「今日课表」
- ✅ 锁屏显示下一节课 + **自走秒倒计时**（常驻通知）
- ✅ 课前提醒（精确闹钟）、考试倒计时、导出 `.ics`
- ✅ 「现在是第几周」自动设置、手动录课
- ✅ 开机自启 + 自动刷新 + 针对华为 ROM 的授权引导

**构建与测试**（安卓版，一条命令）：

```bash
# 环境：JDK17 + Android SDK + Gradle（可自动安装）
python tools/setup_android_env.py        # 一次性安装工具链
bash  tools/build_apk.sh --release       # 跑单测 + 出签名 APK
bash  NJUClassMate/tools/run_tests.sh    # 全量 261 项断言
```

👉 [安卓版详细说明 →](NJUClassMate-Android) · [鸿蒙版详细说明 →](NJUClassMate)

---

## 🧭 目录结构

```
nju-study/
├── python_learner/           # Python 学习助手
├── QuestionSolver/           # 智能题目解答助手
├── NJUClassMate/             # 南京大学课表（鸿蒙原生）
├── NJUClassMate-Android/     # 南京大学课表（安卓）
└── tools/                    # 构建 / 测试脚本（两个课表工程共用）
```

---

## 📮 说明

- 所有项目均为个人学习与自用作品，**仅供学习交流**。
- 抓取脚本来自教务系统页面的 DOM 解析，教务系统改版时可能失效（工程内有离线测试可回归）。
- 欢迎 Star ⭐ 与 Issue 反馈。

<p align="center"><sub>Made with ❤️ for NJU · 记录学习，也记录把想法变成工具的过程</sub></p>
