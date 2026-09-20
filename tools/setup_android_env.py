"""
搭建 Android 构建环境（JDK + Android SDK + Gradle）。

背景：这台机器上什么都没有——没有 Java、没有 Android Studio、没有包管理器。
但三件套在官方渠道都是免登录直链，用脚本装反而最可控、可重复。

⚠️ 一个踩过的坑：当前网络环境下 **github.com 被挡**。
   而 Adoptium 的 JDK 下载和 Gradle 官方发行版都会 302 到 github.com，
   表现是 "CONNECT tunnel failed, response 502"。
   所以这里刻意换了两个非 GitHub 的源：
     - JDK    改用 Amazon Corretto（AWS CDN）
     - Gradle 改用腾讯云镜像
   Android SDK 本身在 dl.google.com，不受影响。

装到 D 盘（C 盘只剩 47G，D 盘 148G）。
"""
import os
import shutil
import ssl
import subprocess
import sys
import time
import urllib.request
import zipfile

ROOT = 'D:/android-dev'
DL = os.path.join(ROOT, 'downloads')
SDK = os.path.join(ROOT, 'sdk')
JDK = os.path.join(ROOT, 'jdk')

TARGETS = [
    {
        'name': 'Amazon Corretto JDK 17',
        'url': 'https://corretto.aws/downloads/latest/amazon-corretto-17-x64-windows-jdk.zip',
        'zip': 'jdk17-corretto.zip',
        'dest': JDK,
    },
    {
        'name': 'Android command-line tools',
        'url': 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip',
        'zip': 'cmdline-tools.zip',
        # 必须落在 cmdline-tools/latest 下，否则 sdkmanager 找不到自己
        'dest': os.path.join(SDK, 'cmdline-tools', 'latest'),
    },
    {
        'name': 'Gradle 8.7 (腾讯云镜像)',
        'url': 'https://mirrors.cloud.tencent.com/gradle/gradle-8.7-bin.zip',
        'zip': 'gradle-8.7.zip',
        'dest': os.path.join(ROOT, 'gradle'),
    },
]

SDK_PACKAGES = [
    'platform-tools',
    'platforms;android-34',
    'build-tools;34.0.0',
]


def human(n):
    for u in ('B', 'KB', 'MB', 'GB'):
        if n < 1024:
            return f'{n:.1f}{u}'
        n /= 1024
    return f'{n:.1f}TB'


def opener():
    """显式使用环境里的代理；对方域名不在白名单时会明确报错，方便换源。"""
    proxy = os.environ.get('https_proxy') or os.environ.get('HTTPS_PROXY') or ''
    handlers = []
    if proxy:
        handlers.append(urllib.request.ProxyHandler({'http': proxy, 'https': proxy}))
    handlers.append(urllib.request.HTTPSHandler(context=ssl.create_default_context()))
    return urllib.request.build_opener(*handlers)


def download(item):
    path = os.path.join(DL, item['zip'])
    if os.path.exists(path) and os.path.getsize(path) > 1024 * 1024:
        print(f"  [skip] {item['name']} 已存在 ({human(os.path.getsize(path))})")
        return path

    print(f"  [dl]   {item['name']}", flush=True)
    op = opener()
    for attempt in range(3):
        try:
            req = urllib.request.Request(item['url'], headers={'User-Agent': 'Mozilla/5.0'})
            with op.open(req, timeout=120) as r, open(path, 'wb') as f:
                total = int(r.headers.get('Content-Length') or 0)
                got = 0
                mark = 0
                while True:
                    chunk = r.read(512 * 1024)
                    if not chunk:
                        break
                    f.write(chunk)
                    got += len(chunk)
                    if got - mark >= 50 * 1024 * 1024:
                        mark = got
                        pct = f' ({got * 100 // total}%)' if total else ''
                        print(f"         {human(got)}{pct}", flush=True)
            print(f"         完成 {human(os.path.getsize(path))}", flush=True)
            return path
        except Exception as e:
            print(f"         第 {attempt + 1} 次失败: {e}", flush=True)
            if os.path.exists(path):
                os.remove(path)
            time.sleep(3)
    raise RuntimeError(f"下载失败: {item['url']}")


