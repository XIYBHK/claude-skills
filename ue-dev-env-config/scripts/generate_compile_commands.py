#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成 compile_commands.json 用于 C++ IntelliSense
支持插件和项目工作区
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

# 设置 UTF-8 控制台
from common import setup_utf8_console, Color, is_windows

setup_utf8_console()


def generate_compile_commands(
    workspace_root: Path,
    engine_path: Path,
    output_path: Path = None
) -> dict:
    """生成 compile_commands.json 数据结构"""

    # UE 头文件路径
    ue_include_paths = [
        "Engine/Source",
        "Engine/Source/Runtime",
        "Engine/Source/Runtime/Core/Public",
        "Engine/Source/Runtime/CoreUObject/Public",
        "Engine/Source/Runtime/Engine/Public",
        "Engine/Source/Runtime/ApplicationCore/Public",
        "Engine/Source/Developer",
        "Engine/Source/Editor"
    ]

    # 转换为绝对路径
    include_args = []
    for rel_path in ue_include_paths:
        abs_path = engine_path / rel_path
        if abs_path.exists():
            include_args.append(f"-I\"{abs_path.as_posix()}\"")

    # UE 预定义宏
    ue_defines = [
        "-DWITH_ENGINE=1",
        "-DWITH_UNREAL_DEVELOPER_TOOLS=1",
        "-DUNREAL_BUILD=1",
        "-D_MSC_VER=1933",
        "-D_WIN32",
        "-D_WIN64"
    ]

    # 查找所有 .cpp 文件
    source_dir = workspace_root / "Source"
    if not source_dir.exists():
        Color.print(f"错误: 未找到 Source 目录: {source_dir}", Color.RED)
        sys.exit(1)

    cpp_files = list(source_dir.rglob("*.cpp"))
    if not cpp_files:
        Color.print(f"警告: 未找到任何 .cpp 文件 in {source_dir}", Color.YELLOW)
        return {"version": 2, "commands": []}

    commands = []
    for cpp_file in cpp_files:
        relative_path = cpp_file.relative_to(workspace_root).as_posix()

        cmd = {
            "directory": workspace_root.as_posix(),
            "file": relative_path,
            "arguments": " ".join([
                "clang++",
                "-xc++",
                "-std=c++20",
                "-fms-compatibility-version=19.33",
                *ue_defines,
                *include_args,
                f"-c \"{relative_path}\""
            ])
        }
        commands.append(cmd)

    result = {
        "version": 2,
        "commands": commands
    }

    return result


def main():
    if len(sys.argv) < 3:
        print("用法: generate_compile_commands.py <workspace_root> <engine_path> [output_path]")
        sys.exit(1)

    workspace_root = Path(sys.argv[1])
    engine_path = Path(sys.argv[2])
    output_path = Path(sys.argv[3]) if len(sys.argv) > 3 else workspace_root / "compile_commands.json"

    if not workspace_root.exists():
        Color.print(f"错误: 工作区不存在: {workspace_root}", Color.RED)
        sys.exit(1)

    if not engine_path.exists():
        Color.print(f"错误: 引擎不存在: {engine_path}", Color.RED)
        sys.exit(1)

    Color.print("[生成 compile_commands.json]", Color.YELLOW)
    Color.print(f"   工作区: {workspace_root}", Color.GRAY)
    Color.print(f"   引擎: {engine_path}", Color.GRAY)
    Color.print("")

    # 生成数据
    result = generate_compile_commands(workspace_root, engine_path)

    # 写入文件
    output_path.write_text(
        json.dumps(result, indent=2, ensure_ascii=False),
        encoding='utf-8'
    )

    Color.print(f"   ✓ 已生成: {output_path}", Color.GREEN)
    Color.print(f"   ✓ 包含 {len(result['commands'])} 个编译条目", Color.GREEN)
    Color.print("")


if __name__ == "__main__":
    main()
