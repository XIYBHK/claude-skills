# 安全模式参考

> 来源：UE 源码 `AssertionMacros.h` + MrRobinOfficial GC 章节 + Tom Looman 防御编程

## 断言宏选择

> 来源：UE 源码 `AssertionMacros.h` (行 351-374)

| 宏 | Shipping 行为 | 用途 | 示例 |
|----|-------------|------|------|
| `check(expr)` | **移除，不执行** | 绝不应该发生的编程错误 | `check(Index >= 0)` |
| `checkf(expr,fmt)` | **移除，不执行** | 同上 + 消息 | `checkf(Ptr, TEXT("Null"))` |
| `ensure(expr)` | 执行，失败时仅日志 | 可恢复错误 + 遥测 | `if (ensure(Obj)) { ... }` |
| `ensureMsgf(expr,fmt)` | 执行，失败时带消息 | 同上 + 上下文 | `ensureMsgf(SOA, TEXT("SOA null"))` |
| `verify(expr)` | **表达式始终执行** | 有副作用的断言 | `verify(Init())` |

**关键规则：**
- [BAD] 在运行时输入验证中用 `checkf` → Shipping 会崩溃或跳过
- [BAD] 在 `check()` 内放有副作用的表达式 → Shipping 中不执行
- [BAD] 对外部输入（用户数据、文件、网络）用 `check` → 用 `ensure` + 错误处理

---

## GC 安全

> 来源：MrRobinOfficial/Guide-UnrealEngine GC 章节, Epic 官方文档

### UObject 创建——只用 3 种方式

```cpp
// [OK] 构造函数内
MyComp = CreateDefaultSubobject<UMyComponent>(TEXT("MyComp"));

// [OK] 运行时创建 UObject
UMyObject* Obj = NewObject<UMyObject>(this);

// [OK] 运行时生成 Actor
AMyActor* Actor = GetWorld()->SpawnActor<AMyActor>(SpawnClass, SpawnTransform);

// [BAD] 绝对禁止
UMyObject* Obj = new UMyObject();  // GC 不追踪，必泄漏
```

### UPROPERTY 是 GC 追踪的唯一入口

> 源码实证：`UnrealTypePrivate.h` — UMapProperty、USetProperty 均实现 `AddReferencedObjects`

**有 UPROPERTY → GC 追踪所有容器：**
```cpp
UPROPERTY()
TArray<UObject*> Tracked;           // [OK] GC 追踪

UPROPERTY()
TMap<int32, UObject*> AlsoTracked;  // [OK] GC 追踪（UE5 UMapProperty 支持）

UPROPERTY()
TSet<UObject*> AlsoTracked;         // [OK] GC 追踪（UE5 USetProperty 支持）
```

**无 UPROPERTY → 任何容器都不追踪：**
```cpp
TArray<UObject*> NotTracked;        // [BAD] 无 UPROPERTY = GC 不追踪
TMap<int32, UObject*> NotTracked;   // [BAD] 同上
```

关键：问题在于**缺少 UPROPERTY**，而非容器类型。

### IsValid() vs nullptr

> 源码实证：`ObjectMacros.h:591` — PendingKill 在 UE 5.4 已废弃，替换为 Garbage Elimination

```cpp
// [BAD] 只检查 null（对象可能已被标记为 Garbage）
if (MyActor != nullptr) { ... }

// [OK] 同时检查 null 和 Garbage 状态
if (IsValid(MyActor)) { ... }
```

注意：UE 5.4+ 中 `IsPendingKill()` 已废弃，统一使用 `IsValid()`。

### 内存管理速查

| 场景 | 使用 |
|------|------|
| UObject 成员引用 | `UPROPERTY() TObjectPtr<T>` (UE5) |
| UObject 弱引用 | `TWeakObjectPtr<T>` |
| 延迟加载资产 | `TSoftObjectPtr<T>` |
| 非 UObject 共享 | `TSharedPtr<T>` / `MakeShared<T>()` |
| 非 UObject 独占 | `TUniquePtr<T>` / `MakeUnique<T>()` |
| 循环引用 | 一方用 `TWeakObjectPtr` / `TWeakPtr` |

**关键规则：**
- `UPROPERTY()` 必须标记所有 UObject 指针成员，否则 GC 不追踪
- `TUniquePtr<T>` 成员需要完整类型定义（头文件 include）
- `TSharedPtr<T>` 成员可用前向声明

---

## Tick 管理

> 来源：MrRobinOfficial best_practices, unreal-engine-cpp-pro

### 默认禁用 Tick

```cpp
// Actor 构造函数
PrimaryActorTick.bCanEverTick = false;
PrimaryActorTick.bStartWithTickEnabled = false;

// Component 构造函数
PrimaryComponentTick.bCanEverTick = false;
PrimaryComponentTick.bStartWithTickEnabled = false;
```

### 必须 Tick 时的优化

```cpp
PrimaryActorTick.TickInterval = 0.2f;  // 5Hz 而非 60Hz
SetActorTickEnabled(true);   // 按需开
SetActorTickEnabled(false);  // 按需关
```

### 非 Actor/Component 的 Tick

```cpp
class FMySystem : public FTickableGameObject {
    void Tick(float DeltaTime) override;
    TStatId GetStatId() const override {
        RETURN_QUICK_DECLARE_CYCLE_STAT(FMySystem, STATGROUP_Tickables);
    }
};
```

**审查规则：**
- [BAD] bCanEverTick 保持默认 true
- [BAD] 在 Tick 中 `Cast<T>()` → 在 BeginPlay 缓存引用
- [BAD] 在 Tick 中 `FindComponentByClass<T>()`

---

## 防御性编程

> 来源：Tom Looman "Defensive Programming" 章节

### 何时检查 nullptr

- [OK] 指针**预期可能为空**时检查 — 如 `GetFocusedActor()` 没有目标时返回 null
- [BAD] 指针**不应该为空**时静默跳过 — 如 `GetPlayerController()` 在运行时必存在

```cpp
// [BAD] 静默吞掉不应发生的空指针
APlayerController* PC = GetWorld()->GetPlayerController(0);
if (PC) {
    PC->AddToInventory(NewItem);  // 跳过时用户丢失物品，无提示
}

// [OK] 不应为空 → 用 check/ensure 暴露
APlayerController* PC = GetWorld()->GetPlayerController(0);
check(PC);
PC->AddToInventory(NewItem);
```

### 数组安全访问

> 来源：Ben UI "IsValidIndex before accessing TArray"

```cpp
// [BAD] 直接索引（越界 = 崩溃）
SomeArray[Index].DoSomething();

// [OK] 先验证索引
if (SomeArray.IsValidIndex(Index)) {
    SomeArray[Index].DoSomething();
}
```

---

## Shipping Build 安全

- `check/checkf` 在运行时输入路径 → 改 `ensure` + 降级逻辑
- `#if !UE_BUILD_SHIPPING` 保护的调试代码 → 确认无副作用泄露
- `verify()` 内的副作用 → Shipping 中执行但不断言

**非 UCLASS 系统类合法性：** Epic 在 `RootMotionSource.h` 中大量使用非反射系统类。性能关键代码不需要 USTRUCT/UCLASS 反射开销。
