# -*- coding: utf-8 -*-
"""第 1 章 起步"""

CHAPTER = {
    "id": "ch00",
    "title": "起步",
    "book_chapter": "第 1 章",
    "summary": "认识 Python、搭建编程环境，从终端运行你的第一个程序，并学会在交互式终端里试代码。",
    "sections": [
        {
            "heading": "认识 Python",
            "body": "Python 是一门简洁、易读的高级语言，语法接近自然语言，被广泛用于网站开发、数据分析、人工智能、自动化脚本等。本书基于 Python 3。",
            "original": "本书使用的 Python 版本是 Python 3。如果你使用的是 Python 2，请务必要安装 Python 3，因为本书的代码与 Python 3 相匹配。Python 是一种了不起的语言，值得花时间好好学习。",
            "code": """print("Hello Python world!")""",
            "output": "Hello Python world!",
        },
        {
            "heading": "搭建编程环境",
            "body": "需要安装 Python 解释器和一个文本编辑器/IDE。你已安装 PyCharm（配套 Python），也可以直接在 PyCharm 里创建 .py 文件并运行。",
            "original": "要开始学习 Python，你需要在计算机上搭建 Python 编程环境。你需要安装 Python，以及一个用于编写和运行代码的文本编辑器。本书推荐使用一个简单却功能强大的文本编辑器，你可以在其中编写代码并运行程序。",
            "code": """# 检查 Python 版本（在终端执行）
# python --version
# 输出类似：Python 3.13.x""",
            "output": "Python 3.13.x",
        },
        {
            "heading": "从终端运行 Python 程序",
            "body": "把代码写进 hello.py 文件，在终端执行 python hello.py 即可运行整个文件。PyCharm 里点右上角绿色三角等价于这个操作。",
            "original": "你编写的大多数程序都将直接在文本编辑器中运行，但有时候，从终端运行程序很有用。例如，你可能想直接运行既有的程序。在终端会话中，输入下面的命令来运行 hello_world.py：python hello_world.py。",
            "code": """# 保存为 hello.py，然后在终端运行：python hello.py
name = "Python"
print("欢迎学习 " + name)""",
            "output": "欢迎学习 Python",
        },
        {
            "heading": "在终端会话运行代码片段",
            "body": "在终端输入 python（不带文件名）进入交互式模式，逐行输入代码会立刻显示结果，适合快速验证想法。退出用 exit()。",
            "original": "在终端中运行 Python 代码片段很有用。要打开 Python 终端会话，可在终端窗口中执行命令 python。然后，你可以在提示符 >>> 后面输入要执行的代码。",
            "code": """# 交互式终端里逐行输入：
# >>> print("Hi")
# Hi
# >>> 2 + 3
# 5""",
            "output": "Hi\n5",
        },
        {
            "heading": "注释与代码风格",
            "body": "用 # 开头写注释，Python 会忽略它。注释用来解释“为什么这样做”。好的代码应清晰易读，Python 社区遵循 PEP 8 风格规范。",
            "original": "在大多数编程语言中，注释都是一项很有用的功能。随着你编写的程序越来越长，复杂度越来越高，你应该添加说明，对你解决问题的方法进行大致的阐述。注释让你能够使用自然语言在程序中添加说明。",
            "code": """# 计算圆的面积
radius = 3
area = 3.14 * radius ** 2
print(area)""",
            "output": "28.26",
        },
    ],
    "exercises": [
        {
            "id": "ch00-e1",
            "title": "我的第一行代码",
            "prompt": "写一行代码，打印出你自己的名字。",
            "hint": "print('你的名字')",
            "starter": "# 打印你的名字\n",
        },
        {
            "id": "ch00-e2",
            "title": "打印一句话",
            "prompt": "用 print 打印一句你想对未来的自己说的话，内容自拟。",
            "hint": "print 后面括号里写字符串。",
            "starter": "# 打印一句鼓励的话\n",
        },
        {
            "id": "ch00-e3",
            "title": "加注释",
            "prompt": "写一行打印语句，并在它上面加一行注释，说明这条语句的作用。",
            "hint": "注释以 # 开头。",
            "starter": "# 在这里加注释\nprint(\"...\")",
        },
        {
            "id": "ch00-e4",
            "title": "多行输出",
            "prompt": "连续用三个 print，分别打印数字 1、2、3，每个占一行。",
            "hint": "三个 print 语句即可。",
            "starter": "# 打印 1、2、3\n",
        },
    ],
}
