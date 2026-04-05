---
name: ue-code-simplifier
description: UE C++ 插件开发终极审查与优化标杆。Use for ANY task involving reviewing, checking, optimizing, refactoring, or improving existing Unreal Engine C++ plugin code. Trigger whenever the user mentions UE/UE5/Unreal C++ code combined with words like：看下、审查、检查、优化、重构、简化、性能、质量、内存、GC、Tick、容器选型、Marketplace、FAB、代码评审、插件质量。Also trigger for UE C++ performance problems (TMap、空间查询、热路径、帧率), memory/GC/safety concerns (UPROPERTY、check/ensure、IsValid), compilation warnings (C5038、TInlineAllocator), or preparing .h/.cpp files for FAB/Marketplace submission. Do NOT trigger for: writing new UE code from scratch, Blueprint-only tasks, HLSL/shader work, packaging/deployment issues, editor crash debugging, or project migration between UE versions.
---

# UE C++ 插件开发审查与优化标杆

基于 UE5 引擎源码实证 + Epic 官方编码标准 + FAB/Marketplace 提交规范 + 生产环境验证。

## 核心原则

- **功能不变性**：只改变实现方式，不改变逻辑结果
- **蓝图接口稳定性**：不修改 UFUNCTION/UPROPERTY 签名（除非明确要求）
- **聚焦近期修改**：默认只审查/优化本次会话中修改过的代码，除非用户明确要求全量审查
- **批判性验证**：对任何建议/方案都要验证是否真实有效且合理
- **最小改动修 bug**：修复 bug 时绝不顺带重构

## 防过度简化

优化代码时保持克制，避免让代码更难理解或扩展：

- **可读性优先于简洁性**：显式清晰的代码优于"聪明"的紧凑写法
- **禁止嵌套模板元编程**：除非性能有明确量化收益，否则不引入模板嵌套
- **禁止合并不相关逻辑**：一个函数只做一件事，不为减少函数数量而合并
- **保留有意义的抽象层**：如果一个中间类/函数使代码结构更清晰，不要为了"少一层"而删除它
- **不追求行数最少**：10 行清晰代码优于 3 行需要注释才能理解的代码
- **保留有价值的注释**：删除"显而易见"的注释，保留解释 WHY 和业务决策的注释

---

## 任务路由

根据用户意图，聚焦对应步骤并**严格只读取表中列出的 reference 文件**。不要读取不相关的 reference — 这会浪费 token 且不增加价值：

| 用户意图 | 聚焦步骤 | 只读这些 reference |
|---------|---------|-------------------|
| "审查代码" / "代码评审" | Step 1→5 全流程 | 按 Step 需要依次加载（不要一次全读） |
| "优化性能" / "太卡了" | Step 3 性能审查 | `performance_patterns.md` |
| "准备发布" / "提交 Marketplace" | Step 2 + 5 | `safety_patterns.md` + `shipping_checklist.md` |
| "简化代码" / "重构" | Step 1 + 4 | `api_patterns.md` + `epic_coding_standard.md` |
| "修 bug" / "编译报错" | 定点修复 | `common_issues.md` |
| "蓝图相关" / "UPROPERTY" | Step 4 | `api_patterns.md` |
| "GC 泄漏" / "内存问题" | Step 2 | `safety_patterns.md` |
| "跨版本兼容" | 专项 | `cross_version_compat.md` |

全量审查时，按 Step 顺序依次读取对应 reference，完成一个 Step 再读下一个，而非一次性加载全部。

---

## 审查工作流

### Step 1: 结构评估
1. 模块结构（Runtime/Editor 分离、Public/Private 分离）
2. `.uplugin` + `Build.cs` 配置（LoadingPhase、依赖声明）
3. 头文件 IWYU + 按字母序排列 + `.generated.h` 最后
4. 命名规范（A/U/F/E/I/T 前缀）
→ 详见 `references/epic_coding_standard.md`

### Step 2: 安全性审查
1. 断言宏：`check`(开发) vs `ensure`(运行时) vs `verify`(副作用)
2. GC 安全：UPROPERTY 标记（所有含 UObject* 的容器）、UObject 创建方式
3. 指针安全：`IsValid()` 替代 `!= nullptr`，防御编程
4. Tick 管理：默认禁用，缓存引用，FTickableGameObject
5. 线程安全：UObject 仅 GameThread，ParallelFor 不访问 UObject
→ 详见 `references/safety_patterns.md`

