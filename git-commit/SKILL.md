---
name: git-commit 智能提交
description: 自动生成符合 Conventional Commits 规范的 git 提交信息并执行提交。当用户需要创建符合项目规范的 git 提交时使用此 Skill。支持自动分析修改文件、推断作用域、生成中文提交信息并执行 git add 和 commit 操作。
---

# Git 提交器 Skill

自动生成符合 Conventional Commits 规范的 git 提交信息并执行提交。

## 使用场景

在以下情况下使用此 Skill：
- 用户要求创建符合项目规范的 git 提交
- 用户要求分析 git 状态并生成提交信息
- 用户需要批量提交代码修改

## 提交格式规范

遵循 Conventional Commits 规范，使用中文描述：

```
<type>(<scope>): <简短描述>

<详细描述（可选）>
```

### 类型 (type)

| 类型 | 说明 | 示例 |
|------|------|------|
| `feat` | 新功能 | feat(ObjectPool): 新增对象池统计命令 |
| `fix` | Bug 修复 | fix(Sort): 修复数组越界问题 |
| `refactor` | 代码重构/优化（不改变功能） | refactor(XToolsCore): 优化原子操作实现 |
| `docs` | 文档更新 | docs: 更新 README 使用说明 |
| `chore` | 构建/工具相关 | chore: 更新 CI 配置 |
| `style` | 代码风格（不影响功能） | style: 统一代码缩进 |
| `perf` | 性能优化 | perf(Sort): 优化排序算法性能 |
| `test` | 测试相关 | test: 添加单元测试 |
| `ci` | CI/CD 配置 | ci: 优化 GitHub Actions 工作流 |
| `build` | 构建系统 | build: 更新构建脚本 |
| `revert` | 回滚提交 | revert: 回滚 commit abc123 |

### 作用域 (scope)

- **单个模块**: `XToolsCore`, `Sort`, `ObjectPool` 等
- **多个模块**: 用逗号分隔，如 `XToolsCore,XTools,Sort`
- **可省略**: 不涉及特定模块时

### 描述规范

- **简短描述**: 中文，不超过 50 字，使用祈使语气（"添加"而不是"添加了"）
- **详细描述**（可选）: 列表格式，每个条目以 `- 模块名: 说明` 开头

### 提交拆分策略

检测到以下情况时应建议用户拆分提交：
- **混合类型**: 新功能 + Bug 修复在同一提交中
- **多个关注点**: 不相关的变更（如文档 + 代码修复）
- **跨多个模块**: 涉及超过 3 个不同模块的复杂变更

**询问用户**: "检测到多种类型的变更，是否拆分为多个提交？"

### 脚注规范（可选）

对于重要变更，可以在详细描述后添加脚注：

```
BREAKING CHANGE: API 接口变更说明
Closes: #123, #124
Refs: issue/456
Co-authored-by: 张三 <zhangsan@example.com>
```

## 工作流程

### 步骤 1: 分析 Git 状态

执行 `git status` 分析待提交修改：
```bash
git status
```

识别修改的文件并推断建议的 **scope**。

**检测提交拆分需求**:
- 分析变更的文件类型和模块
- 如果检测到多种不相关的变更，询问用户是否拆分

### 步骤 2: 收集提交信息

从用户获取以下信息：
- **type**: 提交类型
- **scope**: 作用域（可基于步骤 1 自动推断）
- **short_desc**: 简短描述（中文，祈使语气）
- **details**: 详细描述（可选）
- **footer**: 脚注（可选，如 BREAKING CHANGE、Closes 等）

### 步骤 3: 生成提交信息

根据收集的信息生成符合规范的提交信息。

**格式化规则**:
- 如果有 **details** 或 **footer**，使用多行格式
- 每个详细条目格式: `- 模块名: 说明`
- 脚注格式: `BREAKING CHANGE:`、`Closes:`、`Refs:` 等

### 步骤 4: 执行提交

```bash
# 添加文件
git add <files>

# 提交（使用 HEREDOC 支持多行）
git commit -m "$(cat <<'EOF'
<type>(<scope>): <short_desc>

<details>
EOF
)"
```

**跨平台兼容性**:
- **Windows (PowerShell)**: 使用上述 HEREDOC 格式
- **Linux/Mac (bash)**: 同样使用 HEREDOC 格式

## 输出格式

提交完成后，显示：
```
✅ Git 提交成功！

commit <hash>
<type>(<scope>): <short_desc>

💡 提示：可以使用 GitHub CLI 提升效率
  - 快速创建 PR: gh pr create --fill
  - 查看状态: gh pr checks
  - 更多命令: 见 references/github-cli-guide.md
```

## 最佳实践提醒

在执行过程中，主动提醒用户：
1. **检查变更范围**: 是否包含不相关的改动需要拆分
2. **使用祈使语气**: "添加功能"而不是"添加了功能"
3. **引用问题**: 如果修复了 issue，在脚注中添加 `Closes: #123`
4. **破坏性变更**: 使用 `BREAKING CHANGE:` 标注

## 参考资源

- `references/commit-examples.md` - 项目的实际提交示例
- `references/github-cli-guide.md` - GitHub CLI 完整使用指南
