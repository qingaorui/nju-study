# -*- coding: utf-8 -*-
"""
《Python编程从入门到实践 第2版》学习内容汇总加载器。

内容按“每章一个文件”拆分，本文件负责组装成统一的 CHAPTERS / PROJECTS 列表，
供 server.py 直接导入（from content.content_data import CHAPTERS, PROJECTS）。
"""
from content.chapters import ch00, ch01, ch02, ch03, ch04, ch05, ch06, ch07, ch08, ch09, ch10
from content.projects import alien_invasion, data_viz, web_app
from content import pdf_pages

CHAPTERS = [
    ch00.CHAPTER,
    ch01.CHAPTER,
    ch02.CHAPTER,
    ch03.CHAPTER,
    ch04.CHAPTER,
    ch05.CHAPTER,
    ch06.CHAPTER,
    ch07.CHAPTER,
    ch08.CHAPTER,
    ch09.CHAPTER,
    ch10.CHAPTER,
]

# 为每个小节附加原书 PDF 页码（供前端定位到书中对应页）
for _ch in CHAPTERS:
    _pages = pdf_pages.PAGES.get(_ch["id"], [])
    for _i, _sec in enumerate(_ch["sections"]):
        if _i < len(_pages):
            _sec["pdf_page"] = _pages[_i]

PROJECTS = [
    alien_invasion.PROJECT,
    data_viz.PROJECT,
    web_app.PROJECT,
]
