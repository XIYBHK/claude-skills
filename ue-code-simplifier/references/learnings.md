# 自学习记录

> 本文件由 AI agent 在每次审查/优化任务后自动追加，人工定期审阅维护。
> 高置信度条目经验证后可晋升到对应 reference 文件成为正式规则。

## 格式规范

每条记录使用以下格式：

```
### [日期] — [分类]
- **现象**：具体描述遇到的问题或发现
- **解决**：采取的行动和结果
- **规则**：提炼出的可复用规则（一句话）
- **置信度**：high / medium / low
- **适用范围**：通用 / 特定场景描述
```

## 分类体系

| 分类 | 含义 |
|------|------|
| `compilation` | 编译错误、链接问题、UHT 问题 |
| `performance` | 性能瓶颈、热路径优化、Stats |
| `gc-memory` | GC 泄漏、内存管理、指针安全 |
| `blueprint` | 蓝图暴露、UPROPERTY/UFUNCTION、meta |
| `threading` | 线程安全、ParallelFor、GameThread |
| `shipping` | Shipping 构型、跨平台、FAB 提交 |
| `architecture` | 模块结构、依赖、Subsystem、导出策略 |
| `ue-api` | UE API 用法、版本差异、隐式行为 |

## 晋升条件

当一条 learning 满足以下条件时，应晋升为正式规则：
1. 置信度为 `high`
2. 在 2 个以上不同项目/场景中验证通过
3. 与现有规则不冲突

晋升操作：将规则添加到对应的 reference 文件，并在本文件中标记 `[已晋升 → xxx_patterns.md]`。

## 录入示例

> 以下为格式示范，实际规则已包含在正式 reference 文件中。

编译错误捕获的典型条目：

```
### 2026-04-04 — compilation
- **现象**：将 `TArray<int32>` 改为 `TArray<int32, TInlineAllocator<64>>` 后，传入接受 `TArray<int32>&` 的函数编译报错 C2664
- **解决**：回退为 `TArray<int32>` + `Reserve()`，或将下游函数模板化
- **规则**：UE 的 `TArray<T, AllocA>` 和 `TArray<T, AllocB>` 是不同类型，不能互传引用
- **置信度**：high
- **适用范围**：通用 — 所有使用 TInlineAllocator 的场景
```

常规审查发现的典型条目：

```
### 2026-04-04 — performance
- **现象**：ParallelFor lambda 内每个实例都 Reserve() 新 TArray，万级实例时产生数万次堆分配
- **解决**：将临时数组提升为系统成员变量，跨帧复用
- **规则**：热路径 ParallelFor 内禁止堆分配，用成员复用或 thread-local 缓冲
- **置信度**：high
- **适用范围**：通用 — 所有高频 ParallelFor 场景
```

---

## 记录

（以下由 agent 自动追加）
