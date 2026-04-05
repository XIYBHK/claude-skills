# 性能模式参考

> 来源：UE 5.6 引擎源码实证 + 插件项目实战验证

## Stats Profiling

> 来源：UE 源码 `BodyInstance.cpp`, `NaniteStreamingManager.cpp`, `TickTaskManager.cpp`

每个子系统必须有性能统计覆盖，否则 UE Profiler 中不可见。

**声明 StatGroup（每个模块一次）：**
```cpp
// 在 Private 头文件中
DECLARE_STATS_GROUP(TEXT("MyPlugin"), STATGROUP_MyPlugin, STATCAT_Advanced);

// 可选的详细分析组（默认禁用）
DECLARE_STATS_GROUP_VERBOSE(TEXT("MyPluginDetail"), STATGROUP_MyPluginDetail, STATCAT_Advanced);
```

**包裹热函数：**
```cpp
// 方式1：复用宏（推荐，统一前缀）
#define MYPLUGIN_SCOPE_CYCLE_COUNTER(Name) DECLARE_SCOPE_CYCLE_COUNTER(TEXT(#Name), STAT_MyPlugin_##Name, STATGROUP_MyPlugin)

void FMySystem::Update() {
    MYPLUGIN_SCOPE_CYCLE_COUNTER(Update);
    // ...
}

// 方式2：快速临时测量
QUICK_SCOPE_CYCLE_COUNTER(STAT_MyPlugin_OneOffTest);

// 方式3：嵌套层级（父/子关系）
void FMySystem::Tick() {
    MYPLUGIN_SCOPE_CYCLE_COUNTER(Tick_Total);
    {
        MYPLUGIN_SCOPE_CYCLE_COUNTER(Tick_Phase1);
        // ...
    }
}
```

**注意：** `TRACE_CPUPROFILER_EVENT_SCOPE` 用于 Insights 追踪，`SCOPE_CYCLE_COUNTER` 用于 Stats 系统（`stat game` 命令），两者用途不同，不要混淆。

---

## ParallelFor 标准用法

> 来源：UE 源码 `ParallelFor.h`, `PhysScene_Chaos.cpp`, `NaniteStreamingManager.cpp`

**Epic 标准签名：**
```cpp
ParallelFor(TEXT("DebugName"), Num, MinBatchSize, [&](int32 Index) { ... }, Flags);
```

| 检查项 | 错误 | 正确 |
|--------|------|------|
| DebugName | `ParallelFor(N, ...)` | `ParallelFor(TEXT("PBD_Solve"), N, 1, ...)` |
| MinBatchSize | 缺失（默认=1） | 根据工作量显式设定 |
| Flags | 缺失 | 按需设定 `EParallelForFlags::BackgroundPriority` |
| Lambda 内分配 | `TArray<T> Temp; Temp.Reserve(N);` | 预分配或用成员复用 |

### TInlineAllocator 陷阱

`TArray<T, TInlineAllocator<N>>` 和 `TArray<T>` 是**完全不同的类型**，不能互传引用。如果下游函数签名是 `TArray<T>&`，则不能传入 `TArray<T, TInlineAllocator<N>>`。

解决方案：
1. 将下游函数模板化 `template<typename Alloc> void Func(TArray<T, Alloc>&)`
2. 或回退为 `TArray<T>` + `Reserve()`

---

## 容器选型

> 来源：UE 源码 `HierarchicalHashGrid2D.h`, `SimpleCellGrid.h`, `RenderingSpatialHash.h`

| 场景 | Epic 的选择 | 不推荐 |
|------|------------|--------|
| 稀疏空间网格 | `TSet<FCell>` + 空间质数 hash | `TMap<FIntVector, ...>` |
| 稠密固定网格 | `TArray<T>` + `Y*Width+X` 索引 | `TMap` |
| 热路径邻居列表 | `TArray<T>` + `Reserve()` | 每帧 `new TArray` |
| 小固定缓冲 (≤64) | `TArray<T, TInlineAllocator<N>>` | 堆分配 |

**空间 Hash 函数（Epic 的质数方案）：**
```cpp
// 来自 RenderingSpatialHash.h line 42
uint32 Hash = uint32(X) * 1150168907u + uint32(Y) * 1235029793u + uint32(Z) * 1282581571u;
```

---

## 热路径优化模式

### 成员复用替代局部分配

```cpp
// [BAD] 每帧/每迭代分配
void SolveIteration(int32 N) {
    TArray<int32> Counts;
    Counts.SetNumZeroed(N);  // 每次迭代都分配
}

// [OK] 成员复用
class FSystem {
    TArray<int32> Counts;

    void SolveIteration(int32 N) {
        Counts.SetNumUninitialized(N);
        FMemory::Memzero(Counts.GetData(), N * sizeof(int32));
    }
};
```

### Memcpy 替代逐元素拷贝

```cpp
// [BAD] 逐元素（POD 类型时）
for (int32 i = 0; i < N; ++i) Dst[i] = Src[i];

// [OK] 批量拷贝（仅限 trivially copyable 类型：int32, float, FVector3f 等）
FMemory::Memcpy(Dst.GetData(), Src.GetData(), N * sizeof(T));
```

**注意**：含构造函数/析构函数的非 POD 类型（如 FString、TSharedPtr）**禁止** Memcpy，必须用 `TArray::Append` 或逐元素赋值。

### 查询过滤顺序（从廉价到昂贵）

1. 位运算掩码（~1 cycle）
2. 布尔标志检查（~1 cycle）
3. 用户回调/Lambda（不定）
4. 距离计算（减法 + 乘法 + 比较）

### TArray 移除操作选型

```cpp
// [BAD] RemoveAt 保持顺序 — 移动后续所有元素 O(N)
Slots.RemoveAt(Index);

// [OK] RemoveAtSwap 不保序 — O(1)，将末尾元素交换到被移除位置
Slots.RemoveAtSwap(Index);

// [BAD] Remove 按值查找 + 保序移除 — O(N) 查找 + O(N) 移位
RegisteredActors.Remove(Actor);

// [OK] RemoveSwap 按值查找 + 不保序移除 — O(N) 查找 + O(1) 交换
RegisteredActors.RemoveSwap(Actor);
```

**选型规则**：
- 不关心数组顺序（大多数运行时场景）→ 用 `RemoveAtSwap` / `RemoveSwap`
- 必须保持顺序（UI 列表、有序数据）→ 用 `RemoveAt` / `Remove`
- 从后往前遍历删除时，`RemoveAtSwap` 是安全的（交换的是更靠后的元素，不影响未遍历部分）

---

### GetRecommendedConfig 反模式

如果 `GetRecommendedConfig()` 返回值与默认构造完全一致，存在维护风险：
```cpp
// [BAD] 冗余
static FConfig GetRecommendedConfig() { FConfig C; C.Radius = 60.0f; return C; }

// [OK] 消除冗余
static FConfig GetRecommendedConfig() { return FConfig{}; }
```
