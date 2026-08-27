# -*- coding: utf-8 -*-
"""检测本机 PyCharm 安装，并用它打开文件/项目。"""
import glob
import os
import subprocess


def detect_pycharm():
    """在常见目录与注册表中查找 pycharm 可执行文件，返回路径列表。"""
    candidates = []
    bases = [
        r"C:/Program Files/JetBrains",
        r"C:/Program Files (x86)/JetBrains",
        r"D:/PyCharm 2026.1",
        r"D:/Program Files/JetBrains",
        os.path.expanduser(r"~/AppData/Local/JetBrains"),
        os.path.expanduser(r"~/AppData/Roaming/JetBrains"),
    ]
    for base in bases:
        if not os.path.isdir(base):
            continue
        for pat in ("pycharm64.exe", "pycharm.exe"):
            for exe in glob.glob(os.path.join(base, "**", pat), recursive=True):
                candidates.append(exe)

    # 注册表回退
    try:
        import winreg

        for root in (winreg.HKEY_LOCAL_MACHINE, winreg.HKEY_CURRENT_USER):
            try:
                k = winreg.OpenKey(root, r"Software\JetBrains\PyCharm")
            except OSError:
                continue
            for exe in _scan_registry_pycharm(k):
                candidates.append(exe)
    except Exception:
        pass

    seen = []
    for c in candidates:
        if c not in seen:
            seen.append(c)
    return seen


def _scan_registry_pycharm(key):
    found = []
    try:
        i = 0
        while True:
            sub = winreg.EnumKey(key, i)
            i += 1
            try:
                sk = winreg.OpenKey(key, sub)
                val = winreg.QueryValueEx(sk, "PyCharmHome")[0]
                for pat in ("pycharm64.exe", "pycharm.exe"):
                    p = os.path.join(val, "bin", pat)
                    if os.path.exists(p):
                        found.append(p)
            except Exception:
                pass
    except OSError:
        pass
    return found


def open_in_pycharm(pycharm_path, target):
    """用指定 PyCharm 打开文件或项目目录。"""
    if not pycharm_path or not os.path.exists(pycharm_path):
        return False, "未找到 PyCharm 路径，请在设置中指定。"
    try:
        subprocess.Popen([pycharm_path, target])
        return True, f"已用 PyCharm 打开：{target}"
    except Exception as e:
        return False, str(e)
