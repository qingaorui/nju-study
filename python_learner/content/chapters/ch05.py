# -*- coding: utf-8 -*-
"""第 6 章 字典"""

CHAPTER = {
    "id": "ch05",
    "title": "字典",
    "book_chapter": "第 6 章",
    "summary": "字典用“键-值对”存储相关联的信息，适合表示有属性的对象。",
    "sections": [
        {
            "heading": "一个简单的字典",
            "body": "字典用 {} 定义，键与值用 : 分隔，键值对之间用逗号分隔。用 字典[键] 取值，键不存在会报 KeyError。",
            "original": "下面来编写一个简单的字典，它存储有关特定外星人的信息。在 Python 中，字典是一系列键-值对。每个键都与一个值相关联，你可以使用键来访问与之相关联的值。与键相关联的值可以是数字、字符串、列表乃至字典。事实上，可将任何 Python 对象用作字典中的值。",
            "code": """alien = {"color": "green", "points": 5}
print(alien["color"])
print(alien["points"])""",
            "output": "green\n5",
        },
        {
            "heading": "添加与修改键值对",
            "body": "字典是动态结构，可随时添加键值对：字典[新键]=值。修改已有键的值同样是 字典[键]=新值。",
            "original": "字典是一种动态结构，可随时在其中添加键-值对。要添加键-值对，可依次指定字典名、用方括号括起的键和相关联的值。要修改字典中的值，可依次指定字典名、用方括号括起的键以及与该键相关联的新值。",
            "code": """alien = {"color": "green", "points": 5}
alien["x"] = 0
alien["color"] = "yellow"
print(alien)""",
            "output": "{'color': 'yellow', 'points': 5, 'x': 0}",
        },
        {
            "heading": "删除键值对与空字典",
            "body": "用 del 字典[键] 永久删除。空字典用 {} 表示，常用来等用户输入后再填充。",
            "original": "对于字典中不再需要的信息，可使用 del 语句将相应的键-值对彻底删除。有时候，在空字典中添加键-值对是为了方便，而有时候必须这样做。为此，可先使用一对空的花括号定义一个字典，再分行添加各个键-值对。",
            "code": """alien = {"color": "green", "points": 5}
del alien["points"]
print(alien)""",
            "output": "{'color': 'green'}",
        },
        {
            "heading": "由类似对象组成的字典",
            "body": "字典也适合存同一类对象的多个属性，比如一个人的多种信息。",
            "original": "在前面的示例中，字典存储的是一个对象（游戏中的一个外星人）的多种信息，但你也可以使用字典来存储众多对象的同一种信息。例如，如果要存储很多人的最喜欢的一种编程语言，你可以这样做：favorite_languages = {'jen': 'python', 'sarah': 'c'}。",
            "code": """person = {"first": "eric", "last": "matthes", "age": 20}
print(person["first"].title())""",
            "output": "Eric",
        },
        {
            "heading": "遍历字典：键值对",
            "body": "for k, v in 字典.items(): 同时遍历键和值。变量名可任意，但通常用有意义的命名。",
            "original": "一个 Python 字典可能只包含几个键-值对，也可能包含数百万个键-值对。鉴于字典可能包含大量的数据，Python 支持对字典遍历。要编写用于遍历字典的 for 循环，可声明两个变量，用于存储键-值对中的键和值。方法 items() 返回一个键-值对列表。",
            "code": """fav = {"jen": "python", "sarah": "c"}
for name, lang in fav.items():
    print(f"{name} 喜欢 {lang}")""",
            "output": "jen 喜欢 python\nsarah 喜欢 c",
        },
        {
            "heading": "遍历字典：键与值",
            "body": "for k in 字典.keys(): 遍历键；for v in 字典.values(): 遍历值，可用 set() 去重；用 sorted() 可按顺序遍历键。",
            "original": "在不需要使用字典中的值时，方法 keys() 很有用。字典总是明确地记录键和值之间的关联关系，但获取字典的元素时，获取顺序是不可预测的。要以特定的顺序返回元素，一种办法是在 for 循环中对返回的键进行排序，为此可使用函数 sorted()。方法 values() 返回一个值列表，而不包含任何键。",
            "code": """fav = {"sarah": "c", "jen": "python"}
for name in sorted(fav.keys()):
    print(name)
print(set(fav.values()))""",
            "output": "jen\nsarah\n{'python', 'c'}",
        },
        {
            "heading": "嵌套：字典列表",
            "body": "列表中放字典（字典列表），常用来表示一组同类对象，如游戏里的一群外星人。",
            "original": "有时候，需要将一系列字典存储在列表中，或将列表作为值存储在字典中，这称为嵌套。你可以在列表中嵌套字典、在字典中嵌套列表甚至在字典中嵌套字典。将字典存储在列表中，这是最常见的嵌套方式之一。",
            "code": """aliens = [{"color": "green", "points": 5},
         {"color": "yellow", "points": 10}]
for a in aliens:
    print(a["points"])""",
            "output": "5\n10",
        },
        {
            "heading": "嵌套：字典中存列表与字典",
            "body": "字典的值也可以是列表（一人多个爱好）或另一个字典（更复杂的结构）。",
            "original": "有时候，需要将列表存储在字典中，而不是将字典存储在列表中。每当需要在字典中将一个键关联到多个值时，都可以在字典中嵌套一个列表。你还可以在字典中嵌套字典，但这样做时，代码可能很快复杂起来。",
            "code": """person = {"name": "Tom", "hobbies": ["篮球", "音乐"]}
for h in person["hobbies"]:
    print(h)""",
            "output": "篮球\n音乐",
        },
    ],
    "exercises": [
        {
            "id": "ch05-e1",
            "title": "人",
            "prompt": "创建一个表示人的字典，含名字、年龄、城市三个键值对，逐个打印。",
            "hint": "字典[key] 取值。",
            "starter": "person = {\"first\": \"Eric\", \"age\": 20, \"city\": \"Beijing\"}\n# 逐个打印\n",
        },
        {
            "id": "ch05-e2",
            "title": "喜欢的数字",
            "prompt": "建一个字典存几个人的名字和各自喜欢的数字，遍历打印“X 喜欢数字 Y”。",
            "hint": "字典.items()。",
            "starter": "favorite = {\"Alice\": 7, \"Bob\": 3, \"Carol\": 9}\n# 遍历打印\n",
        },
        {
            "id": "ch05-e3",
            "title": "词汇表",
            "prompt": "用字典存 5 个编程术语及其含义，遍历打印“术语：含义”。",
            "hint": "字典.items()。",
            "starter": "glossary = {\"list\": \"列表\", \"dict\": \"字典\", \"int\": \"整数\"}\n# 遍历打印\n",
        },
        {
            "id": "ch05-e4",
            "title": "河流与国家",
            "prompt": "建一个字典，键是河流名、值是国家名，遍历打印“尼罗河流经埃及”这类句子。",
            "hint": "键值对遍历。",
            "starter": "rivers = {\"nile\": \"egypt\", \"amazon\": \"brazil\"}\n# 遍历打印\n",
        },
        {
            "id": "ch05-e5",
            "title": "字典列表",
            "prompt": "创建含三个“人”字典的列表，每人有 name 和 age，遍历打印简介。",
            "hint": "列表里放字典。",
            "starter": "people = []\n# 添加三人并遍历打印\n",
        },
        {
            "id": "ch05-e6",
            "title": "喜欢的地方",
            "prompt": "建一个字典，键是人名、值是此人喜欢的地方列表，遍历打印每个人的所有地点。",
            "hint": "值是列表，再内层遍历。",
            "starter": "places = {\"Alice\": [\"Paris\", \"Tokyo\"], \"Bob\": [\"Cairo\"]}\n# 嵌套遍历打印\n",
        },
        {
            "id": "ch05-e7",
            "title": "城市（嵌套字典）",
            "prompt": "建一个字典，键是城市名，值是含国家和人口的字典；遍历打印城市信息。",
            "hint": "字典里套字典。",
            "starter": "cities = {\"Beijing\": {\"country\": \"China\", \"pop\": 2000}}\n# 嵌套遍历打印\n",
        },
    ],
}
