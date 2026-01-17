#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
OpenCode LSP 配置脚本 (优化版)
功能：安装和配置 clangd 用于 OpenCode LSP 支持
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path
from typing import Optional

# 设置 UTF-8 控制台
from common import (
    setup_utf8_console,
    Color,
    print_box,
    ClangdDetector,
    is_windows,
)

setup_utf8_console()


# ========================================
# Clangd 安装器
# ========================================

class ClangdInstaller:
    """Clangd 安装器"""

    @staticmethod
    def install_llvm_windows() -> bool:
        """使用 winget 安装 LLVM"""
        Color.print("\n使用 winget 安装 LLVM.LLVM...", Color.CYAN)
        Color.print("将下载约 356 MB 安装包，请耐心等待...", Color.GRAY)
        print()

        try:
            result = subprocess.run(
                ['winget', 'install', 'LLVM.LLVM',
                 '--accept-package-agreements', '--accept-source-agreements'],
                capture_output=True,
                text=True,
                timeout=600  # 10 分钟超时（LLVM 安装包约 356 MB）
            )

            if result.returncode == 0:
                Color.print("\n[OK] LLVM.LLVM 安装成功！", Color.GREEN)
                Color.print("clangd 已自动安装到系统中", Color.GREEN)
                return True
            else:
                Color.print("\n[ERROR] LLVM.LLVM 安装失败", Color.RED)
                Color.print(f"错误信息: {result.stderr}", Color.RED)
                return False

        except subprocess.TimeoutExpired:
            Color.print("\n[ERROR] 安装超时", Color.RED)
            return False
        except FileNotFoundError:
            Color.print("\n[ERROR] 未找到 winget 命令", Color.RED)
            Color.print("请确保 Windows 10/11 已安装 App Installer", Color.YELLOW)
            return False
        except Exception as e:
            Color.print(f"\n[ERROR] 安装错误: {e}", Color.RED)
            return False

    @staticmethod
    def add_to_path_windows(llvm_path: Path) -> bool:
        """将 LLVM 添加到 Windows 用户 PATH"""
        try:
            # 获取当前用户 PATH
            result = subprocess.run(
                ['powershell', '-Command',
                 '[System.Environment]::GetEnvironmentVariable("Path", "User")'],
                capture_output=True,
                text=True
            )

            if result.returncode != 0:
                return False

            current_path = result.stdout.strip()
            llvm_path_str = str(llvm_path)

            # 检查是否已在 PATH 中
            if llvm_path_str in current_path:
                Color.print("   [OK] LLVM 已在 PATH 中", Color.GREEN)
                return True

            # 添加到 PATH
            new_path = f"{current_path};{llvm_path_str}"
            subprocess.run(
                ['powershell', '-Command',
                 f'[System.Environment]::SetEnvironmentVariable("Path", "{new_path}", "User")'],
                check=True
            )

            Color.print(f"   [OK] 已添加 LLVM 到用户 PATH", Color.GREEN)
            Color.print(f"   路径: {llvm_path_str}", Color.WHITE)
            Color.print("\n   [WARN] 注意：新 PATH 在新终端会话中生效", Color.YELLOW)
            Color.print("   → 请重新启动终端或 OpenCode", Color.GRAY)
            return True

        except Exception as e:
            Color.print(f"   [ERROR] 添加到 PATH 失败: {e}", Color.RED)
            return False


# ========================================
# 步骤函数
# ========================================

def step_check_clangd() -> tuple[bool, Optional[Path], Optional[str]]:
    """步骤 0: 检测 clangd 安装状态"""
    Color.print("[步骤 0/4] 检测 clangd 安装状态...", Color.YELLOW)

    is_installed, version_info = ClangdDetector.check_clangd()
    llvm_path = ClangdDetector.find_llvm_path()

    if is_installed:
        Color.print("   [OK] clangd 已安装！", Color.GREEN)
        Color.print(f"   版本信息: {version_info}", Color.WHITE)
    else:
        Color.print("   [ERROR] clangd 未安装或不在 PATH 中", Color.YELLOW)

    if llvm_path:
        Color.print(f"   [OK] 找到 LLVM: {llvm_path}", Color.GREEN)
    else:
        Color.print("   [WARN] 未找到 LLVM 安装路径", Color.YELLOW)

    print()
    return is_installed, llvm_path, version_info


