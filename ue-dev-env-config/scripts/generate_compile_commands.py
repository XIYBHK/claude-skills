#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成 compile_commands.json 用于 C++ IntelliSense
优先使用 UBT（需要项目已编译），失败时使用 Python 脚本
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

# 设置 UTF-8 控制台
from common import setup_utf8_console, Color, is_windows

setup_utf8_console()


def generate_with_ubt(
    project_path: Path,
    engine_path: Path,
    workspace_root: Path
) -> bool:
    """使用 UBT 生成 compile_commands.json"""

    # 获取项目名称
    project_name = project_path.stem

    # UBT 路径
    ubt_path = engine_path / "Engine" / "Build" / "BatchFiles" / "Build.bat"
    if not ubt_path.exists():
        return False

    Color.print(f"   -> 尝试使用 UBT 生成...", Color.CYAN)
    Color.print(f"   项目: {project_name}", Color.GRAY)

    # 构建 UBT 命令
    cmd_args = [
        str(ubt_path),
        f"{project_name}Editor",
        "Win64",
        "Development",
        f"-Project=\"{project_path}\"",
        "-Mode=GenerateClangDatabase"
    ]

    Color.print(f"   执行 UBT...", Color.GRAY)

    try:
        result = subprocess.run(
            cmd_args,
            cwd=str(project_path.parent),
            capture_output=True,
            text=True,
            timeout=180,  # 3 分钟超时
            encoding='utf-8',
            errors='replace',
            shell=is_windows()
        )

        # UBT 可能在两个位置生成文件：
        # 1. 引擎目录: <engine>/compile_commands.json
        # 2. 项目目录: <project_parent>/compile_commands.json
        possible_paths = [
            engine_path / "compile_commands.json",
            project_path.parent / "compile_commands.json"
        ]

        generated_path = None
        for path in possible_paths:
            if path.exists():
                generated_path = path
                break

        if generated_path:
            import shutil

            # 如果是插件工作区，复制到插件目录
            target_path = workspace_root / "compile_commands.json"
            shutil.copy2(generated_path, target_path)

            # 统计条目数
            with open(target_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                count = len(data)

            Color.print(f"   ✓ UBT 生成成功: {count} 个条目", Color.GREEN)
            Color.print(f"     源文件: {generated_path.parent.name}/compile_commands.json", Color.GRAY)
            Color.print(f"     目标: {target_path}", Color.GRAY)
            return True
        else:
            return False

    except Exception as e:
        Color.print(f"   ✗ UBT 执行异常: {e}", Color.RED)
        return False


def generate_with_python(
    workspace_root: Path,
    engine_path: Path
) -> bool:
    """使用 Python 脚本生成 compile_commands.json（后备方案）"""

    Color.print(f"   -> 使用 Python 脚本生成（后备方案）...", Color.CYAN)

    # UE 头文件路径
    ue_include_paths = [
        "Engine/Source",
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
        return False

    cpp_files = list(source_dir.rglob("*.cpp"))
    if not cpp_files:
        return False

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

    # 写入文件
    output_path = workspace_root / "compile_commands.json"
    output_path.write_text(
        json.dumps(result, indent=2, ensure_ascii=False),
        encoding='utf-8'
    )

    Color.print(f"   ✓ Python 脚本生成成功: {len(commands)} 个条目", Color.GREEN)
    return True


def main():
    if len(sys.argv) < 3:
        print("用法: generate_compile_commands.py <workspace_root> <engine_path> [project_path]")
        sys.exit(1)

    workspace_root = Path(sys.argv[1])
    engine_path = Path(sys.argv[2])
    project_path = Path(sys.argv[3]) if len(sys.argv) > 3 else None

    Color.print("[生成 compile_commands.json]", Color.YELLOW)

    success = False

    # 优先尝试 UBT（如果有项目）
    if project_path and project_path.exists():
        success = generate_with_ubt(project_path, engine_path, workspace_root)

        if not success:
            Color.print("", Color.RESET)
            Color.print("   ℹ UBT 生成失败可能的原因:", Color.CYAN)
            Color.print("     1. 项目尚未编译过（需要先在 UE 编辑器中编译至少一次）", Color.WHITE)
            Color.print("     2. 项目文件损坏或配置错误", Color.WHITE)
            Color.print("", Color.RESET)
            Color.print("   -> 正在使用 Python 后备方案...", Color.YELLOW)
            Color.print("", Color.RESET)

    # 如果 UBT 失败，使用 Python 后备方案
    if not success:
        success = generate_with_python(workspace_root, engine_path)

    if not success:
        Color.print("   ✗ 生成失败", Color.RED)
        sys.exit(1)

    Color.print("")


if __name__ == "__main__":
    main()
