---
argument-hint: [--no-verify] [--style=simple|full] [--type=feat|fix|docs|style|refactor|perf|test|chore|ci|build|revert]
description: 创建符合 Conventional Commits 规范的格式化提交信息
---

# Claude 命令：Commit

此命令帮助你创建符合 Conventional Commits 规范的格式化提交信息。

## Conventional Commits 格式

### 简单样式（默认）
```
<type>[可选 scope]: <description>
```
示例：`feat(auth): 添加 JWT 令牌验证`

### 完整样式
```
<type>[可选 scope]: <description>

<body>

<footer>
```

示例：
```
feat(auth): 添加 JWT 令牌验证

实现 JWT 令牌验证中间件，功能包括：
- 验证令牌签名和有效期
- 从载荷中提取用户声明
- 将用户上下文添加到请求对象
- 处理刷新令牌轮换

此变更通过确保所有受保护路由正确验证身份令牌来提高安全性。

BREAKING CHANGE: API 现在需要为所有认证端点提供 Bearer 令牌
Closes: #123
```

## 提交类型

| 类型 | 描述 | 使用场景 |
|------|-------------|-------------|
| `feat` | 新功能 | 添加新功能 |
| `fix` | 修复 Bug | 修复问题 |
| `docs` | 文档 | 仅文档变更 |
| `style` | 代码风格 | 格式化、缺少分号等 |
| `refactor` | 代码重构 | 既不修复 bug 也不添加功能 |
| `perf` | 性能优化 | 性能改进 |
| `test` | 测试 | 添加缺失的测试 |
| `chore` | 维护 | 构建过程或工具的变更 |
| `ci` | CI/CD | CI 配置的变更 |
| `build` | 构建系统 | 影响构建系统的变更 |
| `revert` | 回滚 | 回滚之前的提交 |

## 正文部分指南（完整样式）

正文应该：
- 解释**什么**改变了以及**为什么**（不是如何改变）
- 对多个变更使用项目符号
- 包含变更的动机
- 对比之前的行为
- 引用相关问题或决策
- 每行限制在 72 个字符

好的正文示例：
```
此前，应用允许未认证访问用户配置文件端点，造成安全漏洞。

此提交添加了全面的身份验证中间件，包括：
- 在所有受保护路由上验证 JWT 令牌
- 实现正确的令牌刷新逻辑
- 添加速率限制以防止暴力攻击
- 记录身份验证失败以用于监控

此变更遵循 OAuth 2.0 最佳实践并改善整体应用安全态势。
```

## 脚注部分指南（完整样式）

脚注包含：
- **破坏性变更**：以 `BREAKING CHANGE:` 开头
- **问题引用**：`Closes:`、`Fixes:`、`Refs:`
- **协作者**：`Co-authored-by: name <email>`
- **审核引用**：`Reviewed-by:`、`Approved-by:`

脚注示例：
```
BREAKING CHANGE: 将 config.auth 重命名为 config.authentication
Closes: #123, #124
Co-authored-by: Jane Doe <jane@example.com>
```

## 范围指南

范围应该是：
- 描述代码库部分的名词
- 在整个项目中保持一致
- 简短且有意义的

常见范围：
- `api`、`auth`、`ui`、`db`、`config`、`deps`
- 组件名称：`button`、`modal`、`header`
- 模块名称：`parser`、`compiler`、`validator`

## 提交拆分策略

检测到以下情况时自动建议拆分：
1. **混合类型**：功能 + 修复在同一提交中
2. **多个关注点**：不相关的变更
3. **大范围**：跨越多个模块的变更
4. **文件模式**：源代码 + 测试 + 文档在一起
5. **依赖项**：依赖更新与功能混合

## 最佳实践

### 应该做：
- 使用现在时、祈使语气（"add" 而不是 "added"）
- 第一行保持在 50 个字符以下（最多 72 个）
- 描述的首字母大写
- 主题行末尾不加句号
- 用空行分隔主题和正文
- 使用正文解释是什么和为什么，而不是如何做
- 引用问题和破坏性变更

### 不应该做：
- 在一个提交中混合多个逻辑变更
- 在主题中包含实现细节
- 使用过去时（用 "added" 而不是 "add"）
- 使提交太大无法审核
- 提交损坏的代码（除非是 WIP）
- 包含敏感信息

## 示例

### 简单样式示例
```bash
feat: 添加用户注册流程
fix: 解决事件处理器中的内存泄漏
docs: 更新 API 端点文档
refactor: 简化身份验证逻辑
perf: 优化数据库查询性能
chore: 更新构建依赖
```

