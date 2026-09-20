"""
手机连接检查。

没有 hdc 的情况下，也能从 Windows 的设备注册表里判断出：
  · 有没有华为/荣耀设备接上（HDB 调试口、MTP、USB 网卡、串口等）
  · 是"调试模式"还是"仅充电"还是"文件传输模式"
  · 有没有 U 盘式的存储挂载

原理：USB 设备的 VID/PID 一定会出现在
      HKLM\\SYSTEM\\CurrentControlSet\\Enum\\USB 下，与驱动装没装、hdc 有没有都无关。
"""
import os
import subprocess
import sys
import winreg

# 常见厂商 VID
VENDOR_VID = {
    '12d1': '华为 Huawei',
    '339b': '荣耀 Honor',
    '18d1': 'Google / Android 通用调试口',
    '2717': '小米 Xiaomi',
    '2a70': '一加 OnePlus',
    '22d9': 'OPPO',
    '2d95': 'vivo',
    '04e8': '三星 Samsung',
}

# 接口类描述，用来判断手机处在哪种模式
MODE_HINTS = [
    ('hdb', 'HDB 调试接口 —— 开发者模式已开，可以 hdc 安装'),
    ('adb', 'ADB 调试接口 —— 开发者模式已开'),
    ('mtp', 'MTP 文件传输'),
    ('ptp', 'PTP 相机模式'),
    ('rndis', 'USB 网络共享'),
    ('serial', '串口 (可能是调试口)'),
    ('mass storage', 'U 盘式存储'),
    ('composite', '复合设备'),
]


def reg_subkeys(root, path):
    out = []
    try:
        with winreg.OpenKey(root, path) as k:
            i = 0
            while True:
                try:
                    out.append(winreg.EnumKey(k, i))
                    i += 1
                except OSError:
                    break
    except OSError:
        pass
    return out


def reg_value(root, path, name):
    try:
        with winreg.OpenKey(root, path) as k:
            v, _ = winreg.QueryValueEx(k, name)
            return v
    except OSError:
        return None


def scan_usb():
    """扫 HKLM\\SYSTEM\\CurrentControlSet\\Enum\\USB 下的所有 VID_xxxx&PID_xxxx"""
    base = r'SYSTEM\CurrentControlSet\Enum\USB'
    found = []
    for vid_pid in reg_subkeys(winreg.HKEY_LOCAL_MACHINE, base):
        low = vid_pid.lower()
        if not low.startswith('vid_'):
            continue
        vid = low.split('&')[0].replace('vid_', '')
        # 每个 vid_pid 下是各个实例
        for inst in reg_subkeys(winreg.HKEY_LOCAL_MACHINE, base + '\\' + vid_pid):
            ipath = base + '\\' + vid_pid + '\\' + inst
            desc = reg_value(winreg.HKEY_LOCAL_MACHINE, ipath, 'DeviceDesc') or ''
            friendly = reg_value(winreg.HKEY_LOCAL_MACHINE, ipath, 'FriendlyName') or ''
            service = reg_value(winreg.HKEY_LOCAL_MACHINE, ipath, 'Service') or ''
            cls = reg_value(winreg.HKEY_LOCAL_MACHINE, ipath, 'Class') or ''
            found.append({
                'vid': vid,
                'vidpid': vid_pid,
                'desc': str(desc),
                'friendly': str(friendly),
                'service': str(service),
                'class': str(cls),
                'instance': inst,
            })
    return found


