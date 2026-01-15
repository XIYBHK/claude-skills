---
name: ue-code-simplifier
description: 简化和优化 UE C++ 插件代码，遵循 Epic Games 编码标准和项目约定。当用户需要优化、重构或审查 Unreal Engine C++ 插件代码时使用此 skill。专注于提升代码清晰度、安全性、性能和可维护性，同时保持功能不变。
model: opus
---

# UE 代码简化器

## 概述

专门用于简化、优化和重构 Unreal Engine C++ 插件代码。遵循 Epic Games 编码标准和项目特定约定，将代码转换为更清晰、更安全、更易维护的形式。

## 核心原则

**功能不变性**：只改变实现方式，不改变逻辑结果
**蓝图接口稳定性**：不修改 UFUNCTION 签名或元数据（除非明确要求）
**追求基础解决方案**：减少代码重复，优先使用现有框架而非临时补丁

## 优化工作流程

### 1. 代码审查
识别最近修改的代码段，检查：
- Epic 命名规范（A/U/F/E/I/T 前缀）
- 类型安全（指针检查、Cast 检查、空指针保护）
- 头文件依赖（IWYU 原则）

### 2. 安全性优化
- 替换不安全的指针操作
- 添加必要的 `ensure()` 和 `check()`
- 使用 `FXToolsErrorReporter` 统一错误处理
- 确保 UObject 生命周期管理正确

### 3. 跨版本兼容性
- 使用 `XToolsVersionCompat.h` 宏和函数
- 条件编译 API 差异：`#if XTOOLS_ENGINE_5_5_OR_LATER`
- 原子操作：`XToolsVersionCompat::AtomicStore/Load()`

### 4. 性能优化
- Tick 中避免昂贵操作
- 使用 `TRACE_CPUPROFILER_EVENT_SCOPE` 追踪
- 避免不必要的内存分配
- 线程安全：`FRWLock`/`FCriticalSection`

### 5. 代码清理
- 使用 Early Return 减少嵌套
- 移除未使用的代码/参数/变量
- 清理显而易见的注释，保留引擎行为说明
- 中文注释（技术术语除外）

## Epic Games 编码标准

### 命名规范
| 类型 | 前缀 | 示例 |
|------|------|------|
| Actor | A | `AActorPool` |
| UObject | U | `UXToolsLibrary` |
| Struct | F | `FObjectPoolConfig` |
| Enum | E | `EPoolState` |
| Interface | I | `IPoolInterface` |
| Template | T | `TSharedPtr<FActor>` |

### 头文件管理
- 严格遵循 IWYU（Include What You Use）
- 优先使用前向声明
- `.generated.h` 必须是最后包含的

### 类型使用
| 场景 | 使用 | 避免 |
|------|------|------|
| 容器 | `TArray/TMap/TSet` | `std::vector/map/set` |
| 字符串操作 | `FString` | - |
| 键/索引 | `FName` | - |
| UI/本地化 | `FText` | - |
| 大对象传参 | `const FStruct&` | 传值 |

## 项目特定约定

### 蓝图暴露标准
- 完整中文元数据：`DisplayName`, `Category`, `Keywords`, `ToolTip`
- Category 格式：`"XTools|ModuleName|Subcategory"`
- ToolTip 格式：详细描述 + 参数说明 + 返回值说明

### 模块架构规则
- Runtime 模块必须依赖 XToolsCore
- Runtime 不能依赖 Editor 模块
- UncookedOnly 必须有对应 Runtime 模块

## 常见陷阱

### 头文件和类型定义
- `TUniquePtr` 成员：需要完整类型定义
- `TSharedPtr` 成员：可以使用前向声明
- `STATGROUP` 顺序：`DECLARE_CYCLE_STAT_EXTERN` 在 `DECLARE_STATS_GROUP` 之后

### 编译器警告
- C5038：初始化列表顺序必须与声明顺序一致
- C2440：`TSubclassOf<T>` 到 `TSoftObjectPtr` 需要 `.Get()`

### 反射系统
- 委托回调函数不需要 UFUNCTION 标记
- `GENERATED_BODY()` 必须是类声明第一行

## K2Node 开发标准

- 模块类型：UncookedOnly
- 依赖：`BlueprintGraph`, `KismetCompiler`, `UnrealEd`
- 必须实现：`GetMenuActions()`, `GetNodeTitle()`, `AllocateDefaultPins()`, `ExpandNode()`
- 通配符引脚：使用 `PC_Wildcard`，在 `NotifyPinConnectionListChanged` 同步类型

## 参考资料

查看 `references/` 目录获取：
- Epic Games 编码标准详细说明
- UE 5.3-5.7 跨版本兼容性指南
- 常见问题和解决方案
