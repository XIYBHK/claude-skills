# 实现细节

本文档描述 UE 开发环境配置工具的实现细节。

## 文件结构

```
ue-dev-env-config/
├── SKILL.md                           # 主文档（渐进式披露第一级）
├── references/                        # 详细文档（渐进式披露第二级）
│   ├── CONFIG_DETAILS.md              # 配置文件详解
│   ├── TROUBLESHOOTING.md             # 故障排查
│   ├── IMPLEMENTATION.md              # 本文档
│   └── setup_implementation.md        # 原始脚本参考
├── scripts/                           # 可执行脚本（不加载到上下文）
│   ├── common.py                      # 共享工具模块
│   ├── setup_vscode_env.py            # 主配置脚本
│   ├── setup_opencode_lsp.py          # Clangd LSP 安装
│   └── configure_opencode_json.py     # OpenCode JSON 生成
└── templates/                         # 配置模板（按需读取）
    ├── c_cpp_properties.json
    ├── tasks.json
    ├── launch.json
    ├── settings.json
    └── extensions.json
```

## 架构设计

基于 Claude Skills **渐进式披露** 原则：

| 级别 | 内容 | Token 使用 | 加载时机 |
|------|------|-----------|---------|
| 第一级 | SKILL.md 元数据（name, description） | ~100 | 始终加载 |
| 第二级 | SKILL.md 主体 | ~500 | 触发时加载 |
| 第三级 | references/ 文档 | 按需 | 需要时加载 |
| - | scripts/（直接执行，不加载） | 0 | 执行时 |

## 核心类

### WorkspaceDetector
检测工作区类型（插件/项目/源码）。

```python
class WorkspaceDetector:
    @staticmethod
    def detect(root: Path) -> WorkspaceInfo:
        # 检测 .uplugin 或 .uproject
        # 返回 WorkspaceInfo(type, file, root)
```

### EngineDetector
检测已安装的 UE 引擎（多盘符支持）。

```python
class EngineDetector:
    @staticmethod
    def detect() -> List[EngineInfo]:
        # 搜索 Epic Games/UE_* 目录
        # 过滤 UE 5.0-5.2（仅支持 5.3+）
        # 返回 EngineInfo(version, path, type)
```

### VSMSVCDetector
检测 Visual Studio 和 MSVC 编译器。

```python
class VSMSVCDetector:
    @staticmethod
    def detect() -> Optional[VSInfo]:
        # 搜索 VS 2022 安装路径
        # 返回 VSInfo(edition, msvc_path)
```

### ProjectPathDetector
智能查找 UE 项目路径。

```python
class ProjectPathDetector:
    @staticmethod
    def find(workspace_root: Path) -> List[Path]:
        # 向上搜索父目录（最多 3 层）
        # 搜索常见项目目录
        # 返回项目路径列表
```

### ConfigGenerator
生成 VSCode 配置文件。

```python
class ConfigGenerator:
    def __init__(self, workspace_root, engine, type, project, msvc):
        # 初始化配置生成器

    def _get_template_vars(self) -> dict:
        # 获取模板变量（engine_path, compiler_path, etc.）

    def generate(self, name: str) -> None:
        # 渲染模板并写入 .vscode/
```

## 模板系统

使用 Python `string.Template` 渲染配置模板：

```python
from string import Template

template = Template(engine_path="${engine_path}")
result = template.substitute(engine_path="F:/Epic Games/UE_5.4")
```

### 支持的变量

| 变量 | 说明 | 示例 |
|------|------|------|
| `{engine_path}` | UE 引擎路径 | `F:/Epic Games/UE_5.4` |
| `{compiler_path}` | MSVC 编译器路径 | `C:/.../cl.exe` |
| `{project_path}` | UE 项目路径 | `F:/.../MyProject.uproject` |
| `{project_name}` | 项目名称 | `MyProject` |
| `{plugin_name}` | 插件文件名 | `MyPlugin.uplugin` |
| `{project_includes}` | 项目包含路径（条件） | `["...", "..."]` |
| `{browse_paths}` | browse 路径（条件） | `["...", "..."]` |

## 步骤流程

### setup_vscode_env.py

1. **分析工作区** - 检测插件/项目类型
2. **检测引擎** - 搜索 UE 安装，支持交互选择
3. **检测 VS** - 查找 VS 2022 和 MSVC
4. **检测项目** - 智能查找关联项目
5. **检查配置** - 列出将被覆盖的现有配置
6. **生成配置** - 渲染模板并写入文件
7. **显示摘要** - 输出配置信息和下一步操作

### setup_opencode_lsp.py

1. **检测 clangd** - 检查是否已安装
2. **安装 LLVM** - 使用 winget 安装（Windows）
3. **配置 PATH** - 添加 LLVM 到用户 PATH
4. **输出指南** - 显示下一步操作

### configure_opencode_json.py

1. **检测引擎** - 搜索或提示输入引擎路径
2. **验证路径** - 确认 Engine 目录存在
3. **生成配置** - 创建 opencode.json

## 路径检测策略

### UE 引擎
- Epic Games Launcher: `{Drive}:/Program Files/Epic Games/UE_*`
- Epic Games Launcher: `{Drive}:/Epic Games/UE_*`
- 自定义编译: `{Drive}:/UnrealEngine`
- 过滤: 排除 UE 5.0-5.2（仅支持 5.3+）

### Visual Studio
- 标准路径: `C:/Program Files/Microsoft Visual Studio/2022/`
- 标准路径: `C:/Program Files (x86)/Microsoft Visual Studio/2022/`
- 自定义路径: `{Drive}:/VisualStudio/2022/`, `{Drive}:/VS2022/`
- 版本: Community, Professional, Enterprise, BuildTools

### UE 项目
- 向上搜索: 父目录最多 3 层
- 常见目录: `F:/Unreal Projects/CPP/`, `D:/Unreal Projects/`, `C:/Unreal Projects/`
- 递归搜索: 常见目录的子目录

## 跨平台考虑

### Windows（主要支持）
- PowerShell 脚本执行
- winget 包管理器
- 环境变量设置

### Linux/macOS（有限支持）
- clangd 手动安装
- 路径分隔符处理

## 错误处理

- **引擎未找到**: 提示使用 `-e` 参数指定路径
- **VS 未找到**: 警告但继续（可手动配置）
- **项目未找到**: 警告但继续（仅 IntelliSense）
- **模板渲染失败**: 捕获异常并显示详细错误

## 性能优化

- **路径缓存**: 检测结果可复用
- **并行搜索**: 多盘符并行检测
- **延迟加载**: references/ 仅在需要时读取
- **模板复用**: 模板文件不加载到上下文

## 安全考虑

- **路径验证**: 检查路径是否存在和有效
- **用户确认**: 覆盖配置前显示列表
- **只读检测**: 不修改任何非 .vscode 文件
- **工具限制**: SKILL.md 中指定 allowed-tools

## 扩展性

### 添加新的配置文件

1. 在 `templates/` 创建模板文件
2. 在 `ConfigGenerator.generate()` 添加渲染逻辑
3. 更新 SKILL.md 的配置文件列表

### 添加新的检测器

1. 在 `common.py` 创建检测器类
2. 添加 `detect()` 静态方法
3. 在主脚本中调用

## 基于原型脚本

本工具基于以下原型脚本重构：

```
Plugins/UE_XTools/Docs/智能配置ue环境/setup.ps1
```

原脚本为 PowerShell 实现，本版本为 Python 实现，具有更好的跨平台兼容性和可维护性。
