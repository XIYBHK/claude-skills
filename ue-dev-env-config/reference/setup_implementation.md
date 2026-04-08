# VSCode UE 配置脚本实现参考

此文档详细说明 `setup_vscode_env.py` 和相关 Python 脚本的关键实现细节，供扩展和参考使用。

## 核心设计原则

### 1. 路径处理

#### 空格路径支持

所有路径处理使用 `pathlib.Path`，正确处理带空格的路径（如 "D:\Unreal Projects\My Game"）：

```python
# 使用 Path 对象处理路径，自动处理空格和分隔符
engine = Path("F:/Epic Games/UE_5.4")
# .as_posix() 转换为正斜杠格式（JSON 模板需要）
engine_posix = engine.as_posix()  # "F:/Epic Games/UE_5.4"
```

#### 多盘符检测

遍历所有实际存在的盘符，搜索 UE 引擎安装：

```python
def get_available_drives() -> List[str]:
    if sys.platform != 'win32':
        return ['/']
    return [f"{letter}:" for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            if os.path.exists(f"{letter}:")]
```

### 2. 工作区类型识别

#### 插件工作区检测

```python
class WorkspaceDetector:
    @staticmethod
    def detect(root: Path) -> WorkspaceInfo:
        plugins = list(root.glob("*.uplugin"))
        if plugins:
            return WorkspaceInfo(type="Plugin", file=plugins[0], root=root)
        projects = list(root.glob("*.uproject"))
        if projects:
            return WorkspaceInfo(type="Project", file=projects[0], root=root)
        return WorkspaceInfo(type="Unknown", file=None, root=root)
```

#### 智能项目关联（插件工作区）

自动向上搜索父目录中的 UE 项目（最多3层）：

```python
class ProjectPathDetector:
    @staticmethod
    def find(workspace_root: Path) -> List[Path]:
        found = []
        current = workspace_root.parent
        for _ in range(3):
            if not current:
                break
            for proj in current.glob("*.uproject"):
                if proj not in found:
                    found.append(proj)
            current = current.parent
        # 同时搜索常见项目目录
        for base in PROJECT_BASE_PATHS:
            ...
        return found
```

### 3. UE 引擎路径检测

#### Epic Games Launcher 路径

支持两个 Epic Games 常见路径：

```python
EPIC_GAMES_PATHS = [
    "Program Files/Epic Games",    # Windows 标准路径
    "Epic Games"                   # 其他盘符根路径
]

# 遍历所有盘符
for drive in get_available_drives():
    for base in EPIC_GAMES_PATHS:
        base_path = Path(str(drive) + "\\" + base)  # Windows
        for ue_dir in base_path.iterdir():
            if ue_dir.name.startswith("UE_") and (ue_dir / "Engine").exists():
                # 过滤 UE 5.0-5.2（仅支持 5.3+）
                ...
```

#### 自定义编译引擎路径

```python
for drive in get_available_drives():
    custom = Path(drive) / "UnrealEngine"
    if (custom / "Engine").exists():
        engines.append(EngineInfo(
            version="Custom", path=custom, engine_type="Source Build"))
```

### 4. Visual Studio 检测

#### 版本和 Edition 检测

```python
VS2022_PATHS = [
    "C:/Program Files/Microsoft Visual Studio/2022",
    "C:/Program Files (x86)/Microsoft Visual Studio/2022"
]
VS_EDITIONS = ["Enterprise", "Professional", "Community", "BuildTools"]

# 同时检查非 C 盘的自定义安装路径
for drive in get_available_drives():
    if drive != "C:":
        bases.extend([
            Path(str(drive) + "\\VisualStudio\\2022"),
            Path(str(drive) + "\\VS2022")
        ])
```

#### MSVC 编译器路径定位

```python
# 优先检查直接安装（无 Edition 子文件夹）
msvc = base / "VC/Tools/MSVC"
if msvc.exists():
    versions = sorted(msvc.iterdir(), key=lambda x: x.name, reverse=True)
    if versions and (versions[0] / "bin/Hostx64/x64/cl.exe").exists():
        return VSInfo(edition="Direct Install", msvc_path=...)

# 然后检查标准 Edition 子文件夹
for ed in VS_EDITIONS:
    msvc = base / ed / "VC/Tools/MSVC"
    ...
```

### 5. 配置文件处理

#### 模板系统

使用 Python `string.Template` 渲染配置模板：

```python
from string import Template

content = template_path.read_text(encoding='utf-8')
result = Template(content).safe_substitute(**vars)
# 修复 VSCode ${config:...} 变量被转义的问题
result = result.replace(r"\${", "${")
```

#### c_cpp_properties.json 生成

**includePath 策略：**

- 插件工作区：`${workspaceFolder}/**` + 项目源码 + 引擎 + 引擎插件
- 项目工作区：`${workspaceFolder}/**` + 引擎 + 项目插件 + 引擎

