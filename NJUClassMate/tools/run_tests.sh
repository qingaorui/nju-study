#!/usr/bin/env bash
# 一键跑全部离线测试。
#
#   bash tools/run_tests.sh
#
# 不需要模拟器、不需要真机、不需要登录教务系统。
# 覆盖：
#   1. 四个课表抓取脚本的解析（教务系统改版时最先坏的地方）
#   2. 两个工程里的抓取脚本副本是否分叉（改一份忘同步另一份是最容易犯的错）
#   3. RemoteViews 布局的控件白名单（用了 <View> 之类的控件编译期不报错、
#      运行时才炸，而且报错信息完全指不到根因）
#   4. 「下一节课」计算引擎 —— 鸿蒙 ArkTS 版 + 安卓 Kotlin 版
#
# ⚠ 路径坑：这个脚本跑在 Git Bash 里，而 python/node/java 是原生 Windows 程序。
#   Git Bash 的 /c/Users/... 传给它们会被解析成 C:\c\Users\...。
#   所以下面**一律先 cd 再用相对路径**，绝不把 bash 绝对路径当参数传出去。

set -uo pipefail

HARMONY="$(cd "$(dirname "$0")/.." && pwd)"
ANDROID="$(cd "$HARMONY/.." && pwd)/NJUClassMate-Android"

find_python() {
  for p in \
    "$HOME/.workbuddy/binaries/python/versions/3.13.12/python.exe" \
    "$HOME/.workbuddy/binaries/python/versions/3.13.12/bin/python"
  do
    [ -x "$p" ] && { echo "$p"; return; }
  done
  command -v python3 || command -v python
}

find_node() {
  for p in \
    "$HOME/.workbuddy/binaries/node/versions/22.22.2-2/node.exe" \
    "$HOME/.workbuddy/binaries/node/versions/22.22.2-2/bin/node"
  do
    [ -x "$p" ] && { echo "$p"; return; }
  done
  command -v node
}

PY="$(find_python)"
NODE="$(find_node)"

echo "python  : $PY"
echo "node    : $NODE"
echo

FAILED=0
TOTAL=0

# $1 标题  $2 相对 HARMONY 的测试文件  $3 相对 HARMONY 的脚本目录
run_extractor_suite() {
  local title="$1" file="$2" dir="$3"
  echo "─────────────── ${title} ───────────────"
  local out rc
  out="$( cd "$HARMONY" && NJU_EXTRACTOR_DIR="$dir" "$NODE" "$file" 2>&1 )"
  rc=$?
  echo "$out"
  local n
  n="$(printf '%s\n' "$out" | grep -c '✓' || true)"
  TOTAL=$((TOTAL + n))
  [ $rc -ne 0 ] && FAILED=1
  echo
}

# ---------------- 1. 抓取脚本 ----------------
run_extractor_suite "[1/5] 抓取脚本 · 本科教务系统（鸿蒙副本）" \
  "tools/test_extractor.js" \
  "entry/src/main/resources/rawfile"

run_extractor_suite "[2/5] 抓取脚本 · 另三个入口（鸿蒙副本）" \
  "tools/test_extractors_extra.js" \
  "entry/src/main/resources/rawfile"

if [ -d "$ANDROID/app/src/main/assets/www/extractors" ]; then
  run_extractor_suite "[3/5] 抓取脚本 · 安卓工程副本" \
    "tools/test_extractors_extra.js" \
    "../NJUClassMate-Android/app/src/main/assets/www/extractors"
else
  echo "─────────────── [3/5] 安卓工程未找到，跳过 ───────────────"
  echo
fi

# ---------------- 2. 两个工程的脚本必须逐字节一致 ----------------
echo "─────────────── 脚本副本一致性 ───────────────"
for f in njubksjw.js njubksxk.js njuyjsjw.js njuyjsxk.js; do
  a="$HARMONY/entry/src/main/resources/rawfile/$f"
  b="$ANDROID/app/src/main/assets/www/extractors/$f"
  if [ ! -f "$a" ]; then echo "  缺失(鸿蒙) $f"; FAILED=1; continue; fi
  if [ ! -f "$b" ]; then echo "  缺失(安卓) $f"; FAILED=1; continue; fi
  if cmp -s "$a" "$b"; then
    echo "  ✓ 一致  $f"
    TOTAL=$((TOTAL + 1))
  else
    echo "  ✗ 不一致 $f   —— 两边副本已经分叉！"
    FAILED=1
  fi
done
echo

