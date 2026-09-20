"""
生成 Android 启动图标。

两套并存：
  1. mipmap-anydpi-v26/ic_launcher.xml —— 自适应图标（Android 8+ 用），
     由矢量前景 + 矢量背景组成，能被各家启动器裁成圆/方/水滴等形状；
  2. mipmap-*/ic_launcher.png —— 老系统的兜底位图，按各密度生成。

图案沿用 HarmonyOS 版：渐变底 + 白色课表栅格，不依赖字体。
"""
import math
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, 'NJUClassMate-Android', 'app', 'src', 'main', 'res')

BLUE = (61, 126, 255)
PURPLE = (122, 91, 255)
WHITE = (255, 255, 255)

DENSITIES = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}


def mix(c1, c2, t):
    return tuple(int(round(c1[i] + (c2[i] - c1[i]) * t)) for i in range(3))


def rounded_alpha(x, y, x0, y0, x1, y1, r):
    if x < x0 or x > x1 or y < y0 or y > y1:
        return 0.0
    cx = min(max(x, x0 + r), x1 - r)
    cy = min(max(y, y0 + r), y1 - r)
    d = math.hypot(x - cx, y - cy)
    if d <= r - 0.5:
        return 1.0
    if d >= r + 0.5:
        return 0.0
    return r + 0.5 - d


def draw_icon(u, v, round_mask):
    """u,v 是 0..1 的归一化坐标。round_mask=True 时裁成圆形。"""
    # 背景
    t = (u + v) / 2.0
    base = mix(BLUE, PURPLE, t)
    alpha = 255

    if round_mask:
        a = rounded_alpha(u, v, 0.0, 0.0, 1.0, 1.0, 0.5)
        alpha = int(255 * a)
        if alpha == 0:
            return 0, 0, 0, 0
    else:
        a = rounded_alpha(u, v, 0.0, 0.0, 1.0, 1.0, 0.18)
        alpha = int(255 * a)
        if alpha == 0:
            return 0, 0, 0, 0

    # 白色课表卡片
    m = 0.24
    card = rounded_alpha(u, v, m, m * 0.85, 1 - m, 1 - m * 0.85, 0.075)
    if card > 0:
        base = mix(base, WHITE, card)

    if card > 0.5:
        bx0 = m + 0.07
        bx1 = 1 - m - 0.07
        top = m * 0.85 + 0.10
        gap = 0.075
        h = 0.085
        for i in range(4):
            y0 = top + i * (h + gap)
            y1 = y0 + h
            if i == 1:
                # 高亮那条用主题蓝，代表"正在上的课"
                a = rounded_alpha(u, v, bx0, y0, bx0 + (bx1 - bx0) * 0.6, y1, h / 2)
                if a > 0:
                    base = mix(base, BLUE, a)
            else:
                w1 = bx1 - (bx1 - bx0) * (0.0 if i == 0 else 0.28)
                a = rounded_alpha(u, v, bx0, y0, w1, y1, h / 2)
                if a > 0:
                    base = mix(base, (206, 216, 240), a)
    return base[0], base[1], base[2], alpha


def render(size, round_mask):
    ss = 3
    big = size * ss
    rows = []
    for py in range(big):
        row = bytearray()
        y = (py + 0.5) / big
        for px in range(big):
            x = (px + 0.5) / big
            r, g, b, a = draw_icon(x, y, round_mask)
            row += bytes((r, g, b, a))
        rows.append(row)

    out = []
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
        out.append(row)
    return out


def write_png(path, rows, size):
    raw = bytearray()
    for r in rows:
        raw.append(0)
        raw += r

    def chunk(tag, data):
        return (struct.pack('>I', len(data)) + tag + data
                + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF))

    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(bytes(raw), 9))
    png += chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(png)


# ---------------------------------------------------------------- 自适应图标

ADAPTIVE_XML = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
'''

BG_VECTOR = '''<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:pathData="M0,0h108v108h-108z">
        <aapt:attr xmlns:aapt="http://schemas.android.com/aapt" name="android:fillColor">
            <gradient
                android:startX="0" android:startY="0"
                android:endX="108" android:endY="108"
                android:type="linear">
                <item android:offset="0" android:color="#3D7EFF" />
                <item android:offset="1" android:color="#7A5BFF" />
            </gradient>
        </aapt:attr>
    </path>
</vector>
'''

# 前景要留出安全边距：自适应图标会被裁掉约 1/3 边缘，内容必须落在中间 72x72 内
FG_VECTOR = '''<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <!-- 白色课表卡片 -->
    <path
        android:fillColor="#FFFFFF"
        android:pathData="M36,32h36a5,5 0 0 1 5,5v34a5,5 0 0 1 -5,5h-36a5,5 0 0 1 -5,-5v-34a5,5 0 0 1 5,-5z" />
    <!-- 三条浅色横杠 -->
    <path android:fillColor="#CED8F0" android:pathData="M39,40h30v4h-30z" />
    <path android:fillColor="#CED8F0" android:pathData="M39,55h21v4h-21z" />
    <path android:fillColor="#CED8F0" android:pathData="M39,63h26v4h-26z" />
    <!-- 高亮那条：代表"正在上的课" -->
    <path android:fillColor="#3D7EFF" android:pathData="M39,47.5h19v4h-19z" />
</vector>
'''


def main():
    # 自适应图标（矢量）
    anydpi = os.path.join(RES, 'mipmap-anydpi-v26')
    os.makedirs(anydpi, exist_ok=True)
    for name in ('ic_launcher.xml', 'ic_launcher_round.xml'):
        with open(os.path.join(anydpi, name), 'w', encoding='utf-8', newline='') as f:
            f.write(ADAPTIVE_XML)
    with open(os.path.join(RES, 'drawable', 'ic_launcher_background.xml'), 'w',
              encoding='utf-8', newline='') as f:
        f.write(BG_VECTOR)
    with open(os.path.join(RES, 'drawable', 'ic_launcher_foreground.xml'), 'w',
              encoding='utf-8', newline='') as f:
        f.write(FG_VECTOR)
    print('  自适应图标（矢量）已写入 mipmap-anydpi-v26/ 与 drawable/')

    # 各密度位图兜底
    for folder, size in DENSITIES.items():
        d = os.path.join(RES, folder)
        os.makedirs(d, exist_ok=True)
        write_png(os.path.join(d, 'ic_launcher.png'), render(size, False), size)
        write_png(os.path.join(d, 'ic_launcher_round.png'), render(size, True), size)
        print(f'  {folder}: {size}x{size} 方图 + 圆图')


if __name__ == '__main__':
    main()
