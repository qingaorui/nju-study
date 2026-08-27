# -*- coding: utf-8 -*-
"""全局设置：PDF 路径、PyCharm 路径。存于 data/settings.json。"""
import json
import os
import sys

if getattr(sys, "frozen", False):
    ROOT = sys._MEIPASS
    # 打包后程序目录只读，运行数据写到用户可写目录
    DATA_DIR = os.path.join(os.path.expanduser("~"), "python_learner_data")
else:
    ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    DATA_DIR = os.path.join(ROOT, "data")
SETTINGS_PATH = os.path.join(DATA_DIR, "settings.json")

DEFAULT_PDF = (
    "C:/Users/qinga/Downloads/"
    "Python编程从入门到实践 第2版 (埃里克·马瑟斯（Eric Matthes）) "
    "(z-library.sk, 1lib.sk, z-lib.sk).pdf"
)


def load_settings():
    if os.path.exists(SETTINGS_PATH):
        try:
            with open(SETTINGS_PATH, encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {"pdf_path": DEFAULT_PDF, "pycharm_path": ""}


def save_settings(s):
    os.makedirs(DATA_DIR, exist_ok=True)
    with open(SETTINGS_PATH, "w", encoding="utf-8") as f:
        json.dump(s, f, ensure_ascii=False, indent=2)
    return s
