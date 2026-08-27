# -*- coding: utf-8 -*-
"""第 11 章 测试代码"""

CHAPTER = {
    "id": "ch10",
    "title": "测试代码",
    "book_chapter": "第 11 章",
    "summary": "用 unittest 写自动化测试，确保函数和类按预期工作，改动后能快速发现回归。",
    "sections": [
        {
            "heading": "为什么要写测试",
            "body": "测试能自动验证代码是否正确。修改代码后跑一遍测试，就能立刻知道有没有改坏之前的功能（回归）。",
            "original": "编写函数或类时，还可为其编写测试。通过测试，可确定代码面对各种输入都能够按要求的那样工作。在程序中添加新代码时，你也可以对其进行测试，确认它们都不会破坏程序既有的行为。程序员都会犯错，因此每个程序员都必须经常测试其代码，在用户发现问题前找出它们。",
            "code": """# 被测试的函数
def add(a, b):
    return a + b""",
            "output": "",
        },
        {
            "heading": "用 unittest 测试函数",
            "body": "import unittest，写一个继承 unittest.TestCase 的类，方法名以 test_ 开头。用 assertEqual 断言结果与期望一致。",
            "original": "Python 标准库中的模块 unittest 提供了代码测试工具。单元测试用于核实函数的某个方面没有问题；测试用例是一组单元测试，这些单元测试一起核实函数在各种情形下的行为都符合要求。良好的测试用例考虑到了函数可能收到的各种输入，包含针对所有这些情形的测试。",
            "code": """import unittest
from math_funcs import add

class AddTestCase(unittest.TestCase):
    def test_add(self):
        self.assertEqual(add(2, 3), 5)

if __name__ == "__main__":
    unittest.main()""",
            "output": "（运行后输出 OK，表示测试通过）",
        },
        {
            "heading": "未通过的测试与解决失败",
            "body": "测试失败会给出 FAILED 和具体差异。要么修被测试的代码，要么修正测试的预期。测试失败是好事，它帮你发现真实问题。",
            "original": "测试未通过时，不要修改测试，而应修复导致测试不能通过的代码：检查刚对函数所做的修改，找出导致函数行为不符合预期的修改。",
            "code": """# 若 add 实现错误，测试会失败并提示：
# AssertionError: 4 != 5""",
            "output": "",
        },
        {
            "heading": "常用的断言方法",
            "body": "assertEqual(a,b) 判断相等；assertNotEqual 不等；assertTrue/assertFalse 判断真假；assertIn(a,列表) 判断包含；assertRaises(异常) 判断抛出异常。",
            "original": "unittest.TestCase 类中提供了很多断言方法。断言方法用来核实得到的结果是否与期望的结果一致。下表描述了 6 个常用的断言方法：assertEqual(a, b)、assertNotEqual(a, b)、assertTrue(x)、assertFalse(x)、assertIn(item, list)、assertNotIn(item, list)。",
            "code": """import unittest

class DemoTest(unittest.TestCase):
    def test_in(self):
        self.assertIn("a", ["a", "b"])
    def test_true(self):
        self.assertTrue(1 < 2)

if __name__ == "__main__":
    unittest.main()""",
            "output": "（测试通过）",
        },
        {
            "heading": "测试类",
            "body": "为类写测试时，先在 setUp() 里创建测试用的实例，再在 test_ 方法里断言其属性和方法行为。setUp 会在每个测试方法前自动运行。",
            "original": "前面针对单个函数的测试都通过了，但编写针对类的测试并没有比针对函数的测试困难多少。unittest.TestCase 类包含方法 setUp()，让我们只需创建这些对象一次，并在每个测试方法中使用它们。如果你在 TestCase 类中包含了方法 setUp()，Python 将先运行它，再运行各个以 test_ 打头的方法。",
            "code": """import unittest

class Survey:
    def __init__(self):
        self.responses = []
    def add(self, r):
        self.responses.append(r)

class SurveyTest(unittest.TestCase):
    def setUp(self):
        self.s = Survey()
    def test_add_one(self):
        self.s.add("Python")
        self.assertIn("Python", self.s.responses)

if __name__ == "__main__":
    unittest.main()""",
            "output": "（测试通过）",
        },
    ],
    "exercises": [
        {
            "id": "ch10-e1",
            "title": "城市和国家",
            "prompt": "写 city_country(city, country) 返回“城市, 国家”，再用 unittest 断言它返回正确字符串。",
            "hint": "assertEqual(city_country('santiago','chile'), 'santiago, chile')。",
            "starter": "import unittest\n\ndef city_country(city, country):\n    return f\"{city}, {country}\"\n\n# 写测试类\n",
        },
        {
            "id": "ch10-e2",
            "title": "人口数量",
            "prompt": "在上一题基础上，给函数加可选参数 population，并用测试断言带/不带 population 两种调用结果。",
            "hint": "人口为空时返回“city, country”。",
            "starter": "import unittest\n\ndef city_country(city, country, population=None):\n    pass\n# 写测试\n",
        },
        {
            "id": "ch10-e3",
            "title": "雇员",
            "prompt": "写 Employee 类（姓名 + 年薪）和 give_raise() 方法；写测试类，用 setUp 创建实例，测试默认加薪 5000 和自定义加薪。",
            "hint": "setUp 里 self.emp = Employee(...)。",
            "starter": "import unittest\n\nclass Employee:\n    def __init__(self, name, salary):\n        self.name = name\n        self.salary = salary\n    def give_raise(self, amount=5000):\n        pass\n# 写测试类\n",
        },
    ],
}
