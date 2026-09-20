#!/usr/bin/env bash
# 一键构建 HAP + 安装到已连接的鸿蒙手机。
#
#   bash tools/build_and_install.sh                 # 构建 debug 并安装
#   bash tools/build_and_install.sh --package-only  # 只出安装包，不安装（产物拷到 dist/）
#   bash tools/build_and_install.sh --list          # 只报告工具链和设备，不构建
#   bash tools/build_and_install.sh --clean         # 先清理再构建
#   bash tools/build_and_install.sh --release       # 构建 release（正式包，体积更小、已混淆）
#
# 这个脚本会自动去 DevEco Studio 的安装目录里找 hvigorw / node / hdc，
# 不要求你把它们加进 PATH。
#
# ⚠️ 前置条件（缺一不可）：
#   1. 装了 DevEco Studio（>= 5.1.0）—— 编译器、ArkTS 工具链和 HarmonyOS SDK 都在里面
#   2. 在 DevEco 里配好了签名（File → Project Structure → Signing Configs）
#      —— 鸿蒙不允许安装未签名的 HAP，这一步必须用华为开发者账号

set -uo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

MODE="debug"
DO_LIST=0
DO_CLEAN=0
PACKAGE_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --list)         DO_LIST=1 ;;
    --clean)        DO_CLEAN=1 ;;
    --release)      MODE="release" ;;
    --package-only) PACKAGE_ONLY=1 ;;
    -h|--help)      sed -n '1,22p' "$0"; exit 0 ;;
    *) echo "未知参数: $arg"; exit 2 ;;
  esac
done

hr() { printf '%s\n' "────────────────────────────────────────────────────────"; }

# ───────────────────────── 找 DevEco Studio ─────────────────────────
echo "正在定位 DevEco Studio ..."

DEVECO_CANDIDATES=(
  "/c/Program Files/Huawei/DevEco Studio"
  "/c/Program Files/Huawei/DevEcoStudio"
  "/c/Program Files (x86)/Huawei/DevEco Studio"
  "/d/Program Files/Huawei/DevEco Studio"
  "/d/Huawei/DevEco Studio"
  "$HOME/AppData/Local/Programs/Huawei/DevEco Studio"
  "$HOME/AppData/Local/Huawei/DevEco Studio"
  "$HOME/.deveco/DevEco Studio"
)

DEVECO=""
for d in "${DEVECO_CANDIDATES[@]}"; do
  if [ -d "$d" ]; then DEVECO="$d"; break; fi
done

# 常见位置没有的话，在 Program Files / 用户目录做一次有界搜索
if [ -z "$DEVECO" ]; then
  for base in "/c/Program Files" "/c/Program Files (x86)" "/d/Program Files" "$HOME/AppData/Local"; do
    [ -d "$base" ] || continue
    hit="$(find "$base" -maxdepth 3 -type d -iname 'DevEco*Studio*' 2>/dev/null | head -1)"
    if [ -n "$hit" ]; then DEVECO="$hit"; break; fi
  done
fi

if [ -z "$DEVECO" ]; then
  cat <<'EOF'

  ✗ 没找到 DevEco Studio。

    请先安装：https://developer.huawei.com/consumer/cn/deveco-studio/
    要求版本 >= 5.1.0（本工程用到 API 18 的锁屏卡片能力）。
    详细步骤见 docs/安装到手机.md

EOF
  exit 1
fi
echo "  DevEco : $DEVECO"

# ───────────────────────── 找 hvigorw / node / hdc ─────────────────────────
HVIGORW=""
for p in \
  "$DEVECO/tools/hvigor/bin/hvigorw.bat" \
  "$DEVECO/hvigor/bin/hvigorw.bat" \
  "$DEVECO/tools/hvigor/bin/hvigorw" \
  "$ROOT/hvigorw.bat" "$ROOT/hvigorw"
do
  [ -f "$p" ] && { HVIGORW="$p"; break; }
done
if [ -z "$HVIGORW" ]; then
  HVIGORW="$(find "$DEVECO" -maxdepth 6 -name 'hvigorw.bat' 2>/dev/null | head -1)"
fi

DEVECO_NODE=""
for p in "$DEVECO/tools/node/node.exe" "$DEVECO/tools/node/bin/node"; do
  [ -f "$p" ] && { DEVECO_NODE="$p"; break; }
done

HDC=""
for p in \
  "$DEVECO/sdk/default/openharmony/toolchains/hdc.exe" \
  "$DEVECO/sdk/default/hms/toolchains/hdc.exe"
do
  [ -f "$p" ] && { HDC="$p"; break; }
done
if [ -z "$HDC" ]; then
  HDC="$(find "$DEVECO" -maxdepth 8 -name 'hdc.exe' 2>/dev/null | head -1)"
fi
if [ -z "$HDC" ]; then
  HDC="$(command -v hdc 2>/dev/null || true)"
fi

echo "  hvigorw: ${HVIGORW:-（未找到）}"
echo "  node   : ${DEVECO_NODE:-（用系统 node）}"
echo "  hdc    : ${HDC:-（未找到）}"

# ───────────────────────── 设备检查（出包模式下跳过） ─────────────────────────
if [ "$PACKAGE_ONLY" -eq 1 ]; then
  hr
  echo "（--package-only 模式：只出安装包，不检查设备、不安装）"
