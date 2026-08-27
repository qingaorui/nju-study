# -*- coding: utf-8 -*-
"""项目 1：外星人入侵（第 12~14 章）"""

PROJECT = {
    "id": "alien_invasion",
    "title": "外星人入侵 (Alien Invasion)",
    "book_chapter": "项目 1 · 第 12~14 章",
    "summary": "用 pygame 做一个 2D 射击游戏：飞船左右移动、发射子弹、成群外星人下落，被撞或外星人到底则结束，并加入记分系统。",
    "tech": "pygame",
    "setup": "pip install pygame",
    "steps": [
        {
            "heading": "第 12 章 · 创建游戏窗口",
            "body": "初始化 pygame，设置屏幕尺寸与标题，用一个主循环保持窗口刷新并响应关闭事件。",
            "code": """import pygame
import sys

pygame.init()
screen = pygame.display.set_mode((1200, 800))
pygame.display.set_caption("Alien Invasion")

while True:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            sys.exit()
    pygame.display.flip()""",
            "starter": """import pygame
import sys

# 在这里创建窗口与主循环
""",
        },
        {
            "heading": "第 12 章 · 绘制飞船",
            "body": "新建 Ship 类管理飞船图片与位置，在循环中把飞船画到屏幕。",
            "code": """class Ship:
    def __init__(self, screen):
        self.screen = screen
        self.image = pygame.image.load("ship.bmp")
        self.rect = self.image.get_rect()
        self.rect.centerx = screen.get_rect().centerx
        self.rect.bottom = screen.get_rect().bottom

    def blitme(self):
        self.screen.blit(self.image, self.rect)""",
            "starter": """class Ship:
    def __init__(self, screen):
        pass
    def blitme(self):
        pass
""",
        },
        {
            "heading": "第 12 章 · 飞船移动与子弹",
            "body": "用键盘事件控制飞船左右移动；按空格生成子弹列表并向上飞，飞出屏幕即移除。",
            "code": """class Bullet:
    def __init__(self, screen, ship):
        self.rect = pygame.Rect(0, 0, 3, 15)
        self.rect.centerx = ship.rect.centerx
        self.rect.top = ship.rect.top
        self.y = float(self.rect.y)

    def update(self):
        self.y -= 2
        self.rect.y = self.y""",
            "starter": """class Bullet:
    def __init__(self, screen, ship):
        pass
    def update(self):
        pass
""",
        },
        {
            "heading": "第 13 章 · 创建外星人舰队",
            "body": "新建 Alien 类，循环创建一排排外星人并装入编组，让它们整体向下移动、到达边缘时反向并下移。",
            "code": """class Alien:
    def __init__(self, screen):
        self.image = pygame.image.load("alien.bmp")
        self.rect = self.image.get_rect()
        self.x = float(self.rect.x)

    def update(self):
        self.x += 1
        self.rect.x = self.x""",
            "starter": """class Alien:
    def __init__(self, screen):
        pass
    def update(self):
        pass
""",
        },
        {
            "heading": "第 13 章 · 碰撞与结束",
            "body": "用 pygame.sprite.groupcollide 检测子弹与外星人碰撞并消除；检测飞船与外星人相撞、外星人到达屏幕底部，触发游戏结束。",
            "code": """collisions = pygame.sprite.groupcollide(bullets, aliens, True, True)
if pygame.sprite.spritecollideany(ship, aliens):
    print("飞船被撞！")""",
            "starter": """# 检测子弹与外星人碰撞
# 检测飞船被撞
""",
        },
        {
            "heading": "第 14 章 · 记分系统",
            "body": "创建记分牌，击杀外星人加分并刷新最高分，显示剩余飞船数量。",
            "code": """class Scoreboard:
    def __init__(self, screen):
        self.screen = screen
        self.score = 0

    def show(self):
        font = pygame.font.SysFont(None, 48)
        img = font.render(str(self.score), True, (255, 255, 255))
        self.screen.blit(img, (20, 20))""",
            "starter": """class Scoreboard:
    def __init__(self, screen):
        pass
    def show(self):
        pass
""",
        },
    ],
}
