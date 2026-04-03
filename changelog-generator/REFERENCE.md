# 更新日志生成器 - 参考文档

本文档包含更新日志生成器使用的详细规则和逻辑。

## 模块识别规则

根据文件路径自动识别所属模块：

| 文件路径 | 模块名 |
|---------|--------|
| `Source/PointSampling/` | PointSampling |
| `Source/ObjectPool/` | ObjectPool |
| `Source/BlueprintExtensions/` | BlueprintExtensions |
| `Source/BlueprintExtensionsRuntime/` | BlueprintExtensionsRuntime |
| `Source/Sort/` | Sort |
| `Source/GeometryTool/` | GeometryTool |
| `Source/X_AssetEditor/` | X_AssetEditor |
| `Source/XTools_BlueprintAssist/` | BlueprintAssist |
| `Source/XTools_BlueprintScreenshotTool/` | BlueprintScreenshotTool |
| `Source/XTools_AutoSizeComments/` | AutoSizeComments |
| `Source/XTools_ElectronicNodes/` | ElectronicNodes |
| `Source/FieldSystemExtensions/` | FieldSystemExtensions |
| `Source/RandomShuffles/` | RandomShuffles |
| `Source/MapExtensions/` | MapExtensions |
| `Source/XTools_EnhancedCodeFlow/` | EnhancedCodeFlow |
| `Source/XToolsCore/` | XToolsCore |
| `Source/XTools/` | XTools |
| `Source/ComponentTimelineRuntime/` | ComponentTimelineRuntime |
| `Source/FormationSystem/` | FormationSystem |
| `.github/workflows/` | CI/CD |

## 变更类型推断逻辑

### 新增
**判断依据**：
- 新增函数（函数定义之前不存在）
- 新增类（class 关键字 + 新的类名）
- 新增 USTRUCT（USTRUCT 宏）
- 新增 UENUM（UENUM 宏）
- 新增 UFUNCTION（UFUNCTION 宏）
- 新增蓝图节点（继承 UK2Node）

**描述格式**：`新增 xxx 函数/类/功能`

---

### 优化
**判断依据**：
- 性能改进（时间复杂度降低、缓存优化）
- 代码重构（提取公共函数、消除重复代码）
- 算法优化（改进现有算法实现）

**描述格式**：`优化 xxx 性能/代码/算法`

---

### 修复
**判断依据**：
- Bug 修复（关键词：fix、bug、修复、问题）
- 崩溃修复（关键词：crash、崩溃、空指针）
- 编译错误修复（关键词：编译、link、build）

**描述格式**：`修复 xxx Bug/崩溃/编译错误`

---

### 移除
**判断依据**：
- 删除功能（删除函数、类、模块）
- 移除接口（标记 deprecated 或删除）

**描述格式**：`移除 xxx 功能/接口`

---

### 调整
**判断依据**：
- 参数修改（函数参数变化）
- 行为调整（修改现有逻辑）
- 配置变更（配置文件修改）

**描述格式**：`调整 xxx 参数/行为/配置`

---

### 集成
**判断依据**：
- 新模块集成（添加新模块依赖）
- 第三方插件集成（集成外部库）

**描述格式**：`集成 xxx 模块/插件`

---

### 本地化
**判断依据**：
- 新增翻译（添加文本映射）
- 修改显示文本（NSLOCTEXT、LOCTEXT）

**描述格式**：`本地化 xxx 文本/界面`

## 描述生成规则

### 字数限制
- 单条描述控制在 20 字以内

### 格式模板
`动词 + 对象 + （效果）`

### 示例
- `新增对象池统计命令`（新增 + 对象池统计命令）
- `修复排序算法Bug`（修复 + 排序算法Bug）
- `优化代码结构`（优化 + 代码结构）
- `移除冗余代码`（移除 + 冗余代码）
- `调整参数默认值`（调整 + 参数默认值）
- `集成蓝图截图工具`（集成 + 蓝图截图工具）
- `本地化节点名称`（本地化 + 节点名称）

## Git 命令使用

### 检测修改状态
```bash
git status --porcelain
```

### 读取文件差异
```bash
git diff --name-only
git diff <文件路径>
```

### 分析代码变更
- 查看新增行数：`git diff | grep "^+" | grep -v "^+++"`
- 查看删除行数：`git diff | grep "^-" | grep -v "^---"`
- 查看修改的函数：`git diff | grep "^[\+\-].*function\|def\|class"`
