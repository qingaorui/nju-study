# -*- coding: utf-8 -*-
"""项目 2：数据可视化（第 15~17 章）"""

PROJECT = {
    "id": "data_viz",
    "title": "数据可视化 (Data Visualization)",
    "book_chapter": "项目 2 · 第 15~17 章",
    "summary": "用 matplotlib 画图、从 CSV 与 JSON 读取真实数据（温度、人口），并练习生成图表。",
    "tech": "matplotlib, csv, json",
    "setup": "pip install matplotlib",
    "steps": [
        {
            "heading": "第 15 章 · 画一条折线",
            "body": "用 matplotlib 的 plot() 把一组平方数画成折线，并加标题和坐标轴标签。",
            "code": """import matplotlib.pyplot as plt

x = list(range(1, 6))
y = [v ** 2 for v in x]
plt.plot(x, y)
plt.title("Squares")
plt.xlabel("x")
plt.ylabel("x^2")
plt.show()""",
            "starter": """import matplotlib.pyplot as plt

# 画平方数折线
""",
        },
        {
            "heading": "第 15 章 · 随机散步",
            "body": "定义 RandomWalk 类生成随机游走点，用 scatter() 绘制并按顺序着色。",
            "code": """from random import choice

class RandomWalk:
    def __init__(self, n=5000):
        self.x = [0]
        self.y = [0]
        for _ in range(n):
            dx = choice([1, -1])
            dy = choice([1, -1])
            self.x.append(self.x[-1] + dx)
            self.y.append(self.y[-1] + dy)""",
            "starter": """from random import choice

class RandomWalk:
    def __init__(self, n=5000):
        pass
""",
        },
        {
            "heading": "第 16 章 · 从 CSV 读数据",
            "body": "用 csv 模块读取天气数据文件，取日期与最高温，用 matplotlib 绘制气温折线。",
            "code": """import csv

with open("weather.csv") as f:
    reader = csv.reader(f)
    header = next(reader)
    highs = [int(row[1]) for row in reader]
print(highs[:5])""",
            "starter": """import csv

# 读取并打印最高温列
""",
        },
        {
            "heading": "第 17 章 · 从 JSON 读数据",
            "body": "用 json 读取人口数据文件，遍历国家提取名称与人口，准备绘图数据。",
            "code": """import json

with open("population.json", encoding="utf-8") as f:
    data = json.load(f)
for item in data:
    print(item["Country Name"], item["Value"])""",
            "starter": """import json

# 读取并打印国家与人口
""",
        },
        {
            "heading": "第 17 章 · 柱状图展示人口",
            "body": "把若干国家的人口用 bar() 画成柱状图，加标题与坐标标签，直观对比各国人口。",
            "code": """import matplotlib.pyplot as plt

countries = ["China", "India", "USA"]
pop = [1400, 1380, 330]
plt.bar(countries, pop)
plt.title("Population")
plt.show()""",
            "starter": """import matplotlib.pyplot as plt

# 画人口柱状图
""",
        },
    ],
}
