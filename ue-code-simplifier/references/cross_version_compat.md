# UE 跨版本兼容性指南

## 版本宏定义模式

在插件中定义自己的版本宏，方便条件编译：

```cpp
// 在 MyPluginVersionCompat.h 中定义
#define MYPLUGIN_ENGINE_5_3_OR_LATER \
    (ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 3)

#define MYPLUGIN_ENGINE_5_4_OR_LATER \
    (ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 4)

#define MYPLUGIN_ENGINE_5_5_OR_LATER \
    (ENGINE_MAJOR_VERSION == 5 && ENGINE_MINOR_VERSION >= 5)
```

## 常见 API 变更处理

### FProperty::ElementSize (UE 5.5+ 弃用)

```cpp
// UE 5.3-5.4：直接字段访问
const int32 ElementSize = Property->ElementSize;

// UE 5.5+：改为 getter
const int32 ElementSize = Property->GetElementSize();

// 跨版本兼容写法
#if MYPLUGIN_ENGINE_5_5_OR_LATER
    const int32 ElementSize = Property->GetElementSize();
#else
    const int32 ElementSize = Property->ElementSize;
#endif
```

也可以封装成宏简化使用：
```cpp
#if MYPLUGIN_ENGINE_5_5_OR_LATER
    #define MYPLUGIN_GET_ELEMENT_SIZE(Prop) (Prop)->GetElementSize()
#else
    #define MYPLUGIN_GET_ELEMENT_SIZE(Prop) (Prop)->ElementSize
#endif
```

### FCompression::GetMaximumCompressedSize (UE 5.4+)

```cpp
// UE 5.3
int32 MaxSize = FCompression::GetMaximumCompressedSize(
    UncompressedSize, NAME_Zlib, ECompressionFlags::None);

// UE 5.4+：新增参数
int32 MaxSize = FCompression::GetMaximumCompressedSize(
    UncompressedSize, NAME_Zlib, ECompressionFlags::None, nullptr);
```

## 原子操作

### TAtomic API 差异

```cpp
// 直接赋值/读取在不同 UE 版本中行为可能不一致
// 推荐：封装原子操作函数
template<typename T>
void AtomicStore(TAtomic<T>& Atomic, T Value)
{
    Atomic.Store(Value);
}

template<typename T>
T AtomicLoad(const TAtomic<T>& Atomic)
{
    return Atomic.Load();
}
```

## 编译器差异

| UE 版本 | 推荐 VS 版本 |
|---------|-------------|
| UE 5.3 | VS 2019 |
| UE 5.4+ | VS 2022 |

## 跨版本兼容最佳实践

1. **版本宏集中管理**：所有版本检测宏放在一个头文件中
2. **兼容层封装**：对变更 API 封装统一接口，而非散落 `#if` 到处
3. **Build.cs 中声明依赖**：兼容层模块需要在 `PublicDependencyModuleNames` 中声明
4. **多版本 CI**：配置编译矩阵测试所有目标 UE 版本

```yaml
strategy:
  matrix:
    ue_version: [5.3, 5.4, 5.5]
```

## 调试技巧

```cpp
// 运行时检查 UE 版本
UE_LOG(LogMyPlugin, Display, TEXT("UE Version: %d.%d"),
    ENGINE_MAJOR_VERSION, ENGINE_MINOR_VERSION);
```
