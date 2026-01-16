#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
UE Dev Environment Config - Common Utilities
共享工具模块：提供跨脚本的通用功能
"""

import os
import sys
from pathlib import Path
from dataclasses import dataclass
from typing import Optional, List
from enum import Enum


# ========================================
# 常量定义
# ========================================

class DriveLetter(str, Enum):
    """Windows 驱动器字母枚举"""
    A: str = "A:"
    B: str = "B:"
    C: str = "C:"
    D: str = "D:"
    E: str = "E:"
    F: str = "F:"
    G: str = "G:"
    H: str = "H:"
    I: str = "I:"
    J: str = "J:"
    K: str = "K:"
    L: str = "L:"
    M: str = "M:"
    N: str = "N:"
    O: str = "O:"
    P: str = "P:"
    Q: str = "Q:"
    R: str = "R:"
    S: str = "S:"
    T: str = "T:"
    U: str = "U:"
    V: str = "V:"
    W: str = "W:"
    X: str = "X:"
    Y: str = "Y:"
    Z: str = "Z:"


# 常见 UE 引擎安装路径
EPIC_GAMES_PATHS = [
    "Program Files/Epic Games",
    "Epic Games"
]

# Visual Studio 2022 安装路径
VS2022_PATHS = [
    "C:/Program Files/Microsoft Visual Studio/2022",
    "C:/Program Files (x86)/Microsoft Visual Studio/2022"
]

# VS 版本列表
VS_EDITIONS = ["Enterprise", "Professional", "Community", "BuildTools"]

# LLVM 安装路径（Windows）
LLVM_PATHS_WINDOWS = [
    Path("C:/Program Files/LLVM/bin"),
    Path("C:/Program Files (x86)/LLVM/bin")
]

# 常见 UE 项目基础路径
PROJECT_BASE_PATHS = [
    Path("F:/Unreal Projects/CPP"),
    Path("D:/Unreal Projects"),
    Path("C:/Unreal Projects")
]


# ========================================
# 控制台输出
# ========================================

class Color:
    """控制台颜色输出（ANSI 转义码）"""

    RESET = '\033[0m'
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    CYAN = '\033[96m'
    GRAY = '\033[90m'
    WHITE = '\033[97m'

    @staticmethod
    def print(text: str, color: str = '') -> None:
        """打印带颜色的文本"""
        print(f"{color}{text}{Color.RESET}")


def setup_utf8_console() -> None:
    """设置控制台为 UTF-8 编码（仅 Windows）"""
    if sys.platform == 'win32':
        try:
            import io
            sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
            sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')
        except Exception:
            pass


# ========================================
# 数据类
# ========================================

@dataclass(frozen=True)
class EngineInfo:
    """UE 引擎信息"""
    version: str
    path: Path
    engine_type: str

    def __str__(self) -> str:
        return f"UE {self.version} ({self.engine_type})"

    def __repr__(self) -> str:
        return f"EngineInfo(version={self.version!r}, path={self.path!r}, type={self.engine_type!r})"


@dataclass(frozen=True)
class VSInfo:
    """Visual Studio 信息"""
    edition: str
    msvc_path: Path


@dataclass(frozen=True)
class WorkspaceInfo:
    """工作区信息"""
    type: str  # "Plugin", "Project", "Unknown"
    file: Optional[Path]
    root: Path


# ========================================
# 平台工具
# ========================================

def get_available_drives() -> List[str]:
    """获取所有可用的驱动器"""
    if sys.platform != 'win32':
        return ['/']
    return [f"{letter}:" for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ" if os.path.exists(f"{letter}:")]


def is_windows() -> bool:
    """检查是否为 Windows 平台"""
    return sys.platform == 'win32'


# ========================================
# 检测器基类
# ========================================

class EngineDetector:
    """UE 引擎检测器"""

    @staticmethod
    def detect() -> List[EngineInfo]:
        """检测所有已安装的 UE 引擎"""
        engines = []

        for drive in get_available_drives():
            drive_path = Path(drive)
            for base in EPIC_GAMES_PATHS:
                base_path = drive_path / base
                if not base_path.exists():
                    continue

                try:
                    for ue_dir in base_path.iterdir():
                        if not ue_dir.is_dir() or not ue_dir.name.startswith("UE_"):
                            continue
                        if not (ue_dir / "Engine").exists():
                            continue

                        version = ue_dir.name.replace("UE_", "")
                        # 排除 UE 5.0-5.2
                        parts = version.split('.')
                        if len(parts) >= 2:
                            try:
                                if int(parts[0]) == 5 and 0 <= int(parts[1]) <= 2:
                                    continue
                            except ValueError:
                                pass

                        engines.append(EngineInfo(
                            version=version,
                            path=ue_dir,
                            engine_type="Epic Games Launcher"
                        ))
                except (PermissionError, FileNotFoundError):
                    pass

        # 检测源码构建版本
        for drive in get_available_drives():
            custom = Path(drive) / "UnrealEngine"
            if (custom / "Engine").exists():
                engines.append(EngineInfo(
                    version="Custom",
                    path=custom,
                    engine_type="Source Build"
                ))

        return engines


class VSMSVCDetector:
    """Visual Studio / MSVC 检测器"""

    @staticmethod
    def detect() -> Optional[VSInfo]:
        """检测 Visual Studio 和 MSVC"""
        bases = [Path(p) for p in VS2022_PATHS]
        for drive in get_available_drives():
            if drive != "C:":
                bases.extend([
                    Path(drive) / "VisualStudio/2022",
                    Path(drive) / "Visual Studio/2022",
                    Path(drive) / "VS2022"
                ])

        for base in bases:
            if not base.exists():
                continue

            # 检查 Direct Install
            msvc = base / "VC/Tools/MSVC"
            if msvc.exists():
                versions = sorted(msvc.iterdir(), key=lambda x: x.name, reverse=True)
                if versions and (versions[0] / "bin/Hostx64/x64/cl.exe").exists():
                    return VSInfo(
                        edition="Direct Install",
                        msvc_path=versions[0] / "bin/Hostx64/x64/cl.exe"
                    )

            # 检查各版本
            for ed in VS_EDITIONS:
                msvc = base / ed / "VC/Tools/MSVC"
                if msvc.exists():
                    versions = sorted(msvc.iterdir(), key=lambda x: x.name, reverse=True)
                    if versions and (versions[0] / "bin/Hostx64/x64/cl.exe").exists():
                        return VSInfo(
                            edition=ed,
                            msvc_path=versions[0] / "bin/Hostx64/x64/cl.exe"
                        )

        return None


class ClangdDetector:
    """Clangd 检测器"""

    @staticmethod
    def find_llvm_path() -> Optional[Path]:
        """查找 LLVM 安装路径"""
        if is_windows():
            for path in LLVM_PATHS_WINDOWS:
                if (path / "clangd.exe").exists():
                    return path
        else:
            import shutil
            clangd_path = shutil.which('clangd')
            if clangd_path:
                return Path(clangd_path).parent
        return None

    @staticmethod
    def check_clangd() -> tuple[bool, Optional[str]]:
        """检查 clangd 是否已安装"""
        import subprocess
        try:
            result = subprocess.run(
                ['clangd', '--version'],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode == 0:
                return True, result.stdout.strip()
        except (FileNotFoundError, subprocess.TimeoutExpired):
            pass
        return False, None


class WorkspaceDetector:
    """工作区类型检测器"""

    @staticmethod
    def detect(root: Path) -> WorkspaceInfo:
        """检测工作区类型"""
        # 检查插件
        plugins = list(root.glob("*.uplugin"))
        if plugins:
            return WorkspaceInfo(type="Plugin", file=plugins[0], root=root)

        # 检查项目
        projects = list(root.glob("*.uproject"))
        if projects:
            return WorkspaceInfo(type="Project", file=projects[0], root=root)

        return WorkspaceInfo(type="Unknown", file=None, root=root)


class ProjectPathDetector:
    """项目路径检测器"""

    @staticmethod
    def find(workspace_root: Path) -> List[Path]:
        """查找可能使用此插件的 UE 项目"""
        found = []

        # 向上遍历父目录
        current = workspace_root.parent
        for _ in range(3):
            if not current:
                break
            for proj in current.glob("*.uproject"):
                if proj not in found:
                    found.append(proj)
            current = current.parent

        # 搜索常见项目目录
        for base in PROJECT_BASE_PATHS:
            if not base.exists():
                continue
            for proj in base.glob("*.uproject"):
                if proj not in found:
                    found.append(proj)
            try:
                for subdir in base.iterdir():
                    if subdir.is_dir():
                        for proj in subdir.glob("*.uproject"):
                            if proj not in found:
                                found.append(proj)
            except (PermissionError, FileNotFoundError):
                pass

        return found


# ========================================
# UI 工具
# ========================================

def print_box(title: str, width: int = 60) -> None:
    """打印标题框"""
    border = "╔" + "═" * (width - 2) + "╗"
    content = f"║{title.center(width - 2)}║"
    footer = "╚" + "═" * (width - 2) + "╝"
    Color.print(border, Color.CYAN)
    Color.print(content, Color.CYAN)
    Color.print(footer, Color.CYAN)
    print()


def interactive_select(items: List, prompt: str, display_func=None) -> Optional[int]:
    """交互式选择"""
    if not items:
        return None
    if len(items) == 1:
        Color.print(f"   -> 自动选择: 第 0 项", Color.CYAN)
        return 0

    Color.print(f"\n   {prompt}:", Color.YELLOW)
    for i, item in enumerate(items):
        text = display_func(item) if display_func else str(item)
        Color.print(f"   [{i}] {text}", Color.WHITE)
    Color.print(f"   [N] 跳过", Color.GRAY)

    try:
        choice = input("   输入序号 (默认: N): ").strip()
        if not choice or choice.lower() == 'n':
            return None
        return int(choice)
    except (ValueError, KeyboardInterrupt, EOFError):
        return None
