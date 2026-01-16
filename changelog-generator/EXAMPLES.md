# 更新日志生成器 - 格式示例

本文档包含 CHANGELOG.md 和 UNRELEASED.md 的格式要求和完整示例。

## UNRELEASED.md 格式

### 基本结构
```markdown
# 待发布更新 (UNRELEASED)

> 此文档记录尚未发布的功能更新、修复和移除，用于下次版本发布时的描述参考。
> 发布新版本时，将此文件内容合并到 CHANGELOG.md，然后清空此文件（保留说明部分）。

---

## 模块名

- **类型** 描述
- **类型** 描述

---

## 📋 日志格式说明
[保留说明部分]
---
```

### 完整示例
```markdown
# 待发布更新 (UNRELEASED)

> 此文档记录尚未发布的功能更新、修复和移除，用于下次版本发布时的描述参考。
> 发布新版本时，将此文件内容合并到 CHANGELOG.md，然后清空此文件（保留说明部分）。

---

## PointSampling

- **新增** 自定义点阵生成函数
- **修复** 泊松采样网格索引Bug
- **优化** 矩形采样算法

## ObjectPool

- **新增** 对象池统计命令
- **优化** 代码结构

## CI/CD

- **修复** GitHub Actions工作流错误

---

## 📋 日志格式说明
...
```

---

## CHANGELOG.md 格式

### 版本章节结构
```markdown
## 版本 v{版本号} ({YYYY-MM-DD})

<details>
<summary><strong>主要更新</strong></summary>

### 新增功能
- **模块**: 功能描述
- **模块**: 功能描述

### 重要修复
- **模块**: 问题描述
- **模块**: 问题描述

### 性能优化
- **模块**: 优化描述
- **模块**: 优化描述

</details>

<details>
<summary><strong>模块名</strong></summary>

- **类型** 描述
- **类型** 描述

</details>

---
```

### 完整示例
```markdown
## 版本 v1.9.5 (2026-01-16)

<details>
<summary><strong>主要更新</strong></summary>

### 新增功能
- **PointSampling**: 自定义点阵生成函数
- **ObjectPool**: 对象池统计命令

### 重要修复
- **PointSampling**: 泊松采样网格索引Bug
- **CI/CD**: GitHub Actions工作流错误

### 性能优化
- **PointSampling**: 矩形采样算法
- **ObjectPool**: 代码结构优化

</details>

<details>
<summary><strong>PointSampling</strong></summary>

- **新增** 自定义点阵生成函数
- **修复** 泊松采样网格索引Bug
- **优化** 矩形采样算法

</details>

<details>
<summary><strong>ObjectPool</strong></summary>

- **新增** 对象池统计命令
- **优化** 代码结构

</details>

<details>
<summary><strong>CI/CD</strong></summary>

- **修复** GitHub Actions工作流错误

</details>

---
```

---

## 版本号更新位置

### XToolsDefines.h
```cpp
// Source/XToolsCore/Public/XToolsDefines.h

#define XTOOLS_VERSION_MAJOR 1
#define XTOOLS_VERSION_MINOR 9
#define XTOOLS_VERSION_PATCH 5  // 更新 PATCH 版本号
```

### XTools.uplugin
```json
// XTools.uplugin

{
    "FileVersion": 3,
    "Version": 2,  // 更新整数部分（每次发布递增）
    ...
}
```

---

## Git 提交信息

### 提交信息格式
```
docs: 更新 CHANGELOG.md v{版本号}
```

### 提交文件
- `Docs/版本变更/CHANGELOG.md`
- `Docs/版本变更/UNRELEASED.md`
- `Source/XToolsCore/Public/XToolsDefines.h`
- `XTools.uplugin`

### 完整命令示例
```bash
# 1. 添加修改的文件
git add "Docs/版本变更/CHANGELOG.md" \
        "Docs/版本变更/UNRELEASED.md" \
        "Source/XToolsCore/Public/XToolsDefines.h" \
        "XTools.uplugin"

# 2. 创建提交
git commit -m "docs: 更新 CHANGELOG.md v1.9.5"

# 3. 推送到远程仓库
git push origin main
```

---

## 使用示例

### 第一阶段：整理更新
```bash
# 命令
git status --porcelain
git diff --name-only

# 输出示例
检测到以下变更：
- Source/PointSampling/Private/PoissonSampling.cpp: 新增函数 GenerateCustomPattern()
- Source/ObjectPool/Public/ObjectPoolSubsystem.h: 新增 GetAllPoolStats() 接口
- Source/Sort/Private/SortLibrary.cpp: 修复排序算法边界条件Bug

生成更新记录：
## PointSampling
- **新增** 自定义点阵生成函数

## ObjectPool
- **新增** GetAllPoolStats统计接口

## Sort
- **修复** 排序算法边界Bug

已追加到 UNRELEASED.md
```

### 第二阶段：推送版本
```bash
# 命令
推送版本 v1.9.5

# 输出示例
整理 UNRELEASED.md 内容为 CHANGELOG.md 格式：
- 3 个模块变更
- 8 条更新记录

更新版本号：
- XToolsDefines.h: 1.9.4 → 1.9.5
- XTools.uplugin: 1 → 2

提交并推送：
- 提交信息：docs: 更新 CHANGELOG.md v1.9.5
- 推送到 origin/main

已成功：
- 更新 CHANGELOG.md
- 清空 UNRELEASED.md
- 更新版本号至 v1.9.5
- 提交并推送到远程仓库
```

---

## 错误处理示例

### UNRELEASED.md 为空
```
错误：UNRELEASED.md 中没有待发布内容
解决：请先运行"整理更新"或手动添加变更记录
```

### 版本号格式错误
```
错误：版本号格式不正确
正确格式：v1.9.5 (MAJOR.MINOR.PATCH)
示例：推送版本 v1.9.5
```

### Git 提交失败
```
错误：Git 提交失败 - 远程分支有新提交
解决：请先拉取远程更新，解决冲突后重试
回滚：已恢复文件到修改前状态
```