def unzip(zip_path, dest):
    if os.path.isdir(dest) and os.listdir(dest):
        print(f"  [skip] 已解压 -> {dest}")
        return
    os.makedirs(dest, exist_ok=True)
    print(f"  [unzip] -> {dest}", flush=True)
    with zipfile.ZipFile(zip_path) as z:
        names = [n for n in z.namelist() if not n.endswith('/')]
        # 压缩包里通常套一层同名目录，去掉它
        root = ''
        first = names[0].split('/')[0] if names else ''
        if first and all(n.startswith(first + '/') for n in names):
            root = first + '/'
        for n in names:
            rel = n[len(root):] if root else n
            if not rel:
                continue
            target = os.path.join(dest, rel)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with z.open(n) as src, open(target, 'wb') as out:
                shutil.copyfileobj(src, out)


def run(cmd, env=None, timeout=1800):
    print(f"  $ {' '.join(str(c) for c in cmd)}", flush=True)
    e = dict(os.environ)
    if env:
        e.update(env)
    p = subprocess.run(cmd, env=e, capture_output=True, text=True,
                       timeout=timeout, errors='replace')
    out = (p.stdout or '') + (p.stderr or '')
    for line in out.strip().splitlines()[-25:]:
        print(f"      {line}", flush=True)
    return p.returncode, out


def main():
    os.makedirs(DL, exist_ok=True)
    print(f'安装目录: {ROOT}\n')

    # ---------- 1. 下载并解压 ----------
    for item in TARGETS:
        print(f'== {item["name"]} ==')
        zp = download(item)
        unzip(zp, item['dest'])
        print(flush=True)

    javac = os.path.join(JDK, 'bin', 'javac.exe')
    java_home = JDK if os.path.exists(javac) else None
    if java_home:
        print(f'  JDK: {javac}')
        rc, out = run([javac, '-version'])
    else:
        raise RuntimeError(f'JDK 解压后找不到 javac：{javac}')

    # ---------- 2. 装 Android SDK 组件 ----------
    sdkmanager = os.path.join(SDK, 'cmdline-tools', 'latest', 'bin', 'sdkmanager.bat')
    if not os.path.exists(sdkmanager):
        raise RuntimeError(f'找不到 sdkmanager：{sdkmanager}')

    env = {'JAVA_HOME': java_home} if java_home else {}

    print('\n== 接受 SDK 许可 ==')
    try:
        p = subprocess.run(
            [sdkmanager, '--sdk_root=' + SDK, '--licenses'],
            input='y\n' * 200, capture_output=True, text=True,
            timeout=600, env={**os.environ, **env}, errors='replace')
        tail = (p.stdout or '')[-400:] + (p.stderr or '')[-400:]
        print(f'      退出码 {p.returncode}')
    except Exception as e:
        print(f'      （许可步骤异常，继续尝试安装）: {e}')

    print('\n== 安装 SDK 组件 ==')
    rc, out = run([sdkmanager, '--sdk_root=' + SDK] + SDK_PACKAGES, env=env)
    if rc != 0 and 'Warning' not in out:
        print('  !! sdkmanager 返回非 0，下面单独重试每个包')
        for pkg in SDK_PACKAGES:
            run([sdkmanager, '--sdk_root=' + SDK, pkg], env=env)

    # ---------- 3. 校验 ----------
    print('\n== 校验 ==')
    checks = [
        ('JDK javac',            os.path.join(JDK, 'bin', 'javac.exe')),
        ('sdkmanager',           sdkmanager),
        ('platform-tools/adb',   os.path.join(SDK, 'platform-tools', 'adb.exe')),
        ('android-34',           os.path.join(SDK, 'platforms', 'android-34', 'android.jar')),
        ('build-tools 34',       os.path.join(SDK, 'build-tools', '34.0.0', 'aapt2.exe')),
        ('gradle',               os.path.join(ROOT, 'gradle', 'bin', 'gradle.bat')),
    ]
    ok = True
    for label, path in checks:
        exists = os.path.exists(path)
        ok = ok and exists
        print(f"  {'OK ' if exists else '缺 '} {label:22s} {path}")

    # local.properties：Gradle 靠它找 SDK
    print()
    print('ANDROID_HOME =', SDK)
    print('JAVA_HOME    =', JDK)
    print('GRADLE       =', os.path.join(ROOT, 'gradle', 'bin', 'gradle.bat'))
    print('\n环境' + ('就绪 ✓' if ok else '不完整 ✗'))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
