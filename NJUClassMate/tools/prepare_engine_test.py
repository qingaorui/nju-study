"""
把 ArkTS 源码预处理成 Node 能直接跑的 TS，用于离线验证核心算法。

做四件事：
  1. .ets -> .ts
  2. 去掉所有 @kit.* / @ohos.* 的平台 import（核心算法用不到这些）
  3. 相对 import 补 .ts 后缀（Node 原生 TS 要求显式后缀）
  4. 把"纯类型"的导入名从 import 列表里摘掉

第 4 步是必须的：interface 在编译后被完全擦除，
Node 的 ESM 在运行时会因为"模块没有导出这个名字"直接报错，
而 TypeScript 的常规编译会在类型检查阶段就把它剥掉，所以我们得手工做一遍。

用法：
  python tools/prepare_engine_test.py
  node --experimental-transform-types tools/engine_test.gen.ts
"""
import os
import re
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'entry', 'src', 'main', 'ets')
DST = os.path.join(ROOT, 'tools', '.engine-test')

MODULES = [
    'model/Course',
    'constants/SchoolConfig',
    'common/DateUtil',
    'common/Logger',
    'service/CourseStore',
    'service/NextClassEngine',
]

TEST_SRC = os.path.join(ROOT, 'tools', 'engine_test.ts')
TEST_DST = os.path.join(ROOT, 'tools', 'engine_test.gen.ts')

LOGGER_STUB = """export class Logger {
  static d(msg: string): void {}
  static i(msg: string): void {}
  static w(msg: string): void {}
  static e(msg: string): void { console.error('[Logger.e] ' + msg); }
}
"""

TYPE_RE = re.compile(r'^\s*export\s+(?:declare\s+)?(?:interface|type)\s+(\w+)', re.M)
VALUE_RE = re.compile(
    r'^\s*export\s+(?:declare\s+)?(?:abstract\s+)?(?:function|class|const|let|var|enum|namespace)\s+(\w+)',
    re.M)
IMPORT_RE = re.compile(r"^\s*import\s+(?:type\s+)?\{([^}]*)\}\s+from\s+'([^']+)';\s*$", re.M)


def strip_platform_imports(code: str) -> str:
    return re.sub(r"^\s*import\s+[^;]*?from\s+'@(?:kit|ohos)\.[^']*';\s*$", '', code, flags=re.M)


def fix_specifiers(code: str) -> str:
    return re.sub(r"from\s+'(\.\.?/[^']+?)(?:\.ets)?';", r"from '\1.ts';", code)


def collect_exports(code: str):
    return set(TYPE_RE.findall(code)), set(VALUE_RE.findall(code))


def prune_imports(code: str, index: dict) -> str:
    """把指向工程内部模块的 import 里，只保留运行时有值的名字。

    索引按"文件名（去扩展名）"建键：工程内这几个模块名互不重复，
    比解析相对路径稳妥得多，也不会因为目录层级变化而失效。
    """

    def repl(m: re.Match) -> str:
        names = [n.strip() for n in m.group(1).split(',') if n.strip()]
        spec = m.group(2)
        if not spec.startswith('.'):
            return m.group(0)
        base = re.sub(r'\.ts$', '', os.path.basename(spec))
        entry = index.get(base)
        if entry is None:
            return m.group(0)
        types, values = entry
        kept = [n for n in names if n in values or n not in types]
        if not kept:
            return ''
        return f"import {{ {', '.join(kept)} }} from '{spec}';"

    return IMPORT_RE.sub(repl, code)


def main():
    if os.path.isdir(DST):
        shutil.rmtree(DST)

    # 第一遍：收集每个模块导出的类型名和值名
    index = {}
    sources = {}
    for rel in MODULES:
        with open(os.path.join(SRC, rel + '.ets'), encoding='utf-8') as f:
            sources[rel] = f.read()
        index[os.path.basename(rel)] = collect_exports(sources[rel])

    # 第二遍：写出去
    for rel in MODULES:
        code = strip_platform_imports(sources[rel])
        code = fix_specifiers(code)
        code = prune_imports(code, index)
        dst = os.path.join(DST, 'ets', rel + '.ts')
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, 'w', encoding='utf-8', newline='\n') as f:
            f.write(code)

    # Logger 依赖 hilog，测试环境里换成空实现
    with open(os.path.join(DST, 'ets/common/Logger.ts'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(LOGGER_STUB)

    # 测试文件本身也要摘掉纯类型导入
    with open(TEST_SRC, encoding='utf-8') as f:
        test_code = f.read()
    test_code = prune_imports(test_code, index)
    with open(TEST_DST, 'w', encoding='utf-8', newline='\n') as f:
        f.write(test_code)

    print('  prepared %d modules + engine_test.gen.ts' % len(MODULES))


if __name__ == '__main__':
    main()
