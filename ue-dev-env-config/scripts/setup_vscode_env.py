#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
VSCode UE Environment Configuration Script (优化版)
功能：自动配置 VSCode IntelliSense、编译任务、调试配置、扩展推荐
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from string import Template
from typing import Optional

# 设置 UTF-8 控制台
from common import (
    setup_utf8_console,
    Color,
    print_box,
    interactive_select,
    EngineDetector,
    VSMSVCDetector,
    WorkspaceDetector,
    ProjectPathDetector,
    EngineInfo,
    VSInfo,
    WorkspaceInfo,
)

setup_utf8_console()


# ========================================
# 配置生成器
# ========================================

class ConfigGenerator:
    """配置文件生成器"""

    def __init__(
        self,
        workspace_root: Path,
        engine: Path,
        workspace_type: str,
        project_path: Optional[Path] = None,
        msvc_path: Optional[Path] = None
    ):
        self.root = workspace_root
        self.engine = engine
        self.type = workspace_type
        self.project = project_path
        self.msvc = msvc_path
        self.vscode = workspace_root / ".vscode"
        self.templates = Path(__file__).parent.parent / "templates"

    def _ensure_dir(self) -> None:
        """确保 .vscode 目录存在"""
        self.vscode.mkdir(exist_ok=True)

    def _get_template_vars(self) -> dict:
        """获取模板变量"""
        vars = {
            "engine_path": self.engine.as_posix(),
            "compiler_path": self.msvc.as_posix() if self.msvc else "",
            "workspace_folder": self.root.as_posix(),  # 添加工作区绝对路径
            "project_includes": "",
            "browse_paths": "",
            "project_path": "",
            "project_name": "UnrealEditor",
            "plugin_name": "YourPlugin.uplugin"
        }

        if self.project and self.type in ("Project", "Plugin"):
            proj_dir = self.project.parent.as_posix()
            vars.update({
                "project_path": self.project.as_posix(),
                "project_name": self.project.stem,
                "project_includes": (
                    f'"{proj_dir}/Source/**",\n        '
                    f'"{proj_dir}/Plugins/**",\n        '
                    f'"{proj_dir}/Intermediate/Build/Win64/UnrealEditor/Inc/**",'
                ),
                "browse_paths": f'"{proj_dir}/Source",\n        '
            })

        # 插件名称检测
        if self.type == "Plugin":
            plugin_files = list(self.root.glob("*.uplugin"))
            if plugin_files:
                vars["plugin_name"] = plugin_files[0].name

        return vars

    def _render_template(self, name: str, vars: dict) -> str:
        """渲染模板"""
        template_path = self.templates / f"{name}.json"
        content = template_path.read_text(encoding='utf-8')
        result = Template(content).safe_substitute(**vars)
        # 修复 VSCode ${config:...} 变量被转义的问题
        result = result.replace(r"\${", "${")
        return result

    def generate(self, name: str) -> None:
        """生成配置文件"""
        vars = self._get_template_vars()
        content = self._render_template(name, vars)
        output_path = self.vscode / f"{name}.json"
        output_path.write_text(content, encoding='utf-8')
        Color.print(f"   [OK] 已创建 {name}.json", Color.GREEN)

    def check_existing(self) -> list[str]:
        """检查现有配置文件"""
        configs = ["c_cpp_properties", "settings", "extensions", "tasks", "launch"]
        existing = [name for name in configs
                    if (self.vscode / f"{name}.json").exists()]
        return existing


# ========================================
# 步骤函数
# ========================================

def step_workspace() -> WorkspaceInfo:
    """步骤 0: 分析工作区类型"""
    Color.print("[步骤 0/6] 分析工作区类型...", Color.YELLOW)
    root = Path.cwd()
    Color.print(f"   工作区路径: {root}", Color.GRAY)

    info = WorkspaceDetector.detect(root)
    match info.type:
        case "Plugin":
            Color.print(f"   工作区: 插件工作区", Color.GREEN)
            if info.file:
                Color.print(f"   插件文件: {info.file}", Color.GRAY)
        case "Project":
            Color.print(f"   工作区: 项目工作区", Color.GREEN)
            if info.file:
                Color.print(f"   项目文件: {info.file}", Color.GRAY)
        case _:
            Color.print(f"   工作区: 源码工作区", Color.CYAN)
            Color.print(f"   (未找到 .uplugin 或 .uproject)", Color.GRAY)

    Color.print("")
    return info


