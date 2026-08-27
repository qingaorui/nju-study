# -*- coding: utf-8 -*-
"""第 8 章 函数"""

CHAPTER = {
    "id": "ch07",
    "title": "函数",
    "book_chapter": "第 8 章",
    "summary": "把可复用的代码块写成函数，让程序更清晰、更易维护。",
    "sections": [
        {
            "heading": "定义函数",
            "body": "def 函数名(参数): 定义函数，函数体缩进。定义后调用函数名() 才会执行。",
            "original": "下面打印问候语的简单函数，名为 greet_user()：def greet_user(): 打印问候语。这个示例演示了最简单的函数结构。要使用这个函数，可调用它。函数调用让 Python 执行函数的代码。",
            "code": """def greet():
    print("Hello!")

greet()""",
            "output": "Hello!",
        },
        {
            "heading": "传递实参：位置与关键字",
            "body": "位置实参按顺序对应形参；关键字实参用 形参名=值，顺序不限。两者可混用，但位置实参必须在前。",
            "original": "你调用函数时，Python 必须将函数调用中的每个实参都关联到函数定义中的一个形参。为此，最简单的关联方式是基于实参的顺序，这种关联方式被称为位置实参。关键字实参是传递给函数的名称-值对，你直接在实参中将名称和值关联起来了。使用关键字实参时，务必准确地指定函数定义中的形参名。",
            "code": """def describe(name, animal):
    print(f"{name} 有一只 {animal}")

describe("Eric", "dog")
describe(animal="cat", name="Alice")""",
            "output": "Eric 有一只 dog\nAlice 有一只 cat",
        },
        {
            "heading": "默认值",
            "body": "定义时给形参默认值，调用时可省略。有默认值的形参要放在没有默认值的形参后面。",
            "original": "编写函数时，可给每个形参指定默认值。在调用函数中给形参提供了实参时，Python 将使用指定的实参值；否则，将使用形参的默认值。因此，给形参指定默认值后，可在函数调用中省略相应的实参。",
            "code": """def greet(name, msg="你好"):
    print(f"{msg}，{name}！")

greet("Eric")
greet("Alice", msg="早上好")""",
            "output": "你好，Eric！\n早上好，Alice！",
        },
        {
            "heading": "返回值",
            "body": "用 return 把结果返回给调用者，函数可返回任意类型。返回值让函数可以参与计算或拼接。",
            "original": "函数并非总是直接显示输出，相反，它可以处理一些数据，并返回一个或一组值。函数返回的值被称为返回值。在函数中，可使用 return 语句将值返回到调用函数的代码行。",
            "code": """def make_full(first, last):
    return f"{first} {last}".title()

full = make_full("ada", "lovelace")
print(full)""",
            "output": "Ada Lovelace",
        },
        {
            "heading": "让实参可选与返回字典",
            "body": "给形参默认空值可让实参可选；函数可返回字典，把多段信息打包返回。",
            "original": "有时候，需要让实参变成可选的，这样使用函数的人就只需在必要时才提供额外的信息。可使用默认值来让实参变成可选的。函数可返回任何类型的值，包括列表和字典等较复杂的数据结构。",
            "code": """def build_person(first, last, age=None):
    person = {"first": first, "last": last}
    if age:
        person["age"] = age
    return person

print(build_person("Eric", "Matthes", 20))""",
            "output": "{'first': 'Eric', 'last': 'Matthes', 'age': 20}",
        },
        {
            "heading": "传递列表",
            "body": "函数接收列表后可遍历或修改。默认是可变引用（函数内修改会影响原列表），想禁止修改可传 列表[:] 副本。",
            "original": "向函数传递列表很有用，这种列表包含的可能是名字、数字或更复杂的对象（如字典）。将列表传递给函数后，函数就能直接访问其内容。将列表的副本传递给函数，可禁止函数修改原列表。",
            "code": """def show(users):
    for u in users:
        print(u)

show(["a", "b"])""",
            "output": "a\nb",
        },
        {
            "heading": "传递任意数量的实参",
            "body": "形参加 * 可接收任意多个位置实参（打包成元组）；加 ** 可接收任意关键字实参（打包成字典）。",
            "original": "有时候，你预先不知道函数需要接受多少个实参，好在 Python 允许函数从调用语句中收集任意数量的实参。形参名 *toppings 中的星号让 Python 创建一个名为 toppings 的空元组，并将收到的所有值都封装到这个元组中。",
            "code": """def make_pizza(*toppings):
    print(toppings)

make_pizza("mushrooms", "cheese", "peppers")""",
            "output": "('mushrooms', 'cheese', 'peppers')",
        },
        {
            "heading": "将函数存储在模块中",
            "body": "把函数写进独立 .py 文件即为模块。用 import 模块、from 模块 import 函数、import 模块 as 别名 等导入。",
            "original": "函数的优点之一是，使用它们可将代码块与主程序分离。你还可以更进一步，将函数存储在被称为模块的独立文件中，再将模块导入到主程序中。import 语句允许在当前运行的程序文件中使用模块中的代码。",
            "code": """# my_funcs.py 中定义：
# def add(a, b):
#     return a + b
#
# 主程序：
# from my_funcs import add
# print(add(2, 3))  # 5""",
            "output": "",
        },
    ],
    "exercises": [
        {
            "id": "ch07-e1",
            "title": "消息",
            "prompt": "写一个 display_message() 函数，打印一句你正在学的内容，并调用它。",
            "hint": "def + print + 调用。",
            "starter": "def display_message():\n    pass\n# 调用\n",
        },
        {
            "id": "ch07-e2",
            "title": "喜欢的图书",
            "prompt": "写 favorite_book(title) 函数，打印“我最喜欢的书之一是 X”。",
            "hint": "带一个参数的函数。",
            "starter": "def favorite_book(title):\n    pass\n# 调用\n",
        },
        {
            "id": "ch07-e3",
            "title": "T 恤",
            "prompt": "写 make_shirt(size, text) 打印 T 恤尺码和文字；分别用位置实参和关键字实参调用。",
            "hint": "两个参数，两种调用方式。",
            "starter": "def make_shirt(size, text):\n    pass\n# 两种方式调用\n",
        },
        {
            "id": "ch07-e4",
            "title": "城市名",
            "prompt": "写 city_country(city, country) 返回“城市, 国家”字符串，调用三次打印。",
            "hint": "return 拼接字符串。",
            "starter": "def city_country(city, country):\n    pass\n# 调用三次\n",
        },
        {
            "id": "ch07-e5",
            "title": "专辑",
            "prompt": "写 make_album(singer, title) 返回含歌手和专辑名的字典，调用三次打印。",
            "hint": "return 一个字典。",
            "starter": "def make_album(singer, title):\n    pass\n# 调用三次\n",
        },
        {
            "id": "ch07-e6",
            "title": "消息列表",
            "prompt": "写 show_messages(msgs) 遍历打印列表里的每条消息。",
            "hint": "函数内 for 遍历参数。",
            "starter": "def show_messages(msgs):\n    pass\n# 传入列表调用\n",
        },
        {
            "id": "ch07-e7",
            "title": "三明治（任意数量实参）",
            "prompt": "写 make_sandwich(*items)，先打印“三明治包含：”，再打印所有配料。调用两次。",
            "hint": "用 *items 接收任意多参数。",
            "starter": "def make_sandwich(*items):\n    pass\n# 调用两次\n",
        },
        {
            "id": "ch07-e8",
            "title": "汽车（返回字典）",
            "prompt": "写 make_car(brand, model, **info)，返回含品牌、型号和其他信息的字典。",
            "hint": "用 **info 接收关键字实参。",
            "starter": "def make_car(brand, model, **info):\n    pass\n# 调用打印\n",
        },
    ],
}
