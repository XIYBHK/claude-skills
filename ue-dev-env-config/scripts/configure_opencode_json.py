#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
OpenCode JSON 配置生成脚本 (优化版)
功能：生成 opencode.json 的 LSP 配置
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Optional

# 设置 UTF-8 控制台
from common import (
    setup_utf8_console,
    Color,
    print_box,
    EngineDetector,
    EngineInfo,
)

setup_utf8_console()


# ========================================
# 配置生成器
# ========================================

class OpencodeConfigGenerator:
    """OpenCode 配置生成器"""

    def __init__(self, workspace_root: Path, engine_path: Path):
        self.workspace_root = workspace_root
        self.engine_path = engine_path
        self.vscode_dir = workspace_root / ".vscode"

    def _ensure_dir(self) -> None:
        """确保 .vscode 目录存在"""
        self.vscode_dir.mkdir(exist_ok=True)

    def generate(self) -> Path:
        """生成 opencode.json"""
        compile_commands_path = self.engine_path / "compile_commands.json"

        # 检查 compile_commands.json 是否存在
        if not compile_commands_path.exists():
            Color.print(f"   ⚠ 警告: compile_commands.json 不存在", Color.YELLOW)
            Color.print(f"   路径: {compile_commands_path}", Color.YELLOW)
            Color.print(f"   IntelliSense 可能不准确", Color.YELLOW)
            print()
            Color.print(f"   建议先运行 UE 项目生成或使用 VSCode 编译任务生成", Color.GRAY)
            print()
        else:
            Color.print(f"   ✓ 找到 compile_commands.json", Color.GREEN)

        # 生成配置
        config = {
            "$schema": "https://opencode.ai/config.json",
            "lsp": {
                "clangd": {
                    "command": [
                        "clangd",
                        f"--compile-commands-dir={self.engine_path.as_posix()}"
                    ],
                    "extensions": [
                        ".c", ".cpp", ".cc", ".cxx", ".c++",
                        ".h", ".hpp", ".hh", ".hxx", ".h++"
                    ],
                    "disabled": False
                }
            }
        }

        config_file = self.vscode_dir / "opencode.json"
        with open(config_file, 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=4, ensure_ascii=False)

        Color.print(f"   ✓ 已生成 opencode.json", Color.GREEN)
        Color.print(f"   位置: {config_file}", Color.GRAY)

        return config_file


# ========================================
# 步骤函数
# ========================================

def step_detect_engine(args: argparse.Namespace) -> EngineInfo:
    """步骤 1: 检测或获取 UE 引擎"""
    Color.print("[步骤 1/3] 检测 Unreal Engine 安装...", Color.YELLOW)

    if args.engine_path:
        engine_path = Path(args.engine_path)
        Color.print(f"   ✓ 使用指定的引擎路径: {engine_path}", Color.GREEN)
        # 验证引擎路径
        if not (engine_path / "Engine").exists():
            Color.print(f"   ✗ 无效的引擎路径", Color.RED)
            sys.exit(1)
        return EngineInfo(version="Custom", path=engine_path, engine_type="Manual")

    engines = EngineDetector.detect()
    if not engines:
        Color.print("   ✗ 未找到 UE 引擎安装！", Color.RED)
        print()
        sys.exit(1)

    Color.print(f"   ✓ 找到 {len(engines)} 个 UE 引擎", Color.GREEN)
    for engine in engines:
        Color.print(f"     - {engine}", Color.GRAY)

    if len(engines) == 1:
        Color.print(f"   -> 自动选择: {engines[0].version}", Color.CYAN)
        return engines[0]

    # 交互选择
    print()
    Color.print("   选择要使用的引擎版本:", Color.YELLOW)
    for i, engine in enumerate(engines):
        Color.print(f"   [{i}] {engine.version} - {engine.path}", Color.WHITE)

    while True:
        try:
            choice = input("   请输入序号 (默认: 0): ").strip()
            idx = int(choice) if choice else 0
            if 0 <= idx < len(engines):
                Color.print(f"   -> 已选择: {engines[idx].path}", Color.CYAN)
                return engines[idx]
            Color.print(f"   ✗ 无效选择，请输入 0-{len(engines)-1}", Color.RED)
        except ValueError:
            Color.print("   ✗ 请输入有效数字", Color.RED)
        except KeyboardInterrupt:
            print()
            Color.print("\n操作已取消", Color.YELLOW)
            sys.exit(1)


