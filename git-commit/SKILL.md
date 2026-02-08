---
name: git-commit 智能提交
description: 自动生成符合 Conventional Commits 规范的 git 提交信息并执行提交。当用户需要创建符合项目规范的 git 提交时使用此 Skill。支持自动分析修改文件、推断作用域、生成中文提交信息并执行 git add 和 commit 操作。支持智能分批提交多模块变更。
---

# Git 提交器 Skill

自动生成符合 Conventional Commits 规范的 git 提交信息并执行提交。

## 使用场景

在以下情况下使用此 Skill：
- 用户要求创建符合项目规范的 git 提交
- 用户要求分析 git 状态并生成提交信息
- 用户需要批量提交代码修改
- 用户需要分批提交多模块变更（自动检测）

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

**询问用户**: "检测到多种类型的变更，是否分批提交？"

- **选择分批**: 进入分批提交流程（步骤 2A），自动分析并执行多次提交
- **选择不分批**: 进入单次提交流程（步骤 2B），收集信息后执行单次提交

### 脚注规范（可选）

对于重要变更，可以在详细描述后添加脚注：

```
BREAKING CHANGE: API 接口变更说明
Closes: #123, #124
Refs: issue/456
Co-authored-by: 张三 <zhangsan@example.com>
```

## 工作流程

### 步骤 0: 检查远程同步状态（方案 A）

在分析本地状态前，先检查远程仓库是否有新提交：

```bash
# 获取远程信息（不修改本地）
git fetch origin

# 比较本地和远程 HEAD
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse @{u})
BASE=$(git merge-base HEAD @{u})

if [ "$LOCAL" != "$REMOTE" ]; then
  # 有差异，需要判断
  if [ "$LOCAL" == "$BASE" ]; then
    # 本地落后于远程
    BEHIND=$(git rev-list --count HEAD..@{u})
    echo "警告: 本地落后远程 $BEHIND 个提交"
  elif [ "$REMOTE" == "$BASE" ]; then
    # 本地领先于远程（正常情况）
    echo "本地领先远程 $(git rev-list --count @{u}..HEAD) 个提交"
  else
    # 分叉情况
    echo "警告: 本地和远程已分叉！"
  fi
fi
```

**检查输出示例**:
```bash
# 显示远程新增的提交
git log HEAD..@{u} --oneline

# 检查是否是 CI 自动提交
if git log HEAD..@{u} --grep="auto-fix\|build(deps)\|dependabot" --oneline; then
  echo "⚠️  检测到 CI 自动提交，建议先拉取"
fi
```

**询问用户决策**:
```
检测到远程有 N 个新提交（可能是 CI 自动提交或 Dependabot 更新）

最近的远程提交：
  abc1234 style: auto-fix formatting
  def5678 build(deps): update dependency

操作选择：
  [1] 先执行 git pull --rebase（推荐）
  [2] 跳过检查，直接提交
  [3] 取消操作，手动处理
```

**如果用户选择先拉取**:
```bash
git pull --rebase origin $(git branch --show-current)
# 检查是否成功
if [ $? -eq 0 ]; then
  echo "✅ 已同步远程最新提交"
  # 继续步骤 1
else
  echo "❌ 拉取失败，可能有冲突，请手动处理"
  return
fi
```

**如果用户选择跳过**:
- 继续执行步骤 1
- 提示用户可能需要在 push 时处理冲突

---

### 步骤 1: 分析 Git 状态

执行 `git status` 和 `git diff` 分析待提交修改：
```bash
git status
git diff --stat           # 查看变更统计
git diff <具体文件>       # 查看每个文件的实际变更内容
git diff --staged
```

**关键步骤：完整性检查**
- **必须查看每个修改文件的实际 diff 内容**，不要仅凭文件名判断
- **识别功能关联性**：相关文件应归为同一批次
- **排除临时文件**：`*.pdb`, `*_test.rs`, `*.log` 等调试/测试文件

识别修改的文件并推断建议的 **scope**。

**检测提交拆分需求**:
- 分析变更的文件类型和模块
- 如果检测到以下情况，进入步骤 2A（分批提交流程）：
  - 混合类型：新功能 + Bug 修复在同一提交中
  - 多个关注点：不相关的变更（如文档 + 代码修复）
  - 跨多个模块：涉及超过 3 个不同模块的复杂变更
