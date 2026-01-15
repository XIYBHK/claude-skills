#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Git 状态分析脚本
自动分析 git status 并建议提交作用域 (scope)
"""

import subprocess
import sys
import io
from pathlib import Path

# 配置 UTF-8 输出（修复 Windows 编码问题）
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')


def run_git_command(args):
    """运行 git 命令并返回输出"""
    try:
        result = subprocess.run(
            ['git'] + args,
            capture_output=True,
            text=True,
            check=False
        )
        return result.stdout.strip(), result.returncode
    except FileNotFoundError:
        print("错误: 未找到 git 命令")
        sys.exit(1)


def get_modified_files():
    """获取修改的文件列表"""
    output, _ = run_git_command(['status', '--porcelain'])
    files = []
    for line in output.split('\n'):
        if line:
            # 解析状态: XY filename
            status = line[:2]
            filepath = line[3:]
            if filepath.strip():
                files.append({
                    'status': status,
                    'path': filepath.strip()
                })
    return files


def extract_module_from_path(filepath, project_root=None):
    """从文件路径提取模块名"""
    path = Path(filepath)

    # 解析路径: Source/ModuleName/...
    parts = path.parts
    if 'Source' in parts:
        idx = parts.index('Source')
        if idx + 1 < len(parts):
            return parts[idx + 1]

    return None


def suggest_scope(modified_files):
    """根据修改的文件建议作用域"""
    modules = set()
    for file in modified_files:
        module = extract_module_from_path(file['path'])
        if module:
            modules.add(module)

    # 过滤掉第三方集成模块
    third_party = {'XTools_EnhancedCodeFlow', 'XTools_AutoSizeComments',
                   'XTools_BlueprintAssist', 'XTools_ElectronicNodes',
                   'XTools_BlueprintScreenshotTool', 'XTools_SwitchLanguage'}

    modules = modules - third_party

    if not modules:
        return None

    # 按字母排序并返回逗号分隔的列表
    return ','.join(sorted(modules))


def main():
    """主函数"""
    print("=== Git 状态分析 ===\n")

    # 获取修改的文件
    modified_files = get_modified_files()

    if not modified_files:
        print("当前没有修改的文件")
        return

    print("修改的文件:")
    for file in modified_files:
        print(f"  [{file['status']}] {file['path']}")

    # 建议作用域
    suggested_scope = suggest_scope(modified_files)
    print(f"\n建议的 scope: {suggested_scope if suggested_scope else '(无)'}")

    # 输出为机器可读格式（供 Claude 解析）
    print("\n=== 解析结果 ===")
    print(f"SCOPE_SUGGESTION={suggested_scope if suggested_scope else ''}")


if __name__ == '__main__':
    main()
