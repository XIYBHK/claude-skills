---
name: ue-env-config
description: 配置 Unreal Engine 开发环境，包括 VSCode IntelliSense 和 OpenCode LSP（clangd）。提供统一的 PowerShell 执行工具，确保所有脚本在 Windows 上安全执行，避免中文编码和命令执行错误
compatibility: claude-code, opencode-cli
---

# UE 开发环境配置工具

提供完整的 UE 开发环境配置解决方案，包括：

- **VSCode 工作区配置** - IntelliSense、编译任务、调试配置
- **OpenCode LSP 配置** - 自动安装/验证 clangd、配置 opencode.json
- **统一 PowerShell 执行器** - 确保 Python 脚本在 Windows 上安全执行
- **智能路径检测** - 自动识别 UE 引擎、项目、编译器路径
- **工作区类型识别** - 区分插件开发（.uplugin）和项目开发（.uproject）
- **交互式配置** - 所有路径均可手动指定，不写死固定路径

## 何时使用此 skill

- **VSCode 配置场景：**
  - 首次设置 UE 插件/项目开发环境
  - IntelliSense 无法识别引擎头文件
  - 编译失败提示找不到 UE 引擎
  - 需要配置调试环境
  - 切换 UE 版本后需要更新配置

- **OpenCode LSP 配置场景：**
  - 需要在 opencode 中启用 clangd LSP 支持
  - clangd 未安装或需要安装
  - 需要配置 opencode.json 中的 LSP 选项
  - UE 项目路径变更后更新 LSP 配置

- **统一脚本执行**：
  - 需要 Python 脚本在 Windows 上安全执行
  - 避免中文编码输出错误
  - 确保命令行参数正确传递

- **通用配置场景：**
  - 多盘符 UE 安装环境
  - 自定义编译引擎路径
  - Visual Studio 版本切换

## 核心功能

### 1. VSCode IntelliSense 配置

自动创建/更新以下配置文件：

- **c_cpp_properties.json** - IntelliSense 配置
  - 引擎路径、项目路径、插件路径
  - 完整的 UE 宏定义（WITH_EDITOR、UE_BUILD_DEVELOPMENT 等）
  - compile_commands.json 支持（最准确的编译参数）

- **tasks.json** - 编译任务配置
  - Build Plugin - Development Editor
  - Compile Plugin in Project（快速编译）
  - Generate Project Files
  - Rebuild IntelliSense Database

- **launch.json** - 调试配置
  - Debug UE Editor 启动
  - Attach to running UE Editor

- **settings.json** - 编辑器设置
  - UE 编码标准（Tab、换行符）
  - 文件关联和排除规则

### 2. OpenCode LSP 配置

- **安装 clangd** - 检测并安装 LLVM/clangd
  - Windows: 使用 winget 安装 LLVM.LLVM
  - 验证安装路径和版本
  - 配置 opencode.json 使用 clangd

- **配置 opencode.json**
  ```json
  {
    "$schema": "https://opencode.ai/config.json",
    "lsp": {
      "clangd": {
          "command": ["clangd", "--compile-commands-dir=<引擎路径>"],
          "extensions": [".c", ".cpp", ".cc", ".cxx", ".c++", ".h", ".hpp", ".hh", ".hxx", ".h++"],
          "disabled": false
      }
    }
  }
  ```

- **更新系统 PATH** - 添加 LLVM 到用户 PATH

### 3. 智能路径检测

自动检测或提示以下路径：

- **UE 引擎路径**
  - Epic Games Launcher 默认安装（多盘符）
  - "Program Files\Epic Games\UE_XX"
  - "Epic Games\UE_XX"
  - 自定义编译引擎路径（UnrealEngine）

- **Visual Studio / MSVC**
  - Visual Studio 2022（多版本：Community/Professional/Enterprise）
  - MSVC 编译器路径（bin\Hostx64\x64\cl.exe）