- 否则进入步骤 2B（单次提交流程）

---

## 分批提交流程（步骤 2A）

**先询问用户**: "检测到多种类型的变更，是否分批提交？"

- 如果用户选择 **不分批** → 跳转到步骤 2B（单次提交流程）
- 如果用户选择 **分批** → 继续以下步骤

### 步骤 2A-1: 智能分析并规划批次

根据变更的文件内容和模块关系，自动规划合理的提交批次：

**分析原则**:
1. **按模块分组**: 同一模块的变更放在同一批次
2. **按变更类型分组**: feat、fix、refactor、docs 等分开
3. **按依赖关系排序**: 基础设施 → 核心功能 → 业务逻辑
4. **逻辑相关性**: 相关文件的变更放在同一批次

**示例批次规划**:
```
批次 1: refactor(LLM) - 移除 LLM 模块
批次 2: refactor(Core) - 移除 Editor Window
批次 3: feat(Serializer) - 新增伪代码序列化器
批次 4: refactor(Core) - 更新核心集成
批次 5: build - 清理依赖
批次 6: docs - 添加文档
```

### 步骤 2A-2: 展示提交计划

向用户展示提交计划列表：
```
## 📋 提交计划

检测到以下变更，建议分为 N 个提交：

[1] refactor(LLM): 移除 LLM 翻译模块
    - 45 个文件

[2] refactor(Core): 移除 Editor Window 和 Widget 组件
    - 6 个文件

[3] feat(Serializer): 新增伪代码序列化器
    - 2 个文件

是否按此计划执行？[Enter=确认 / Ctrl+C=取消]
```

### 步骤 2A-3: 执行分批提交

对每个批次执行以下操作：

```bash
# 1. 添加该批次的文件
git add <批次文件列表>

# 2. 【关键】验证暂存区完整性
git diff --cached --stat        # 检查文件数量
git diff --cached                # 检查变更内容是否完整

# 3. 如果发现遗漏，补充添加
git add <遗漏的文件>

# 4. 自动生成并执行提交
git commit -m "$(cat <<'EOF'
<type>(<scope>): <short_desc>

<自动生成的详细描述>
EOF
)"
```

**自动生成提交信息的规则**:
- **type**: 根据变更类型自动判断（删除=refactor, 新增=feat, 修改=refactor/fix）
- **scope**: 根据文件路径自动推断模块名
- **short_desc**: 简洁描述变更内容，使用祈使语气
- **details**: 列出主要变更点，每条以 `- 模块名: 说明` 开头

**如果发现遗漏**（在提交后发现）:
```bash
# 方法 1: 补充提交（推荐）
git add <遗漏的文件>
git commit -m "$(cat <<'EOF'
fix(scope): 补充提交 - 说明遗漏的内容
EOF
)"

# 方法 2: 修改上一个提交（仅限未推送）
git add <遗漏的文件>
git commit --amend --no-edit
```

### 步骤 2A-4: 显示执行结果

所有批次提交完成后，显示：
```
## ✅ 分批提交完成！

共完成 N 个提交：

### 提交历史
<commit-hash> <type>(<scope>): <short_desc>
...

### 提交统计
- 总文件数: X 个
- 新增行数: +Y 行
- 删除行数: -Z 行

```

---

## 单次提交流程（步骤 2B）

### 步骤 2B-1: 收集提交信息

从用户获取以下信息：
- **type**: 提交类型
- **scope**: 作用域（可基于步骤 1 自动推断）
- **short_desc**: 简短描述（中文，祈使语气）
- **details**: 详细描述（可选）
- **footer**: 脚注（可选，如 BREAKING CHANGE、Closes 等）

### 步骤 2B-2: 生成提交信息

根据收集的信息生成符合规范的提交信息。

**格式化规则**:
- 如果有 **details** 或 **footer**，使用多行格式
- 每个详细条目格式: `- 模块名: 说明`
- 脚注格式: `BREAKING CHANGE:`、`Closes:`、`Refs:` 等

### 步骤 2B-3: 执行提交

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

### 单次提交输出

