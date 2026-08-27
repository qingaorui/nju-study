# -*- coding: utf-8 -*-
"""第 10 章 文件和异常"""

CHAPTER = {
    "id": "ch09",
    "title": "文件和异常",
    "book_chapter": "第 10 章",
    "summary": "学会读写文件、用 try-except 处理错误，并用 json 保存数据。",
    "sections": [
        {
            "heading": "从文件中读取数据：整个文件",
            "body": "with open(路径) as f: 会在代码块结束后自动关闭文件。read() 读全部内容。",
            "original": "要使用文本文件中的信息，首先需要将信息读取到内存中。为此，你可以一次性读取文件的全部内容。关键字 with 在不再需要访问文件后将其关闭。有了 with，你只管打开文件，并在需要时使用它，Python 自会在合适的时候自动将其关闭。",
            "code": """with open("pi.txt") as f:
    content = f.read()
print(content)""",
            "output": "（pi.txt 的内容）",
        },
        {
            "heading": "逐行读取与文件路径",
            "body": "用 for line in f: 逐行读取，避免一次载入大文件。相对路径相对于当前工作目录，绝对路径从盘符开始。",
            "original": "读取文件时，常常需要检查其中的每一行。要以每次一行的方式检查文件，可对文件对象使用 for 循环。要让 Python 打开不与程序文件位于同一个目录中的文件，需要提供文件路径，它让 Python 到系统的特定位置去查找。",
            "code": """with open("pi.txt") as f:
    for line in f:
        print(line.rstrip())""",
            "output": "（逐行打印文件内容）",
        },
        {
            "heading": "写入文件：覆盖",
            "body": "open(路径,'w') 以写入模式打开（覆盖原内容），文件不存在会自动新建。注意 'w' 会清空原内容。",
            "original": "保存数据的最简单的方式之一是将其写入到文件中。通过将输出写入文件，即便关闭包含程序输出的终端窗口，这些输出也依然存在。在这个示例中，调用 open() 时提供了两个实参：第一个实参也是要打开的文件的名称，第二个实参（'w'）告诉 Python，我们要以写入模式打开这个文件。",
            "code": """with open("log.txt", "w") as f:
    f.write("hello\\n")
    f.write("world\\n")""",
            "output": "",
        },
        {
            "heading": "写入文件：追加",
            "body": "open(路径,'a') 是追加模式，在文件末尾添加内容而不覆盖。",
            "original": "如果你要给文件添加内容，而不是覆盖原有的内容，可以附加模式打开文件。你以附加模式打开文件时，Python 不会在返回文件对象前清空文件，而你写入到文件的行都将添加到文件末尾。",
            "code": """with open("log.txt", "a") as f:
    f.write("new line\\n")""",
            "output": "",
        },
        {
            "heading": "异常：try-except",
            "body": "用 try/except 捕获异常避免程序崩溃，如 ZeroDivisionError（除零）、FileNotFoundError（文件不存在）。",
            "original": "Python 使用被称为异常的特殊对象来管理程序执行期间发生的错误。每当发生让 Python 不知所措的错误时，它都会创建一个异常对象。如果你编写了处理该异常的代码，程序将继续运行；如果你未对异常进行处理，程序将停止，并显示一个 traceback。",
            "code": """try:
    result = 10 / 0
except ZeroDivisionError:
    print("不能除以 0！")""",
            "output": "不能除以 0！",
        },
        {
            "heading": "异常：else 与静默失败",
            "body": "else 代码块在 try 成功时执行。except 里写 pass 可“静默失败”，即出错时什么都不做。",
            "original": "通过将可能引发错误的代码放在 try-except 代码块中，可提高这个程序抵御错误的能力。依赖于 try 代码块成功执行的代码都应放到 else 代码块中。有时候，你希望程序在发生异常时一声不吭，可像通常那样编写 try-except 代码块，但在 except 代码块中明确地告诉 Python 什么都不要做。",
            "code": """try:
    result = 10 / 2
except ZeroDivisionError:
    pass
else:
    print(result)""",
            "output": "5.0",
        },
        {
            "heading": "存储数据：json",
            "body": "json.dump(数据,文件) 把数据写入文件，json.load(文件) 读回。适合保存用户设置、游戏进度等。",
            "original": "很多程序都要求用户输入某种信息，程序把用户提供的信息存储在列表和字典等数据结构中。一种简单的方式是使用模块 json 来存储数据。模块 json 让你能够将简单的 Python 数据结构转储到文件中，并在程序再次运行时加载该文件中的数据。",
            "code": """import json
data = {"name": "Tom", "age": 20}
with open("data.json", "w") as f:
    json.dump(data, f)
with open("data.json") as f:
    print(json.load(f))""",
            "output": "{'name': 'Tom', 'age': 20}",
        },
    ],
    "exercises": [
        {
            "id": "ch09-e1",
            "title": "学习笔记",
            "prompt": "写程序，把“我在学 Python”写入 note.txt，再读出来打印验证。",
            "hint": "open 写模式 + 读模式。",
            "starter": "text = \"我在学 Python\"\n# 写入并读回打印\n",
        },
        {
            "id": "ch09-e2",
            "title": "访客",
            "prompt": "让程序把一行问候（自拟）写入 guest.txt，然后读出来打印。",
            "hint": "写入固定内容即可。",
            "starter": "# 写问候到 guest.txt 并读回\n",
        },
        {
            "id": "ch09-e3",
            "title": "访客名单（追加）",
            "prompt": "用追加模式 'a' 向 guest.txt 写入一个新名字，再读出来打印。",
            "hint": "open(路径,'a')。",
            "starter": "# 追加一个名字并读回\n",
        },
        {
            "id": "ch09-e4",
            "title": "加法运算",
            "prompt": "让用户输入两个数做加法，用 try/except 捕获 ValueError（输入非数字）并提示。",
            "hint": "try 里 int(input(...))。",
            "starter": "# 加法并捕获输入错误\n",
        },
        {
            "id": "ch09-e5",
            "title": "猫和狗",
            "prompt": "尝试打开 cats.txt 和 dogs.txt 并打印内容，用 try/except 捕获 FileNotFoundError。",
            "hint": "except FileNotFoundError。",
            "starter": "# 打开两个文件并捕获缺失\n",
        },
        {
            "id": "ch09-e6",
            "title": "静默失败",
            "prompt": "尝试打开一个不存在的文件，用 except FileNotFoundError 里 pass 静默处理，程序照常结束。",
            "hint": "except FileNotFoundError: pass。",
            "starter": "# 静默处理文件不存在\n",
        },
        {
            "id": "ch09-e7",
            "title": "喜欢的数字（json）",
            "prompt": "用 json 把用户最喜欢的数存到 favorite.json，再读回来打印“你喜欢的数字是 X”。",
            "hint": "json.dump / json.load。",
            "starter": "import json\nnum = 7\n# 保存并读回\n",
        },
    ],
}
