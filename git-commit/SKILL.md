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

### 作用域 (scope)

- **单个模块**: `XToolsCore`, `Sort`, `ObjectPool` 等
- **多个模块**: 用逗号分隔，如 `XToolsCore,XTools,Sort`
- **可省略**: 不涉及特定模块时

### 描述规范

- **简短描述**: 中文，不超过 50 字
- **详细描述**（可选）: 列表格式，每个条目以 `- 模块名: 说明` 开头

## 工作流程

### 步骤 1: 分析 Git 状态

执行 `git status` 分析待提交修改：
```bash
git status
```

识别修改的文件并推断建议的 **scope**。

### 步骤 2: 收集提交信息

从用户获取以下信息：
- **type**: 提交类型
- **scope**: 作用域（可基于步骤 1 自动推断）
- **short_desc**: 简短描述（中文）
- **details**: 详细描述（可选）

### 步骤 3: 生成提交信息

根据收集的信息生成符合规范的提交信息。

**格式化规则**:
- 如果有 **details**，使用多行格式
- 每个详细条目格式: `- 模块名: 说明`

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

## 参考资源

查看 `references/commit-examples.md` 了解项目的实际提交示例。

## 输出格式

提交完成后，显示：
```
✅ Git 提交成功！

commit <hash>
<type>(<scope>): <short_desc>
```
