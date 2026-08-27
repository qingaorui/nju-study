# -*- coding: utf-8 -*-
"""项目 3：Web 应用程序（第 18~20 章）"""

PROJECT = {
    "id": "web_app",
    "title": "Web 应用程序 (Web App)",
    "book_chapter": "项目 3 · 第 18~20 章",
    "summary": "用 Django 搭建一个“学习笔记”网站：建立项目与应用、定义数据模型、用模板展示、支持用户注册登录与部署。",
    "tech": "Django",
    "setup": "pip install django",
    "steps": [
        {
            "heading": "第 18 章 · 建立 Django 项目",
            "body": "用 django-admin startproject 创建项目，再 startapp 创建应用，理解项目结构。",
            "code": """# 在命令行执行：
# django-admin startproject learning_log .
# python manage.py startapp learning_logs
# python manage.py migrate
# python manage.py runserver""",
            "starter": """# 写下你创建项目的命令步骤
""",
        },
        {
            "heading": "第 18 章 · 定义数据模型",
            "body": "在 models.py 里用类定义 Topic 和 Entry 模型，建立外键关系，再 makemigrations 与 migrate 生成数据库表。",
            "code": """from django.db import models

class Topic(models.Model):
    text = models.CharField(max_length=200)
    date_added = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.text""",
            "starter": """from django.db import models

# 定义 Topic 模型
""",
        },
        {
            "heading": "第 18 章 · 视图与模板",
            "body": "在 views.py 写视图函数查询数据，在 templates 里用模板语言渲染页面，用 URL 把路径映射到视图。",
            "code": """from django.shortcuts import render
from .models import Topic

def index(request):
    topics = Topic.objects.order_by("date_added")
    return render(request, "index.html", {"topics": topics})""",
            "starter": """from django.shortcuts import render

# 写 index 视图
""",
        },
        {
            "heading": "第 19 章 · 用户注册与登录",
            "body": "使用 Django 自带的 User 模型与认证系统，编写注册、登录、注销视图，并用 @login_required 限制访问。",
            "code": """from django.contrib.auth.decorators import login_required

@login_required
def topics(request):
    topics = Topic.objects.filter(owner=request.user)
    return render(request, "topics.html", {"topics": topics})""",
            "starter": """# 写登录保护的主题视图
""",
        },
        {
            "heading": "第 20 章 · 部署到服务器",
            "body": "配置 settings.py 的 ALLOWED_HOSTS 与静态文件，收集静态资源，使用托管平台（如 Heroku）部署上线。",
            "code": """# settings.py 关键项：
# ALLOWED_HOSTS = ["你的域名"]
# STATIC_ROOT = BASE_DIR / "static"
# python manage.py collectstatic""",
            "starter": """# 写出部署前要配置的关键项
""",
        },
    ],
}
