# -*- coding: utf-8 -*-
"""第 5 章 if 语句"""

CHAPTER = {
    "id": "ch04",
    "title": "if 语句",
    "book_chapter": "第 5 章",
    "summary": "用条件判断让程序根据不同情况做不同事情。",
    "sections": [
        {
            "heading": "条件测试：相等与不相等",
            "body": "用 == 判断相等（区分大小写），!= 判断不等。注意 = 是赋值，== 才是比较。比较结果是一个布尔值 True/False。",
            "original": "每条 if 语句的核心都是一个值为 True 或 False 的表达式，这种表达式被称为条件测试。Python 根据条件测试的值为 True 还是 False 来决定是否执行 if 语句中的代码。检查是否相等时使用两个等号（==），一个等号是赋值。检查是否不相等使用感叹号和等号（!=）。",
            "code": """car = "bmw"
print(car == "bmw")
print(car == "audi")
print(car != "audi")""",
            "output": "True\nFalse\nTrue",
        },
        {
            "heading": "条件测试：数值比较",
            "body": "可用 <、<=、>、>= 比较数字。配合 and（同时满足）和 or（满足其一）组合多个条件。",
            "original": "检查数值非常简单，例如，下面的代码检查一个人是否到 18 岁：age == 18。你还可以检查两个条件都为 True 时才执行相应的操作，可使用关键字 and；关键字 or 让你能够检查多个条件，只要至少有一个条件满足，就能通过整个测试。",
            "code": """age = 18
print(age == 18)
print(age > 21)
print(age >= 18 and age < 65)
print(age < 12 or age > 60)""",
            "output": "True\nFalse\nTrue\nFalse",
        },
        {
            "heading": "检查特定值是否在列表中",
            "body": "用 in 判断值是否在列表中，not in 判断不在。常用来检查用户名是否被占用、配料是否已选。",
            "original": "有时候，执行操作前必须检查列表是否包含特定的值。要判断特定的值是否已包含在列表中，可使用关键字 in。还有些时候，确定特定的值未包含在列表中很重要，可使用关键字 not in。",
            "code": """guests = ["alice", "bob"]
print("carol" in guests)
print("carol" not in guests)""",
            "output": "False\nTrue",
        },
        {
            "heading": "简单的 if 与 if-else",
            "body": "if 条件为真才执行；if-else 在两个分支中二选一，必执行一个。",
            "original": "最简单的 if 语句只有一个测试和一个操作。经常需要在条件测试通过时执行一个操作，并在没有通过时执行另一个操作，此时可使用 if-else 语句。if-else 结构适合让 Python 执行两种操作之一的情形。",
            "code": """age = 17
if age >= 18:
    print("可以投票")
else:
    print("还不能投票")""",
            "output": "还不能投票",
        },
        {
            "heading": "if-elif-else 多分支",
            "body": "elif 是“否则如果”，可串联多个；else 是兜底，可省略。互斥的条件用 elif，彼此独立的多个条件应写多个 if。",
            "original": "经常需要检查超过两个的情形，为此可使用 Python 提供的 if-elif-else 结构。Python 只执行 if-elif-else 结构中的一个代码块，它依次检查每个条件测试，直到遇到通过了的条件测试。Python 并不要求 if-elif 结构后面必须有 else 代码块。",
            "code": """age = 12
if age < 4:
    price = 0
elif age < 18:
    price = 25
else:
    price = 40
print(f"票价：{price}")""",
            "output": "票价：25",
        },
        {
            "heading": "使用 if 处理列表：特殊元素",
            "body": "遍历列表时用 if 检查特殊元素（如缺货的配料），对它单独处理。",
            "original": "通过结合使用 if 语句和列表，可完成一些有趣的任务：对列表中特定的值做特殊处理；高效地管理不断变化的情形，如餐馆是否还有特定的食材；证明代码在各种情形下都将按预期那样运行。",
            "code": """toppings = ["mushrooms", "cheese", "green peppers"]
for t in toppings:
    if t == "green peppers":
        print("抱歉，青椒卖完了")
    else:
        print(f"加入 {t}")""",
            "output": "加入 mushrooms\n加入 cheese\n抱歉，青椒卖完了",
        },
        {
            "heading": "确定列表非空与多个列表",
            "body": "if 列表名: 在列表非空时为真。处理前先判断是否为空，为空给出提示。多个列表可互相检查。",
            "original": "到目前为止，对于处理的每个列表都做了一个简单的假设，即假设它们都至少包含一个元素。但是如果列表为空，就需要做出不同处理。在 if 语句中将列表名用在条件表达式中时，Python 将在列表至少包含一个元素时返回 True，并在列表为空时返回 False。",
            "code": """orders = []
if orders:
    for o in orders:
        print(o)
else:
    print("没有订单")""",
            "output": "没有订单",
        },
    ],
    "exercises": [
        {
            "id": "ch04-e1",
            "title": "条件测试",
            "prompt": "写至少 5 个条件测试，每个都打印结果和预测，例如判断 10 是否大于 5。",
            "hint": "用 ==、!=、>、<、>=、<=。",
            "starter": "# 写多个条件测试并打印\n",
        },
        {
            "id": "ch04-e2",
            "title": "外星人颜色 1",
            "prompt": "定义 alien_color，若颜色是绿色打印“获得 5 分”。",
            "hint": "if + ==。",
            "starter": "alien_color = \"green\"\n# 判断并加分\n",
        },
        {
            "id": "ch04-e3",
            "title": "外星人颜色 2",
            "prompt": "在上一题基础上加 else：绿色得 5 分，否则得 10 分。分别用绿色和非绿色测试。",
            "hint": "if-else。",
            "starter": "alien_color = \"green\"\n# if-else 加分\n",
        },
        {
            "id": "ch04-e4",
            "title": "外星人颜色 3",
            "prompt": "用 if-elif-else 按颜色给分：绿色 5 分、黄色 10 分、红色 15 分。",
            "hint": "elif 判断黄色，else 红色。",
            "starter": "alien_color = \"yellow\"\n# 三种颜色分支\n",
        },
        {
            "id": "ch04-e5",
            "title": "人生的不同阶段",
            "prompt": "根据年龄打印阶段：<2 婴儿，<4 幼儿，<13 儿童，<20 青少年，<65 成年人，否则老年人。",
            "hint": "if-elif-else 链式判断。",
            "starter": "age = 30\n# 打印阶段\n",
        },
        {
            "id": "ch04-e6",
            "title": "以特殊方式跟管理员打招呼",
            "prompt": "创建用户名列表，遍历它：是 admin 打印特殊问候，否则打印普通问候。",
            "hint": "循环内 if 判断 admin。",
            "starter": "users = [\"admin\", \"alice\", \"bob\"]\n# 遍历并区分问候\n",
        },
        {
            "id": "ch04-e7",
            "title": "检查用户名",
            "prompt": "模拟注册：已有用户名列表，判断一个新名字是否被占用，被占用则提示“请换一个”。",
            "hint": "用 not in 判断。",
            "starter": "current = [\"admin\", \"alice\", \"bob\"]\nname = \"alice\"\n# 判断是否可用\n",
        },
    ],
}
