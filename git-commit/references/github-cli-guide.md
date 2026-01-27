# GitHub CLI 提效指南

GitHub CLI (`gh`) 可以显著提升与 GitHub 仓库交互的效率。

## 安装

- **Windows**: `winget install --id GitHub.cli`
- **macOS**: `brew install gh`
- **Linux**: 参考 https://cli.github.com/

## 认证

首次使用需要登录：
```bash
gh auth login
```

## 常用提效命令

### Pull Request 操作

创建 PR：
```bash
gh pr create --fill  # 自动从提交信息填充标题和描述
gh pr create --title "feat: 新功能" --body "详细描述"
```

查看 PR 列表：
```bash
gh pr list --state open  # 只显示开放的 PR
gh pr list --author username  # 查看特定作者的 PR
```

查看 PR 详情：
```bash
gh pr view 123
gh pr view 123 --web  # 在浏览器中打开
```

检出 PR 代码：
```bash
gh pr checkout 123  # 检出 PR #123 到本地
```

审查 PR：
```bash
gh pr diff 123  # 查看 PR 的 diff
gh pr checks 123  # 查看 CI 检查状态
```

### Issue 操作

列出 Issues：
```bash
gh issue list --state open
gh issue list --label bug  # 筛选特定标签
```

查看 Issue：
```bash
gh issue view 456
gh issue view 456 --web
```

从 Issue 创建分支：
```bash
gh issue develop 456  # 基于创建功能分支
```

### 搜索和查询

搜索 PR：
```bash
gh search prs state:open author:username
gh search prs review:required  # 需要审查的 PR
```

搜索 Issues：
```bash
gh search issues state:open label:bug
```

### CI/CD 操作

查看 Actions 运行：
```bash
gh run list
gh run view  # 查看最新运行
gh run view 123 --log  # 查看运行日志
```

重新运行失败的 workflow：
```bash
gh run rerun 123
```

### 评论和交互

添加评论：
```bash
gh pr comment 123 --body "看起来不错！"
gh issue comment 456 --body "需要更多信息"
```

批准 PR：
```bash
gh pr review 123 --approve  # 批准
gh pr review 123 --request-changes  # 请求变更
gh pr review 123 --comment -b "有问题"  # 评论但不批准
```

合并 PR：
```bash
gh pr merge 123 --squash  # squash 合并
gh pr merge 123 --merge  # 合并提交
gh pr merge 123 --delete-branch  # 合并后删除分支
```

### 仓库操作

在浏览器中打开仓库：
```bash
gh repo view --web
gh repo view owner/repo --web
```

查看仓库信息：
```bash
gh repo view
gh repo view owner/repo
```

## 实用工作流

### 完整提交流程
```bash
# 1. 提交代码
git add .
git commit -m "feat: 新功能"
git push

# 2. 创建 PR
gh pr create --fill

# 3. 查看状态
gh pr checks  # 查看 CI 状态
```

### 快速审查 PR
```bash
# 列出需要审查的 PR
gh pr list --search "review:required"

# 检出并审查
gh pr checkout 123
gh pr diff 123

# 批准
gh pr review 123 --approve
```

### 处理 Issue
```bash
# 从 Issue 创建分支并开始工作
gh issue develop 456  # 创建分支如 issue/456

# 完成后创建 PR
git push
gh pr create --fill --body "Closes #456"
```

## 配置别名（可选）

在 `~/.gitconfig` 中添加别名：
```ini
[alias]
  prs = "!gh pr list"
  pr-view = "!gh pr view"
  pr-co = "!gh pr checkout"
  issues = "!gh issue list"
  issue-view = "!gh issue view"
```

使用：
```bash
git prs
git pr-co 123
```

## 最佳实践

1. **使用 `--fill` 自动填充**: 从提交信息自动生成 PR 标题和描述
2. **批量操作**: 使用 `gh pr list` 筛选后批量处理
3. **脚本集成**: 在 CI/CD 脚本中使用 `gh` 自动化流程
4. **web 参数**: 善用 `--web` 快速在浏览器中打开复杂内容

## 更多信息

- 官方文档: https://cli.github.com/manual/
- 完整命令参考: `gh --help`
- 特定命令帮助: `gh pr --help`, `gh issue --help`
