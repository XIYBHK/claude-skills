# 故障排查指南

## IntelliSense 问题

### 症状：UE 头文件无法识别

**可能原因**：
- includePath 配置错误
- compile_commands.json 不存在
- IntelliSense 数据库损坏

**解决方案**：
```bash
# 1. 重新运行配置脚本
python scripts/setup_vscode_env.py

# 2. 重建 IntelliSense 数据库
# 在 VSCode 中运行任务: "Rebuild IntelliSense Database"

# 3. 检查 c_cpp_properties.json 中的路径是否正确
```

### 症状：宏定义未定义（如 PLATFORM_MICROSOFT）

**解决方案**：
- 确保 `c_cpp_properties.json` 中包含 UE 必需宏定义
- 检查 `defines` 数组是否包含所有 9 个 UE 宏

### 症状："转到定义" 不工作

**解决方案**：
- 确保 `browse.path` 配置正确
- 运行 "Rebuild IntelliSense Database" 任务
- 检查文件是否在 `browse.path` 中

## Visual Studio 问题

### 症状：找不到 Visual Studio

**可能原因**：
- VS 2022 未安装
- 未安装 "使用 C++ 的桌面开发" 工作负载
- VS 安装在非标准路径

**解决方案**：
```bash
# 1. 确保安装 VS 2022（Community/Professional/Enterprise）
# 2. 确保安装 "使用 C++ 的桌面开发" 工作负载
# 3. 重新运行脚本（支持多盘符检测）

# 如果仍无法检测，手动指定 MSVC 路径：
# 编辑 c_cpp_properties.json 中的 compilerPath
```

### 症状：MSVC 编译器路径错误

**解决方案**：
- 检查路径格式：`.../MSVC/14.xx/bin/Hostx64/x64/cl.exe`
- 确保使用 `Hostx64/x64` 而非 `Hostx86/x64`

## 编译任务问题

### 症状：编译任务失败

**可能原因**：
- 引擎路径错误
- 项目路径不存在
- PowerShell 执行策略限制

**解决方案**：
```bash
# 1. 检查 tasks.json 中的路径是否正确
# 2. 确保在 PowerShell 终端中运行（非 CMD）
# 3. 检查执行策略：
Get-ExecutionPolicy

# 如果是 Restricted，设置为 RemoteSigned：
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 症状：Build Plugin 任务失败

**解决方案**：
- 确保 .uplugin 文件存在
- 检查插件模块依赖是否满足
- 查看 UE 输出日志获取详细错误信息

## 调试配置问题

### 症状：无法启动调试

**解决方案**：
- 确保 UE 编辑器路径正确
- 检查项目路径是否存在
- 尝试 "Attach to UE Editor" 模式

### 症状：断点不命中

**解决方案**：
- 确保使用 Development 配置（非 Shipping）
- 检查代码是否为当前编译版本
- 尝试重新编译项目

## OpenCode LSP 问题

### 症状：clangd 无法启动

**解决方案**：
```bash
# 1. 安装 LLVM（包含 clangd）
python scripts/setup_opencode_lsp.py

# 2. 验证 clangd 已安装
clangd --version

# 3. 生成 opencode.json 配置
python scripts/configure_opencode_json.py
```

### 症状：LSP 不提供代码补全

**解决方案**：
- 确保 compile_commands.json 存在于引擎目录
- 检查 opencode.json 中的 `--compile-commands-dir` 参数
- 重启 OpenCode 以重新加载 LSP 配置

## 通用问题

### 症状：配置生成后 VSCode 无变化

**解决方案**：
1. 按 F1 或 Ctrl+Shift+P
2. 输入 "Reload Window" 并回车

### 症状：运行脚本时出现路径错误

**可能原因**：
- Bash shell 中反斜杠被转义
- 路径包含空格但未用引号包裹

**解决方案**：
```bash
# 使用正斜杠（推荐，跨平台兼容）
python scripts/setup_vscode_env.py

# 或者用双引号包裹路径
python "scripts\setup_vscode_env.py"

# 避免这种写法（Bash 中会出错）
# python scripts\setup_vscode_env.py
```

**示例场景**：
```bash
# 错误：Bash 中的反斜杠转义
python C:\Users\...  # → 路径被破坏

# 正确：使用正斜杠
python C:/Users/...

# 正确：用引号包裹
python "C:\Users\..."
```

### 症状：扩展安装失败

**解决方案**：
- 手动安装 extensions.json 中的扩展
- 检查网络连接
- 尝试使用 VSCode 扩展市场手动搜索安装

## 日志和调试

### 启用详细日志

```bash
# 使用 --verbose 参数查看详细输出
python scripts/setup_vscode_env.py --verbose
```

### 检查配置文件

```bash
# 验证 JSON 格式是否正确
python -m json.tool .vscode/c_cpp_properties.json
python -m json.tool .vscode/tasks.json
python -m json.tool .vscode/launch.json
```

## 获取帮助

如果以上解决方案无法解决问题：

1. 检查 VSCode 输出面板（View → Output）
2. 查看 C/C++ 扩展日志
3. 确认 UE 版本（5.3+）和 VS 版本（2022）兼容性
4. 查看脚本实现细节：[IMPLEMENTATION.md](IMPLEMENTATION.md)
