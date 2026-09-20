#!/usr/bin/env bash
# 构建 Android APK。
#
#   bash tools/build_apk.sh              # 跑单测 + 出 debug APK（可直接装机）
#   bash tools/build_apk.sh --release    # 出 release APK（需要签名，脚本会自动生成密钥）
#   bash tools/build_apk.sh --test-only  # 只跑引擎单元测试
#   bash tools/build_apk.sh --clean      # 先清理再构建
#
# 环境由 tools/setup_android_env.py 装到 D:\android-dev 下，
# 这个脚本会自动去找，不要求配 PATH。

set -uo pipefail

# 这个脚本住在工作区的 tools/ 下，安卓工程是它的兄弟目录。
# 注意别 cd 到工作区根目录——那里没有 Gradle 构建。
WORKSPACE="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$WORKSPACE/NJUClassMate-Android"

if [ ! -f "$ROOT/settings.gradle.kts" ]; then
  echo "✗ 找不到安卓工程：$ROOT"
  echo "  这个脚本假设工程在 <工作区>/NJUClassMate-Android"
  exit 1
fi

DEV_ROOT="D:/android-dev"
JDK="$DEV_ROOT/jdk"
SDK="$DEV_ROOT/sdk"
GRADLE="$DEV_ROOT/gradle/bin/gradle.bat"

# Git Bash 的 /c/... 路径 Java 不认，凡是传给 java/keytool 的路径都要转成 Windows 形式
winpath() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi
}

MODE="debug"
DO_CLEAN=0
TEST_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --release)   MODE="release" ;;
    --clean)     DO_CLEAN=1 ;;
    --test-only) TEST_ONLY=1 ;;
    -h|--help)   sed -n '1,14p' "$0"; exit 0 ;;
    *) echo "未知参数: $arg"; exit 2 ;;
  esac
done

hr() { printf '%s\n' "────────────────────────────────────────────────────────"; }

# ---------------------------------------------------------------- 环境检查
echo "检查构建环境 ..."
MISSING=0
check() {
  if [ -e "$1" ]; then
    printf '  OK   %-16s %s\n' "$2" "$1"
  else
    printf '  缺   %-16s %s\n' "$2" "$1"; MISSING=1
  fi
}
check "$JDK/bin/javac.exe"                  "JDK 17"
check "$SDK/platforms/android-34/android.jar" "android-34"
check "$SDK/build-tools/34.0.0/aapt2.exe"   "build-tools 34"
check "$GRADLE"                             "Gradle"

if [ "$MISSING" -eq 1 ]; then
  cat <<'EOF'

  环境不完整。先跑：
      python tools/setup_android_env.py

EOF
  exit 1
fi

export JAVA_HOME="$JDK"
export ANDROID_HOME="$SDK"
export ANDROID_SDK_ROOT="$SDK"
export PATH="$JDK/bin:$SDK/platform-tools:$PATH"

# local.properties：Gradle 靠它找 SDK
if [ ! -f "$ROOT/local.properties" ]; then
  printf 'sdk.dir=%s\n' "$(echo "$SDK" | sed 's|/|\\\\|g')" > "$ROOT/local.properties"
  echo "  已生成 local.properties"
fi

# ---------------------------------------------------------------- 签名密钥
# release 包必须签名才能装机。这里用 keytool 自签一个，完全不需要任何账号——
# 这正是 Android 相对鸿蒙最大的优势。
KS="$ROOT/nju-classmate.jks"
KSPROPS="$ROOT/keystore.properties"
if [ "$MODE" = "release" ] && [ ! -f "$KS" ]; then
  hr
  echo "生成签名密钥（自签，不需要任何账号）..."
  KS_WIN="$(winpath "$KS")"
  "$JDK/bin/keytool.exe" -genkeypair -v \
    -keystore "$KS_WIN" \
    -alias njucm \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass njucm2026 -keypass njucm2026 \
    -dname "CN=NJU ClassMate, OU=Personal, O=Personal, L=Nanjing, ST=Jiangsu, C=CN" 2>&1 | tail -4

  if [ ! -f "$KS" ]; then
    echo "  ✗ 密钥生成失败，release 包无法签名。"
    exit 1
  fi

  cat > "$KSPROPS" <<EOF
storeFile=nju-classmate.jks
storePassword=njucm2026
keyAlias=njucm
keyPassword=njucm2026
EOF
  echo "  密钥: $KS"
  echo "  ⚠ 这个文件丢了就再也无法用同一签名更新 App，请自行备份。"
fi

# ---------------------------------------------------------------- 构建
cd "$ROOT"

if [ "$DO_CLEAN" -eq 1 ]; then
  hr
  echo "清理 ..."
  "$GRADLE" clean --no-daemon -q || true
fi

hr
echo "运行引擎单元测试（JVM，不需要模拟器）..."
"$GRADLE" :app:testDebugUnitTest --no-daemon --console=plain 2>&1 | grep -vE "^\s*$" | tail -25
TEST_RC=${PIPESTATUS[0]}

if [ "$TEST_RC" -ne 0 ]; then
  echo
  echo "  ✗ 单元测试失败，先修测试再出包。"
  echo "    报告：app/build/reports/tests/testDebugUnitTest/index.html"
  exit "$TEST_RC"
fi
echo "  ✓ 单元测试通过"

if [ "$TEST_ONLY" -eq 1 ]; then
  exit 0
fi

hr
if [ "$MODE" = "release" ]; then
  echo "构建 release APK ..."
  "$GRADLE" :app:assembleRelease --no-daemon --console=plain 2>&1 | tail -25
else
  echo "构建 debug APK ..."
  "$GRADLE" :app:assembleDebug --no-daemon --console=plain 2>&1 | tail -25
fi
BUILD_RC=${PIPESTATUS[0]}

if [ "$BUILD_RC" -ne 0 ]; then
  cat <<'EOF'

  ✗ 构建失败。常见原因见 outputs 上方的报错行：
      · 依赖下载失败 → 本机网络对 github.com 不可达，
        但 AGP/Maven 都走 dl.google.com 和 repo1.maven.org，通常没问题；
      · SDK 版本不匹配 → 确认 platforms/android-34 已装好。

EOF
  exit "$BUILD_RC"
fi

# ---------------------------------------------------------------- 收集产物
hr
APK_DIR="app/build/outputs/apk/$MODE"
APK="$(find "$APK_DIR" -name '*.apk' 2>/dev/null | head -1)"

if [ -z "$APK" ]; then
  echo "✗ 构建成功但找不到 APK，检查 $APK_DIR"
  exit 1
fi

mkdir -p dist
OUT="dist/nju-classmate-${MODE}-$(date +%Y%m%d).apk"
cp -f "$APK" "$OUT"

SIZE="$(du -h "$OUT" | cut -f1)"
SHA="$(sha256sum "$OUT" 2>/dev/null | cut -c1-16 || echo 'n/a')"

cat <<EOF

  ✓ 构建完成

    APK     : $OUT
    大小    : $SIZE
    SHA256  : $SHA...
    包名    : com.nju.classmate
    模式    : $MODE$([ "$MODE" = "debug" ] && echo '（debug 包可以直接装，自签名）')

  安装到手机（USB 连接 + 开启 USB 调试）：

      adb install -r $OUT

  手机上也完全可以直接安装：把 APK 拷进手机，用文件管理器点开，
  系统会提示「允许来自此来源的应用」，同意即可。
  HarmonyOS 4 及更早的机型走的就是这条路。

EOF