def step_verify_engine(engine: EngineInfo) -> None:
    """步骤 2: 验证引擎路径"""
    Color.print("[步骤 2/3] 验证引擎路径...", Color.YELLOW)

    engine_dir = engine.path / "Engine"
    if not engine_dir.exists():
        Color.print(f"   ✗ 无效的引擎路径: {engine.path}", Color.RED)
        Color.print(f"   未找到 Engine 目录", Color.RED)
        sys.exit(1)

    Color.print("   ✓ 引擎路径验证通过", Color.GREEN)
    print()


def step_generate_config(workspace_root: Path, engine: EngineInfo) -> Path:
    """步骤 3: 生成 opencode.json"""
    Color.print("[步骤 3/3] 生成 opencode.json...", Color.YELLOW)
    print()

    generator = OpencodeConfigGenerator(workspace_root, engine.path)
    generator._ensure_dir()
    return generator.generate()


def print_summary(engine: EngineInfo, config_file: Path) -> None:
    """打印配置摘要"""
    print()

    Color.print("╔══════════════════════════════════════════════════════════╗", Color.GREEN)
    Color.print("║              配置完成！                                   ║", Color.GREEN)
    Color.print("╚══════════════════════════════════════════════════════════╝", Color.GREEN)
    print()

    Color.print("📋 配置摘要:", Color.CYAN)
    Color.print(f"   UE 引擎路径: {engine.path}", Color.WHITE)
    Color.print(f"   opencode.json: {config_file}", Color.WHITE)
    Color.print(f"   compile_commands.json: {engine.path / 'compile_commands.json'}", Color.WHITE)
    print()

    Color.print("📝 下一步操作:", Color.CYAN)
    print()
    Color.print("   1. 验证 opencode.json 配置", Color.WHITE)
    Color.print(f"      → 打开: {config_file}", Color.GRAY)
    print()
    Color.print("   2. 重启 OpenCode", Color.WHITE)
    Color.print("      → 关闭当前 OpenCode 会话", Color.GRAY)
    Color.print("      → 重新打开 OpenCode", Color.GRAY)
    Color.print("      → LSP 配置将自动生效", Color.GRAY)
    print()
    Color.print("   3. 打开任意 C/C++ 文件", Color.WHITE)
    Color.print("      → OpenCode 会自动启动 clangd LSP", Color.GRAY)
    Color.print("      → 验证 LSP 状态（查看 OpenCode 日志）", Color.GRAY)
    print()

    Color.print("✨ OpenCode LSP 配置完成！", Color.GREEN)
    print()


# ========================================
# 主函数
# ========================================

def main() -> int:
    parser = argparse.ArgumentParser(
        description='OpenCode JSON 配置生成工具',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument('-e', '--engine-path', help='指定 UE 引擎路径')

    args = parser.parse_args()

    print_box("OpenCode LSP 配置向导")

    workspace_root = Path.cwd()

    # 执行步骤
    engine = step_detect_engine(args)
    step_verify_engine(engine)
    config_file = step_generate_config(workspace_root, engine)
    print_summary(engine, config_file)

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        Color.print("\n\n操作已取消", Color.YELLOW)
        sys.exit(1)
    except Exception as e:
        Color.print(f"\n错误: {e}", Color.RED)
        import traceback
        traceback.print_exc()
        sys.exit(1)
