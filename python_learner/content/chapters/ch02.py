# -*- coding: utf-8 -*-
"""第 3 章 列表简介"""

CHAPTER = {
    "id": "ch02",
    "title": "列表简介",
    "book_chapter": "第 3 章",
    "summary": "列表把一组相关数据放在一起，能按位置访问、增删、排序。",
    "sections": [
        {
            "heading": "列表是什么",
            "body": "列表用方括号 [] 表示，元素用逗号分隔，可以存任意类型（字符串、数字等）。列表通常取复数名。",
            "original": "列表由一系列按特定顺序排列的元素组成。你可以创建包含字母表中所有字母、数字 0~9 或所有家庭成员姓名的列表；也可以将任何东西加入列表中，其中的元素之间可以没有任何关系。鉴于列表通常包含多个元素，给列表指定一个表示复数的名称（如 letters、digits 或 names）是个不错的主意。在 Python 中，用方括号（[]）来表示列表，并用逗号来分隔其中的元素。",
            "code": """bicycles = ["trek", "cannondale", "redline"]
print(bicycles)""",
            "output": "['trek', 'cannondale', 'redline']",
        },
        {
            "heading": "访问列表元素",
            "body": "用 列表[索引] 访问单个元素，索引从 0 开始。负数索引从末尾往前数，-1 是最后一个元素。",
            "original": "列表是有序集合，因此要访问列表的任何元素，只需将该元素的位置或索引告诉 Python 即可。要访问列表元素，可指出列表的名称，再指出元素的索引，并将其放在方括号内。在 Python 中，第一个列表元素的索引为 0，而不是 1。通过将索引指定为 -1，可让 Python 返回最后一个列表元素。",
            "code": """bicycles = ["trek", "cannondale", "redline"]
print(bicycles[0].title())
print(bicycles[1])
print(bicycles[-1])""",
            "output": "Trek\ncannondale\nredline",
        },
        {
            "heading": "修改、添加和删除元素",
            "body": "修改：列表[索引]=新值。添加：append() 末尾追加，insert(位置,值) 指定位置插入。删除：del 按位置删，pop() 弹出末尾，remove(值) 按值删除。",
            "original": "你创建的大多数列表都将是动态的，这意味着列表创建后，将随着程序的运行增删元素。方法 append() 将元素添加到列表末尾，而不影响列表中的其他所有元素；方法 insert() 可在列表的任何位置添加新元素；如果知道要删除的元素在列表中的位置，可使用 del 语句；方法 pop() 可删除列表末尾的元素，并让你能够接着使用它；方法 remove() 只删除第一个指定的值。",
            "code": """cars = ["bmw", "audi"]
cars[0] = "benci"
cars.append("toyota")
cars.insert(1, "subaru")
print(cars)
last = cars.pop()
print(last, cars)
cars.remove("audi")
print(cars)""",
            "output": "['benci', 'subaru', 'audi', 'toyota']\ntoyota ['benci', 'subaru', 'audi']\n['benci', 'subaru']",
        },
        {
            "heading": "组织列表：排序",
            "body": "sort() 永久排序（加 reverse=True 反序）；sorted(列表) 临时排序不改变原列表；reverse() 反转顺序（不排序）；len() 求长度。",
            "original": "你创建的列表中，元素的排列顺序常常是无法预测的。方法 sort() 让你能够较为轻松地对列表进行排序。方法 sort() 永久性地修改了列表元素的排列顺序。要保留列表元素原来的排列顺序，同时以特定的顺序呈现它们，可使用函数 sorted()。要反转列表元素的排列顺序，可使用方法 reverse()。使用函数 len() 可快速获悉列表的长度。",
            "code": """names = ["charlie", "bob", "alice"]
print(sorted(names))
print(names)
names.sort()
print(names)
names.reverse()
print(names)
print(len(names))""",
            "output": "['alice', 'bob', 'charlie']\n['charlie', 'bob', 'alice']\n['alice', 'bob', 'charlie']\n['charlie', 'bob', 'alice']\n3",
        },
        {
            "heading": "避免索引错误",
            "body": "访问超出范围的索引会抛 IndexError。最后一个元素的索引是 len(列表)-1，或用 -1。对空列表取 -1 也会报错。",
            "original": "刚接触列表时，经常会遇到一种错误。假设你有一个包含三个元素的列表，却要求获取第四个元素。这将导致索引错误（IndexError）。请记住，每当需要访问最后一个列表元素时，都可使用索引 -1。仅当列表为空时，这种访问最后一个元素的方式才会导致错误。",
            "code": """items = ["a", "b", "c"]
print(items[2])
print(items[-1])
# print(items[3])  # 这行会报 IndexError""",
            "output": "c\nc",
        },
    ],
    "exercises": [
        {
            "id": "ch02-e1",
            "title": "姓名",
            "prompt": "把几个朋友的名字存进列表，分别打印每个人的名字（用索引逐个访问）。",
            "hint": "names[0]、names[1]……",
            "starter": "names = [\"Alice\", \"Bob\", \"Carol\"]\n# 逐个打印\n",
        },
        {
            "id": "ch02-e2",
            "title": "嘉宾名单",
            "prompt": "创建一个含若干客人姓名的列表，为每个名字打印一句邀请语。",
            "hint": "逐个用索引访问并拼接打印。",
            "starter": "guests = [\"Alice\", \"Bob\", \"Carol\"]\n# 打印邀请语\n",
        },
        {
            "id": "ch02-e3",
            "title": "修改嘉宾名单",
            "prompt": "某位客人不能来了，用列表[索引]=新值替换，再打印变更说明。",
            "hint": "guests[1] = \"Dave\"。",
            "starter": "guests = [\"Alice\", \"Bob\", \"Carol\"]\n# 替换一位并说明\n",
        },
        {
            "id": "ch02-e4",
            "title": "放眼世界",
            "prompt": "列出 5 个你想去的地方，分别用原顺序、sorted() 临时排序、sort() 永久排序、reverse() 反转各打印一次，最后打印当前长度。",
            "hint": "综合使用排序与反转方法。",
            "starter": "places = [\"Paris\", \"Tokyo\", \"New York\", \"Cairo\", \"Sydney\"]\n# 多种方式打印\n",
        },
        {
            "id": "ch02-e5",
            "title": "晚餐嘉宾人数",
            "prompt": "创建一个客人列表，用 len() 打印“我将邀请 X 位客人共进晚餐”。",
            "hint": "len(列表)。",
            "starter": "guests = [\"Alice\", \"Bob\", \"Carol\", \"Dave\"]\n# 打印人数\n",
        },
        {
            "id": "ch02-e6",
            "title": "尝试使用各个函数",
            "prompt": "创建一个列表，依次用 append、insert、del、pop、remove 操作它，每步都打印当前列表。",
            "hint": "每操作一步 print 一次。",
            "starter": "items = [\"a\", \"b\", \"c\"]\n# 依次练习各种增删方法\n",
        },
        {
            "id": "ch02-e7",
            "title": "负数索引",
            "prompt": "创建一个至少 4 个元素的列表，用负数索引打印最后两个元素。",
            "hint": "[-1] 和 [-2]。",
            "starter": "nums = [10, 20, 30, 40, 50]\n# 打印最后两个\n",
        },
    ],
}