- **UE 项目路径**
  - 自动向上搜索父目录中的 .uproject 文件
  - 插件工作区：搜索使用此插件的 UE 项目
  - 支持手动指定项目路径

### 4. 工作区类型识别

- **插件工作区** - 检测到 .uplugin 文件
  - 配置：插件源码 + 引擎 + 引擎插件
  - 用途：插件开发、调试插件

- **项目工作区** - 检测到 .uproject 文件
  - 配置：项目源码 + 引擎 + 项目插件
  - 用途：完整游戏项目开发

- **源码工作区** - 未检测到 .uplugin 或 .uproject
  - 配置：基础 UE 引擎 + 自定义源码
  - 用途：独立源码开发

### 5. 统一 PowerShell 执行器

提供统一的 Python 工具脚本，解决 Windows 执行问题：

- **编码支持** - UTF-8 编码输出
- **错误处理** - 捕获并格式化错误信息
- **命令执行** - 安全执行 PowerShell 脚本，支持参数传递
- **跨平台兼容** - 同时支持 Linux/Mac（通过判断）

```python
# 执行 PowerShell 脚本
def run_powershell(script_path, args=None, cwd=None):
    subprocess.run(['powershell.exe', '-ExecutionPolicy', 'Bypass', '-File', script_path] + args])
```

### 6. 关键特性

- ✅ **路径不写死**：所有路径可手动指定或交互式获取
- ✅ **多盘符支持**：C:/、D:/、F:/ 等
- ✅ **空格路径处理**：正确处理带空格的路径
- ✅ **工作区类型识别**：插件/项目/源码
- ✅ **保留用户自定义**：配置操作保留现有自定义设置
- ✅ **中文编码支持**：统一 UTF-8 输出处理

### 7. 实现参考

详细实现参考：`references/setup_implementation.md`

主要参考脚本：
- `scripts/setup_vscode_env.ps1` - VSCode 配置主脚本
- `scripts/setup_opencode_lsp.ps1` - clangd 安装脚本
- `scripts/configure_opencode_json.ps1` - opencode.json 配置脚本
- `scripts/powershell_runner.py` - 统一 PowerShell 执行器

## 使用流程

### VSCode 工作区配置

#### 方式 1：完全自动配置（推荐）

执行 `scripts/setup_vscode_env.ps1`，脚本会：

1. 检测工作区类型（插件/项目/源码）
2. 自动搜索所有盘符下的 UE 引擎安装
3. 检测 Visual Studio 和 MSVC 编译器
4. 智能查找关联的 UE 项目（仅插件工作区）
5. 创建/更新所有配置文件（c_cpp_properties.json、tasks.json、launch.json、settings.json）
6. 保留用户自定义配置

#### 方式 2：指定路径配置

如果自动检测失败或需要使用特定路径：

```powershell
# 指定 UE 项目路径
scripts\setup_vscode_env.ps1 -UEProjectPath "D:\UnrealProjects\MyProject\MyProject.uproject"

# 指定引擎路径
scripts\setup_vscode_env.ps1 -UEEnginePath "F:\Epic Games\UE_5.4"

# 指定为插件工作区
scripts\setup_vscode_env.ps1 -IsPlugin

# 查看完整帮助
scripts\setup_vscode_env.ps1 -Help
```

### OpenCode LSP 配置

#### 步骤 1：安装/验证 clangd

执行 `scripts/setup_opencode_lsp.ps1`：

1. 检测 clangd 是否已安装
2. 如果未安装，使用 winget 自动安装 LLVM.LLVM
3. 验证安装路径和版本
4. 显示安装版本和状态

#### 步骤 2：配置 opencode.json

执行 `scripts/configure_opencode_json.ps1`：

1. 交互式获取 UE 引擎路径（或自动检测）
2. 生成 opencode.json 配置
3. 添加 clangd LSP 配置
4. 配置 compile_commands.json 路径
5. 更新系统 PATH（如需要）

## 配置文件详解

### c_cpp_properties.json 关键配置