### Step 3: 性能审查
1. Stats Profiling：每个子系统热函数包裹 `SCOPE_CYCLE_COUNTER`
2. ParallelFor：必须有 `TEXT("Name")` + MinBatchSize
3. 容器选型：空间网格用空间质数 hash，热路径避免 TMap
4. 热路径：成员复用替代局部分配，Memcpy 替代逐元素拷贝
5. TInlineAllocator 陷阱：与 TArray 是不同类型，不能互传引用
→ 详见 `references/performance_patterns.md`

### Step 4: API 质量审查
1. UPROPERTY meta：UIMin/UIMax + ForceUnits + EditCondition
2. Delegate 选型：只在需要蓝图暴露时用 Dynamic
3. Subsystem 选型：WorldSubsystem vs GameInstanceSubsystem
4. API 导出：MinimalAPI → 选择性导出 → 全导出（分级）
5. BlueprintPure 陷阱：昂贵 const 函数加 `BlueprintPure = false`
6. 自定义 Log Category + Console Variable
→ 详见 `references/api_patterns.md`

### Step 5: 发布验证
1. 编译 Editor + Game + Shipping 三构型
2. FAB/Marketplace 7 项就绪检查
3. 跨平台：无硬编码路径，无平台特定头文件
4. 模块加载阶段：Editor 模块必须 PostEngineInit
5. Hot Reload 安全：不缓存 Subsystem 指针，不用 static 持有引擎对象
6. 软引用：大型资产用 TSoftObjectPtr/TSoftClassPtr
→ 详见 `references/shipping_checklist.md`

---

## 标准输出格式

审查结果必须按以下结构组织，确保输出一致性和可读性：

```
# [文件名] 审查报告

> 审查范围 / 用户需求 / 审查依据

## 问题总览

| # | 严重度 | 问题 | 位置 | 规则 |
|---|--------|------|------|------|
（按 P0 → P1 → P2 排列所有问题，每行一个）

## 详细分析

### [P0-1] 问题标题
**位置**：文件:行号
**问题**：具体描述
**修复方案**：代码示例
**规则 #N**：对应规则名

（按严重度分组，P0 全部在前，P1 次之，P2 最后）

## 修复优先级
（按修复顺序排列的编号清单）
```

问题总览表是强制的 — 它让用户一眼看到全貌。详细分析中每个问题必须引用规则编号（来自 25 条速查表），使建议可溯源。

---

## 25 条规则速查表

按严重度排序，用于快速定位问题。详细说明和代码示例在对应 reference 文件中。

### P0 — 必修（崩溃/泄漏/数据丢失）

| # | 规则 | 一句话 | Reference |
|---|------|--------|-----------|
| 1 | UPROPERTY 必标 | 所有 UObject* 成员/容器必须 UPROPERTY()，否则 GC 不追踪（含 TMap/TSet） | safety_patterns.md#gc |
| 2 | UObject 创建 | 只用 NewObject/SpawnActor/CreateDefaultSubobject，禁止 `new` | safety_patterns.md#gc |
| 3 | 断言宏选择 | checkf 在 Shipping 中被移除，运行时用 ensureMsgf | safety_patterns.md#assert |
| 4 | check 内副作用 | check 内的表达式在 Shipping 中不执行 | safety_patterns.md#assert |
| 5 | IsValid() | 用 IsValid() 替代 nullptr 检查（UE5.4+ PendingKill 已废弃） | safety_patterns.md#gc |

### P1 — 重要（性能/可维护性）

| # | 规则 | 一句话 | Reference |
|---|------|--------|-----------|
| 6 | Stats Profiling | 子系统热函数必须有 SCOPE_CYCLE_COUNTER | performance_patterns.md#stats |
| 7 | ParallelFor 签名 | 必须有 TEXT("Name") + MinBatchSize | performance_patterns.md#parallelfor |
| 8 | Tick 默认禁用 | bCanEverTick = false，在 BeginPlay 缓存引用 | safety_patterns.md#tick |
| 9 | 热路径堆分配 | 成员复用替代每帧 TArray 分配 | performance_patterns.md#hotpath |
| 10 | TInlineAllocator | 和 TArray 是不同类型，不能互传引用 | performance_patterns.md#parallelfor |
| 11 | Delegate 选型 | 不需要蓝图暴露时禁用 Dynamic | api_patterns.md#delegate |
| 12 | 自定义 Log Category | 禁止全用 LogTemp | api_patterns.md#log |
| 13 | 防御编程 | 不应为空的指针用 check 暴露，不要静默跳过 | safety_patterns.md#defensive |
| 14 | 数组安全 | IsValidIndex() 后再访问 | safety_patterns.md#defensive |
| 15 | 容器选型 | 空间网格不用 TMap，用空间质数 hash | performance_patterns.md#container |
| 16 | API 导出 | 默认不导出，按需分级（MinimalAPI → 选择性 → 全导出） | api_patterns.md#export |
| 17 | BlueprintPure | 昂贵 const 函数加 BlueprintPure = false | api_patterns.md#blueprintpure |

