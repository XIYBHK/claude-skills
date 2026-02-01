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
1. 【验证】读取完整的 UNRELEASED.md 内容，检查是否有待发布内容
2. 【整理】按 CHANGELOG.md 格式整理内容（按模块分组）
3. 【更新】在 CHANGELOG.md 顶部插入新版本章节
4. 【清空】清空 UNRELEASED.md 待发布内容（保留说明部分）
5. 【版本号】自动检测并更新所有版本号文件：
   - `XTools.uplugin` - 插件版本号
   - `Source/XToolsCore/Public/XToolsDefines.h` - 版本宏定义
   - `CLAUDE.md` - 文档中的版本号
   - `README.md` - Badge 版本号
   - 其他包含版本号的文件（自动检测）
6. 【提交】提交版本更新到 git
7. 【Tag】创建 annotated tag（`git tag -a v{x.y.z} -m "Release version {x.y.z}"`）
8. 【推送】推送 commits 和 tags 到远程仓库

**验证检查**：
- UNRELEASED.md 中是否有内容（如无内容则警告退出）
- CHANGELOG.md 格式是否正确
- 版本号文件是否全部更新

**格式要求**：见 [EXAMPLES.md](./EXAMPLES.md) - CHANGELOG.md 格式和示例

---

## 使用建议

1. **开发阶段**：代码修改完成后运行"整理更新"
2. **发布前**：手动检查 UNRELEASED.md 内容是否完整
3. **发布时**：运行"推送版本 v{x.y.z}"自动化完成所有流程
4. **版本号规划**：遵循语义化版本规范（MAJOR.MINOR.PATCH）

---

## 重要注意事项

### UNRELEASED.md 内容完整性
推送版本时会读取**完整的** UNRELEASED.md 内容，包括之前"整理更新"添加的所有内容。确保：
- 所有需要发布的模块都已添加到 UNRELEASED.md
- 检查是否有遗漏的更新内容
- 确认描述格式正确（20字内，动词+对象+效果）

### Tag 推送的重要性
CI/CD 工作流通常由 tag 触发，确保：
- Tag 格式正确：`v{major}.{minor}.{patch}`（如 `v1.9.5`）
- Tag 是 annotated tag（带注释），不是 lightweight tag
- Tag 必须推送到远程仓库（`git push origin v{x.y.z}`）

### 版本号文件检测
系统会自动检测包含版本号的文件，通常包括：
- `XTools.uplugin` - `VersionName` 字段
- `Source/XToolsCore/Public/XToolsDefines.h` - 版本宏定义
- `CLAUDE.md` - 文档描述中的版本号
- `README.md` - Badge 中的版本号
- `CHANGELOG.md` - 更新历史中的版本号

如果检测到其他包含旧版本号的文件，也会一并更新。

---

## 常见问题

### Q: 推送版本时提示没有待发布内容？
A: 检查 UNRELEASED.md 是否有内容，如果没有，说明"整理更新"没有执行或内容已被清空。

### Q: CI 工作流没有触发？
A: 确认 tag 是否正确推送到远程仓库，检查 tag 格式是否符合 CI 配置。

### Q: 版本号文件没有全部更新？
A: 系统会自动检测常见位置，如果某些文件没有被检测到，需要手动更新。

---

1. **开发阶段**：代码修改完成后运行"整理更新"
2. **发布前**：手动检查 UNRELEASED.md 内容是否完整
3. **发布时**：运行"推送版本 v{x.y.z}"自动化完成所有流程
4. **版本号规划**：遵循语义化版本规范（MAJOR.MINOR.PATCH）
