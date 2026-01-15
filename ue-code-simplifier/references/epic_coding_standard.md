# Epic Games 编码标准

## 命名规范

### 类命名前缀

| 前缀 | 用途 | 示例 |
|------|------|------|
| A | 继承自 AActor | `AActorPool`, `AMyCharacter` |
| U | 继承自 UObject | `UXToolsLibrary`, `UMyComponent` |
| F | Struct/普通类 | `FVector`, `FMyConfig` |
| E | Enum | `EInstanceState`, `EMyEnum` |
| I | Interface | `IPoolInterface`, `IMyInterface` |
| T | Template | `TArray`, `TSharedPtr<FMyType>` |

### 变量命名

```cpp
// 成员变量：驼峰命名，前缀 m_ 可选但推荐
int32 MyVariable;
float CurrentHealth;

// 布尔值：使用 b 前缀
bool bIsActive;
bool bHasInitialized;

// 函数参数：驼峰命名
void ProcessData(const FString& Data, int32 Count);

// 全局变量：使用 g_ 前缀
extern int32 GGlobalCounter;
```

### 函数命名

```cpp
// 蓝图函数库
UCLASS()
class UMyLibrary : public UBlueprintFunctionLibrary
{
    UFUNCTION(BlueprintCallable, Category = "MyCategory")
    static void MyBlueprintFunction();
};

// 成员函数：动词开头
void CalculateValue();
int32 GetItemCount() const;
bool IsValid() const;
```

## 头文件管理

### IWYU (Include What You Use)

```cpp
// 正确：只包含需要的头文件
#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "MyModuleTypes.h"           // 项目内头文件
#include "MyInterface.h"             // 需要完整定义时
#include "MyObject.generated.h"      // 必须是最后包含

// 前向声明（在头文件中优先使用）
class AMyActor;                      // 前向声明 Actor
struct FMyData;                     // 前向声明 Struct

// 错误：包含不需要的头文件
#include "Engine/Engine.h"           // 太宽泛
#include "CoreUObject.h"             // 已包含在 CoreMinimal.h
```

## 类型使用指南

### 容器类型

| UE 类型 | STL 类型 | 说明 |
|---------|---------|------|
| TArray | std::vector | 动态数组 |
| TMap | std::map/unordered_map | 键值对映射 |
| TSet | std::set/unordered_set | 唯一值集合 |

```cpp
// 使用 UE 容器
TArray<FString> Names;
TMap<int32, AActor*> ActorMap;
TSet<FName> UniqueTags;

// 容器迭代
for (const FString& Name : Names)
{
    // 处理 Name
}

// 避免使用 STL
// std::vector<FString> Names;  // 不推荐
```

### 字符串类型

| 类型 | 用途 | 示例 |
|------|------|------|
| FString | 字符串操作、修改 | `FString Path = FPaths::Combine(...);` |
| FName | 键、索引、快速比较 | `FName Tag = FName("MyTag");` |
| FText | UI 显示、本地化 | `FText::FromString("Hello");` |

```cpp
// FString：需要修改时使用
FString Result = SourceStr.Replace(*SearchStr, *ReplaceStr);

// FName：用作键或快速比较
FName MyTag = FName("Player");
if (Actor->Tags.Contains(MyTag)) { }

// FText：UI 显示（支持本地化）
FText DisplayText = LOCTEXT("MyKey", "Hello World");
```

## 指针和内存管理

### UObject 指针

```cpp
// 使用 TWeakObjectPtr 避免悬空指针
TWeakObjectPtr<AActor> WeakActor = MyActor;
if (AActor* StrongActor = WeakActor.Get())
{
    // 安全使用
}

// 或直接使用原始指针（依赖 GC）
AActor* MyActor = GetSafeActor();
if (MyActor && MyActor->IsValidLowLevel())
{
    // 安全使用
}
```

### 非 UObject 指针

```cpp
// 普通对象：使用智能指针
TSharedPtr<FMyData> DataPtr = MakeShared<FMyData>();
TUniquePtr<FMyData> DataUnique = MakeUnique<FMyData>();

// 弱引用
TWeakPtr<FMyData> DataWeak = DataPtr;
if (TSharedPtr<FMyData> StrongPtr = DataWeak.Pin())
{
    // 安全使用
}
```

## 蓝图暴露

### UFUNCTION 元数据

```cpp
UFUNCTION(BlueprintCallable, Category = "XTools|MyModule|MySubcategory",
    meta = (
        DisplayName = "函数显示名称",
        Keywords = "关键词,搜索",
        ToolTip = "详细说明。\n参数:\nParam1 - 参数1说明\n返回值:\nResult - 结果说明",
        AdvancedDisplay = "Param2,Param3"  // 高级显示参数
    ))
static void MyFunction(
    UPARAM(DisplayName="参数名称") const FString& Param,
    int32& OutResult);
```

### UPROPERTY 元数据

```cpp
UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "MyCategory",
    meta = (
        DisplayName = "属性显示名称",
        ToolTip = "属性说明",
        ClampMin = "0",    // 限制最小值
        ClampMax = "100"   // 限制最大值
    ))
float MyProperty = 50.0f;
```

## 性能优化

### 避免昂贵操作

```cpp
// Tick 中避免重复计算
void AMyActor::Tick(float DeltaTime)
{
    Super::Tick(DeltaTime);

    // 使用间隔检查
    if (GetWorld()->GetTimeSeconds() - LastUpdateTime < UpdateInterval)
    {
        return;
    }
    LastUpdateTime = GetWorld()->GetTimeSeconds();

    // 执行更新...
}

// 缓存计算结果
const float CachedValue = ExpensiveCalculation();
for (int32 i = 0; i < 1000; ++i)
{
    Process(CachedValue);  // 使用缓存值
}
```

### 性能分析

```cpp
// 使用性能追踪
TRACE_CPUPROFILER_EVENT_SCOPE(MyFunction);

void UMyLibrary::MyFunction()
{
    TRACE_CPUPROFILER_EVENT_SCOPE(Section1);
    // 代码段 1

    TRACE_CPUPROFILER_EVENT_SCOPE(Section2);
    // 代码段 2
}
```

## 线程安全

```cpp
// 读写锁：读多写少场景
FRWLock MyLock;

// 读操作
MyLock.ReadLock();
// 读取数据...
MyLock.ReadUnlock();

// 写操作
MyLock.WriteLock();
// 修改数据...
MyLock.WriteUnlock();

// 临界区：简单互斥
FCriticalSection MyCS;
MyCS.Lock();
// 保护代码...
MyCS.Unlock();
```
