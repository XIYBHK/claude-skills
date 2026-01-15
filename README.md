# Claude Skills

个人 Claude Code 技能集合，用于扩展 Claude 的开发能力。

## 包含的 Skills

### [ue-code-simplifier](./ue-code-simplifier/)
UE C++ 代码简化优化器，用于优化、重构 Unreal Engine C++ 插件代码。

- 遵循 Epic Games 编码标准
- 支持 UE 5.3-5.7 跨版本兼容
- 代码安全性和性能优化
- 完整的中文文档支持

### [git-commit](./git-commit/)
Git 提交信息生成器，自动生成符合 Conventional Commits 规范的提交信息。

- 遵循项目提交格式规范
- 中文描述支持
- 自动分析修改文件并推断作用域

### [changelog-generator](./changelog-generator/)
变更日志生成器（内置 skill）。

### [web-artifacts-builder](./web-artifacts-builder/)
Web 组件构建器（内置 skill）。

### [skill-creator](./skill-creator/)
Skill 创建工具，用于创建新的 Claude Skills。

## 安装方法

### 方式 1: 手动安装

将 skill 目录复制到 Claude Code 的 skills 目录：

```
# Windows
C:\Users\<用户名>\.claude\skills\

# macOS
~/.claude/skills/
```

### 方式 2: Git Clone

```bash
cd C:\Users\<用户名>\.claude
git clone https://github.com/XIYBHK/claude-skills.git skills
```

## 更新方法

```bash
cd C:\Users\<用户名>\.claude\skills
git pull
```

## 使用方法

在 Claude Code 中，skills 会在相应场景下自动触发。例如：

- 编写 UE C++ 代码时，`ue-code-simplifier` 会自动优化代码
- 提交 git 时，使用 `git-commit` 生成规范的提交信息
- 创建新 skill 时，使用 `skill-creator` 初始化模板

## 项目规范

### Git 提交格式

遵循 Conventional Commits 规范，使用中文描述：

```
<type>(<scope>): <简短描述>

<详细描述（可选）>
```

**类型 (type)**:
- `feat`: 新功能
- `fix`: Bug 修复
- `refactor`: 代码重构/优化
- `docs`: 文档更新
- `chore`: 构建/工具相关

## 许可证

MIT License

## 作者

XIYBHK

---

**注意**: 此仓库为个人自用，Skills 针对特定项目环境定制。
