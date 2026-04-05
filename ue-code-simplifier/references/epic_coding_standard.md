# Epic Games 编码标准

## 命名规范

### 类命名前缀

| 前缀 | 用途 | 示例 |
|------|------|------|
| A | 继承自 AActor | `AActorPool`, `AMyCharacter` |
| U | 继承自 UObject | `UMyLibrary`, `UMyComponent` |
| F | Struct/普通类 | `FVector`, `FMyConfig` |
| E | Enum | `EInstanceState`, `EMyEnum` |
| I | Interface | `IPoolInterface`, `IMyInterface` |
| T | Template | `TArray`, `TSharedPtr<FMyType>` |

### 变量命名

```cpp
// 成员变量：驼峰命名
int32 MyVariable;
float CurrentHealth;

// 布尔值：使用 b 前缀
bool bIsActive;
bool bHasInitialized;

// 函数参数：驼峰命名
void ProcessData(const FString& Data, int32 Count);

// 全局变量：使用 G 前缀
extern int32 GGlobalCounter;
```

### 函数命名

```cpp
// 成员函数：动词开头
void CalculateValue();
int32 GetItemCount() const;
bool IsValid() const;
```

## 头文件管理

### IWYU (Include What You Use)

```cpp
// 只包含需要的头文件
#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "MyModuleTypes.h"
#include "MyInterface.h"
#include "MyObject.generated.h"      // 必须是最后包含

// 前向声明（在头文件中优先使用）
class AMyActor;
struct FMyData;

// 避免：包含太宽泛的头文件
// #include "Engine/Engine.h"        // 太宽泛
```

## 类型使用指南

### 容器类型

| UE 类型 | STL 等价 | 说明 |
|---------|---------|------|
| TArray | std::vector | 动态数组 |
| TMap | std::unordered_map | 键值对映射 |
| TSet | std::unordered_set | 唯一值集合 |

始终使用 UE 容器，避免 STL 容器。

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

## 蓝图暴露

### UFUNCTION 元数据

```cpp
UFUNCTION(BlueprintCallable, Category = "MyPlugin|MyModule|Subcategory",
    meta = (
        DisplayName = "My Function",
        Keywords = "keyword,search",
        ToolTip = "Detailed description.",
        AdvancedDisplay = "Param2,Param3"
    ))
static void MyFunction(
    UPARAM(DisplayName="Parameter") const FString& Param,
    int32& OutResult);
```

> 指针安全、内存管理、性能优化、线程安全等内容详见对应 reference 文件：
> - `safety_patterns.md` — GC、断言、防御编程、Tick 管理
> - `performance_patterns.md` — Stats、ParallelFor、容器选型、热路径
> - `api_patterns.md` — UPROPERTY meta、Delegate、Subsystem、导出、CVar