#### tasks.json 编译任务

使用 VSCode 设置变量引用引擎/项目路径：

```json
{
  "type": "shell",
  "command": "${config:unreal.engine.path}/Engine/Build/BatchFiles/Build.bat",
  "args": [
    "${config:unreal.project.name}Editor",
    "Win64",
    "Development",
    "-Project=${config:unreal.project.path}"
  ]
}
```

### 6. compile_commands.json 支持

双模式策略：优先使用 UBT 生成，失败时回退到 Python 脚本：

```python
# 优先尝试 UBT（需要项目已编译过）
success = generate_with_ubt(project_path, engine_path, workspace_root)

# UBT 失败时使用 Python 后备方案
if not success:
    success = generate_with_python(workspace_root, engine_path)
```

UBT 模式使用 `-Mode=GenerateClangDatabase`，Python 后备模式生成标准格式的 compile_commands.json（顶层 JSON 数组，arguments 为字符串列表）。

## OpenCode LSP 配置

### opencode.json 结构

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

### .clangd 配置

自动生成 `.clangd` 配置文件，抑制 UE 代码库中常见的 clangd 误报：

```yaml
CompileFlags:
  Add:
    - -ferror-limit=0
    - -Wno-everything
Diagnostics:
  Suppress:
    - pp_file_not_found    # .generated.h 在编译前不存在
Index:
  Background: Build
```

### clangd 自动安装

使用 winget 安装 LLVM 并配置 PATH：

```python
subprocess.run(['winget', 'install', 'LLVM.LLVM',
                '--accept-package-agreements', '--accept-source-agreements'],
               timeout=600)

# 添加到用户 PATH
subprocess.run(['powershell', '-Command',
    f'[System.Environment]::SetEnvironmentVariable("Path", "{new_path}", "User")'])
```

## 关键实现细节

### 1. 错误处理

所有操作使用 try-except 捕获错误，确保流程稳定：

```python
try:
    result = subprocess.run(cmd_args, capture_output=True, text=True, timeout=180)
except subprocess.TimeoutExpired:
    Color.print("   [WARN] 操作超时", Color.YELLOW)
except Exception as e:
    Color.print(f"   [ERROR] 操作失败: {e}", Color.RED)
```

### 2. 用户交互

```python
def interactive_select(items: List, prompt: str, display_func=None) -> Optional[int]:
    if len(items) == 1:
        return 0  # 自动选择唯一选项
    # 显示选择列表
    for i, item in enumerate(items):
        text = display_func(item) if display_func else str(item)
        Color.print(f"   [{i}] {text}", Color.WHITE)
    choice = input("   输入序号 (默认: N): ").strip()
    ...
```

### 3. UTF-8 控制台处理

Windows 中文环境下正确处理编码：

```python
def setup_utf8_console() -> None:
    if sys.platform == 'win32':
        import io
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')
```

## 扩展指南

### 添加新的配置模板

1. 在 `templates/` 创建模板文件（使用 `$variable` 占位符）
2. 在 `ConfigGenerator.generate()` 添加渲染逻辑
3. 更新 SKILL.md 的配置文件列表

### 添加新的检测器

1. 在 `common.py` 创建检测器类
2. 添加 `detect()` 静态方法
3. 在主脚本的步骤函数中调用

### 修改现有功能

1. **工作区类型** - 在 `WorkspaceDetector.detect()` 添加新的文件匹配
2. **路径检测** - 在对应常量列表中添加新路径
3. **配置生成** - 修改 `_get_template_vars()` 添加新变量

## 测试建议

1. **测试多盘符环境** - 确保脚本在不同盘符配置下正常工作
2. **测试空格路径** - 验证所有带空格的路径正确处理
3. **测试工作区类型** - 分别测试插件工作区、项目工作区、源码工作区
4. **测试自动检测** - 验证自动检测的准确性
5. **测试手动指定** - 确保手动指定路径优先级正确

## 常见问题

### Q: 如何切换到不同的 UE 版本？

**A:** 重新运行脚本并选择不同的版本，或使用 `-e` 参数强制指定引擎路径。

### Q: 如何为多个项目配置？

**A:** 运行 `python scripts/setup_vscode_env.py` 并选择其中一个项目。可以在 `launch.json` 中手动添加其他项目配置。

### Q: 配置后 IntelliSense 仍然无法识别引擎头文件？

**A:**
1. 重新加载 VSCode 窗口（F1 -> Reload Window）
2. 运行 "Generate Project Files" 任务
3. 检查 `c_cpp_properties.json` 中的路径是否正确
4. 运行 "Rebuild IntelliSense Database" 任务

### Q: OpenCode LSP 如何验证是否工作？

**A:**
1. 重启 OpenCode
2. 打开任意 C/C++ 文件
3. 检查 OpenCode 日志确认 clangd 已启动
4. 使用 `lsp` 工具测试功能（如跳转到定义）
