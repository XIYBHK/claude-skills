---
name: changelog-generator 更新日志管理
description: 自动管理更新日志：整理变更到 UNRELEASED.md，推送版本到 CHANGELOG.md 并更新版本号。当用户需要管理项目更新日志或发布版本时使用此 skill。
---

# 更新日志生成器（两阶段式）

这个 skill 提供两阶段式更新日志管理流程，自动化版本发布。

## 第一阶段：整理更新

**触发关键词**：
- "整理更新"
- "归档更新内容"

**核心流程**：
1. 检测文件修改状态（`git status`）
2. 分析变更类型和所属模块
3. 生成简洁描述（20字内，动词+对象+效果）
4. 按模块分类并追加到 UNRELEASED.md

**详细规则**：见 [REFERENCE.md](./REFERENCE.md) - 模块识别规则和类型推断逻辑

---

## 第二阶段：推送版本

**触发关键词**：
- "推送版本 v x.x.x"
- "版本更新 v x.x.x"

**核心流程**：
1. 读取 UNRELEASED.md 内容
2. 按 CHANGELOG.md 格式整理内容
3. 在 CHANGELOG.md 顶部插入新版本章节
4. 清空 UNRELEASED.md（保留说明部分）
5. 更新版本号（**7个文件必须全部同步更新**）
6. 提交 git 并推送到远程仓库

**格式要求**：见 [EXAMPLES.md](./EXAMPLES.md) - CHANGELOG.md 格式和示例

---

## 使用建议

1. **开发阶段**：代码修改完成后运行"整理更新"
2. **发布前**：手动检查 UNRELEASED.md 内容是否完整
3. **发布时**：运行"推送版本 v{x.y.z}"自动化完成所有流程
4. **版本号规划**：遵循语义化版本规范（MAJOR.MINOR.PATCH）
