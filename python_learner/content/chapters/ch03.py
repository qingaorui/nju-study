# -*- coding: utf-8 -*-
"""第 4 章 操作列表"""

CHAPTER = {
    "id": "ch03",
    "title": "操作列表",
    "book_chapter": "第 4 章",
    "summary": "用 for 循环遍历列表，用 range 生成数列，并认识切片与元组。",
    "sections": [
        {
            "heading": "遍历整个列表",
            "body": "for 变量 in 列表: 依次取出每个元素。注意冒号和缩进：循环体必须缩进，缩进一致的代码属于同一代码块。",
            "original": "你经常需要遍历列表的所有元素，对每个元素执行相同的操作。例如，在游戏中，你可能需要将每个界面元素平移相同的距离；在网站中，你可能需要显示文章列表中的每个标题。对列表中的每个元素都执行相同的操作时，可使用 Python 中的 for 循环。",
            "code": """magicians = ["alice", "david", "carolina"]
for mag in magicians:
    print(f"{mag.title()}，这次表演太精彩了！")
print("谢谢大家！")""",
            "output": "Alice，这次表演太精彩了！\nDavid，这次表演太精彩了！\nCarolina，这次表演太精彩了！\n谢谢大家！",
        },
        {
            "heading": "避免缩进错误",
            "body": "Python 靠缩进判断代码块。忘记缩进会报 IndentationError；循环体外的代码被误缩进会被重复执行；不必要的缩进也会报错。",
            "original": "Python 根据缩进来判断代码行与前一个代码行的关系。Python 通过使用缩进让代码更易读。忘记缩进、忘记缩进额外的代码行、不必要的缩进、遗漏冒号都会引发错误。为避免意外缩进错误，请只缩进需要缩进的代码。",
            "code": """# 正确：循环体缩进，循环外不缩进
for n in [1, 2]:
    print(n)   # 属于循环
print("结束")   # 不属于循环""",
            "output": "1\n2\n结束",
        },
        {
            "heading": "创建数值列表：range",
            "body": "range(起始,结束) 生成到“结束前一个数”为止的数；list(range(...)) 可转成列表；可加步长 range(1,11,2)。",
            "original": "Python 函数 range() 让你能够轻松地生成一系列的数字。函数 range() 让 Python 从你指定的第一个值开始数，并在到达你指定的第二个值后停止，因此输出不包含第二个值。要创建数字列表，可使用函数 list() 将 range() 的结果直接转换为列表。",
            "code": """nums = list(range(1, 6))
print(nums)
print(list(range(2, 11, 2)))""",
            "output": "[1, 2, 3, 4, 5]\n[2, 4, 6, 8, 10]",
        },
        {
            "heading": "统计计算与列表解析",
            "body": "min()/max()/sum() 作用于数字列表。列表解析用一行代码生成列表：[表达式 for 变量 in range(...)]，简洁高效。",
            "original": "有几个专门用于处理数字列表的 Python 函数，例如，你可以轻松地找出数字列表的最大值、最小值和总和。列表解析让你能够生成所需列表，只需编写一行代码就能实现。列表解析将 for 循环和创建新元素的代码合并成一行，并自动附加新元素。",
            "code": """nums = list(range(1, 11))
print(min(nums), max(nums), sum(nums))
squares = [v ** 2 for v in range(1, 6)]
print(squares)""",
            "output": "1 10 55\n[1, 4, 9, 16, 25]",
        },
        {
            "heading": "使用列表的一部分：切片",
            "body": "切片 列表[起:止] 取子列表（含起不含止）；省略起点从 0 开始，省略终点到末尾；[::-1] 反转。",
            "original": "你还可以处理列表的部分元素——Python 称之为切片。要创建切片，可指定要使用的第一个元素和最后一个元素的索引。与函数 range() 一样，Python 在到达你指定的第二个索引前面的元素后停止。",
            "code": """players = ["a", "b", "c", "d", "e"]
print(players[:3])
print(players[2:])
print(players[::-1])""",
            "output": "['a', 'b', 'c']\n['c', 'd', 'e']\n['e', 'd', 'c', 'b', 'a']",
        },
        {
            "heading": "遍历切片与复制列表",
            "body": "可以只遍历列表的一部分：for x in 列表[:3]。复制列表用 列表[:]，直接用 = 赋值只是两个名字指向同一列表。",
            "original": "如果要遍历列表的部分元素，可在 for 循环中使用切片。要复制列表，可创建一个包含整个列表的切片，方法是同时省略起始索引和终止索引（[:]）。这让 Python 创建一个始于第一个元素、终止于最后一个元素的切片，即复制整个列表。",
            "code": """foods = ["pizza", "noodles", "rice"]
for f in foods[:2]:
    print(f)
copy = foods[:]
print(copy)""",
            "output": "pizza\nnoodles\n['pizza', 'noodles', 'rice']",
        },
        {
            "heading": "元组：不可变的列表",
            "body": "元组用 () 定义，元素不可修改，适合放不应变化的集合。要“修改”只能重新给整个变量赋值。",
            "original": "有时候你需要创建一系列不可修改的元素，元组可以满足这种需求。Python 将不能修改的值称为不可变的，而不可变的列表被称为元组。元组看起来犹如列表，但使用圆括号而不是方括号来标识。定义元组后，就可以使用索引来访问其元素，就像访问列表元素一样。",
            "code": """dimensions = (200, 50)
print(dimensions[0])
# dimensions[0] = 250  # 会报错：元组不可修改
dimensions = (400, 100)
print(dimensions)""",
            "output": "200\n(400, 100)",
        },
        {
            "heading": "设置代码格式",
            "body": "遵循 PEP 8：每行不超过 79 字符、用 4 个空格缩进（不要用 Tab）、运算符两侧留空格。",
            "original": "随着你编写的程序越来越长，有必要了解一些代码格式设置约定。若要提出 Python 语言修改建议，需要编写 Python 改进提案（PEP）。PEP 8 是最古老的 PEP 之一，它向 Python 程序员提供了代码格式设置指南。建议每级缩进都使用四个空格；建议每行不超过 80 个字符。",
            "code": """# 符合 PEP 8 的写法
for number in range(1, 4):   # 冒号后换行，缩进 4 空格
    print(number)            # 运算符两侧留空格""",
            "output": "1\n2\n3",
        },
    ],
    "exercises": [
        {
            "id": "ch03-e1",
            "title": "比萨",
            "prompt": "创建三种比萨列表，用 for 循环打印“我喜欢 X 比萨”，循环外再打印一句总结。",
            "hint": "循环体内 f 字符串，循环外 print。",
            "starter": "pizzas = [\"培根\", \"芝士\", \"水果\"]\n# 循环打印 + 总结\n",
        },
        {
            "id": "ch03-e2",
            "title": "数到 20",
            "prompt": "用 range 和 for 循环打印 1 到 20（含 20）。",
            "hint": "range(1, 21)。",
            "starter": "# 打印 1~20\n",
        },
        {
            "id": "ch03-e3",
            "title": "奇数",
            "prompt": "用 range 和 for 循环打印 1~20 之间的所有奇数。",
            "hint": "range(1, 21, 2)。",
            "starter": "# 打印 1~20 的奇数\n",
        },
        {
            "id": "ch03-e4",
            "title": "立方",
            "prompt": "用列表推导式生成 1~10 的立方（三次方）列表并打印。",
            "hint": "[x**3 for x in range(1, 11)]",
            "starter": "# 生成并打印立方列表\n",
        },
        {
            "id": "ch03-e5",
            "title": "切片",
            "prompt": "创建 1~9 的列表，打印前三个、中间三个、以及整个列表的反转。",
            "hint": "用切片和 [::-1]。",
            "starter": "items = list(range(1, 10))\n# 打印各切片\n",
        },
        {
            "id": "ch03-e6",
            "title": "你的比萨和我的比萨",
            "prompt": "创建一份比萨列表，用 列表[:] 复制一份，各自添加不同配料，打印证明是两个独立列表。",
            "hint": "用 [:] 复制，不能用 =。",
            "starter": "my_pizzas = [\"培根\", \"芝士\"]\n# 复制并各自添加\n",
        },
        {
            "id": "ch03-e7",
            "title": "自助餐",
            "prompt": "把一家餐厅的固定菜品存成元组，打印所有菜品；然后整体重新赋值换成新菜单再打印。",
            "hint": "元组不可改元素，但可整体重新赋值。",
            "starter": "menu = (\"宫保鸡丁\", \"麻婆豆腐\", \"鱼香肉丝\")\n# 打印并“更换”菜单\n",
        },
    ],
}
