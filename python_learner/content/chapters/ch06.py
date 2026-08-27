# -*- coding: utf-8 -*-
"""第 7 章 用户输入和 while 循环"""

CHAPTER = {
    "id": "ch06",
    "title": "用户输入和 while 循环",
    "book_chapter": "第 7 章",
    "summary": "用 input() 获取用户输入，用 while 循环重复执行直到条件不满足。",
    "sections": [
        {
            "heading": "input() 获取输入",
            "body": "input('提示语') 会暂停并等待用户输入，返回的是字符串。注意：本软件的“本地运行”不等待输入，含 input 的练习建议在 PyCharm 里运行。",
            "original": "函数 input() 让程序暂停运行，等待用户输入一些文本。获取用户输入后，Python 将其存储在一个变量中，以方便你使用。函数 input() 接受一个参数：即要向用户显示的提示或说明，让用户知道该如何做。",
            "code": """name = input("你叫什么？ ")
print(f"你好，{name}！")""",
            "output": "你叫什么？ Tom\n你好，Tom！",
        },
        {
            "heading": "用 int() 处理数值输入",
            "body": "input() 返回字符串，做数字运算前要用 int()（整数）或 float()（浮点数）转换。",
            "original": "使用函数 input() 时，Python 将用户输入解读为字符串。如果你需要的是数字，就需要将字符串转换为数字，可使用函数 int()，它让 Python 将输入视为数值。",
            "code": """age = int(input("年龄？ "))
print(age >= 18)""",
            "output": "年龄？ 20\nTrue",
        },
        {
            "heading": "求模运算 %",
            "body": "a % b 返回 a 除以 b 的余数，常用于判断奇偶（n % 2 == 0 是偶数）或倍数。",
            "original": "处理数值信息时，求模运算符（%）是一个很有用的工具，它将两个数相除并返回余数。求模运算符不会指出一个数是另一个数的多少倍，而只指出余数是多少。如果一个数可被另一个数整除，余数就为 0，因此求模运算符将返回 0。",
            "code": """print(10 % 3)
print(6 % 2)""",
            "output": "1\n0",
        },
        {
            "heading": "while 循环基础",
            "body": "while 条件: 在条件为真时反复执行。要有一个能让条件最终变为假的“出口”，否则会无限循环。",
            "original": "for 循环用于针对集合中的每个元素都一个代码块，而 while 循环不断地运行，直到指定的条件不满足为止。你可以使用 while 循环来数数。",
            "code": """current = 1
while current <= 5:
    print(current)
    current += 1""",
            "output": "1\n2\n3\n4\n5",
        },
        {
            "heading": "让用户选择何时退出",
            "body": "结合 input() 和 while，让用户输入特定值（如 quit）退出循环。",
            "original": "可使用 while 循环让程序在用户愿意时不断地运行。我们定义了一个退出值，只要用户输入的不是这个值，程序就接着运行。",
            "code": """while True:
    city = input("城市（输入 quit 结束）：")
    if city == "quit":
        break
    print(f"我要去 {city}")""",
            "output": "（交互式示例，输入 quit 后结束）",
        },
        {
            "heading": "标志与 break / continue",
            "body": "标志（flag）是一个控制整个循环的布尔变量。break 立即退出循环；continue 跳过本轮、进入下一轮。",
            "original": "在前一个示例中，我们让程序在满足指定条件时就执行特定的任务。但在更复杂的程序中，很多不同的事件都会导致程序停止运行。此时可定义一个变量，用于判断整个程序是否处于活动状态，这个变量被称为标志。要立即退出 while 循环，不再运行循环中余下的代码，也不管条件测试的结果如何，可使用 break 语句。要返回到循环开头，并根据条件测试结果决定是否继续执行循环，可使用 continue 语句。",
            "code": """n = 0
while n < 10:
    n += 1
    if n % 2 == 0:
        continue
    print(n)""",
            "output": "1\n3\n5\n7\n9",
        },
        {
            "heading": "使用 while 处理列表和字典",
            "body": "用 while 在列表之间移动元素、删除列表中所有特定值，以及用输入填充字典。",
            "original": "到目前为止，我们每次都只处理了一项用户信息：获取用户的输入，再将输入打印出来或作出应答；循环再次运行时，我们获悉另一个输入值并作出响应。然而，要记录大量的用户和信息，需要在 while 循环中使用列表和字典。for 循环是一种遍历列表的有效方式，但在 for 循环中不应修改列表，否则将导致 Python 难以跟踪其中的元素。要在遍历列表的同时对其进行修改，可使用 while 循环。",
            "code": """items = ["a", "b", "c"]
while items:
    print("处理:", items.pop())
print(items)""",
            "output": "处理: c\n处理: b\n处理: a\n[]",
        },
    ],
    "exercises": [
        {
            "id": "ch06-e1",
            "title": "汽车租赁",
            "prompt": "提示用户输入想租的汽车品牌，打印“让我看看能不能帮你找到 X”。",
            "hint": "input + f 字符串。",
            "starter": "# 汽车租赁提示（含 input，建议在 PyCharm 运行）\n",
        },
        {
            "id": "ch06-e2",
            "title": "餐馆订位",
            "prompt": "询问用户用餐人数，用 int() 转换；超过 8 人打印“请稍等”，否则“有座位”。",
            "hint": "int(input(...)) 后 if 判断。",
            "starter": "# 订位判断\n",
        },
        {
            "id": "ch06-e3",
            "title": "10 的整数倍",
            "prompt": "让用户输入一个数，用 % 判断它是否是 10 的倍数并打印结果。",
            "hint": "n % 10 == 0。",
            "starter": "# 判断 10 的倍数\n",
        },
        {
            "id": "ch06-e4",
            "title": "比萨配料",
            "prompt": "用 while 循环提示输入配料，输入 quit 结束；每加一种就打印“会在比萨里加入：X”。",
            "hint": "break 退出 + input 交互。",
            "starter": "# 比萨配料循环（含 input）\n",
        },
        {
            "id": "ch06-e5",
            "title": "电影票",
            "prompt": "用 while 循环打印 1~5 号座位，每个座位提示“第 X 号座位已售”。",
            "hint": "计数器自增，条件 <=5。",
            "starter": "seat = 1\n# 打印座位\n",
        },
        {
            "id": "ch06-e6",
            "title": "熟食店（列表间移动）",
            "prompt": "有一个待处理订单列表，用 while 循环逐个 pop 出来打印“正在制作：X”，直到列表为空。",
            "hint": "while 列表名: + pop()。",
            "starter": "orders = [\"三明治\", \"披萨\", \"沙拉\"]\n# 逐项处理\n",
        },
        {
            "id": "ch06-e7",
            "title": "五香烟熏牛肉卖完了",
            "prompt": "从三明治列表里用 while 删除所有“五香烟熏牛肉”，再打印清理后的列表。",
            "hint": "while 值 in 列表: 列表.remove(值)。",
            "starter": "sandwiches = [\"培根\", \"五香烟熏牛肉\", \"火腿\", \"五香烟熏牛肉\"]\n# 删除指定配料\n",
        },
    ],
}