def step_engine(args: argparse.Namespace) -> Path:
    """步骤 1: 检测 UE 引擎"""
    Color.print("[步骤 1/6] 检测 Unreal Engine...", Color.YELLOW)

    if args.engine_path:
        engine = Path(args.engine_path)
        Color.print(f"   使用指定路径: {engine}", Color.GREEN)
    else:
        engines = EngineDetector.detect()
        if not engines:
            Color.print("   [ERROR] 未找到 UE 引擎！", Color.RED)
            Color.print("   请确保 UE 已安装或使用 -e 指定路径", Color.YELLOW)
            sys.exit(1)

        Color.print(f"   [OK] 找到 {len(engines)} 个 UE 引擎", Color.GREEN)
        for e in engines:
            Color.print(f"     - {e.version} ({e.engine_type}): {e.path}", Color.GRAY)

        if args.non_interactive or len(engines) == 1:
            engine = engines[0].path
            Color.print(f"   -> 自动选择: UE {engines[0].version}", Color.CYAN)
        else:
            idx = interactive_select(
                engines,
                "选择引擎版本",
                lambda e: f"UE {e.version} - {e.path}"
            )
            engine = engines[idx].path if idx is not None else engines[0].path
            Color.print(f"   -> 已选择: {engine}", Color.CYAN)

    Color.print(f"   使用: {engine}", Color.GREEN)
    Color.print("")
    return engine


def step_vs() -> Optional[VSInfo]:
    """步骤 2: 检测 Visual Studio"""
    Color.print("[步骤 2/6] 检测 Visual Studio...", Color.YELLOW)

    vs_info = VSMSVCDetector.detect()
    if vs_info:
        Color.print(f"   [OK] 找到 VS 2022 {vs_info.edition}", Color.GREEN)
        Color.print(f"   [OK] MSVC: {vs_info.msvc_path}", Color.GREEN)
    else:
        Color.print(f"   未找到 VS 2022", Color.YELLOW)
        Color.print(f"   请安装 VS 2022（含 C++ 工作负载）", Color.YELLOW)

    Color.print("")
    return vs_info


def step_project(
    args: argparse.Namespace,
    workspace_info: WorkspaceInfo
) -> Optional[Path]:
    """步骤 3: 检测项目路径"""
    Color.print("[步骤 3/6] 检测 UE 项目路径...", Color.YELLOW)

    project = Path(args.project_path) if args.project_path else None

    if not project and workspace_info.type == "Plugin":
        Color.print(f"   -> 搜索使用此插件的 UE 项目...", Color.CYAN)
        found = ProjectPathDetector.find(workspace_info.root)

        if found:
            Color.print(f"\n   [OK] 找到 {len(found)} 个 UE 项目", Color.GREEN)
            if args.non_interactive or len(found) == 1:
                project = found[0]
                Color.print(f"   -> 自动选择: {project}", Color.CYAN)
            else:
                idx = interactive_select(
                    found,
                    "选择项目（用于调试）",
                    lambda p: f"{p.name} - {p.parent}"
                )
                if idx is not None:
                    project = found[idx]
                    Color.print(f"   -> 已选择: {project}", Color.CYAN)
                else:
                    Color.print(f"   -> 跳过项目链接，仅配置 IntelliSense", Color.GRAY)
        else:
            Color.print(f"   未找到 UE 项目", Color.GRAY)
            Color.print(f"      使用 -p 指定: -p \"路径/To/Project.uproject\"", Color.GRAY)
    elif project:
        Color.print(f"   使用指定项目: {project}", Color.GREEN)

    Color.print("")
    return project


def step_check_configs(gen: ConfigGenerator) -> None:
    """步骤 4: 检查配置文件"""
    Color.print("[步骤 4/6] 检查配置文件...", Color.YELLOW)
    gen._ensure_dir()

    existing = gen.check_existing()
    if existing:
        Color.print(f"   [INFO] 现有配置将被覆盖: {', '.join(existing)}", Color.CYAN)
    else:
        Color.print("   [OK] 无现有配置，将创建新文件", Color.GREEN)
    Color.print("")


def step_generate_configs(gen: ConfigGenerator, project: Optional[Path]) -> None:
    """步骤 5: 生成配置"""
    Color.print("[步骤 5/7] 生成 VSCode 配置...", Color.YELLOW)

    # 基础配置（始终生成）
    for name in ["c_cpp_properties", "settings", "extensions"]:
        gen.generate(name)

    # 项目相关配置
    if project:
        gen.generate("tasks")
        gen.generate("launch")
    else:
        Color.print(f"   跳过 tasks.json 和 launch.json（无项目路径）", Color.GRAY)

    Color.print("")