### 完整样式示例
```bash
feat(auth): 实现 OAuth2 身份验证流程

添加完整的 OAuth2 身份验证系统，支持多个提供商
（Google、GitHub、Microsoft）。实现遵循 RFC 6749 规范
并包括：

- 使用 PKCE 的授权码流程
- 刷新令牌轮换
- 基于范围的权限
- 使用 Redis 的会话管理
- 每个客户端的速率限制

这为用户提供了安全的单点登录功能，同时保持与
现有 JWT 身份验证的向后兼容性。

BREAKING CHANGE: /api/auth 端点现在需要 client_id 参数
Closes: #456, #457
Refs: RFC-6749, RFC-7636
```

## 工作流程

1. 分析变更以确定提交类型和范围
2. 检查变更是否应该拆分为多个提交
3. 对于每个提交：
   - 暂存相应的文件
   - 根据样式设置生成提交信息
   - 如果是完整样式，创建详细的正文和脚注
   - 使用生成的信息执行 git commit
4. 提供已提交变更的摘要

## 重要说明

- 默认样式为 `simple`，用于快速日常提交
- 对以下情况使用 `full` 样式：
  - 破坏性变更
  - 复杂功能
  - 需要解释的错误修复
  - 影响多个系统的变更
- 工具会智能检测完整样式何时有益并建议使用
- 确认前务必查看生成的信息
- 提交前检查有助于维护代码质量

## 使用 GitHub CLI 提效

GitHub CLI (`gh`) 是一个强大的工具，可以显著提升与 GitHub 仓库交互的效率。

### 安装

- **Windows**: `winget install --id GitHub.cli`
- **macOS**: `brew install gh`
- **Linux**: 参考官方文档 https://cli.github.com/

### 认证

首次使用需要登录：
```bash
gh auth login
```

### 常用提效命令

#### 快速创建 Pull Request
提交代码后，直接创建 PR：
```bash
gh pr create --title "feat: 添加用户认证" --body "实现完整的 OAuth2 登录流程"
```

#### 查看和切换 PR
查看当前仓库的 PR 列表：
```bash
gh pr list
```

查看特定 PR 详情：
```bash
gh pr view 123
```

#### 快速检出 PR 代码
直接检出 PR 进行测试或审查：
```bash
gh pr checkout 123
```

#### 查看 Issues
列出所有 Issues：
```bash
gh issue list
```

查看特定 Issue：
```bash
gh issue view 456
```

#### 从 Issue 创建分支
基于 Issue 快速创建功能分支：
```bash
gh issue develop 456
```

#### 在代码仓库中搜索
搜索代码或 Issues：
```bash
gh search prs state:open author:username
gh search issues state:open label:bug
```

#### 查看 CI/CD 状态
查看最近的 Actions 运行状态：
```bash
gh run list
gh run view
```

#### 在浏览器中打开仓库
快速在浏览器中打开当前仓库：
```bash
gh repo view --web
```

打开特定 PR 或 Issue：
```bash
gh pr view 123 --web
gh issue view 456 --web
```

#### 添加评论
为 PR 或 Issue 添加评论：
```bash
gh pr comment 123 --body "看起来不错！"
gh issue comment 456 --body "这个问题需要更多信息"
```

#### 批量操作
合并所有已批准的 PR：
```bash
gh pr merge --approve --auto
```

### 最佳实践

1. **与 Git 工作流集成**
   ```bash
   # 完整工作流
   git add .
   git commit -m "feat: 新功能"
   git push
   gh pr create --fill  # 自动从提交信息填充 PR 标题和描述
   ```

2. **使用模板**
   ```bash
   # 使用 PR 模板
   gh pr create --template .github/PULL_REQUEST_TEMPLATE.md
   ```

3. **快速审查**
   ```bash
   # 在终端中查看 PR diff
   gh pr diff 123
   ```

4. **自动化脚本**
   ```bash
   # 查看需要审查的 PR
   gh pr list --state open --search "review:required"
   ```

### 配置别名提升效率

在 `~/.gitconfig` 中添加别名：
```ini
[alias]
  pr = "!f() { gh pr create --title \"$1\" --body \"$2\"; }; f"
  prs = "!gh pr list"
  pr-view = "!gh pr view"
  co-pr = "!gh pr checkout"
```

使用方式：
```bash
git pr "feat: 新功能" "详细描述"
git prs
```