### P2 — 改善（编辑器体验/代码质量）

| # | 规则 | 一句话 | Reference |
|---|------|--------|-----------|
| 18 | UPROPERTY UIMin/UIMax | 数值属性必须有滑块范围 | api_patterns.md#uproperty |
| 19 | ForceUnits | 距离/速度/时间属性显示单位 | api_patterns.md#uproperty |
| 20 | EditCondition | bool 控制的子属性条件显示 | api_patterns.md#uproperty |
| 21 | Subsystem 选型 | WorldSubsystem 替代 Actor 单例 | api_patterns.md#subsystem |
| 22 | CVar 调试参数 | 运行时可调参数用 TAutoConsoleVariable | api_patterns.md#cvar |
| 23 | Include 排序 | 按字母序，.generated.h 最后 | shipping_checklist.md#include |
| 24 | 软引用 | 大资产用 TSoftObjectPtr 避免加载链 | shipping_checklist.md#softref |
| 25 | 冗余工厂函数 | 返回值等于默认构造时直接 return {} | performance_patterns.md#hotpath |

---

## 自学习协议

本 skill 具备持续学习能力。每次审查/优化任务结束后，agent 应将新发现记录到 `references/learnings.md`，使知识跨会话积累。

### 任务开始前
1. 读取 `references/learnings.md`，应用已有高置信度条目
2. 检查是否有与当前任务相关分类的历史记录

### 编译错误捕获（自动触发）
当 UE C++ 项目编译失败并完成修复后，自动执行：
1. 判断错误是否具备录入价值（满足任一条件即可）：
   - UE 特有错误（UHT、反射、模块链接、平台差异）
   - 修复花费 >1 次尝试
   - 涉及 UE API 隐式行为或版本差异
   - 类型系统陷阱（如 TInlineAllocator 不兼容、缺失 UPROPERTY 导致 GC 不追踪）
2. 如果有录入价值，向用户展示提炼的规则并询问：
   ```
   发现可复用的编译经验：
   - 现象：[脱敏后的错误描述]
   - 规则：[一句话可复用规则]
   - 分类：[compilation / ue-api / ...]
   是否录入到 skill 自学习记录？
   ```
3. 用户确认后，脱敏并追加到 `references/learnings.md`
4. 跳过不录入的情况：单纯拼写错误、缺少分号、遗漏 include 等低价值问题

### 任务结束后
1. 回顾本次任务中遇到的问题和发现
2. 筛选出**项目无关的、可复用的**新知识（排除项目名、路径等隐私信息）
3. 按格式追加到 `references/learnings.md`
4. 如果发现的规则已在现有 reference 中有覆盖 → 跳过，不重复记录

### 晋升机制
当 learnings.md 中的条目满足以下条件时，将其晋升为正式规则：
- 置信度 `high` + 在 2 个以上不同场景验证通过
- 晋升操作：添加到对应 reference 文件，原条目标记 `[已晋升]`

### 维护
- 超过 50 条时，审阅并清理过时/已晋升条目
- 保持条目具体可执行，拒绝模糊描述

→ 详见 `references/learnings.md` 中的分类体系和格式规范

---

## Reference 文件导航

| 文件 | 内容 | 何时读取 |
|------|------|---------|
| `references/performance_patterns.md` | Stats/ParallelFor/容器选型/空间Hash/热路径优化 | 性能审查 (Step 3) |
| `references/safety_patterns.md` | 断言/GC/Tick/防御编程/IsValid/Shipping | 安全审查 (Step 2) |
| `references/api_patterns.md` | UPROPERTY meta/Delegate/Subsystem/导出/CVar/Log/BlueprintPure | API 审查 (Step 4) |
| `references/shipping_checklist.md` | FAB/跨平台/模块加载/HotReload/软引用/序列化/Include | 发布验证 (Step 5) |
| `references/epic_coding_standard.md` | 命名规范/类型使用/头文件管理/蓝图暴露 | 结构评估 (Step 1) |
| `references/common_issues.md` | 编译警告/TInlineAllocator/空间数据结构/反射/线程安全 | 修 bug |
| `references/cross_version_compat.md` | UE 5.3-5.7 跨版本兼容 | 跨版本 |
| `references/learnings.md` | 自学习记录（自动积累 + 晋升机制） | 每次任务开始前读取 |

