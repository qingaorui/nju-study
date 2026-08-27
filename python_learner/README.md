# Python 学习助手

一款面向初学者的 Python 学习工具（桌面软件，Windows 可运行），参考书为《Python编程从入门到实践 第2版》。

## 功能

- **章节学习**：按书中第 1~11 章划分，每章含多个小节，点击可逐节学习（讲解 + 示例代码 + 原书 PDF 对应页）
- **内置编译器**：每个示例和练习都能直接在软件内运行，即时查看输出
- **练习题库**：约 70+ 道精选练习，覆盖书中经典"动手试一试"
- **DeepSeek 网页批改**：一键整理提示词并打开 DeepSeek 网页批改你的代码
- **PDF 阅读**：内置参考书 PDF 阅读器
- **大型项目**：外星人入侵、数据可视化、Web 应用三大项目，分步骤带起始代码
- **作业提交**：练习代码可保存，作业页可回看

## 运行

直接双击 `dist/Python学习助手.exe` 即可（无需安装 Python）。

- 首次启动稍慢（单文件需解压）
- 窗口基于系统自带的 Edge WebView2
- 内置"运行代码"功能需本机安装 Python 且在 PATH 中

## 开发与打包

```bash
pip install -r requirements.txt
python main.py            # 开发模式运行

# 打包为 exe
build.bat
# 或
python -m PyInstaller build.spec --noconfirm
```

## 目录结构

```
python_learner/
├── main.py              # 入口（Flask + PyWebView）
├── src/                 # 后端：服务、设置、存储、DeepSeek
├── content/             # 学习内容（每章一个文件）
│   ├── chapters/        #   第 1~11 章
│   ├── projects/        #   3 大项目
│   └── pdf_pages.py     #   小节→原书页码映射
├── web/                 # 前端界面
└── dist/                # 打包好的 exe
```