```json
{
  "configurations": [
    {
      "name": "Win64",
      "includePath": [
        "${workspaceFolder}/**",
        "引擎/Engine/Source/**",
        "引擎/Engine/Plugins/**",
        "项目/Source/**",
        "项目/Plugins/**"
      ],
      "defines": [
        "WITH_EDITOR=1",
        "UE_BUILD_DEVELOPMENT=1",
        "UE_EDITOR=1",
        "POS",
        "PLATFORM_WINDOWS=1",
        "WIN64=1",
        "UBT_COMPILED_PLATFORM=Win64",
        "UNICODE=1"
      ],
      "compilerPath": "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Windows Kits/10/Community/UCRT/VC/Tools/MSVC/14.38.33130/bin/Hostx64/x64/cl.exe",
      "compileCommands": "引擎/compile_commands.json"
    }
  ]
}
```

### opencode.json LSP 配置

```json
{
  "$schema": "https://opencode.ai/config.json",
  "lsp": {
      "clangd": {
          "command": ["clangd", "--compile-commands-dir=<引擎路径>"],
          "extensions": [".c", ".cpp", ".cc", ".cxx", ".c++", ".h", ".hpp", ".hh", ".hxx", ".h++"],
          "disabled": false
      }
    }
}
```

## 统一 PowerShell 执行器

创建 `scripts/powershell_runner.py`，提供统一的脚本执行接口：

```python
import sys
import subprocess

def run_powershell(script_path, args=None, cwd=None):
    """执行 PowerShell 脚本，处理中文编码和命令执行"""
    try:
        # 使用 UTF-8 编码
        result = subprocess.run(
            ['powershell.exe', '-ExecutionPolicy', 'Bypass', '-File', script_path],
            args if args else [],
            capture_output=True,
            text=True,
            check=False,
            cwd=cwd
        )
        return result.stdout.strip(), result.returncode
    except FileNotFoundError:
        return f"错误: 脚本文件不存在: {script_path}"
    except subprocess.CalledProcessError as e:
        return f"错误: PowerShell 执行失败: {e.stdout}"

def main():
    if len(sys.argv) < 2:
        print("用法: python scripts/powershell_runner.py <script_path> [args...]")
        sys.exit(1)
    
    script_path = sys.argv[1] if len(sys.argv) > 1 else None
    print(run_powershell(script_path, sys.argv[2:]))
```

## 故障排查

### VSCode IntelliSense 问题

**问题**：IntelliSense 无法识别引擎头文件
**解决方案**：
1. 运行 `Rebuild IntelliSense Database` 任务
2. 或重新运行 `scripts/setup_vscode_env.ps1`
3. 检查 `c_cpp_properties.json` 中的路径是否正确

**问题**：编译失败提示找不到 UE 引擎
**解决方案**：
1. 运行脚本自动重新检测引擎路径
2. 或手动指定：`-UEEnginePath <路径>`

### OpenCode LSP 问题

**问题**：clangd 未启动或不可用
**解决方案**：
1. 运行 `scripts/setup_opencode_lsp.ps1` 安装/验证 clangd
2. 运行 `scripts/configure_opencode_json.ps1` 更新配置
3. 重启 opencode 使配置生效
4. 检查 opencode 日志确认 LSP 状态

**问题**：LSP 诊断不准确
**解决方案**：
1. 确保 compile_commands.json 路径正确
2. compile_commands.json 存在于 UE 引擎根目录
3. 检查 UE 版本与 compile_commands.json 是否匹配

## 参考资源

详细实现参考：`references/setup_implementation.md`

主要参考脚本：
- `scripts/setup_vscode_env.ps1` - VSCode 配置主脚本
- `scripts/setup_opencode_lsp.ps1` - clangd 安装脚本
- `scripts/configure_opencode_json.ps1` - opencode.json 配置脚本

这些脚本基于现有 XTools 文档中的 `Plugins\XTools\Docs\ide配置脚本\setup.ps1` 实现，支持多盘符、空格路径、工作区类型识别。
