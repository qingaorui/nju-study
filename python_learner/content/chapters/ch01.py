# -*- coding: utf-8 -*-
"""第 2 章 变量和简单数据类型"""

CHAPTER = {
    "id": "ch01",
    "title": "变量和简单数据类型",
    "book_chapter": "第 2 章",
    "summary": "学会把信息存进变量，并用字符串和数字做基本运算，这是后面所有内容的基础。",
    "sections": [
        {
            "heading": "变量：给数据起名字",
            "body": "变量是存储值的标签，第一次赋值时创建。变量名只能含字母、数字、下划线，不能以数字开头；应简短且有描述性。Python 里 = 是“赋值”，不是“等于”。",
            "original": "下面来尝试在 hello_world.py 中使用一个变量。我们添加了一个名为 message 的变量。每个变量都存储了一个值——与变量相关联的信息。在这里，存储的值为文本“Hello Python world!”。添加变量导致 Python 解释器需要做更多工作：先将变量 message 和文本关联起来，再让 print() 打印与变量相关联的值。变量名只能包含字母、数字和下划线，可以字母或下划线打头，但不能以数字打头。",
            "code": """message = "Hello Python world!"
print(message)

message = "Hello Python Crash Course world!"
print(message)""",
            "output": "Hello Python world!\nHello Python Crash Course world!",
        },
        {
            "heading": "字符串：用引号包起来的文本",
            "body": "字符串是一系列字符，用单引号或双引号包裹。用 .title() 把每个单词首字母大写，.upper() 全大写，.lower() 全小写。",
            "original": "字符串就是一系列字符。在 Python 中，用引号括起的都是字符串，其中的引号可以是单引号，也可以是双引号。对于字符串，可执行的最简单的操作之一是修改其中的单词的大小写。方法（method）是 Python 可对数据执行的操作。",
            "code": """name = "ada lovelace"
print(name.title())
print(name.upper())
print(name.lower())""",
            "output": "Ada Lovelace\nADA LOVELACE\nada lovelace",
        },
        {
            "heading": "在字符串中使用变量：f 字符串",
            "body": "f 字符串（格式字符串）用 f 开头，把变量名放在花括号 {} 里，即可把变量的值插入字符串。Python 3.6 起支持。",
            "original": "在很多情况下，你可能需要在字符串中使用变量的值。要在字符串中插入变量的值，可在前引号前加上字母 f，再将要插入的变量放在花括号内。这样，当 Python 显示字符串时，将把每个变量都替换为其值。这种字符串名为 f 字符串。f 是 format（设置格式）的简写。",
            "code": """first = "ada"
last = "lovelace"
full = f"{first} {last}"
print(full.title())
print(f"Hello, {full.title()}!")""",
            "output": "Ada Lovelace\nHello, Ada Lovelace!",
        },
        {
            "heading": "制表符与换行",
            "body": "用 \\t 表示制表符（缩进），\\n 表示换行。它们常用来让输出排版更整齐。",
            "original": "在编程中，空白泛指任何非打印字符，如空格、制表符和换行符。要在字符串中添加制表符，可使用字符组合 \\t；要在字符串中添加换行符，可使用字符组合 \\n。",
            "code": """print("Languages:\\n\\tPython\\n\\tJava\\n\\tC")""",
            "output": "Languages:\n\tPython\n\tJava\n\tC",
        },
        {
            "heading": "删除空白",
            "body": "strip() 去掉字符串两端空白，lstrip() 只去左侧，rstrip() 只去右侧。处理用户输入时很常用。",
            "original": "在程序中，额外的空白可能令人迷惑。Python 能够找出字符串开头和末尾多余的空白。要确保字符串末尾没有空白，可使用方法 rstrip()。你还可以剔除字符串开头的空白，或同时剔除字符串两端的空白，为此可分别使用方法 lstrip() 和 strip()。",
            "code": """lang = " python "
print(lang.strip())
print(lang.lstrip())
print(lang.rstrip())""",
            "output": "python\npython \n python",
        },
        {
            "heading": "数：整数与浮点数",
            "body": "整数(int)可做加减乘除与乘方 **。浮点数(float)带小数点，运算结果是浮点数，注意 4/2 结果是 2.0。用 str() 把数字转字符串才能拼接。",
            "original": "在编程中，经常使用数来记录游戏得分、表示可视化数据、存储 Web 应用信息等。Python 根据数的用法以不同的方式处理它们。在 Python 中，可对整数执行加（+）减（-）乘（*）除（/）运算。Python 将带小数点的数字都称为浮点数。",
            "code": """print(2 + 3)
print(3 ** 2)
print(0.1 + 0.2)

age = 23
print("我 " + str(age) + " 岁")""",
            "output": "5\n9\n0.30000000000000004\n我 23 岁",
        },
        {
            "heading": "下划线、多变量赋值与常量",
            "body": "数字可用下划线分组便于阅读（如 1_000_000 仍是 1000000）。可同时给多个变量赋值 a, b = 1, 2。常量习惯用全大写命名。",
            "original": "书写很大的数时，可使用下划线将其中的数字分组，使其更清晰易读：universe_age = 14_000_000_000。可在一行代码中给多个变量赋值：x, y, z = 0, 0, 0。常量是值在程序整个生命周期内都保持不变的变量，Python 程序员通常使用全大写来指出应将某个变量视为常量。",
            "code": """big = 1_000_000
print(big)
x, y, z = 0, 1, 2
print(x, y, z)
MAX_SPEED = 120
print(MAX_SPEED)""",
            "output": "1000000\n0 1 2\n120",
        },
        {
            "heading": "注释与 Python 之禅",
            "body": "注释用 # 开头，解释代码意图。在终端输入 import this 会显示“Python 之禅”（The Zen of Python）。",
            "original": "注释让你能够使用自然语言在程序中添加说明。在 Python 中，注释用井号（#）标识，井号后面的内容都会被 Python 解释器忽略。经验丰富的程序员倡导尽可能避繁就简，Python 社区的理念都包含在 Tim Peters 撰写的“Python 之禅”中。",
            "code": """# 这是注释，解释下面代码的作用
print("代码要优美，胜于丑陋")  # 行尾也可加注释""",
            "output": "代码要优美，胜于丑陋",
        },
    ],
    "exercises": [
        {
            "id": "ch01-e1",
            "title": "简单消息",
            "prompt": "把一条消息存进变量，再打印出来（例如 msg = \"我正在学 Python\"）。",
            "hint": "变量赋值后用 print 打印。",
            "starter": "msg = \"...\"\n# 打印变量\n",
        },
        {
            "id": "ch01-e2",
            "title": "个性化消息",
            "prompt": "把用户姓名存进变量，打印一条消息，如“你好，Eric，欢迎来学 Python！”。",
            "hint": "用 f 字符串把姓名变量嵌入。",
            "starter": "name = \"Eric\"\n# 用 f 字符串打印问候\n",
        },
        {
            "id": "ch01-e3",
            "title": "调整名字大小写",
            "prompt": "用变量存一个姓名，分别用 title()、upper()、lower() 打印三种形式。",
            "hint": "对字符串变量连续调用三个方法。",
            "starter": "name = \"eRIC maTThes\"\n# 打印三种形式\n",
        },
        {
            "id": "ch01-e4",
            "title": "剔除人名中的空白",
            "prompt": "定义一个两端有多余空格的名字，用 strip() 去掉后打印，并用 len() 对比去空白前后的长度。",
            "hint": "len() 看长度，strip() 去空白。",
            "starter": "name = \"  Eric  \"\n# 去空白并对比长度\n",
        },
        {
            "id": "ch01-e5",
            "title": "数字 8",
            "prompt": "写四行代码，分别用加减乘除让结果等于 8，并把每行结果打印出来。",
            "hint": "如 4+4、10-2、2*4、16/2。",
            "starter": "# 四则运算都得到 8\n",
        },
        {
            "id": "ch01-e6",
            "title": "最喜欢的数",
            "prompt": "把最喜欢的数存进变量，用 f 字符串打印“我最喜欢的数是 X”。",
            "hint": "数字可直接放进 f 字符串。",
            "starter": "num = 7\n# 打印这句话\n",
        },
        {
            "id": "ch01-e7",
            "title": "下划线与多变量赋值",
            "prompt": "用下划线写一个大数字（如 1_000_000）并打印；再用一行同时给两个变量赋值并打印。",
            "hint": "a, b = 1, 2。",
            "starter": "# 下划线数字 + 多变量赋值\n",
        },
    ],
}
