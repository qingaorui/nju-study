# -*- coding: utf-8 -*-
"""第 9 章 类"""

CHAPTER = {
    "id": "ch08",
    "title": "类",
    "book_chapter": "第 9 章",
    "summary": "用类把数据和行为打包成对象，模拟真实世界的事物，并支持继承复用。",
    "sections": [
        {
            "heading": "创建和使用类",
            "body": "class 类名: 定义类（类名首字母大写）。方法第一个参数必须是 self。__init__(self,...) 是构造方法，创建实例时自动调用。",
            "original": "面向对象编程是最有效的软件编写方法之一。根据类来创建对象被称为实例化，这让你能够使用类的实例。方法 __init__() 是一个特殊的方法，每当你根据 Dog 类创建新实例时，Python 都会自动运行它。我们将方法 __init__() 定义成了包含三个形参：self、name 和 age。在这个方法的定义中，形参 self 必不可少，还必须位于其他形参的前面。",
            "code": """class Dog:
    def __init__(self, name):
        self.name = name

    def sit(self):
        print(f"{self.name} 坐下了")

my_dog = Dog("旺财")
print(my_dog.name)
my_dog.sit()""",
            "output": "旺财\n旺财 坐下了",
        },
        {
            "heading": "使用类和实例：修改属性",
            "body": "修改属性值有三种方式：直接改 实例.属性=值；定义方法改；定义递增方法。用方法改更安全，可在方法里加校验。",
            "original": "有时候需要修改属性的值，可以以三种不同的方式修改属性的值：直接通过实例进行修改；通过方法进行设置；通过方法进行递增（增加特定的值）。",
            "code": """class Car:
    def __init__(self, brand):
        self.brand = brand
        self.miles = 0

    def drive(self, km):
        self.miles += km

c = Car("Toyota")
c.drive(100)
print(c.miles)""",
            "output": "100",
        },
        {
            "heading": "继承：子类",
            "body": "子类 class 子类(父类): 继承父类属性和方法。用 super().__init__(...) 调用父类构造。",
            "original": "编写类时，并非总是要从空白开始。如果你要编写的类是另一个现成类的特殊版本，可使用继承。一个类继承另一个类时，它将自动获得另一个类的所有属性和方法；原有的类称为父类，而新类称为子类。子类继承了其父类的所有属性和方法，同时还可以定义自己的属性和方法。super() 是一个特殊函数，帮助 Python 将父类和子类关联起来。",
            "code": """class Car:
    def __init__(self, brand):
        self.brand = brand

class ElectricCar(Car):
    def __init__(self, brand):
        super().__init__(brand)
        self.battery = 75

e = ElectricCar("Tesla")
print(e.brand, e.battery)""",
            "output": "Tesla 75",
        },
        {
            "heading": "继承：重写与实例作属性",
            "body": "子类定义与父类同名方法即可覆盖它。也可把复杂属性抽成独立类，作为另一个类的实例属性（组合）。",
            "original": "对于父类的方法，只要它不符合子类模拟的实物的行为，都可对其进行重写。为此，可在子类中定义一个这样的方法，即它与要重写的父类方法同名。使用代码模拟实物时，你可能会发现自己给类添加的细节越来越多。这时，可将类的一部分作为一个独立的类提取出来，将大型类拆分成多个协同工作的小类。",
            "code": """class Animal:
    def speak(self):
        print("动物叫")

class Dog(Animal):
    def speak(self):
        print("汪汪")

Dog().speak()""",
            "output": "汪汪",
        },
        {
            "heading": "导入类",
            "body": "类常写在独立模块里再导入：from 模块 import 类；可导入多个类、用 as 起别名，或 import 模块 后用 模块.类。",
            "original": "随着你不断地给类添加功能，文件可能变得很长，即便你妥善地使用了继承亦如此。为遵循 Python 的总体理念，应让文件尽可能整洁。为在这方面提供帮助，Python 允许你将类存储在模块中，然后在主程序中导入所需的模块。",
            "code": """# car.py 中：
# class Car:
#     ...
# 主程序：
# from car import Car
# my_car = Car("bmw")""",
            "output": "",
        },
        {
            "heading": "Python 标准库",
            "body": "标准库是随 Python 安装的一批模块，如 random（随机数）、collections（OrderedDict）。用 import 即可使用。",
            "original": "Python 标准库是一组模块，安装的 Python 都包含它。你现在对类的工作原理已有大致的了解，可以开始使用其他程序员编写好的模块了。可使用标准库中的任何函数和类，为此只需在程序开头包含一条简单的 import 语句。",
            "code": """from random import randint

print(randint(1, 6))
print(randint(1, 6))""",
            "output": "3\n5",
        },
        {
            "heading": "类的编码风格",
            "body": "类名用驼峰命名（如 ElectricCar）；实例名和模块名用小写加下划线。每个类定义后跟一个文档字符串。",
            "original": "类名应采用驼峰命名法，即将类名中的每个单词的首字母都大写，而不使用下划线。实例名和模块名都采用小写格式，并在单词之间加上下划线。对于每个类，都应紧跟在类定义后面包含一个文档字符串。",
            "code": """class StudentProfile:
    \"\"\"学生的基本信息。\"\"\"
    def __init__(self, name):
        self.name = name""",
            "output": "",
        },
    ],
    "exercises": [
        {
            "id": "ch08-e1",
            "title": "餐馆",
            "prompt": "定义 Restaurant 类，属性 name 和 cuisine，方法 describe() 打印简介、open() 打印“正在营业”。创建实例并调用。",
            "hint": "__init__ 存属性，定义两个方法。",
            "starter": "class Restaurant:\n    def __init__(self, name, cuisine):\n        pass\n# 创建实例并调用\n",
        },
        {
            "id": "ch08-e2",
            "title": "三家餐馆",
            "prompt": "用上一题的 Restaurant 类创建三个不同餐馆实例，分别调用 describe()。",
            "hint": "循环创建或逐个创建。",
            "starter": "class Restaurant:\n    def __init__(self, name, cuisine):\n        self.name = name\n        self.cuisine = cuisine\n    def describe(self):\n        print(f\"{self.name} 主打 {self.cuisine}\")\n# 创建三个实例\n",
        },
        {
            "id": "ch08-e3",
            "title": "用户",
            "prompt": "定义 User 类，属性 first_name、last_name，方法 describe() 打印信息、greet() 打印问候。创建两个实例。",
            "hint": "多属性 + 两个方法。",
            "starter": "class User:\n    def __init__(self, first_name, last_name):\n        pass\n# 创建两个实例\n",
        },
        {
            "id": "ch08-e4",
            "title": "就餐人数",
            "prompt": "给 Restaurant 类加 number_served 属性（默认 0），写 set_number(n) 和 increment_number(n) 修改它，并打印验证。",
            "hint": "用方法修改属性。",
            "starter": "class Restaurant:\n    def __init__(self, name):\n        self.name = name\n        self.number_served = 0\n    pass\n# 修改并打印\n",
        },
        {
            "id": "ch08-e5",
            "title": "尝试登录次数",
            "prompt": "给 User 类加 login_attempts 属性，写 increment_login() 和 reset_login()，测试多次登录后重置。",
            "hint": "递增方法 + 重置方法。",
            "starter": "class User:\n    def __init__(self, first):\n        self.first = first\n        self.login_attempts = 0\n    pass\n# 递增后重置\n",
        },
        {
            "id": "ch08-e6",
            "title": "冰淇淋小店",
            "prompt": "定义 IceCreamStand(Restaurant) 子类，新增 flavors 列表和 show_flavors() 方法。",
            "hint": "super().__init__(...)。",
            "starter": "class Restaurant:\n    def __init__(self, name):\n        self.name = name\n\nclass IceCreamStand(Restaurant):\n    def __init__(self, name):\n        pass\n# 创建并展示口味\n",
        },
        {
            "id": "ch08-e7",
            "title": "骰子（标准库）",
            "prompt": "用 random 的 randint 模拟掷骰子：定义函数返回 1~6 的随机数，掷 10 次并打印。",
            "hint": "from random import randint。",
            "starter": "from random import randint\n# 掷 10 次骰子\n",
        },
    ],
}
