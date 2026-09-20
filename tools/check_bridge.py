#!/usr/bin/env python3
"""
检查 JS ↔ Kotlin 的桥是否对齐。

## 为什么需要这个

安卓版的界面是网页（assets/www），所有"算"的部分在 Kotlin 里，
两边通过 `window.NJU.call(method, args)` 通信，方法名是**纯字符串**——
也就是说拼错了、或者 Kotlin 那边忘了把新方法接进 `when (method)` 分发表，
**编译器一个字都不会说**：

    · Kotlin 编译通过（函数定义了没人调用，最多是条 unused 警告）
    · JS 语法检查通过
    · 单元测试通过（桥是平台胶水，测不到）

运行时表现为：`NJU.call('xxx')` 返回 `{"ok":false,"error":"未知方法: xxx"}`，
界面上就是"点了没反应"或者"按钮永远是灰的"。

这个坑真的踩过：`lockNotifyInfo` / `pushLockNotify` 两个方法在 WebBridge 里
写好了函数体，却漏了分发表那两行——锁屏状态检测和「立即推送」按钮
在手机上会静默失效。

用法：
    python tools/check_bridge.py               # 自动定位工程
    python tools/check_bridge.py <工程根目录>
    python tools/check_bridge.py --quiet

退出码：0 对齐；1 有问题；2 找不到工程。
"""
import os
import re
import sys

JS_CALL = re.compile(r"""(?:native|NJU\.call)\(\s*['"](\w+)['"]""")


def find_project(explicit: str | None) -> str | None:
    def ok(p: str) -> bool:
        return os.path.isfile(os.path.join(p, 'app/src/main/java/com/nju/classmate/web/WebBridge.kt'))

    if explicit:
        return explicit if ok(explicit) else None
    here = os.path.dirname(os.path.abspath(__file__))
    for base in (os.path.dirname(here), here, os.getcwd()):
        for name in ('', 'NJUClassMate-Android'):
            cand = os.path.join(base, name) if name else base
            if ok(cand):
                return cand
    return None


def parse_dispatch(kotlin: str) -> dict[str, str]:
    """从 `when (method) { ... }` 里取出 {方法名: 处理函数名}"""
    start = kotlin.find('when (method)')
    if start < 0:
        return {}
    end = kotlin.find('else ->', start)
    body = kotlin[start:end if end > 0 else len(kotlin)]
    # 形如：  "state" -> stateJson()
    return {m.group(1): m.group(2) for m in re.finditer(r'"(\w+)"\s*->\s*(\w+)\s*\(', body)}


def parse_js_methods(www: str) -> dict[str, list[str]]:
    """扫所有网页文件，取出 {方法名: [用到它的文件]}"""
    used: dict[str, list[str]] = {}
    for root, _, files in os.walk(www):
        for f in files:
            if not f.endswith(('.js', '.html')):
                continue
            path = os.path.join(root, f)
            try:
                src = open(path, encoding='utf-8').read()
            except Exception:
                continue
            for m in JS_CALL.finditer(src):
                used.setdefault(m.group(1), []).append(f)
    return used


def check(project: str, quiet: bool = False) -> int:
    bridge = os.path.join(project, 'app/src/main/java/com/nju/classmate/web/WebBridge.kt')
    www = os.path.join(project, 'app/src/main/assets/www')

    kotlin = open(bridge, encoding='utf-8').read()
    dispatch = parse_dispatch(kotlin)
    used = parse_js_methods(www)

    if not dispatch:
        print('没能从 WebBridge.kt 里解析出分发表（when (method) 结构变了？）')
        return 1

    # 处理函数是否真的有定义
    defined = set(re.findall(r'fun\s+(\w+)\s*\(', kotlin))
    missing_fn = {k: v for k, v in dispatch.items() if v not in defined}

    # 前端调了、但 Kotlin 没分发 —— 这就是运行时静默失效的那一类
    not_dispatched = sorted(set(used) - set(dispatch))

    # 分发了、但前端没人用 —— 只是信息，不算错（可能是留给以后的）
    unused = sorted(set(dispatch) - set(used))

    if not quiet:
        print('分发表里的方法：')
        for k in sorted(dispatch):
            who = ','.join(sorted(set(used.get(k, [])))) or '—'
            print(f'    {k:<20} -> {dispatch[k]:<20} 被 {who} 调用')
        print()

    ok = True

    if missing_fn:
        print('✗ 分发表指向了不存在的函数（编译会报错，但先说一声）：')
        for k, v in sorted(missing_fn.items()):
            print(f'    "{k}" -> {v}()   但 WebBridge.kt 里没有 fun {v}(')
        ok = False

    if not_dispatched:
        print('✗ 前端调用了、但 Kotlin 没分发的方法（运行时只会返回"未知方法"）：')
        for k in not_dispatched:
            files = ','.join(sorted(set(used[k])))
            hint = f'  已经被定义但漏接进 when？' if f'fun {k}(' in kotlin else ''
            print(f'    {k:<20} 出现在 {files}{hint}')
        ok = False

    if unused:
        print(f'· 分发了但前端暂时没用到（仅提示，不算错）：{", ".join(unused)}')

    print()
    if ok:
        print(f'桥已对齐：前端用到 {len(used)} 个方法，Kotlin 分发 {len(dispatch)} 个，全部对得上')
    return 0 if ok else 1


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    proj = find_project(args[0] if args else None)
    if proj is None:
        print('找不到 Android 工程（需要含 app/src/main/java/com/nju/classmate/web/WebBridge.kt）')
        sys.exit(2)
    sys.exit(check(proj, quiet='--quiet' in sys.argv))
