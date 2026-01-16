---
name: ue-dev-env-config
description: |
  配置 Unreal Engine 开发环境，包括 VSCode IntelliSense、编译任务、调试配置和扩展推荐。

  触发条件：
  - 用户提到 "VSCode"、"IntelliSense"、"代码提示"
  - UE 头文件无法识别、宏定义未定义
  - 需要配置编译任务、调试环境
  - 切换 UE 引擎版本后需要更新配置
  - 首次设置 UE 开发环境

  用途：
  - 自动生成 c_cpp_properties.json、tasks.json、launch.json、settings.json、extensions.json
  - 智能检测 UE 引擎、Visual Studio、项目路径
  - 支持插件工作区（.uplugin）和项目工作区（.uproject）

dependencies: python>=3.10
allowed-tools: Bash, Read, Write, Glob
---

# UE 开发环境配置

配置 Unreal Engine 开发环境的 VSCode 工作区设置。

## 快速开始

在工作区根目录运行：

```bash
python scripts/setup_vscode_env.py
```

脚本会自动：
1. 检测工作区类型（插件/项目）
2. 搜索 UE 引擎安装
3. 检测 Visual Studio 和 MSVC
4. 生成所有 VSCode 配置文件

## 使用选项

```bash
# 指定引擎路径
python scripts/setup_vscode_env.py -e "F:/Epic Games/UE_5.4"

# 指定项目路径（用于调试）
python scripts/setup_vscode_env.py -p "F:/Unreal Projects/MyProject.uproject"

# 非交互模式（自动选择第一项）
python scripts/setup_vscode_env.py --non-interactive

# 强制指定工作区类型
python scripts/setup_vscode_env.py --is-plugin
python scripts/setup_vscode_env.py --is-project
```

## 生成的配置文件

| 文件 | 用途 |
|------|------|
| `c_cpp_properties.json` | IntelliSense 配置（include 路径、宏定义） |
| `tasks.json` | 编译任务（Build Plugin、编译项目） |
| `launch.json` | 调试配置（启动/附加 UE 编辑器） |
| `settings.json` | 编辑器设置（Tab 大小、文件关联） |
| `extensions.json` | 推荐扩展（C++ 工具、GitLens 等） |

## 详细说明

- **配置文件详解**: See [CONFIG_DETAILS.md](references/CONFIG_DETAILS.md)
- **故障排查**: See [TROUBLESHOOTING.md](references/TROUBLESHOOTING.md)
- **实现细节**: See [IMPLEMENTATION.md](references/IMPLEMENTATION.md)

## 配置完成后

1. 重新加载 VSCode 窗口（F1 → "Reload Window"）
2. 安装推荐的扩展
3. 等待 IntelliSense 索引完成

## OpenCode LSP 配置

如需使用 OpenCode 的 clangd LSP：

```bash
# 安装 clangd
python scripts/setup_opencode_lsp.py

# 生成 opencode.json
python scripts/configure_opencode_json.py
```
