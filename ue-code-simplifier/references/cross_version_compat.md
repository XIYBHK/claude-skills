# UE 5.3-5.7 跨版本兼容性指南

## 版本宏定义

```cpp
// 在 XToolsVersionCompat.h 中定义
#define XTOOLS_ENGINE_5_3_OR_LATER \
    (ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 3)

#define XTOOLS_ENGINE_5_4_OR_LATER \
    (ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 4)

#define XTOOLS_ENGINE_5_5_OR_LATER \
    (ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 5)
```

## API 变更处理

### FProperty::ElementSize (UE 5.5+ 弃用)

```cpp
// 旧代码（UE 5.3-5.4）
const int32 ElementSize = Property->ElementSize;

// 新代码（UE 5.5+）
const int32 ElementSize = Property->GetElementSize();

// 跨版本兼容
const int32 ElementSize = XTOOLS_GET_ELEMENT_SIZE(Property);
```

### BufferCommand (UE 5.5+ 弃用)

```cpp
// 旧代码（UE 5.3-5.4）
BufferCommand<Property>(Property, Dest, Src);

// 新代码（UE 5.5+）
BufferFieldCommand_Internal<Property>(Property, Dest, Src);

// 跨版本兼容
#if XTOOLS_ENGINE_5_5_OR_LATER
    BufferFieldCommand_Internal<Property>(Property, Dest, Src);
#else
    BufferCommand<Property>(Property, Dest, Src);
#endif
```

### FCompression::GetMaximumCompressedSize (UE 5.4+)

```cpp
// UE 5.3
int32 MaxSize = FCompression::GetMaximumCompressedSize(
    UncompressedSize,
    NAME_Zlib,
    ECompressionFlags::None);

// UE 5.4+
int32 MaxSize = FCompression::GetMaximumCompressedSize(
    UncompressedSize,
    NAME_Zlib,
    ECompressionFlags::None,
    nullptr);  // 新增参数
```

## 原子操作

### TAtomic API 差异

```cpp
// UE 5.3+: 直接操作支持
TAtomic<int32> Counter;
Counter = 10;           // 直接赋值
int32 Value = Counter;  // 直接读取

// 跨版本兼容函数
XToolsVersionCompat::AtomicStore(Counter, 10);
int32 Value = XToolsVersionCompat::AtomicLoad(Counter);
int32 OldValue = XToolsVersionCompat::AtomicExchange(Counter, 5);
bool Success = XToolsVersionCompat::AtomicCompareExchange(Counter, Expected, Desired);
```

## 编译器差异

### Visual Studio 版本

| UE 版本 | VS 版本 |
|---------|---------|
| UE 5.3 | VS 2019 |
| UE 5.4+ | VS 2022 |

### 条件编译

```cpp
#if _MSC_VER >= 1930  // VS 2022
    // VS 2022 特定代码
#elif _MSC_VER >= 1920  // VS 2019
    // VS 2019 特定代码
#endif
```

## 模块依赖

### XToolsCore 依赖

所有 Runtime 模块应在 `.Build.cs` 中声明：

```csharp
PublicDependencyModuleNames.AddRange(new string[] {
    "Core",
    "CoreUObject",
    "Engine",
    "XToolsCore"  // 添加跨版本兼容层
});
```

### 检查模块依赖

```cpp
// 在需要跨版本兼容的代码中
#include "XToolsVersionCompat.h"

// 使用版本宏
#if XTOOLS_ENGINE_5_5_OR_LATER
    // UE 5.5+ 特定代码
#else
    // UE 5.3-5.4 兼容代码
#endif
```

## 常见兼容性问题

### 问题 1：GetElementSize 未定义

```cpp
// 错误：在 UE 5.3-5.4 使用 GetElementSize
const int32 Size = Property->GetElementSize();

// 正确：使用跨版本宏
const int32 Size = XTOOLS_GET_ELEMENT_SIZE(Property);
```

### 问题 2：原子操作非原子

```cpp
// 错误：非原子操作
TAtomic<int32> Counter;
int32 Old = Counter;  // 非原子
Counter = 10;

// 正确：使用原子函数
XToolsVersionCompat::AtomicStore(Counter, 10);
int32 Old = XToolsVersionCompat::AtomicExchange(Counter, 5);
```

### 问题 3：模板参数变更

```cpp
// UE 5.3-5.4
template<typename T>
void MyFunction(T& Value);

// UE 5.5+ 模板参数变更
template<typename T>
void MyFunction(T&& Value);  // 转发引用

// 跨版本解决方案：条件编译或函数重载
```

## 测试建议

### 多版本测试

1. 在 UE 5.3 环境编译测试
2. 在 UE 5.4 环境编译测试
3. 在 UE 5.5+ 环境编译测试

### CI 配置

```yaml
# 多版本编译矩阵
strategy:
  matrix:
    ue_version: [5.3, 5.4, 5.5]
```

## 调试技巧

### 版本检查

```cpp
// 在运行时检查 UE 版本
UE_LOG(LogTemp, Warning, TEXT("UE Version: %d.%d"),
    ENGINE_MAJOR_VERSION, ENGINE_MINOR_VERSION);

// 检查宏
#if XTOOLS_ENGINE_5_5_OR_LATER
    UE_LOG(LogTemp, Warning, TEXT("Running on UE 5.5+"));
#endif
```

### 条件断点

```cpp
// 只在特定版本触发断点
#if XTOOLS_ENGINE_5_4_OR_LATER
    // UE 5.4+ 特定断点
    check(false && "Debug UE 5.4+ code path");
#endif
```