def step_generate_compile_commands(
    workspace_info: WorkspaceInfo,
    engine: Path,
    project: Optional[Path] = None
) -> None:
    """步骤 6: 生成 compile_commands.json"""
    Color.print("[步骤 6/7] 生成 compile_commands.json...", Color.YELLOW)

    # 如果有项目路径，使用 UBT 生成
    if project:
        script_path = Path(__file__).parent / "generate_compile_commands.py"

        import subprocess
        try:
            result = subprocess.run(
                [sys.executable, str(script_path), str(workspace_info.root), str(engine), str(project)],
                capture_output=True,
                text=True,
                timeout=300,  # 5 分钟超时（UBT 生成 compile_commands）
                encoding='utf-8',
                errors='replace'
            )

            # 输出结果
            if result.stdout:
                for line in result.stdout.strip().split('\n'):
                    if line:
                        print(line)

            if result.returncode != 0:
                Color.print(f"   [WARN] 生成失败，将使用 includePath 模式", Color.YELLOW)
        except subprocess.TimeoutExpired:
            Color.print(f"   [WARN] 生成超时（超过 5 分钟），将使用 includePath 模式", Color.YELLOW)
        except Exception as e:
            Color.print(f"   [WARN] 生成失败: {e}，将使用 includePath 模式", Color.YELLOW)
    else:
        # 无项目路径，直接使用 Python 脚本
        script_path = Path(__file__).parent / "generate_compile_commands.py"

        import subprocess
        try:
            result = subprocess.run(
                [sys.executable, str(script_path), str(workspace_info.root), str(engine)],
                capture_output=True,
                text=True,
                timeout=60,  # 1 分钟超时（Python 后备方案生成）
                encoding='utf-8',
                errors='replace'
            )

            if result.stdout:
                for line in result.stdout.strip().split('\n'):
                    if line:
                        print(line)

            if result.returncode != 0:
                Color.print(f"   [WARN] 生成失败，将使用 includePath 模式", Color.YELLOW)
        except Exception as e:
            Color.print(f"   [WARN] 生成失败: {e}，将使用 includePath 模式", Color.YELLOW)

    Color.print("")


def step_summary(
    workspace_info: WorkspaceInfo,
    engine: Path,
    project: Optional[Path],
    vs_info: Optional[VSInfo]
) -> None:
    """步骤 7: 配置摘要"""
    Color.print("[步骤 7/7] 配置摘要", Color.YELLOW)
    Color.print("")
    Color.print("配置完成！", Color.GREEN)
    Color.print("")

    Color.print("配置信息:", Color.CYAN)
    Color.print(f"   工作区类型:  {workspace_info.type}", Color.WHITE)
    Color.print(f"   UE 引擎: {engine}", Color.WHITE)
    if project:
        Color.print(f"   UE 项目: {project}", Color.WHITE)
    if vs_info:
        Color.print(f"   MSVC:      {vs_info.edition}", Color.WHITE)
    Color.print("")

    Color.print("下一步操作:", Color.CYAN)
    Color.print("   1. 重新加载 VSCode 窗口 (F1 -> Reload Window)", Color.WHITE)
    Color.print("   2. 安装推荐的扩展", Color.WHITE)
    Color.print("   3. 等待 IntelliSense 索引完成", Color.WHITE)
    Color.print("")

    if workspace_info.type == "Plugin" and not project:
        Color.print("提示: 仅配置了 IntelliSense，无调试链接", Color.CYAN)
        Color.print("   使用 -p 指定项目以启用调试:", Color.GRAY)
        Color.print(r"   python scripts/setup_vscode_env.py -p \"路径/To/Project.uproject\"", Color.GRAY)
        Color.print("")

    Color.print("完成！", Color.GREEN)
    Color.print("")


# ========================================
# 主函数
# ========================================

def main() -> int:
    parser = argparse.ArgumentParser(
        description='VSCode UE 环境配置工具 v2.0',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  %(prog)s                              自动检测并配置
  %(prog)s -e "F:/Epic Games/UE_5.4"    指定引擎路径
  %(prog)s -p "F:/Projects/MyProj"      指定项目路径
  --is-plugin                           强制插件工作区
  --is-project                          强制项目工作区
  --non-interactive                     非交互模式
        """
    )
    parser.add_argument('-p', '--project-path', help='UE 项目路径')
    parser.add_argument('-e', '--engine-path', help='UE 引擎路径')
    parser.add_argument('--is-plugin', action='store_true', help='强制插件工作区')
    parser.add_argument('--is-project', action='store_true', help='强制项目工作区')
    parser.add_argument('--non-interactive', action='store_true', help='非交互模式')
    args = parser.parse_args()

    print_box("VSCode UE 环境配置工具 v2.0")

    # 执行各步骤
    workspace_info = step_workspace()

    # 覆盖工作区类型（如果指定）
    if args.is_plugin:
        workspace_info = WorkspaceInfo(type="Plugin", file=workspace_info.file, root=workspace_info.root)
    elif args.is_project:
        workspace_info = WorkspaceInfo(type="Project", file=workspace_info.file, root=workspace_info.root)

    engine = step_engine(args)
    vs_info = step_vs()
    project = step_project(args, workspace_info)

    # 生成配置
    gen = ConfigGenerator(
        workspace_info.root,
        engine,
        workspace_info.type,
        project,
        vs_info.msvc_path if vs_info else None
    )
    step_check_configs(gen)
    step_generate_configs(gen, project)
    step_generate_compile_commands(workspace_info, engine, project)
    step_summary(workspace_info, engine, project, vs_info)

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        Color.print("\n已取消", Color.YELLOW)
        sys.exit(1)
    except Exception as e:
        Color.print(f"\n错误: {e}", Color.RED)
        import traceback
        traceback.print_exc()
        sys.exit(1)
