"""在 Windows 上快速找鸿蒙开发工具链，避免用 find 全盘慢扫。"""
import os

TARGETS = {
    'hdc.exe': 'HarmonyOS 调试桥',
    'ohpm.bat': 'ohpm 包管理器',
    'hvigorw.bat': 'hvigor 构建包装器',
    'deveco-studio.exe': 'DevEco Studio',
    'node.exe': None,          # 太常见，只记录路径里有 DevEco/Harmony 的
}

ROOTS = ['C:\\', 'D:\\', 'E:\\']
SKIP = {
    'Windows', 'System Volume Information', '$Recycle.Bin', 'Recovery',
    'WinSxS', 'servicing', 'Assembly', 'Microsoft.NET', 'Installer',
    '$SysReset', 'PerfLogs', 'node_modules', '.git', 'Cache', 'cache',
    'Temp', 'temp', 'tmp', 'DriverStore', 'FileRepository',
}
MAX_DEPTH = 6

found = {}
dir_hits = []


def scan(path: str, depth: int):
    if depth > MAX_DEPTH:
        return
    try:
        with os.scandir(path) as it:
            entries = list(it)
    except (PermissionError, OSError):
        return

    for e in entries:
        try:
            low = e.name.lower()
            if e.is_dir(follow_symlinks=False):
                if low in {s.lower() for s in SKIP}:
                    continue
                if 'deveco' in low or 'harmony' in low or 'openharmony' in low or 'hvigor' in low:
                    dir_hits.append(e.path)
                scan(e.path, depth + 1)
            else:
                if low in TARGETS and TARGETS[low]:
                    found.setdefault(low, []).append(e.path)
                elif low == 'node.exe' and ('deveco' in path.lower() or 'harmony' in path.lower()):
                    found.setdefault(low, []).append(e.path)
        except OSError:
            continue


for r in ROOTS:
    if os.path.isdir(r):
        print('扫描', r, '...', flush=True)
        scan(r, 0)

print()
print('=== 命中的可执行文件 ===')
if found:
    for k, v in found.items():
        print(f'  {k}  ({TARGETS[k] or "DevEco 自带 node"})')
        for p in v[:6]:
            print('     ', p)
else:
    print('  无')

print()
print('=== 名字里带 DevEco / Harmony / hvigor 的目录 ===')
if dir_hits:
    for d in dir_hits[:40]:
        print('  ', d)
    if len(dir_hits) > 40:
        print(f'   ...(共 {len(dir_hits)} 个)')
else:
    print('  无')