def pnputil_devices():
    try:
        out = subprocess.run(['pnputil', '/enum-devices', '/connected'],
                             capture_output=True, timeout=60)
        raw = out.stdout
    except Exception:
        return []
    txt = None
    for enc in ('utf-16-le', 'utf-8', 'gbk'):
        try:
            t = raw.decode(enc)
            if t.count('\n') > 3:
                txt = t
                break
        except Exception:
            continue
    if txt is None:
        return []
    devs, cur = [], {}
    for line in txt.replace('\r', '').split('\n'):
        s = line.strip()
        if s.startswith('实例 ID') or s.lower().startswith('instance id'):
            if cur:
                devs.append(cur)
            cur = {'id': s.split(':', 1)[-1].strip()}
        elif ('设备描述' in s or 'Device Description' in s) and cur:
            cur['name'] = s.split(':', 1)[-1].strip()
        elif ('状态' in s or 'Status' in s) and cur:
            cur['status'] = s.split(':', 1)[-1].strip()
    if cur:
        devs.append(cur)
    return devs


def drive_letters():
    out = []
    for d in 'CDEFGHIJKLMNOPQRSTUVWXYZ':
        p = d + ':\\'
        if os.path.exists(p):
            out.append(p)
    return out


def main():
    print('=' * 62)
    print('手机连接检查')
    print('=' * 62)

    usb = scan_usb()
    print(f'\n[1] 注册表里的 USB 设备：{len(usb)} 个接口')

    # 找厂商
    hits = [u for u in usb if u['vid'] in VENDOR_VID]
    hit_vendors = sorted({u['vid'] for u in hits})

    print('\n[2] 手机厂商识别')
    if not hits:
        print('    ✗ 没有任何已知手机厂商的 USB 设备接入')
        print('      已知厂商 VID：' + '、'.join(
            f"{k}({v.split()[0]})" for k, v in VENDOR_VID.items()))
    else:
        for v in hit_vendors:
            print(f'    ✓ 检测到 {VENDOR_VID[v]}  (VID_{v})')

    if hits:
        print('\n[3] 手机相关接口明细')
        for u in hits:
            text = (u['desc'] + ' ' + u['friendly'] + ' ' + u['service']).lower()
            mode = '未知接口'
            for key, label in MODE_HINTS:
                if key in text:
                    mode = label
                    break
            desc = u['desc'].replace('\\', '').strip() or u['friendly'] or '(无描述)'
            print(f'    · {u["vidpid"]}')
            print(f'        描述: {desc}')
            print(f'        服务: {u["service"] or "-"}   类别: {u["class"] or "-"}')
            print(f'        判断: {mode}')
    else:
        print('\n[3] 手机相关接口明细 —— 无')

    # pnputil 兜底（有时注册表里 Class 为空，pnputil 能给出友好名）
    devs = pnputil_devices()
    mobile = []
    for d in devs:
        s = (d.get('name', '') + ' ' + d.get('id', '')).lower()
        if any(k in s for k in ('huawei', 'honor', 'harmony', 'hdb', 'android',
                                'mtp', '便携', 'portable', 'adb')):
            mobile.append(d)

    print(f'\n[4] 已连接设备总数: {len(devs)}；其中疑似手机/便携设备: {len(mobile)}')
    for d in mobile:
        print(f'    · {d.get("name")}  [{d.get("status", "")}]')

    print(f'\n[5] 当前盘符: {" ".join(drive_letters())}')

    print('\n' + '=' * 62)
    if hits or mobile:
        print('结论：检测到手机接入。')
        print('  但要安装 App 还需要 hdc —— 它随 DevEco Studio / HarmonyOS SDK 一起提供。')
    else:
        print('结论：没有检测到手机接入。')
        print('  如果线已经插上，按顺序排查：')
        print('    1. 换一根支持数据传输的线（很多线只能充电，这是最常见的原因）')
        print('    2. 手机上：设置 → 关于本机 → 连续点「版本号」7 次，开启开发者模式')
        print('    3. 手机上：设置 → 系统和更新 → 开发人员选项 → 打开 USB 调试')
        print('    4. 插上后手机若弹出「是否允许 USB 调试」→ 点允许')
        print('    5. 换个 USB 口（优先用主板后置口，不要用前面板或 hub）')
    print('=' * 62)
    return 0


if __name__ == '__main__':
    sys.exit(main())
