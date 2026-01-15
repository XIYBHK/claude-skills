# 常见问题和解决方案

## 编译警告

### C5038: 初始化列表顺序

```cpp
// 错误：初始化顺序与声明顺序不一致
class FMyStruct
{
    int32 B;
    int32 A;

    FMyStruct()
        : B(1)  // 警告 C5038
        , A(2)
    {}
};

// 正确：按声明顺序初始化
class FMyStruct
{
    int32 A;  // 先声明
    int32 B;  // 后声明

    FMyStruct()
        : A(2)  // 先初始化
        , B(1)  // 后初始化
    {}
};
```

### C2440: 类型转换

```cpp
// 错误：TSubclassOf 直接转换
TSubclassOf<AActor> ActorClass;
TSoftObjectPtr<AActor> SoftPtr = ActorClass;  // C2440

// 正确：使用 Get() 获取 UClass*
TSubclassOf<AActor> ActorClass;
TSoftObjectPtr<AActor> SoftPtr = ActorClass.Get();
```

## 头文件问题

### TUniquePtr 需要完整定义

```cpp
// 错误：只有前向声明
class FMyData;
class FMyClass
{
    TUniquePtr<FMyData> Data;  // 错误：析构函数需要完整定义
};

// 正确：包含完整头文件
#include "MyData.h"
class FMyClass
{
    TUniquePtr<FMyData> Data;  // 正确
};

// TSharedPtr 可以使用前向声明
class FMyOtherData;
class FMyOtherClass
{
    TSharedPtr<FMyOtherData> Data;  // 正确：SharedPtr 可以使用前向声明
};
```

### .generated.h 包含顺序

```cpp
// 错误：.generated.h 不是最后包含
#include "MyActor.h"
#include "MyActor.generated.h"
#include "OtherHeader.h"  // 错误

// 正确：.generated.h 必须是最后包含
#include "MyActor.h"
#include "OtherHeader.h"
#include "MyActor.generated.h"  // 正确
```

## 反射系统

### UFUNCTION 不用于委托回调

```cpp
// 错误：AddLambda 绑定的函数标记为 UFUNCTION
UFUNCTION()
void MyCallback();

MyDelegate.AddLambda(this, &UMyClass::MyCallback);

// 正确：移除 UFUNCTION 标记
void MyCallback();

MyDelegate.AddLambda(this, &UMyClass::MyCallback);

// 或使用动态委托（需要 UFUNCTION）
DECLARE_DYNAMIC_DELEGATE_OneParam(FMyDelegate, int32, Value);

UFUNCTION()
void MyDynamicCallback(int32 Value);

MyDynamicDelegate.BindDynamic(this, &UMyClass::MyDynamicCallback);
```

### GENERATED_BODY() 位置

```cpp
// 错误：GENERATED_BODY() 不是第一行
UCLASS()
class AMyActor : public AActor
{
    // 其他代码
    GENERATED_BODY()  // 错误
};

// 正确：GENERATED_BODY() 必须是第一行
UCLASS()
class AMyActor : public AActor
{
    GENERATED_BODY()  // 正确

    // 其他代码
};
```

## 性能问题

### Tick 中的昂贵操作

```cpp
// 错误：每帧执行昂贵操作
void AMyActor::Tick(float DeltaTime)
{
    Super::Tick(DeltaTime);

    for (int32 i = 0; i < 10000; ++i)
    {
        ExpensiveCalculation();  // 每帧执行！
    }
}

// 正确：使用间隔检查
void AMyActor::Tick(float DeltaTime)
{
    Super::Tick(DeltaTime);

    if (GetWorld()->GetTimeSeconds() - LastUpdateTime < 0.1f)
    {
        return;  // 跳过
    }

    LastUpdateTime = GetWorld()->GetTimeSeconds();
    for (int32 i = 0; i < 10000; ++i)
    {
        ExpensiveCalculation();
    }
}
```

### 不必要的分配