# ---------------- 3. 安卓工程的静态检查 + 网页执行沙箱 ----------------
echo "─────────────── [4/5] 安卓静态检查 + 网页执行沙箱 ───────────────"
# 这三个检查抓的都是**编译器不会报错**的问题：
#   · RemoteViews 用了非白名单控件 → 运行时才抛 InflateException
#   · 前端调了 Kotlin 没分发的方法 → 运行时只返回"未知方法"，界面点了没反应
#   · app.js 加载/渲染时抛异常 → 按钮绑不上、页面空白（用假 DOM 真跑一遍）
# 都用相对路径调用（原生 python/node 不认 Git Bash 的 /c/... 路径）
if [ -d "$ANDROID/app/src/main/res/layout" ]; then
  for chk in check_remoteviews.py check_bridge.py; do
    echo "  ── $chk ──"
    CHK_OUT="$( cd "$ANDROID" && "$PY" "../tools/$chk" . 2>&1 )"
    CHK_RC=$?
    printf '%s\n' "$CHK_OUT" | sed 's/^/  /'
    TOTAL=$((TOTAL + 1))
    [ $CHK_RC -ne 0 ] && FAILED=1
    echo
  done

  echo "  ── www_smoke.js（假 DOM 跑 app.js） ──"
  # 先 cd 到工作区根再用相对路径：原生 node 不认 Git Bash 的 /c/... 绝对路径
  SMOKE_OUT="$( cd "$HARMONY/.." && "$NODE" tools/www_smoke.js 2>&1 )"
  SMOKE_RC=$?
  printf '%s\n' "$SMOKE_OUT" | sed 's/^/  /'
  TOTAL=$((TOTAL + 1))
  [ $SMOKE_RC -ne 0 ] && FAILED=1
  echo
else
  echo "  安卓工程未找到，跳过"
  echo
fi

# ---------------- 4. 计算引擎 ----------------
echo "─────────────── [5/5] 下一节课计算引擎 ───────────────"

# 4a. 鸿蒙 ArkTS 版：预处理成 Node 能跑的 TS
echo "  ── 鸿蒙 ArkTS 引擎 ──"
if [ -f "$HARMONY/tools/engine_test.ts" ]; then
  ( cd "$HARMONY" && "$PY" tools/prepare_engine_test.py >/dev/null )
  ENV_OUT="$( cd "$HARMONY" && "$NODE" --experimental-transform-types tools/engine_test.gen.ts 2>/dev/null || true )"
  printf '%s\n' "$ENV_OUT" | grep -E '结果：|✗' || true
  n="$(printf '%s\n' "$ENV_OUT" | grep -c '✓' || true)"
  TOTAL=$((TOTAL + n))
  if ! ( cd "$HARMONY" && "$NODE" --experimental-transform-types tools/engine_test.gen.ts >/dev/null 2>&1 ); then
    FAILED=1
  fi
fi

# 4b. 安卓 Kotlin 版：真正的 JVM 单测
echo
echo "  ── 安卓 Kotlin 引擎（JVM 单测） ──"
if [ -f "D:/android-dev/gradle/bin/gradle.bat" ] && [ -e "D:/android-dev/sdk/platforms/android-34/android.jar" ]; then
  if ( cd "$ANDROID" \
        && JAVA_HOME="D:/android-dev/jdk" ANDROID_HOME="D:/android-dev/sdk" \
           "D:/android-dev/gradle/bin/gradle.bat" :app:testDebugUnitTest \
           --no-daemon --console=plain -q >/tmp/gradle_test.log 2>&1 ); then
    # 统计必须也在 ANDROID 目录下做：相对 glob 才对得上
    KT=$( cd "$ANDROID" && "$PY" -c "
import glob, re
total = fails = 0
for f in glob.glob('app/build/test-results/testDebugUnitTest/*.xml'):
    s = open(f, encoding='utf-8').read()
    m = re.search(r'tests=\"(\d+)\".*?failures=\"(\d+)\".*?errors=\"(\d+)\"', s)
    if m:
        total += int(m.group(1)); fails += int(m.group(2)) + int(m.group(3))
print(f'{total} {fails}')
" 2>/dev/null )
    KT_N="${KT%% *}"; KT_F="${KT##* }"
    echo "     Kotlin 引擎单测：${KT_N:-?} 项，失败 ${KT_F:-?}"
    TOTAL=$((TOTAL + ${KT_N:-0}))
    [ "${KT_F:-1}" != "0" ] && FAILED=1
  else
    echo "     ✗ Gradle 单测失败，日志：/tmp/gradle_test.log"
    tail -20 /tmp/gradle_test.log
    FAILED=1
  fi
else
  echo "     （安卓工具链未就绪，跳过）"
fi

echo
echo "════════════════════════════════════════════════════"
if [ "$FAILED" -eq 0 ]; then
  echo "全部测试通过 ✓   共 ${TOTAL} 项断言"
else
  echo "存在失败的测试 ✗"
  exit 1
fi