提交完成后，显示：
```
✅ Git 提交成功！

commit <hash>
<type>(<scope>): <short_desc>

```

### 分批提交输出

所有批次完成后，显示：
```
## ✅ 分批提交完成！

共完成 N 个提交：

### 提交历史
<commit-hash> <type>(<scope>): <short_desc>
<commit-hash> <type>(<scope>): <short_desc>
...

### 提交统计
- 总提交数: N 个
- 总文件数: X 个
- 新增行数: +Y 行
- 删除行数: -Z 行

```

## 常见遗漏点

在分批提交时，以下文件容易被遗漏，需要特别检查：

### 功能关联性检查清单

| 功能模块 | 容易遗漏的文件 | 检查方法 |
|---------|--------------|---------|
| **新增 Tauri 命令** | `main.rs`（命令注册） | 查找 `invoke_handler` 中的新增命令 |
| **修改 Rust 结构体** | `mod.rs`（模块导出） | 检查是否需要 `pub use` |
| **修改前端类型** | 同名 `.test.ts` / `.spec.ts` | 查找测试文件 |
| **修改 API 接口** | API 文档、类型定义 | 检查 docs/ 和 types/ 目录 |
| **修改配置** | 配置文件的示例文件 | 如 `config.example.json` |

### 防遗漏检查流程

```bash
# 1. 提交前验证暂存区
git diff --cached --name-only    # 列出暂存的文件
git diff --cached                # 查看暂存的变更内容

# 2. 检查是否有相关文件未添加
git status                       # 查看未暂存的修改

# 3. 使用 grep 搜索相关文件
# 例如：新增了 translator.rs 中的命令，检查 main.rs
git diff src-tauri/src/main.rs | grep -i "cancel"

# 4. 提交后再次检查
git status                       # 确认工作区干净
```

### 典型遗漏案例

**案例 1**: 新增翻译任务取消功能
- ✅ 已提交: `translation_task.rs`, `translator.rs`
- ❌ 遗漏: `main.rs`（注册 `cancel_translation` 命令）
- **原因**: 未查看 `main.rs` 的实际 diff 内容

**案例 2**: 修改 Rust 结构体字段
- ✅ 已提交: `services/config.rs`
- ❌ 遗漏: `commands/config_cmd.rs`（使用该结构体）
- **原因**: 未检查结构体的使用位置

**案例 3**: 更新前端类型定义
- ✅ 已提交: `types/api.ts`
- ❌ 遗漏: `types/api.test.ts`
- **原因**: 未搜索同名测试文件

---

## 最佳实践提醒

在执行过程中，主动提醒用户：
1. **检查变更范围**: 是否包含不相关的改动需要拆分
2. **分批提交优势**:
   - 更清晰的变更历史
   - 更容易代码审查
   - 更简单的回滚操作
   - 更好的语义化版本控制
3. **使用祈使语气**: "添加功能"而不是"添加了功能"
4. **引用问题**: 如果修复了 issue，在脚注中添加 `Closes: #123`
5. **破坏性变更**: 使用 `BREAKING CHANGE:` 标注

### CI 自动提交场景（重要）

当项目使用 CI 自动格式化或 Dependabot 时：

**典型场景**:
- 每次 push 触发 CI 自动格式化（Prettier/cargo fmt）
- Dependabot 自动更新依赖
- 多设备/多人协作

**风险提示**:
```
时间线示例：
  T1: 本地开发基于 commit A
  T2: 本地 push → CI 自动格式化 → 创建 commit B
  T3: 本地继续开发（仍基于 A）
  T4: 尝试 push → ❌ rejected! 需要先拉取 B
```

**推荐工作流**:
```bash
# 提交前检查
git fetch origin
git log HEAD..@{u} --oneline  # 查看远程新提交

# 如果有 CI 提交，先拉取
git pull --rebase

# 然后正常提交和推送
git add .
git commit -m "..."
git push
```

**检测 CI 提交的命令**:
```bash
# 检测常见的 CI 提交模式
git log HEAD..@{u} --grep="auto-fix\|build(deps)\|dependabot\|style:" --oneline
```

## 参考资源

- `references/commit-examples.md` - 项目的实际提交示例
- `references/github-cli-guide.md` - GitHub CLI 完整使用指南
