"""
生成工程所需的图标 PNG（纯标准库实现，不依赖 Pillow）。
图标是几何风格：渐变底 + 白色课表栅格，避免依赖字体。
"""
import math
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_BASE = os.path.join(ROOT, 'entry', 'src', 'main', 'resources', 'base', 'media')
OUT_APP = os.path.join(ROOT, 'AppScope', 'resources', 'base', 'media')

BLUE = (61, 126, 255)
PURPLE = (122, 91, 255)
WHITE = (255, 255, 255)


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1, c2, t):
    return tuple(int(round(lerp(c1[i], c2[i], t))) for i in range(3))


def rounded_rect_alpha(x, y, x0, y0, x1, y1, r):
    """点 (x,y) 在圆角矩形内的覆盖度，0~1（内部为 1）。"""
    if x < x0 or x > x1 or y < y0 or y > y1:
        return 0.0
    cx = min(max(x, x0 + r), x1 - r)
    cy = min(max(y, y0 + r), y1 - r)
    dx = x - cx
    dy = y - cy
    d = math.sqrt(dx * dx + dy * dy)
    if d <= r - 0.5:
        return 1.0
    if d >= r + 0.5:
        return 0.0
    return r + 0.5 - d


def render(size, draw_fn):
    """以 2 倍超采样渲染，得到平滑边缘。"""
    ss = 2
    big = size * ss
    rows = []
    for py in range(big):
        row = bytearray()
        y = py + 0.5
        for px in range(big):
            x = px + 0.5
            r, g, b, a = draw_fn(x / big, y / big, big)
            row += bytes((r, g, b, a))
        rows.append(row)

    # 下采样
    out_rows = []
    for oy in range(size):
        row = bytearray()
        for ox in range(size):
            acc = [0, 0, 0, 0]
            for dy in range(ss):
                src = rows[oy * ss + dy]
                for dx in range(ss):
                    i = (ox * ss + dx) * 4
                    acc[0] += src[i]
                    acc[1] += src[i + 1]
                    acc[2] += src[i + 2]
                    acc[3] += src[i + 3]
            n = ss * ss
            row += bytes((acc[0] // n, acc[1] // n, acc[2] // n, acc[3] // n))
        out_rows.append(row)
    return out_rows


def write_png(path, rows, size):
    raw = bytearray()
    for r in rows:
        raw.append(0)
        raw += r

    def chunk(tag, data):
        c = struct.pack('>I', len(data)) + tag + data
        return c + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(bytes(raw), 9))
    png += chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(png)
    print('  ->', path, len(png), 'bytes')


def gradient(u, v):
    """对角渐变底色。"""
    t = (u + v) / 2.0
    return mix(BLUE, PURPLE, t)


def icon_painter(with_bg=True, inset=0.0):
    """画一个"课表"图标：若干条横杠，其中一条高亮。"""

    def draw(u, v, big):
        if with_bg:
            base = gradient(u, v)
            alpha = 255
        else:
            base = (0, 0, 0)
            alpha = 0

        # 主体白色圆角矩形
        m = 0.22 + inset * 0.18
        card = rounded_rect_alpha(u, v, m, m * 0.78, 1 - m, 1 - m * 0.78, 0.09)
        if card > 0:
            base = mix(base, WHITE, card)
            alpha = max(alpha, int(255 * card))

        # 卡片内横杠
        if card > 0.5:
            bar_x0 = m + 0.075
            bar_x1 = 1 - m - 0.075
            top = m * 0.78 + 0.09
            gap = 0.055
            h = 0.072
            for i in range(4):
                y0 = top + i * (h + gap)
                y1 = y0 + h
                if i == 1:
                    # 高亮那一条用蓝色，代表"正在上的课"
                    w0 = bar_x0
                    w1 = bar_x0 + (bar_x1 - bar_x0) * 0.62
                    a = rounded_rect_alpha(u, v, w0, y0, w1, y1, h / 2)
                    if a > 0:
                        base = mix(base, BLUE, a)
                else:
                    w1 = bar_x1 - (bar_x1 - bar_x0) * (0.0 if i == 0 else 0.25)
                    a = rounded_rect_alpha(u, v, bar_x0, y0, w1, y1, h / 2)
                    if a > 0:
                        # 用半透明白灰模拟次级信息
                        base = mix(base, (206, 216, 240), a)
        return base[0], base[1], base[2], alpha

    return draw


def solid(color, radius=0.0):
    def draw(u, v, big):
        if radius <= 0:
            return color[0], color[1], color[2], 255
        a = rounded_rect_alpha(u, v, 0, 0, 1, 1, radius)
        return color[0], color[1], color[2], int(255 * a)

    return draw


def main():
    os.makedirs(OUT_BASE, exist_ok=True)
    os.makedirs(OUT_APP, exist_ok=True)

    print('生成应用图标：')
    write_png(os.path.join(OUT_APP, 'app_icon.png'), render(512, icon_painter(True)), 512)
    write_png(os.path.join(OUT_BASE, 'app_icon.png'), render(512, icon_painter(True)), 512)

    # 分层图标：背景是渐变，前景是白色课表（留出安全边距）
    write_png(os.path.join(OUT_BASE, 'background.png'),
              render(512, lambda u, v, b: (gradient(u, v)[0], gradient(u, v)[1], gradient(u, v)[2], 255)), 512)
    write_png(os.path.join(OUT_BASE, 'foreground.png'),
              render(512, icon_painter(False, inset=1.0)), 512)

    # 启动页图标：白底蓝标
    def start_icon(u, v, big):
        a = rounded_rect_alpha(u, v, 0.04, 0.04, 0.96, 0.96, 0.16)
        base = mix(WHITE, BLUE, 0.0)
        if a > 0:
            base = mix(base, BLUE, a)
        sub = icon_painter(False, inset=0.55)(u, v, big)
        if sub[3] > 0:
            t = sub[3] / 255.0
            base = mix(base, (255, 255, 255), t)
        return base[0], base[1], base[2], 255

    write_png(os.path.join(OUT_BASE, 'startIcon.png'), render(512, start_icon), 512)


if __name__ == '__main__':
    main()
