# Shipping / 发布就绪检查

> 来源：FAB 技术规范 + Epic 官方 + 实战经验

## FAB/Marketplace 提交就绪度

| 检查项 | 要求 |
|--------|------|
| 编译 | Editor + Game + Shipping 三构型 0 错误 |
| 外部依赖 | 全部打包，不要求用户额外下载 |
| 平台声明 | `.uplugin` 中明确 SupportedTargetPlatforms |
| 版本号 | 语义化版本（1.0.0） |
| 演示 | 至少一个测试 Map |
| 路径 | 全部使用 `FPaths::` API，无硬编码 |
| 第三方代码 | 许可证合规 |

---

## 跨平台编译

**禁止：**
```cpp
#include <windows.h>        // [BAD] 平台特定
FString P = TEXT("C:\\.."); // [BAD] 硬编码路径
std::ifstream File(...);    // [BAD] STL 文件 I/O
```

**使用：**
```cpp
FPlatformProcess::GetDllHandle(...)  // DLL 加载
FPaths::ProjectConfigDir()           // 路径
IFileManager::Get()                  // 文件操作
#if PLATFORM_WINDOWS / PLATFORM_LINUX / PLATFORM_MAC  // 条件编译
```

---

## 模块加载阶段

> 来源：Epic 官方 `ELoadingPhase::Type`, imzlp FModuleManager 分析

| 阶段 | 时机 | 用途 |
|------|------|------|
| `PostConfigInit` | 配置系统完成后 | Runtime 核心模块（最早） |
| `PreDefault` | 默认加载前 | 需要在大多数模块前初始化 |
| `Default` | 默认 | 普通 Runtime 模块 |
| `PostDefault` | 默认加载后 | 依赖其他模块的 Runtime |
| `PostEngineInit` | 引擎完全初始化后 | **Editor 模块必须用这个** |

- [BAD] Editor 模块用 `Default` 加载阶段 → `PostEngineInit`
- `.uplugin` 中 `LoadingPhase` 必须与模块用途匹配

---

## 模块架构

| 目录 | 内容 |
|------|------|
| `Public/` | 头文件：其他模块可见的接口 |
| `Private/` | 实现 + 内部头文件 |

```csharp
PublicDependencyModuleNames  // 头文件中 #include 的模块
PrivateDependencyModuleNames // 仅 .cpp 中使用的模块
```

**Runtime 模块禁止依赖 Editor 模块。** 用 `#if WITH_EDITOR` 保护。

---

## Hot Reload / Live Coding 陷阱

> 来源：northstarhana.com, SubsystemBrowserPlugin issue #14

- **Subsystem 会在 Hot Reload 时重建** — 不要在其他地方缓存 Subsystem 指针
- **static/全局变量持有引擎指针** — Hot Reload 后变成悬空指针
- **类替换（Reinstancing）会孤立实例** — 监听 `FWorldDelegates::OnWorldCleanup`
- **IDetailCustomization 需要刷新** — Hot Reload 后调用 `NotifyCustomizationModuleChanged()`

---

## 软引用避免加载链

> 来源：unreal-engine-cpp-pro skill, Tom Looman Cast 章节

```cpp
// [BAD] 硬引用（加载此蓝图时强制加载引用的所有资产）
UPROPERTY(EditDefaultsOnly)
TSubclassOf<AWeapon> WeaponClass;

// [OK] 软引用（按需加载）
UPROPERTY(EditDefaultsOnly)
TSoftClassPtr<AWeapon> WeaponClass;
```

- [BAD] UPROPERTY 硬引用大型资产 → 改用 `TSoftObjectPtr<T>`
- [BAD] TSubclassOf 引用复杂蓝图类 → 改用 `TSoftClassPtr<T>`

---

## Include 排序

> 来源：Ben UI 2024 Coding Standards

```cpp
// [OK] 按字母序排列（减少 merge conflict）
#include "MyClass.h"
#include "Components/HealthComponent.h"
#include "GameFramework/Character.h"
#include "MyClass.generated.h" // 始终最后
```

---

## 粒子系统选型

UE5 中 Cascade（`UParticleSystemComponent`）已被 Niagara（`UNiagaraComponent`）取代。Marketplace 新提交的插件应优先使用 Niagara。

```cpp
// [BAD] 已弃用的 Cascade 粒子系统
UPROPERTY()
TObjectPtr<UParticleSystemComponent> RainEffect;

// [OK] UE5 推荐的 Niagara 系统
UPROPERTY()
TObjectPtr<UNiagaraComponent> RainEffect;
```

- Marketplace 审核不会因 Cascade 直接拒绝，但使用 Niagara 是最佳实践
- 如需同时支持旧项目，可提供 Cascade 和 Niagara 两套实现
- Niagara 需要在 Build.cs 中添加 `"Niagara"` 模块依赖

---

## 序列化/版本化

```cpp
enum class EMyPluginVersion : int32 {
    Initial = 0,
    AddedNewField = 1,
    LatestPlusOne,
    Latest = LatestPlusOne - 1
};

void Serialize(FArchive& Ar) {
    Ar.UsingCustomVersion(MyPluginGUID);
    const int32 Ver = Ar.CustomVer(MyPluginGUID);
    Ar << BaseData;
    if (Ver >= (int32)EMyPluginVersion::AddedNewField) {
        Ar << NewField;
    }
}
```