```cpp
// 错误：循环中重复分配
for (int32 i = 0; i < 1000; ++i)
{
    TArray<FString> TempArray;  // 每次循环都分配
    TempArray.Add(Item);
}

// 正确：预先分配
TArray<FString> TempArray;
TempArray.Reserve(1000);  // 预分配
for (int32 i = 0; i < 1000; ++i)
{
    TempArray.Add(Item);
}
```

## 线程安全

### 双重锁定

```cpp
// 错误：嵌套锁定导致死锁
FRWLock Lock1;
FRWLock Lock2;

void Thread1()
{
    Lock1.WriteLock();
    Lock2.WriteLock();  // 可能死锁
    // ...
    Lock2.WriteUnlock();
    Lock1.WriteUnlock();
}

void Thread2()
{
    Lock2.WriteLock();
    Lock1.WriteLock();  // 可能死锁
    // ...
    Lock1.WriteUnlock();
    Lock2.WriteUnlock();
}

// 正确：统一锁定顺序
void Thread1()
{
    Lock1.WriteLock();
    Lock2.WriteLock();
    // ...
    Lock2.WriteUnlock();
    Lock1.WriteUnlock();
}

void Thread2()
{
    Lock1.WriteLock();  // 相同顺序
    Lock2.WriteLock();
    // ...
    Lock2.WriteUnlock();
    Lock1.WriteUnlock();
}
```

## 内存泄漏

### UObject 循环引用

```cpp
// 错误：UObject 之间使用原始指针导致循环引用
UCLASS()
class AActorA : public AActor
{
    UPROPERTY()
    AActorB* RefB;  // 强引用
};

UCLASS()
class AActorB : public AActor
{
    UPROPERTY()
    AActorA* RefA;  // 强引用 - 循环！
};

// 正确：一方使用弱引用
UCLASS()
class AActorB : public AActor
{
    UPROPERTY()
    TWeakObjectPtr<AActorA> RefA;  // 弱引用 - 打破循环
};
```

### 非 UObject 内存管理

```cpp
// 错误：new 不配对 delete
class FMyData
{
    static FMyData* Create()
    {
        return new FMyData();  // 没有对应的 delete
    }
};

// 正确：使用智能指针
class FMyData
{
    static TSharedPtr<FMyData> Create()
    {
        return MakeShared<FMyData>();  // 自动管理
    }
};
```

## 蓝图问题

### 元数据不完整

```cpp
// 错误：缺少中文元数据
UFUNCTION(BlueprintCallable)
static void MyFunction(FString Data);

// 正确：完整的中文元数据
UFUNCTION(BlueprintCallable, Category = "XTools|MyModule",
    meta = (
        DisplayName = "我的函数",
        Keywords = "关键词",
        ToolTip = "函数详细说明\n参数:\nData - 数据说明"
    ))
static void MyFunction(
    UPARAM(DisplayName="数据") const FString& Data);
```

### Category 格式不一致

```cpp
// 错误：格式不一致
UFUNCTION(BlueprintCallable, Category = "MyFunction")  // 缺少模块前缀
UFUNCTION(BlueprintCallable, Category = "XTools|MyFunction")  // 缺少子类别

// 正确：统一格式
UFUNCTION(BlueprintCallable, Category = "XTools|MyModule|Subcategory")
```

## 调试技巧

### 条件编译调试

```cpp
// 只在 Debug 构建启用
#if UE_BUILD_DEBUG
    UE_LOG(LogTemp, Warning, TEXT("Debug: Value = %d"), MyValue);
#endif

// 只在开发版本启用
#if !UE_BUILD_SHIPPING
    verify(MyCondition);  // 在 Shipping 中编译为空
#endif
```

### 性能追踪

```cpp
// 使用 CPU Profiler 追踪
TRACE_CPUPROFILER_EVENT_SCOPE(MyFunction);

void MyFunction()
{
    TRACE_CPUPROFILER_EVENT_SCOPE(Section1);
    // 代码 1

    TRACE_CPUPROFILER_EVENT_SCOPE(Section2);
    // 代码 2
}
```
