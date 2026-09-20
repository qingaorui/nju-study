# 南哪儿课表 · NJU ClassMate

南京大学课表助手，HarmonyOS（ArkTS + Stage 模型）原生实现。

核心体验：**打开就是下一节课**。桌面和锁屏卡片常驻显示"下一节是什么课、几点、在哪"，
不需要打开 App、不需要解锁。

---

## 一、它是怎么拿到课表的

参考项目 [nju.app（南哪课表）](https://nju.app/) 的思路：**不碰接口，只读页面**。

```
用户点「一键导入」
   ↓
内置浏览器打开 https://authserver.nju.edu.cn/authserver/login?service=...ehallapp.nju.edu.cn/jwapp/sys/wdkb/...
   ↓
用户在官方页面上完成统一身份认证（应用全程不接触账号密码）
   ↓
跳到课表页 ehallapp.nju.edu.cn/jwapp/sys/wdkb/*default/index.do#/xskcb
   ↓
onPageEnd 检测到 URL 命中目标 → 注入 rawfile/njubksjw.js
   ↓
脚本读 DOM：`#dqxnxqkclb` 拿学期名，`table tbody tr` 逐行解析
   ↓
结果通过 window.njuBridge.postMessage() 回传原生（回传失败则退回 runJavaScript 返回值）
   ↓
存入本地 preferences → 让用户确认开学日期 → 刷新卡片 + 重建提醒
```

为什么不用 HTTP 直接请求教务系统：它挂在统一身份认证后面，
自己实现票据流转要处理加密参数和风控，既脆弱又踩线。
在真实浏览器里登录一次、读一次已经渲染好的表格，是成本最低、最稳、
也最尊重用户账号安全的方式。

**已适配的四个入口**（URL 与 nju.app 官方配置逐字对齐）：

| 入口 | 说明 |
| --- | --- |
| 本科生教务系统 | 推荐，走「我的课表」 |
| 本科生选课系统 | `xk.nju.edu.cn`，刚选完课时用 |
| 研究生教务系统 | `gsapp/sys/wdkbapp`，研院是独立界面 |
| 研究生选课系统 | `yjsxk.nju.edu.cn` |

想加别的学校（东南、上交……），只要往 `constants/SchoolConfig.ets` 的 `SCHOOL_LIST`
里加一条 + 放一个抓取脚本，主流程完全不用动。

---

## 二、功能清单

### 你明确要的

| 需求 | 实现 |
| --- | --- |
| 内置浏览器打开南大课表并读取 | `pages/ImportPage.ets` + `resources/rawfile/njubksjw.js`，登录后**自动**抓取，注册了重试（教务系统表格是异步渲染的），也留了「手动读取当前页」兜底 |
| 桌面小工具显示下一节课 | `form/pages/NextClassCard.ets`，2×2 / 2×4，显示课程名、第几节、起止时间、地点、教师、还有多久 |
| 锁屏小工具 | `form/pages/LockScreenCard.ets`，1×2 / 1×1，只需 API 18+ |
| 开机自启 | 见下方「三、关于开机自启」——这条在鸿蒙上有硬限制，我给了三条真实可行的替代路径 |
| 自动刷新 | 三层：卡片系统级定时刷新 + 持久化后台任务 + 前台 30 秒重算 |

### 我额外加的（按我认为的实用度排序）

| 功能 | 为什么加 |
| --- | --- |
| **上课提醒**（可调 5/10/15/20/30 分钟） | 用系统提醒代理 `reminderAgentManager`，应用被杀也会准时弹。这是课表类 App 唯一真正"救命"的功能 |
| **考试倒计时** | 教务系统那张表第 11 列本来就带考试时间，nju.app 抓了但没怎么用。白捡的信息，直接做成倒计时列表 + 考前一天 20:00 提醒 |
| **同时段多门课并排显示** | 南大「免修不免考」很常见，同一时段两门课不能只显示一门。周课表里同格并排 + 打「冲」角标，卡片上也会提示"同时段还有 N 门" |
| **导出 .ics 到系统日历** | 课表 App 只能解决"看"，导进日历之后手表震动、平板、电脑全都能收到。投入产出比最高、又几乎没人做的功能 |
| **自由时间课程单独归类** | 「自由时间」的课没有固定时间地点，塞进网格会把整张表搞乱，单独列一栏更清爽 |
| **周次压缩显示** | 把 `[1,2,3,10,11,12,13]` 显示成「1-3, 10-13 周」，课程详情里一眼看懂 |
| **作息时间可校准** | 各校区/夏令时不同，作息表做成可改的。发现卡片时间整体偏移，一键恢复默认再核对 |
| **备份导出 / 恢复** | 换手机、换学期不用重新登录一遍教务系统 |
| **今日卡片自动顶上明天** | 今天没课时不显示"今天没有课"这种废话，直接把明天的课顶上来 |

### 顺手做掉的

- 周课表按课程号稳定哈希配色，同一门课每次打开颜色一样
- 未开学 / 假期 / 学期末都有明确状态，不会显示空白或"NaN"
- 卡片不设背景色、文字用系统色，深浅色模式自动适配
- 卡片预留了精确刷新时刻：不是每 5 分钟无脑刷，而是算准"状态即将变化"的那一刻再刷
- **卡片上的「明天」按钮**：今日课表卡片右上角点一下就能切到明天，不用打开 App
- **卡片上的「刷新」按钮**：改完设置或觉得数据旧了，在卡片上直接刷

### 作息校准页（`pages/SlotEditorPage.ets`）

这一条其实是**核心正确性的根基**，不只是个设置项：

课表里存的只是"第几节"，而卡片上显示的"几点几分"完全由作息表换算而来。
作息一旦不对，所有课的时间整体偏移，但界面本身看不出哪里错了——这是最难自查的一类问题。

所以给了两条修正路径：

| 路径 | 适用情况 |
| --- | --- |
| **整体平移**（提前/延后 5 或 10 分钟，一键） | 所有课都偏了同一个量。夏令时、校区差异、班次微调基本都是这种，一次点掉 |
| **逐节微调**（点某一节的开始/结束时间单独改） | 只有某一节不对 |

改完立即回写设置、重算卡片、重排提醒，不用再手动同步一次。

---

## 三、关于「开机自启」——必须说清楚的一件事

**HarmonyOS NEXT 上，三方普通应用无法监听开机广播自启。**

`StaticSubscriberExtensionAbility` 的静态订阅能力主要面向系统应用和企业 MDM 托管应用。
我照样把 `staticsubscriber/BootSubscriber.ets` 写好了、`module.json5` 也配好了——
但你要知道它在普通设备上**不会被调用**，别指望它。

真正让"开机后课表照常工作"的是下面三条，而且这三条已经覆盖了全部实际需求：

1. **桌面卡片由系统恢复渲染。**
   重启后桌面会被重建，卡片提供方（`FormExtensionAbility`）被拉起，
   数据本来就在本地 preferences 里，卡片一渲染就是对的——这就是事实上的"开机自启"。

2. **后台任务是持久化的。**
   `WorkScheduler` 注册时带 `isPersisted: true`，任务写进系统，
   重启后系统自动恢复，到点拉起 `RefreshWorkAbility` 重算周次、刷新卡片、重排提醒。

3. **上课提醒走系统提醒代理。**
   `reminderAgentManager` 登记的是系统级提醒，重启后照样准时弹，完全不依赖应用存活。

如果还想更激进，让用户自己在
**设置 → 应用启动管理 → 南哪儿课表** 里打开「允许自启动 / 允许关联启动 / 允许后台活动」。
这一条我在设置页里写了引导文案。

---

## 四、架构

```
┌──────────────────────────── 表现层 ────────────────────────────┐
│  pages/Index.ets          下一节课大卡片 + 今日时间线 + 周课表 + 考试 │
│  pages/ImportPage.ets     内置浏览器 + 自动抓取                    │
│  pages/SettingsPage.ets   学期/提醒/后台/卡片/数据/关于             │
│  view/WeekGrid.ets        周课表网格（绝对定位 + 冲突并排）          │
└───────────────────────────────┬────────────────────────────────┘
                                │
┌──────────────────────────── 服务层 ────────────────────────────┐
│  NextClassEngine.ets    ★ 核心：算"下一节课"                      │
│  Extractor.ets            注入脚本 + 结果解析（含 bridge 通道）      │
│  CourseStore.ets          preferences 持久化 + 备份/恢复            │
│  WidgetService.ets        卡片数据构造（同步版给 onAddForm）        │
│  ReminderService.ets      提醒队列整体重建                         │
│  ExportService.ets        备份 JSON / 导出 .ics                   │
│  WorkSchedulerHelper.ets  后台任务注册 + 兜底刷新                  │
│  AppBootstrap.ets         三条入口共用的初始化与收口                │
└───────────────────────────────┬────────────────────────────────┘
                                │
┌──────────────────────────── 系统能力 ──────────────────────────┐
│  FormKit(卡片)  BackgroundTasksKit(提醒+后台任务)  ArkWeb(内置浏览器) │
│  ArkData(preferences)  CoreFileKit(文件选择/保存)  ArkTS(编解码)     │
└───────────────────────────────────────────────────────────────┘
```

### 内存里一个有意思的设计：`buildSync`

`FormExtensionAbility.onAddForm` 是**同步**回调，必须立刻返回数据，不能 await。
所以 `WidgetService` 提供一个用 `preferences.getPreferencesSync` / `getSync`
的同步版本，把课表读出来现算；异步的 `refreshAllForms` 则用于课表变更后主动推更新。
这一条如果搞错，表现就是"卡片一直是空的、但也不报错"，非常难查。

### 卡片为什么用扁平槽位而不是数组绑定

ArkTS 卡片对 `Record<string, Object>` 里混装数组的类型推断很挑，
类型对不上时卡片**不报错、只显示空白**。`TodayCard` 因此用 6 个固定槽位
（`s0Time` / `s0Name` / `s0Loc` / `s0State` …），一天最多 6 节封顶完全够用。
用一点啰嗦换取确定性，值得。

---

## 五、目录结构

```
NJUClassMate/
├── AppScope/
│   ├── app.json5
│   └── resources/base/{element/string.json, media/app_icon.png}
├── entry/
│   ├── build-profile.json5 / hvigorfile.ts / oh-package.json5 / obfuscation-rules.txt
│   └── src/main/
│       ├── module.json5                  ★ 卡片/后台任务/静态订阅/权限声明
│       ├── ets/
│       │   ├── entryability/EntryAbility.ets
│       │   ├── pages/{Index, ImportPage, SettingsPage, SlotEditorPage}.ets
│       │   ├── view/WeekGrid.ets
│       │   ├── form/
│       │   │   ├── FormCommon.ets             卡片共用工具
│       │   │   ├── NextClassFormAbility.ets
│       │   │   ├── TodayFormAbility.ets
│       │   │   ├── LockScreenFormAbility.ets
│       │   │   └── pages/{NextClassCard, TodayCard, LockScreenCard}.ets
│       │   ├── work/RefreshWorkAbility.ets
│       │   ├── staticsubscriber/BootSubscriber.ets
│       │   ├── service/
│       │   │   ├── NextClassEngine.ets  ★ 下一节课计算引擎
│       │   │   ├── Extractor.ets
│       │   │   ├── CourseStore.ets
│       │   │   ├── WidgetService.ets
│       │   │   ├── ReminderService.ets
│       │   │   ├── ExportService.ets
│       │   │   ├── WorkSchedulerHelper.ets
│       │   │   └── AppBootstrap.ets
│       │   ├── model/Course.ets
│       │   ├── constants/SchoolConfig.ets     ★ 南大 URL + 作息表
│       │   └── common/{DateUtil, Logger}.ets
│       └── resources/
│           ├── base/element/{string, color}.json
│           ├── base/media/{app_icon, background, foreground, startIcon}.png + layered_image.json
│           ├── base/profile/{main_pages, form_config, form_today_config,
│           │                 form_lock_config, static_subscriber_config}.json
│           ├── dark/element/color.json
│           ├── zh_CN, en_US/element/string.json
│           └── rawfile/                    ★ 注入到教务系统页面的抓取脚本
│               ├── njubksjw.js             本科教务系统（DOM 表格）
│               ├── njubksxk.js             本科选课系统（DOM div 布局）
│               ├── njuyjsjw.js             研究生教务系统（同步 XHR 调 JSON 接口）
│               └── njuyjsxk.js             研究生选课系统（页面本身就是 JSON）
├── tools/
│   ├── gen_icons.py             生成图标（纯标准库，不依赖 Pillow）
│   ├── test_extractor.js        本科教务系统抓取脚本离线单测（28 项）
│   ├── test_extractors_extra.js 另外三个入口的抓取脚本离线单测（66 项）
│   ├── engine_test.ts           引擎单测模板（63 项）
│   ├── prepare_engine_test.py   把 ArkTS 预处理成 Node 能跑的 TS
│   ├── run_tests.sh             一键跑全部测试（不需要模拟器）
│   ├── build_and_install.sh     一键构建 / 出包 / 安装到手机
│   ├── check_phone.py           检查手机有没有连上、是哪种模式（不依赖 hdc）
│   └── find_harmony_toolchain.py 排查：机器上到底有没有鸿蒙工具链
├── docs/
│   ├── 设计文档.html            可视化设计文档（卡片效果图 / 数据流 / 架构）
│   └── 安装到手机.md            从零装 DevEco 到装进手机的完整步骤 + 报错对照表
├── build-profile.json5 / hvigorfile.ts / oh-package.json5
└── hvigor/hvigor-config.json5
```

---

## 六、跑起来

> **想把 App 装到手机上？看 [`docs/安装到手机.md`](docs/安装到手机.md)。**
> 里面写了工具链要求、签名配置、手机开发者模式怎么开，以及一张常见报错对照表。
> 里面也解释了**为什么没法直接把安装包发给你**（鸿蒙的签名链，绕不过去）。
>
> 装好 DevEco Studio 之后，一条命令完成构建；出包或安装都行：
>
> ```bash
> bash tools/build_and_install.sh                  # 构建 + 安装到手机
> bash tools/build_and_install.sh --package-only   # 只出安装包，产物在 dist/
> bash tools/build_and_install.sh --list           # 只看工具链位置和已连接设备
> ```

**⚠️ 先确认手机的鸿蒙版本**——这决定一切：

| 手机系统 | 能装吗 | 原因 |
| --- | --- | --- |
| HarmonyOS NEXT / 5.x / 6.x | ✅ 能 | 纯血鸿蒙，只认 HAP，正是本工程的形态 |
| HarmonyOS 4.x 或更早 | ❌ 不能 | 兼容版鸿蒙最高只到 API 10，本工程要求 API 12+；锁屏卡片更是 API 18 才有的能力 |

HarmonyOS 4 用户可以走 `设置 → 关于本机 → 检查更新`，看能不能升到 NEXT。
升不了的话需要降级重写（做不了锁屏卡片），细节见安装文档的「第零步」。

**其余硬要求**：HAP 必须签名，签名必须用华为开发者账号，
所以需要 **DevEco Studio（≥ 5.1.0）+ HarmonyOS SDK（内嵌在 DevEco 里）+ 华为开发者账号**。

### 编译运行

1. DevEco Studio 打开 `NJUClassMate` 目录（工程根目录，能看到 `AppScope` 的那一层）
2. `File → Project Structure → Signing Configs` 勾选 **Automatically generate signature**
3. 选真机（**锁屏卡片要求 API 18+ / HarmonyOS 5.1 及以上**，模拟器不支持锁屏卡片）
4. Run

`build-profile.json5` 里当前设置：

```
compileSdkVersion   : 5.1.0(18)
compatibleSdkVersion: 5.0.0(12)
targetSdkVersion    : 5.1.0(18)
```

> 如果不需要锁屏卡片，把 `compatibleSdkVersion` 保持 12 也能编译；
> 但锁屏卡片的 `renderingMode` 字段在 API 18 之后配置方式有过调整，
> **请以你本地 SDK 的 DevEco 自动补全提示为准核对一次**
> `entry/src/main/resources/base/profile/form_lock_config.json`。

### 首次使用

1. 打开 App → 「一键导入课表」→ 选一个入口 → 登录
2. 停在「我的课表」页面，等它自动读取（失败会重试 4 次，也可以点「手动读取当前页」）
3. 弹出日期选择器，选**本学期第一周的任意一天**（会自动归到那一周的周一）
4. 长按桌面图标 → 卡片 → 添加「下一节课」「今日课表」
5. 锁屏上双手捏合进入编辑态 → 添加「下一节课（锁屏）」

### 一键跑测试

```bash
bash tools/run_tests.sh
```

不用开模拟器、不用连真机，在电脑上就能验证两块最关键的逻辑。

---

## 七、测试

这套工程的思路是：**把"改版风险最高"和"边界最多"的两块逻辑从 UI 里剥出来，单独测。**
一共 **157 项断言**，`bash tools/run_tests.sh` 一键跑完，不需要模拟器、真机或教务系统账号。

| 测试 | 覆盖 | 结果 |
| --- | --- | --- |
| `tools/test_extractor.js`<br><span>本科教务系统</span> | 周次（单/双/间断/区间）、一门课多时段、自由时间、表头跳过、异常兜底、bridge 通道 | **28 / 28** |
| `tools/test_extractors_extra.js`<br><span>另外三个入口</span> | 选课系统的动态列表头识别 + 纯文本单元格兜底、研究生教务的接口调用与学期选取、研究生选课的纯 JSON 页面、三个脚本的 bridge 通道 | **66 / 66** |
| `tools/engine_test.ts`<br><span>下一节课计算引擎</span> | 周次计算、单日课表、课前/课中/课间/跨天/周末/未开学、冲突检测、考试解析、空课表 | **63 / 63** |

### 测试实际抓到过什么

不是"写了测试然后全绿"，下面这几个是真跑出来的问题：

1. **三个入口引用了不存在的脚本。** `SCHOOL_LIST` 里配了 4 个 entry，
   但 rawfile 里只有 1 个脚本 —— 另外 3 个入口点下去必然报"网络错误"，
   排查方向完全被误导。现在 4 个脚本都补齐了。
2. **选课系统的"时间地点"格如果只有纯文本、没有子 div，整行会被丢掉。**
   现在是"拿不到子元素就把这一格当作一段"。
3. **两个脚本的正则只认「星期五」，不认「周五」。** 一种写法变了就整份课表读不出来。
4. **研究生教务的学期选取靠 `terms[0]`**，一旦接口的排序方向变了就会抓到最老的学期。
   现在改成按「学年 + 学期序号」算出日期区间、选中包含今天的那一个。

为什么值得这么做：教务系统改版时，最先坏的就是 DOM 选择器和正则；
而"下一节课"的边界多到在真机上根本守不完——你得等到某一节课正好开始才能验证一次状态翻转。
造个假 DOM、stub 掉 XHR、固定住系统时间，这两个问题就都变成了秒级回归。

---

## 八、已知限制

1. **默认作息是"常见值"，第一次用请核对一次。**
   `DEFAULT_TIME_SLOTS` 给的是仙林本科班次（第 1 节 08:00 起）。
   南大各校区、各学期、研究生班次可能不同，夏令时也可能整体挪。
   **导入后对着自己的课表看一眼**——如果卡片时间整体偏移，问题 99% 出在这里，
   到「设置 → 作息时间表 → 整体平移」一次改掉即可。

2. **另外三个入口的抓取脚本来自社区，我没有账号做真机验证。**
   本科生选课 / 研究生教务 / 研究生选课这三份的解析规则取自
   [NJU-Class-Shedule-Flutter](https://github.com/idealclover/NJU-Class-Shedule-Flutter)，
   我按它的规则重写并补了离线测试（66 项断言），顺手修了其中三个 bug
   （单双周奇偶性、正则不认「周五」、研究生选课把 courses 序列化成字符串）。
   但**真实的教务系统页面我没法验证**——如果你走这三个入口遇到问题，日志里会有明确的
   失败阶段（`findHead` / `fetchTerms` / `readBody` / `emptyCourses`），照着定位会很快。

3. **锁屏卡片的 `renderingMode` 配置方式在 API 18 之后有调整。**
   当前按经典写法配在 `form_lock_config.json` 顶层，编译报错时以本地 SDK 提示为准。

4. **抓取依赖教务系统的页面结构。**
   ehall 改版会让 `#dqxnxqkclb` 或 `table tbody` 失效。
   脚本里加了多级兜底和明确的错误分阶段提示（`findTable` / `emptyTable` / `emptyCourses`），
   出问题时能快速定位。改版后只需要改对应的一个 `.js` 文件，然后跑 `run_tests.sh` 回归。

5. **登录不自动。**
   统一身份认证必须人工输入，应用不会代填、不会保存密码。
   代价是每次重新导入要登录一次（Cookie 会保留一段时间）。

6. **`BootSubscriber` 在普通设备上不会被触发。** 见第三节，这是平台限制，不是实现问题。

---

## 九、后续可以做的

- **作息表逐节可编辑**：现在是整表恢复默认，理想是按校区预设 + 手动微调
- **课表分享**：生成图片/链接分享给同学；或者反向做「同班同学课表对比」找共同空课时间
- **空教室查询**：ehall 本身有空教室查询，可以再写一个注入脚本接到同一个导入框架里
- **蹭课推荐**：基于公开课表数据做"这门课这周讲了什么"
- **桌面卡片长按快捷切周次**：`onFormEvent` 已经接好了，加两个按钮即可

---

## 致谢

课表解析规则与教务系统 URL 配置参考了开源项目
[NJU-Class-Shedule-Flutter](https://github.com/idealclover/NJU-Class-Shedule-Flutter)（南哪课表）
的公开实现，特此致谢。

本项目只读取用户自己有权查看的课表数据，全部保存在本机，不向任何服务器上传。
