# API 模式参考

> 来源：UE 源码 CharacterMovementComponent.h + Tom Looman + Ben UI

## UPROPERTY Meta 完整指南

> 来源：UE 源码 `CharacterMovementComponent.h`

```cpp
UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "模块|子类",
    meta = (
        ClampMin = "0", ClampMax = "100",  // 硬限制（序列化时强制）
        UIMin = "0", UIMax = "100",        // 滑块范围（可超出 Clamp）
        ForceUnits = "cm",                 // 单位显示（cm, cm/s, s, degrees）
        EditCondition = "bEnabled",        // 条件显示
        EditConditionHides                 // 条件不满足时隐藏（而非灰显）
    ))
float MyProperty = 50.0f;
```

| 检查项 | 优先级 |
|--------|--------|
| 数值属性缺少 `UIMin/UIMax` | P1 中 |
| 距离/速度/时间属性缺少 `ForceUnits` | P1 中 |
| bool 控制的子属性缺少 `EditCondition` | P1 中 |
| 高级参数缺少 `AdvancedDisplay` | P2 低 |

---

## Delegate 选型

> 来源：Tom Looman, Ben UI Advanced Delegates

| 类型 | 蓝图可见 | 性能 | 用途 |
|------|---------|------|------|
| `DECLARE_DELEGATE` | [BAD] | 最快 | 纯 C++ 回调 |
| `DECLARE_MULTICAST_DELEGATE` | [BAD] | 快 | 多绑定 C++ 事件 |
| `DECLARE_DYNAMIC_DELEGATE` | [OK] | 慢 | 蓝图单播 |
| `DECLARE_DYNAMIC_MULTICAST_DELEGATE` | [OK] | 最慢 | 蓝图事件调度器 |

**关键规则：**
- [BAD] 所有 delegate 都用 Dynamic → 只在需要蓝图暴露时用
- [BAD] 在构造函数中绑定 delegate → 会被序列化到蓝图，改用 `PostInitializeComponents()` 或 `BeginPlay()`
- [BAD] delegate 回调函数标记 `UFUNCTION()` → 非 Dynamic 绑定不需要

---

## Subsystem 选型

> 来源：Epic 官方文档, uhiyama-lab.com

| Subsystem 类型 | 生命周期 | 用途 |
|---------------|---------|------|
| `UEngineSubsystem` | 引擎启动→关闭 | 全局服务（极少用） |
| `UEditorSubsystem` | 编辑器启动→关闭 | 编辑器工具 |
| `UGameInstanceSubsystem` | 游戏启动→退出 | 跨关卡持久数据 |
| `UWorldSubsystem` | 关卡加载→卸载 | 关卡级系统 |
| `ULocalPlayerSubsystem` | 玩家加入→退出 | 分屏/多玩家 UI 状态 |

- 插件级单例系统优先用 `UWorldSubsystem`
- 跨关卡状态用 `UGameInstanceSubsystem`
- 不要用 `AActor` 单例替代 Subsystem

---

## API 导出策略

> 来源：Ben UI "Don't Export Everything"

```cpp
// 分级导出策略（从最小到最大）
// 1. 默认不导出
UCLASS()
class AMyInternalActor : public AActor { ... };

// 2. MinimalAPI — 只允许 Cast<T>
UCLASS(MinimalAPI)
class AMyActor : public AActor { ... };

// 3. 导出特定函数
UCLASS()
class AMyActor : public AActor {
    MYPLUGIN_API void PublicFunction();
    void InternalFunction();
};

// 4. 导出全部 — 仅限真正需要完全暴露的类
UCLASS()
class MYPLUGIN_API AMyPublicActor : public AActor { ... };
```

---

## 自定义日志类别

> 来源：Ben UI "Log Until It Gets Annoying" + Epic 官方

```cpp
// 头文件
DECLARE_LOG_CATEGORY_EXTERN(LogMyPlugin, Log, All);

// 源文件
DEFINE_LOG_CATEGORY(LogMyPlugin);

// 使用
UE_LOG(LogMyPlugin, Display, TEXT("Initialized: %d instances"), N);
UE_LOG(LogMyPlugin, Warning, TEXT("Config out of range: %f"), V);
```

- [BAD] 所有日志用 `LogTemp` → 声明自定义 Log Category
- [BAD] 关键决策路径无日志 → 添加 `UE_LOG`
- [OK] UE5.2+ 优先用 `UE_LOGFMT`

---

## Console Variable 模式

> 来源：Epic 官方 Console Variables C++ 文档

```cpp
static TAutoConsoleVariable<int32> CVarMyFeature(
    TEXT("my.plugin.FeatureEnabled"), 1,
    TEXT("Enable my plugin feature (0=off, 1=on)"),
    ECVF_Default);

int32 Value = CVarMyFeature.GetValueOnGameThread();
```

- 调试参数用 CVar 而非 UPROPERTY
- CVar 命名：`pluginname.system.parameter`

---

## BlueprintPure 陷阱

> 来源：MrRobinOfficial

const UFUNCTION 被 UE 自动标记为 Pure。纯函数在蓝图中**每拉一根线都重新执行**：

```cpp
// [BAD] 昂贵 const 函数被自动 Pure
UFUNCTION(BlueprintCallable)
TArray<AActor*> FindNearbyEnemies() const;

// [OK] 显式禁用
UFUNCTION(BlueprintCallable, BlueprintPure = false)
TArray<AActor*> FindNearbyEnemies() const;
```