else
  hr
  echo "已连接的鸿蒙设备："
  if [ -z "$HDC" ]; then
    echo "  拿不到 hdc，跳过设备检查"
  else
    targets="$("$HDC" list targets 2>/dev/null | tr -d '\r')"
    if [ -z "$targets" ] || echo "$targets" | grep -qi 'empty'; then
      cat <<'EOF'

  ✗ 没有检测到设备。

    按顺序检查：
      1. 数据线是不是只供电？换一根支持传输的线（最常见的坑）
      2. 手机上：设置 → 关于本机 → 连续点「版本号」7 次，开启开发者模式
      3. 手机上：设置 → 系统和更新 → 开发人员选项 → 打开 USB 调试
      4. 手机上弹出「是否允许 USB 调试」→ 允许
      5. 还不行就装华为 USB 驱动

    只想出安装包、不想连手机的话，加 --package-only 重跑：
      bash tools/build_and_install.sh --package-only

EOF
      exit 1
    else
      echo "$targets" | sed 's/^/  /'
    fi
  fi
fi

if [ "$DO_LIST" -eq 1 ]; then
  hr
  echo "（--list 模式，不做构建）"
  exit 0
fi

# ───────────────────────── 构建 ─────────────────────────
if [ -z "$HVIGORW" ]; then
  echo "✗ 找不到 hvigorw，无法命令行构建。"
  echo "  可以直接用 DevEco Studio 打开工程点 Run（见 docs/安装到手机.md）"
  exit 1
fi

if [ -n "$DEVECO_NODE" ]; then
  export PATH="$(dirname "$DEVECO_NODE"):$PATH"
fi

hr
if [ "$DO_CLEAN" -eq 1 ]; then
  echo "清理旧产物 ..."
  "$HVIGORW" clean --no-daemon || true
fi

echo "开始构建（$MODE）..."
if [ "$MODE" = "release" ]; then
  "$HVIGORW" assembleHap --mode module -p product=default -p buildMode=release --no-daemon
else
  "$HVIGORW" assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
fi
BUILD_RC=$?

if [ "$BUILD_RC" -ne 0 ]; then
  cat <<'EOF'

  ✗ 构建失败。

    最常见的原因：
      · 还没配签名 → DevEco 里 File → Project Structure → Signing Configs
                    勾选 Automatically generate signature 并登录华为开发者账号
      · 没跑过 Sync → 先在 DevEco 里打开工程等右下角 Sync 完成
      · SDK 版本不够 → 升级 DevEco 到 >= 5.1.0

    完整排错表见 docs/安装到手机.md

EOF
  exit "$BUILD_RC"
fi

# ───────────────────────── 找 HAP ─────────────────────────
HAP="$(find entry/build -name '*-signed.hap' 2>/dev/null | head -1)"
SIGNED=1
if [ -z "$HAP" ]; then
  HAP="$(find entry/build -name '*.hap' 2>/dev/null | head -1)"
  SIGNED=0
fi
if [ -z "$HAP" ]; then
  echo "✗ 构建成功但找不到 .hap 产物，检查 entry/build 目录"
  exit 1
fi

SIZE="$(du -h "$HAP" | cut -f1)"
SHA="$(sha256sum "$HAP" 2>/dev/null | cut -c1-16 || echo 'n/a')"

# 统一把安装包拷到 dist/，文件名带上版本和构建模式，方便发给别人或归档
mkdir -p dist
STAMP="$(date +%Y%m%d)"
OUT="dist/nju-classmate-${MODE}-${STAMP}.hap"
cp -f "$HAP" "$OUT"

hr
cat <<EOF

  ✓ 安装包已生成

    文件    : $OUT
    大小    : $SIZE
    SHA256  : $SHA...
    签名    : $([ "$SIGNED" -eq 1 ] && echo '已签名' || echo '⚠ 未签名，这个包装不上，检查签名配置')

EOF

if [ "$SIGNED" -eq 0 ]; then
  echo "  ⚠ 没找到 signed 产物，说明签名没配上。鸿蒙拒绝安装未签名的 HAP。"
  echo "    去 DevEco：File → Project Structure → Signing Configs → 勾选自动签名。"
  echo
fi

if [ "$PACKAGE_ONLY" -eq 1 ]; then
  cat <<'EOF'
  --package-only 模式，到此结束。

  把这个 .hap 拷到手机上是装不上的 —— 鸿蒙没有「未知来源安装」，
  必须用 hdc 或 DevEco 推到设备。要安装就重跑（不带 --package-only）：

      bash tools/build_and_install.sh

EOF
  exit 0
fi

# ───────────────────────── 安装 ─────────────────────────
echo "正在安装 ..."

if [ -z "$HDC" ]; then
  echo "✗ 找不到 hdc，无法安装。安装包已生成在 $OUT，可以手动推："
  echo "    hdc install -r $OUT"
  exit 1
fi

if "$HDC" install -r "$HAP"; then
  cat <<'EOF'

  ✓ 安装成功。

    接下来：
      1. 打开「南哪儿课表」→ 一键导入课表 → 登录 → 停在「我的课表」
      2. 长按桌面图标 → 卡片 → 添加「下一节课」「今日课表」
      3. 锁屏双手捏合 → 编辑态 → 添加「下一节课（锁屏）」

    注意：锁屏卡片需要手机系统 API 18+（HarmonyOS 5.1 及以上）。
    如果卡片列表里没有「南哪儿课表」，多半是系统版本不够。

EOF
else
  echo "✗ 安装失败。常见原因：签名证书里没有这台设备（重新生成自动签名）、或系统版本低于 API 12。"
  exit 1
fi
