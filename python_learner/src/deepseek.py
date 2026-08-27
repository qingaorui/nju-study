# -*- coding: utf-8 -*-
"""拼接批改提示词，复制到剪贴板并打开 DeepSeek 网页端。"""
import webbrowser

import pyperclip

DEEPSEEK_URL = "https://chat.deepseek.com"


def build_grading_prompt(exercise_title, exercise_prompt, code):
    return (
        "你是一位严谨、友好的 Python 老师。请批改下面这份练习作业。\n\n"
        f"【练习题目】{exercise_title}\n{exercise_prompt}\n\n"
        f"【学生提交的代码】\n```python\n{code}\n```\n\n"
        "请按以下结构给出批改意见（用中文）：\n"
        "1. 能否正常运行（如有语法/运行错误，请明确指出行与原因）\n"
        "2. 逻辑是否正确、是否达成题目要求\n"
        "3. 可改进之处（命名、可读性、健壮性、Python 风格等）\n"
        "4. 综合评分（0-100 分）与一句话总评\n"
    )


def open_deepseek(prompt):
    """复制提示词到剪贴板并打开 DeepSeek 网页。返回 (复制成功, 打开成功)。"""
    try:
        pyperclip.copy(prompt)
        copied = True
    except Exception:
        copied = False
    try:
        webbrowser.open(DEEPSEEK_URL)
        opened = True
    except Exception:
        opened = False
    return copied, opened
