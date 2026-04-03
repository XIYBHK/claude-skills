# Git 提交示例

本文档包含项目的实际提交示例，作为生成提交信息的参考。

## 提交格式

```
<type>(<scope>): <简述>

<详细描述（可选）>
```

## 实际示例

### 重构类 (refactor)

```
refactor(XToolsCore,XTools,Sort,GeometryTool): 代码审查修复 - 原子操作安全/数组越界/版本兼容

- XToolsCore: 修复原子操作使用 FPlatformAtomics 替代非原子实现
- XTools: 修复 DrawBezierDebug 数组越界风险并移除重复定义
- Sort: 使用 XTOOLS_GET_ELEMENT_SIZE 宏适配 UE 5.5+
- GeometryTool: 移除未使用的 XToolsErrorReporter.h 头文件
```

```
refactor(ObjectPool,BlueprintExtensions): 新增对象池统计命令并优化K2Node代码
```

```
refactor(PointSampling): 优化代码结构并增强纹理采样功能
```

### 修复类 (fix)

```
fix(PointSampling): 修复 CI 编译错误
```

```
fix(PointSampling): 修复泊松采样网格索引Bug并添加内存预分配
```

```
fix(GeometryTool): 移除 Kismet 模块依赖，修复 CI 构建失败
```

### 新功能类 (feat)

```
feat(GeometryTool): 新增基于形状组件的点阵生成功能，支持 Box/Sphere 形状和随机变换参数
```

```
feat(ObjectPool,BlueprintExtensions): 新增对象池统计命令并优化K2Node代码
```

### 文档类 (docs)

```
docs: CHANGELOG.md 移除emoji并统一折叠栏格式
```

```
docs: 合并 UNRELEASED.md 到 CHANGELOG.md v1.9.4
```

```
docs(ci): 同步 CI 工作流配置更新到 UNRELEASED.md
```

### 工具类 (chore)

```
chore: 将 GitHub Actions 工作流的 powershell 替换为 pwsh
```

## 模块名称参考

### 核心模块
- XToolsCore
- XTools

### 功能模块
- Sort
- SortEditor
- RandomShuffles
- PointSampling
- FormationSystem
- ObjectPool
- ObjectPoolEditor
- FieldSystemExtensions
- GeometryTool

### 编辑器模块
- BlueprintExtensions
- BlueprintExtensionsRuntime
- X_AssetEditor
- XTools_ComponentTimelineRuntime
- XTools_ComponentTimelineUncooked

### 第三方集成（不直接修改）
- XTools_EnhancedCodeFlow
- XTools_AutoSizeComments
- XTools_BlueprintAssist
- XTools_ElectronicNodes
- XTools_BlueprintScreenshotTool
- XTools_SwitchLanguage