def step_install(llvm_path: Optional[Path]) -> bool:
    """步骤 1-3: 安装 clangd（如需要）"""
    if llvm_path:
        Color.print("[步骤 1/4] clangd 已安装，添加到 PATH...", Color.YELLOW)
        print()
        return True

    if not is_windows():
        Color.print("[步骤 1/4] 安装 clangd", Color.YELLOW)
        Color.print("\n[ERROR] 自动安装仅支持 Windows 平台", Color.RED)
        Color.print("\n请手动安装 clangd：", Color.YELLOW)
        Color.print("  Linux: sudo apt install clangd", Color.GRAY)
        Color.print("  Mac: brew install llvm", Color.GRAY)
        return False

    Color.print("[步骤 1/4] 安装 LLVM.LLVM (包含 clangd)...", Color.YELLOW)

    if not ClangdInstaller.install_llvm_windows():
        Color.print("\n请尝试手动安装：", Color.YELLOW)
        Color.print("  1. 从官网下载: https://github.com/clangd/clangd/releases", Color.GRAY)
        Color.print("  2. 或使用其他包管理器安装", Color.GRAY)
        return False

    # 重新检测
    print()
    Color.print("[步骤 2/4] 验证安装...", Color.YELLOW)

    import time
    time.sleep(2)

    is_installed, version_info = ClangdDetector.check_clangd()
    llvm_path = ClangdDetector.find_llvm_path()

    if is_installed and llvm_path:
        Color.print("   [OK] clangd 验证成功！", Color.GREEN)
        Color.print(f"   版本: {version_info}", Color.WHITE)
    else:
        Color.print("   [WARN] clangd 验证失败，可能需要重启终端", Color.YELLOW)
        if version_info:
            Color.print(f"   版本: {version_info}", Color.WHITE)

    print()
    Color.print("[步骤 3/4] 添加 LLVM 到 PATH...", Color.YELLOW)
    print()

    return True


def step_configure_path(llvm_path: Optional[Path]) -> None:
    """步骤 3: 添加到 PATH"""
    if llvm_path and is_windows():
        ClangdInstaller.add_to_path_windows(llvm_path)
    elif llvm_path:
        Color.print("   [OK] LLVM 已在 PATH 中", Color.GREEN)
    print()


def print_next_steps() -> None:
    """打印下一步操作"""
    print()
    Color.print("╔══════════════════════════════════════════════════════════╗", Color.CYAN)
    Color.print("║                下一步操作                                 ║", Color.CYAN)
    Color.print("╚══════════════════════════════════════════════════════════╝", Color.CYAN)
    print()

    Color.print("1. 配置 opencode.json", Color.WHITE)
    Color.print("   运行: python configure_opencode_json.py", Color.GRAY)
    Color.print("   此脚本会：", Color.GRAY)
    Color.print("   - 检测或提示输入 UE 引擎路径", Color.GRAY)
    Color.print("   - 生成 opencode.json LSP 配置", Color.GRAY)
    Color.print("   - 配置 clangd 命令和参数", Color.GRAY)
    print()

    Color.print("2. 重启 OpenCode", Color.WHITE)
    Color.print("   关闭当前 OpenCode 会话", Color.GRAY)
    Color.print("   重新打开 OpenCode", Color.GRAY)
    print()

    Color.print("3. 打开任意 C/C++ 文件", Color.WHITE)
    Color.print("   OpenCode 会自动启动 clangd LSP", Color.GRAY)
    Color.print("   LSP 诊断和代码智能功能将可用", Color.GRAY)
    print()


# ========================================
# 主函数
# ========================================

def main() -> int:
    print_box("OpenCode Clangd LSP 配置工具")

    # 步骤 0: 检测
    is_installed, llvm_path, version_info = step_check_clangd()

    # 步骤 1-3: 安装
    if not step_install(llvm_path):
        return 1

    # 重新获取路径
    _, llvm_path, _ = step_check_clangd()

    # 步骤 3: 添加到 PATH
    step_configure_path(llvm_path)

    # 步骤 4: 生成配置指南
    Color.print("[步骤 4/4] 生成配置指南...", Color.YELLOW)
    print_next_steps()

    Color.print("╔══════════════════════════════════════════════════════════╗", Color.GREEN)
    Color.print("║              Clangd LSP 配置完成！                       ║", Color.GREEN)
    Color.print("╚══════════════════════════════════════════════════════════╝", Color.GREEN)
    print()

    Color.print("配置摘要:", Color.CYAN)
    if llvm_path:
        Color.print(f"   Clangd 路径: {llvm_path}", Color.WHITE)
    if is_installed and version_info:
        Color.print(f"   Clangd 版本: {version_info}", Color.WHITE)
    print()

    Color.print("Clangd LSP 配置完成！", Color.GREEN)
    print()

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
