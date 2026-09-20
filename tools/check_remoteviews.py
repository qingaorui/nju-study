#!/usr/bin/env python3
"""
检查 Android 工程里所有 RemoteViews 布局有没有用越界的控件。

为什么需要这个：RemoteViews 不是普通布局，它只允许被 @RemoteView 标注过的
一小撮控件。用了别的（最典型的是拿 <View> 画分隔线）**编译期不会报错**，
而是在运行时抛：

    android.view.InflateException: Class not allowed to be inflated android.view.View

表现是"小组件加不上 / 一片空白 / 桌面闪一下"，日志里那句话又很难让人
联想到是一条分隔线的问题。Android 12 起 RemoteViews 会挂
LayoutInflater.Filter，对越界控件的态度从"多数 ROM 勉强能跑"变成"直接拒绝"，
所以这个坑在新设备上更容易踩。

用法：
    python tools/check_remoteviews.py                 # 自动定位工程
    python tools/check_remoteviews.py <工程根目录>     # 显式指定
    python tools/check_remoteviews.py --quiet         # 只输出结论

退出码：0 全部合规；1 有违规；2 找不到工程。
"""
import glob
import os
import re
import sys

# RemoteViews 允许的控件（AOSP 里都标注了 @RemoteView）
ALLOWED = {
    # 容器
    'FrameLayout', 'LinearLayout', 'RelativeLayout', 'GridLayout',
    # 叶子控件
    'AnalogClock', 'Button', 'Chronometer', 'ImageButton', 'ImageView',
    'ProgressBar', 'TextClock', 'TextView', 'ViewFlipper',
    # 列表类
    'ListView', 'GridView', 'StackView', 'AdapterViewFlipper',
}

# 只有这些布局是给 RemoteViews 用的。
# activity_*.xml 是普通 Activity 布局，不受这个限制（ConstraintLayout 随便用）。
PATTERNS = [
    'app/src/main/res/layout/widget_*.xml',        # 桌面小组件
    'app/src/main/res/layout/notification_*.xml',  # 通知的自定义布局
]


def find_project(explicit: str | None) -> str | None:
    """显式路径优先；否则从脚本位置逐级往上找带 app/src/main/res/layout 的目录。"""
    if explicit:
        return explicit if os.path.isdir(os.path.join(explicit, 'app/src/main/res/layout')) else None
    here = os.path.dirname(os.path.abspath(__file__))
    for base in (os.path.dirname(here), here, os.getcwd()):
        for name in ('', 'NJUClassMate-Android'):
            cand = os.path.join(base, name) if name else base
            if os.path.isdir(os.path.join(cand, 'app/src/main/res/layout')):
                return cand
    return None


def check(project: str, quiet: bool = False) -> int:
    # 注意要用 os.path.join(project, pat) 去 glob：
    # glob 是相对"当前工作目录"的，直接 glob('app/...') 在别的目录下运行就找不到文件
    files = sorted({
        p
        for pat in PATTERNS
        for p in glob.glob(os.path.join(project, pat))
    })
    if not files:
        print('没找到任何 RemoteViews 布局（widget_*/notification_*）')
        return 2

    bad_total = 0
    for path in files:
        src = open(path, encoding='utf-8').read()
        # 先摘掉注释，否则注释里举例写的 <View> 会被误判
        src = re.sub(r'<!--.*?-->', '', src, flags=re.S)

        tags = set(re.findall(r'<([A-Za-z][\w.]*)\b', src))
        tags.discard('appwidget-provider')  # xml/ 下声明文件的名字，不是控件
        bad = sorted(t for t in tags if t.split('.')[-1] not in ALLOWED)
        bad_total += len(bad)

        rel = os.path.relpath(path, project).replace(os.sep, '/')
        if not quiet:
            print(('  x  ' if bad else '  ok ') + rel)
            for t in sorted(tags):
                mark = '   <-- 不允许！' if t.split('.')[-1] not in ALLOWED else ''
                print('      ' + t + mark)

    print()
    if bad_total:
        print(f'检查了 {len(files)} 个 RemoteViews 布局，发现 {bad_total} 个越界控件')
        print('  改法：用 TextView（layout_height="1dp"）代替 <View> 画线；')
        print('        用 LinearLayout/FrameLayout/RelativeLayout 代替 ConstraintLayout')
    else:
        print(f'检查了 {len(files)} 个 RemoteViews 布局，控件全部合规')
    return 1 if bad_total else 0


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    project = find_project(args[0] if args else None)
    if project is None:
        print('找不到 Android 工程（需要含 app/src/main/res/layout 的目录）')
        sys.exit(2)
    sys.exit(check(project, quiet='--quiet' in sys.argv))
