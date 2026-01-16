---
name: ue-dev-config-utils
description: PowerShell 执行工具脚本，提供统一的接口安全地在 Windows 上执行 Python 脚本和 PowerShell 脚本
compatibility: claude-code, opencode-cli
---

# PowerShell 执行工具

提供统一的 Python 脚本执行接口，解决 Windows 上的编码和命令执行问题。

## 何时使用此 skill

- **执行 Python 脚本时** - 需要确保 UTF-8 编码正确输出
- **执行 PowerShell 脚本时** - 需要正确传递参数，避免中文乱码
- **批量执行多个脚本** - 需要统一的调用方式

## 核心功能

### 1. Python 脚本执行

```python
python scripts/powershell_runner.py <python-script-path> [args...]
```

**功能**：
- ✅ UTF-8 编码输出
- ✅ 正确的参数传递
- ✅ 跨平台兼容（Windows/Linux/Mac）
- ✅ 捕获并格式化输出
- ✅ 错误处理和返回

### 2. PowerShell 脚本执行

```python
python scripts/powershell_runner.py <powershell-script-path> [args...]
```

**功能**：
- ✅ UTF-8 输入/输出支持
- ✅ 正确的参数解析
- ✅ 错误处理和返回码
- ✅ 支持脚本文件路径中的空格

### 3. 路径安全

- ✅ 自动处理带空格的路径
- ✅ 支持相对路径和绝对路径
- ✅ 验证路径存在性

## 使用方法

### 执行 Python 脚本

```python
scripts/powershell_runner.py scripts/setup_vscode_env.ps1
```

### 执行 PowerShell 脚本

```python
scripts/powershell_runner.py scripts/setup_opencode_lsp.ps1
```

## 参考资源

详细实现：`references/powershell_implementation.md`

主要参考脚本：
- `scripts/setup_vscode_env.ps1` - 示范了 UTF-8 编码处理
- `scripts/setup_opencode_lsp.ps1` - 示范了 PowerShell 调用方式
