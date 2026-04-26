# dev-loop Skill Implementation Plan

> **历史归档（非当前 SSoT）**
>
> 本文件是 v0.1 初始实施计划，保留旧代码片段和旧假设。
> 当前 v0.1.6 实现以 `scripts/`、`templates/`、`INIT.md`、`RUN.md`、
> `CRITICAL_REVIEW.md` 和 `CHANGELOG.md` 为准。本文件中的 SSoT 说法只对
> 当时 v0.1 实施阶段有效。

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `~/.claude/skills/dev-loop/` 构建一个通用的、基于 Anthropic harness 思想的开发循环 skill v0.1。能通过 `/dev-loop init` 为任意新项目生成 `.devloop/` 工作流（`CLAUDE.md` / `architecture.md` / `task.json` / `config.json` / `run.ps1` / `guard_commit.ps1` / ...），并用 `run.ps1` 驱动 headless Claude 循环完成任务。

**Architecture:** Skill 由三个认知骨架文档（`SKILL.md` / `INIT.md` / `RUN.md`）+ CR gate 判定文档（`CRITICAL_REVIEW.md`）+ 8 份静态模板 + PowerShell 主循环脚本（`run.ps1`）+ PreCommit guard（`guard_commit.ps1`）+ 3 个库脚本构成。通过 `.devloop/task.json` 这块共享黑板连接 Claude 与调度脚本，用 6 个 Critical Review Gates（四层强制机制：Prompt / Schema / 工件 / Hook）保证批判性审查不被跳过。

**Tech Stack:** PowerShell 7 (Windows), Pester 5.x（单元测试）, Markdown, JSON Schema。完整设计规格见 `~/.claude/skills/dev-loop/docs/specs/2026-04-26-dev-loop-skill-design.md`（下文简称 **spec**）。

**历史 SSoT 说明：** 本 plan 对 markdown 文档任务（RUN.md / INIT.md / CRITICAL_REVIEW.md / references）以"按 spec §X.Y 复制并做 Y 调整"方式引用 spec 章节。这不是 placeholder —— spec 在 v0.1 初始实施时是设计决策的单一事实源；当前 v0.1.6 不再以本 plan/spec 为事实源。

---

## File Structure

```
~/.claude/skills/dev-loop/
├── SKILL.md                               # Task 1
├── INIT.md                                # Task 10
├── RUN.md                                 # Task 9
├── CRITICAL_REVIEW.md                     # Task 11
├── templates/                             # Task 2-3
│   ├── task.json.tpl                      # Task 2
│   ├── config.json.tpl                    # Task 2
│   ├── CLAUDE.md.tpl                      # Task 3
│   ├── architecture.md.tpl                # Task 3
│   ├── progress.md.tpl                    # Task 3
│   ├── lessons.md.tpl                     # Task 3
│   ├── gitignore.tpl                      # Task 3
│   └── claude-settings.json.tpl           # Task 3
├── scripts/
│   ├── run.ps1                            # Task 8
│   ├── guard_commit.ps1                   # Task 7
│   └── lib/
│       ├── task_picker.ps1                # Task 4
│       ├── verify_runner.ps1              # Task 5
│       └── claude_invoker.ps1             # Task 6
├── tests/
│   ├── fixtures/
│   │   ├── valid_task.json                # Task 4
│   │   ├── cyclic_deps.json               # Task 4
│   │   └── oversize.json                  # Task 4
│   ├── task_picker.Tests.ps1              # Task 4
│   ├── verify_runner.Tests.ps1            # Task 5
│   ├── claude_invoker.Tests.ps1           # Task 6
│   ├── guard_commit.Tests.ps1             # Task 7
│   └── run.Tests.ps1                      # Task 8
├── references/                            # Task 12
│   ├── schemas.md
│   ├── failure-playbook.md
│   ├── headless-gotchas.md
│   ├── evidence-levels.md
│   ├── task-granularity.md
│   └── ROADMAP.md
└── docs/
    ├── specs/2026-04-26-dev-loop-skill-design.md   # 已存在
    └── plans/2026-04-26-dev-loop-skill.md          # 本 plan
```

**工作目录假设：** 所有 `cd` 和相对路径操作的基点是 `C:\Users\xiybh\.claude\skills`（skills 仓库根）。任务内所有 `git` 命令作用于该仓库。所有 PowerShell 命令假定 PowerShell 7 (`pwsh.exe`)。

**环境前置（一次性）：** Task 4–8 使用 Pester 5.x。首次执行前在 PowerShell 7 里运行：

```powershell
if (-not (Get-Module -ListAvailable -Name Pester | Where-Object Version -ge 5.0)) {
    Install-Module Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck
}
Import-Module Pester
```

---

## Task 1: Skill 骨架与 SKILL.md 入口

**Files:**
- Create: `dev-loop/SKILL.md`
- Create directories: `dev-loop/templates/`, `dev-loop/scripts/lib/`, `dev-loop/tests/fixtures/`, `dev-loop/references/`

- [ ] **Step 1: 创建目录骨架**

```powershell
cd C:\Users\xiybh\.claude\skills\dev-loop
New-Item -ItemType Directory -Force -Path templates, scripts/lib, tests/fixtures, references | Out-Null
Test-Path templates, scripts/lib, tests/fixtures, references
```
Expected: 四个 `True`

- [ ] **Step 2: 写 SKILL.md 完整内容**

Create `dev-loop/SKILL.md`:

```markdown
---
name: dev-loop
description: 用于项目启动和循环执行开发任务的 harness。TRIGGER 当用户要：(1) 为新项目搭建自动化开发循环（"做个循环执行脚本"/"帮我拆任务自动跑"/"基于任务列表自动开发"）；(2) 在已有 .devloop/ 项目执行 `/dev-loop init` 或 `/dev-loop run`；(3) 讨论"长期运行 agent 的 harness 设计"。SKIP 当：任务是一次性实现、debug、code review，或项目没有明确的任务清单需求。
---

# Dev-Loop Skill

两阶段 harness：init 四段对话生成 `.devloop/` 工作流，`run.ps1` 驱动 headless Claude 循环执行任务。

## 决策流程图

​```dot
digraph dev_loop {
    "User triggers /dev-loop" [shape=doublecircle];
    "Which subcommand?" [shape=diamond];
    "Read INIT.md and execute 4-stage dialog" [shape=box];
    "Point user to .\\.devloop\\scripts\\run.ps1" [shape=box];

    "User triggers /dev-loop" -> "Which subcommand?";
    "Which subcommand?" -> "Read INIT.md and execute 4-stage dialog" [label="init"];
    "Which subcommand?" -> "Point user to .\\.devloop\\scripts\\run.ps1" [label="run"];
}
​```

## 两个入口命令

- `/dev-loop init` — 交互式四段对话生成完整 harness（Read `INIT.md`）
- `/dev-loop run` — 提示用户从 PowerShell 执行 `.\.devloop\scripts\run.ps1`（Claude 不在会话内循环）

## 必读文档（按需）

- `INIT.md` — init 阶段 Claude 主动 Read
- `RUN.md` — run 阶段 headless Claude 冷启动时 Read
- `CRITICAL_REVIEW.md` — 6 个 CR Gate 完整判定准则
- `docs/specs/2026-04-26-dev-loop-skill-design.md` — 完整设计规格（SSoT）

## 绝不做的事（红线）

1. 禁止直接创建 task.json 而跳过 INIT.md 的 4 段对话
2. 禁止在未触发 CR-2（证据等级审查）的情况下生成 architecture.md
3. 禁止把 run.ps1 的循环逻辑写进 Claude 对话里"自己循环"——Claude 不负责循环调度
4. 禁止自动 push / 自动 PR
5. 禁止修改已落盘的 `.devloop/config.json`（init 一次写入，run 阶段只读）
6. 禁止为了过 CR gate 而伪造查证记录——CR-5 允许 `NO_RESEARCH_NEEDED` 诚实出口

## 引用资料

按需查阅 `references/` 目录：
- `schemas.md` — task.json / config.json 完整 JSON Schema
- `failure-playbook.md` — 失败策略决策树（a2+b1+c1）
- `headless-gotchas.md` — Windows + headless Claude 已知坑
- `evidence-levels.md` — A/B/C 证据等级判定与升级流程
- `task-granularity.md` — 粗粒度 + 5 文件约束判例
- `ROADMAP.md` — v0.2+ 扩展计划
```

> **注意**：上面 `​```dot` 中的 Unicode 零宽空格 `​` 是 plan 文档里的转义标记，实际写入 SKILL.md 时必须**删除**（让 dot 代码块正常闭合）。验证 step 会检查该 `​` 字符不存在。

- [ ] **Step 3: 验证 frontmatter 正确**

```powershell
$content = Get-Content dev-loop/SKILL.md -Raw
if ($content -notmatch '^---\r?\nname: dev-loop\r?\n') { throw 'frontmatter missing' }
if ($content -notmatch 'description:.+TRIGGER') { throw 'description missing TRIGGER keyword' }
if ($content -match [char]0x200B) { throw 'zero-width-space escape leaked into file' }
'frontmatter OK'
```
Expected: `frontmatter OK`

- [ ] **Step 4: 验证关键 section 存在**

```powershell
$required = @('## 决策流程图', '## 两个入口命令', '## 必读文档', '## 绝不做的事', '## 引用资料')
$content = Get-Content dev-loop/SKILL.md -Raw
foreach ($s in $required) {
    if ($content -notmatch [regex]::Escape($s)) { throw "Missing section: $s" }
}
'All sections present'
```
Expected: `All sections present`

- [ ] **Step 5: Commit**

```powershell
git add dev-loop/SKILL.md
git commit -m "feat(dev-loop): 新增 skill 入口 SKILL.md

含 frontmatter 触发规则、决策流程图、红线清单与引用资料索引。"
```

---

## Task 2: JSON Templates（task.json.tpl + config.json.tpl）

**Files:**
- Create: `dev-loop/templates/task.json.tpl`
- Create: `dev-loop/templates/config.json.tpl`

- [ ] **Step 1: 写 task.json.tpl**

内容完全来自 spec §6.1。Create `dev-loop/templates/task.json.tpl`:

```json
{
  "schemaVersion": "1.0",
  "project": {
    "name": "<PROJECT_NAME>",
    "mainBranch": "main",
    "createdAt": "<ISO_8601_TIMESTAMP>",
    "lastRunAt": null
  },
  "tasks": [
    {
      "id": "T-001",
      "title": "<任务标题>",
      "description": "<任务的完整描述，包含上下文和约束>",
      "steps": [
        "<步骤 1>",
        "<步骤 2>"
      ],
      "estimated_files": 3,
      "depends_on": [],
      "category": "chore",
      "scope": "project",
      "verify_cmds": [
        "npm run lint",
        "npm run build"
      ],
      "passes": false,
      "attempts": 0,
      "blocked": false,
      "blockReason": "",
      "lastError": "",
      "notes": "",
      "startedAt": null,
      "completedAt": null
    }
  ]
}
```

- [ ] **Step 2: 写 config.json.tpl**

内容完全来自 spec §6.2。Create `dev-loop/templates/config.json.tpl`:

```json
{
  "schemaVersion": "1.0",
  "projectType": "<由 init 段 1 Q2 填写，自由文本>",
  "init": {
    "cmds": [],
    "markerFile": ".devloop/.initialized"
  },
  "verify": {
    "globalCmds": [],
    "browserTests": {
      "enabled": false,
      "url": "http://localhost:3000",
      "consoleErrorCheck": true,
      "requiredSelectors": [],
      "screenshotDir": ".devloop/logs/screenshots"
    },
    "manualChecklist": []
  },
  "limits": {
    "maxAttemptsPerTask": 3,
    "maxConsecBlocked": 3,
    "maxFilesPerTask": 5,
    "claudeTimeoutSec": 1800,
    "totalBudgetMinutes": 0
  },
  "git": {
    "mainBranch": "main",
    "autoPush": false,
    "autoPR": false,
    "commitTemplate": "{category}({scope}): {title}\n\nTask-ID: {id}\nAttempts: {attempts}\nVerified: {verifyCmds}"
  },
  "claude": {
    "model": null,
    "dangerouslySkipPermissions": true,
    "outputFormat": "json",
    "mcp": {
      "context7Available": false
    }
  }
}
```

- [ ] **Step 3: 验证 JSON 合法**

```powershell
Get-Content dev-loop/templates/task.json.tpl -Raw | ConvertFrom-Json | Out-Null
Get-Content dev-loop/templates/config.json.tpl -Raw | ConvertFrom-Json | Out-Null
'Both JSON templates parse OK'
```
Expected: `Both JSON templates parse OK`

- [ ] **Step 4: Commit**

```powershell
git add dev-loop/templates/task.json.tpl dev-loop/templates/config.json.tpl
git commit -m "feat(dev-loop): 新增 task.json 与 config.json 模板

内容按 spec §6.1 / §6.2，含完整状态位（passes/blocked/attempts/depends_on）
与运行时策略（limits/git/claude）字段。"
```

---

## Task 3: Markdown Templates（其他 6 份）

**Files:**
- Create: `dev-loop/templates/CLAUDE.md.tpl`
- Create: `dev-loop/templates/architecture.md.tpl`
- Create: `dev-loop/templates/progress.md.tpl`
- Create: `dev-loop/templates/lessons.md.tpl`
- Create: `dev-loop/templates/gitignore.tpl`
- Create: `dev-loop/templates/claude-settings.json.tpl`

- [ ] **Step 1: CLAUDE.md.tpl**

```markdown
# CLAUDE.md · <PROJECT_NAME>

> 此文件由 `/dev-loop init` 生成。Claude Code 会话启动时自动加载。

## 每任务必读清单（run 阶段冷启动）

按顺序读取：
1. `.devloop/task.json` — 定位当前任务
2. `architecture.md` — 项目架构与 [A/B/C] 证据等级
3. `.devloop/lessons.md` — 历史避坑经验
4. （attempt > 1 时）`.devloop/logs/task_<id>_attempt_<n-1>.log` — 上次错误

## 开发循环（run.ps1 驱动）

初始化 → 选任务 → 实现 → 测试验证 → 更新进度 → 提交

详细执行协议见 `~/.claude/skills/dev-loop/RUN.md`。

## 关键规则

1. **不要** 手动创建任务到 `task.json`——结构由 init 固化
2. **不要** 修改 `.devloop/config.json`——init 后只读
3. **不要** 运行 `git commit`——由 `run.ps1` 在验证通过后统一提交
4. **必须** 每任务开始前过 CR-5（查证不确定 API）
5. **必须** 每任务 commit 前过 CR-6（自省 3 问）

## 测试判定规则

<由 init 段 1 Q3 的回答填充>

## Commit 类型枚举

<由 init 段 1 Q4 填充，例如：feat / fix / refactor / chore / docs / test>

## Git 配置

- 主分支：<由 init 段 1 Q5 填充>
- AutoPush：关（显式手动推送）
- AutoPR：关
```

- [ ] **Step 2: architecture.md.tpl**

内容来自 spec §6.5。Create `dev-loop/templates/architecture.md.tpl`:

```markdown
# <PROJECT_NAME> · 架构

## 项目目标

<由 init 段 2 基于 stage1.json 填充。MVP 范围明确。>

## 测试判定规则

- **自动化**：<cmds>
- **浏览器**：<启用时：URL + 必需元素 + 截图规则>
- **后端 API**：<启用时：endpoint + schema 期望>
- **手动**：<若无法自动化，给出每次怎么确认的清单>

## 技术栈（证据等级）

| 层 | 选型 | 证据 |
|---|---|---|
| <运行时> | <如 Node.js 20 LTS> | `[A]` <context7 或官方文档链接> |
| <Web 框架> | <如 Fastify 4.x> | `[A]` <链接> |
| <数据库> | <如 PostgreSQL 15> | `[B]` <主流选型理由> |

> **CR-2 规则**：每项必须带 `[A/B/C]` 等级。任何 `[C]` 必须升级到 A/B 或显式标 `[C — 未验证]` 并在 `lessons.md` 登记。

## 模块划分

### `<module_name>/`

- **职责**：<一句话>
- **对外接口**：<如 HTTP endpoint、API 函数签名>
- **依赖**：<内部模块 / 外部库>

## 数据流

<一句话描述请求/事件从输入到输出的路径>

## 未决事项（[C — 未验证]）

- <项目>：<拟用方案> — <评估触发条件（如"P50 > 100ms"）>

## 相关教训

参见 `.devloop/lessons.md`——已被否决的方案和替代决策。
```

- [ ] **Step 3: progress.md.tpl**

内容来自 spec §6.3。Create `dev-loop/templates/progress.md.tpl`:

```markdown
# Dev Loop Progress · <PROJECT_NAME>

> 由 `run.ps1` 追加；人类不改写。跨日自动开新节。

<!-- 每任务结束时 append 形如：
## YYYY-MM-DD (Day N)

| Time  | Task  | Title                       | Status     | Attempts | Notes |
|-------|-------|-----------------------------|-----------|----------|-------|
| HH:MM | T-001 | <title>                     | ✓ done    | 1        | —     |
-->

## Overrides

<!-- `[skip-devloop]` commit 在此登记，格式：YYYY-MM-DD HH:MM · <commit-sha> · <reason> -->
```

- [ ] **Step 4: lessons.md.tpl**

内容来自 spec §6.4。Create `dev-loop/templates/lessons.md.tpl`:

```markdown
# Dev Loop Lessons · <PROJECT_NAME>

> 此文件只追加，不删除。每次 CR-2 / CR-6 触发修正时 Claude 追加一条。
> 每次任务启动前 Claude 必读本文件（见 RUN.md 第 1 步）。

<!-- 条目模板（追加用）：

---

## YYYY-MM-DD · T-<ID> · <类别，如"技术选型修正 (CR-2)" 或 "实现简化 (CR-6)">
- **被否决建议**：<具体方案>
- **否决理由**：<证据来源链接或源码位置>
- **采用替代**：<最终方案>
- **适用场景**：<什么情况下本结论有效>

-->
```

- [ ] **Step 5: gitignore.tpl**

Create `dev-loop/templates/gitignore.tpl`:

```
# --- dev-loop (追加片段，非完整 .gitignore) ---
.devloop/logs/
.devloop/init/
.devloop/.initialized
.devloop/.current_task_id
```

- [ ] **Step 6: claude-settings.json.tpl**

Create `dev-loop/templates/claude-settings.json.tpl`:

```json
{
  "$schema": "https://raw.githubusercontent.com/anthropics/claude-code/main/schema/settings.json",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NoProfile -File .devloop/scripts/guard_commit.ps1"
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 7: 验证所有存在且 JSON 合法**

```powershell
$all = @(
  'dev-loop/templates/CLAUDE.md.tpl',
  'dev-loop/templates/architecture.md.tpl',
  'dev-loop/templates/progress.md.tpl',
  'dev-loop/templates/lessons.md.tpl',
  'dev-loop/templates/gitignore.tpl',
  'dev-loop/templates/claude-settings.json.tpl'
)
$all | ForEach-Object { if (-not (Test-Path $_)) { throw "Missing: $_" } }
Get-Content dev-loop/templates/claude-settings.json.tpl -Raw | ConvertFrom-Json | Out-Null
'All 6 markdown/settings templates OK'
```
Expected: `All 6 markdown/settings templates OK`

- [ ] **Step 8: Commit**

```powershell
git add dev-loop/templates/CLAUDE.md.tpl dev-loop/templates/architecture.md.tpl `
        dev-loop/templates/progress.md.tpl dev-loop/templates/lessons.md.tpl `
        dev-loop/templates/gitignore.tpl dev-loop/templates/claude-settings.json.tpl
git commit -m "feat(dev-loop): 新增 6 份 markdown/settings 模板

含 CLAUDE.md / architecture.md / progress.md / lessons.md / gitignore / claude-settings.json。
内容按 spec §6.3-§6.5 与 §5.1 段 4 文件清单。"
```

---

## Task 4: lib/task_picker.ps1（Pester TDD）

**Files:**
- Create: `dev-loop/scripts/lib/task_picker.ps1`
- Create: `dev-loop/tests/task_picker.Tests.ps1`
- Create: `dev-loop/tests/fixtures/valid_task.json`
- Create: `dev-loop/tests/fixtures/cyclic_deps.json`
- Create: `dev-loop/tests/fixtures/oversize.json`

**函数契约：**
- `Select-NextTask -Path <task.json>` → 返回第一个 `passes=false && blocked=false && depends_on 全部已 passed` 的 task 对象，或 `$null`
- `Assert-TaskJsonValid -Path <task.json> -MaxFiles <N>` → `estimated_files > N` 或存在依赖环或 `verify_cmds` 空 → `throw`；否则静默通过

- [ ] **Step 1: 写 3 份 fixture**

Create `dev-loop/tests/fixtures/valid_task.json`:

```json
{
  "schemaVersion": "1.0",
  "project": { "name": "fixture", "mainBranch": "main", "createdAt": "2026-04-26T00:00:00Z", "lastRunAt": null },
  "tasks": [
    { "id": "T-001", "title": "done task", "description": "", "steps": [], "estimated_files": 2, "depends_on": [], "category": "chore", "scope": "p", "verify_cmds": ["true"], "passes": true,  "attempts": 1, "blocked": false, "blockReason": "", "lastError": "", "notes": "", "startedAt": null, "completedAt": null },
    { "id": "T-002", "title": "next available", "description": "", "steps": [], "estimated_files": 3, "depends_on": ["T-001"], "category": "feat", "scope": "p", "verify_cmds": ["true"], "passes": false, "attempts": 0, "blocked": false, "blockReason": "", "lastError": "", "notes": "", "startedAt": null, "completedAt": null },
    { "id": "T-003", "title": "blocked by missing dep", "description": "", "steps": [], "estimated_files": 2, "depends_on": ["T-999"], "category": "feat", "scope": "p", "verify_cmds": ["true"], "passes": false, "attempts": 0, "blocked": false, "blockReason": "", "lastError": "", "notes": "", "startedAt": null, "completedAt": null }
  ]
}
```

Create `dev-loop/tests/fixtures/cyclic_deps.json`:

```json
{
  "schemaVersion": "1.0",
  "project": { "name": "fixture", "mainBranch": "main", "createdAt": "2026-04-26T00:00:00Z", "lastRunAt": null },
  "tasks": [
    { "id": "A", "title": "a", "description": "", "steps": [], "estimated_files": 1, "depends_on": ["B"], "category": "chore", "scope": "p", "verify_cmds": ["true"], "passes": false, "attempts": 0, "blocked": false, "blockReason": "", "lastError": "", "notes": "", "startedAt": null, "completedAt": null },
    { "id": "B", "title": "b", "description": "", "steps": [], "estimated_files": 1, "depends_on": ["A"], "category": "chore", "scope": "p", "verify_cmds": ["true"], "passes": false, "attempts": 0, "blocked": false, "blockReason": "", "lastError": "", "notes": "", "startedAt": null, "completedAt": null }
  ]
}
```

Create `dev-loop/tests/fixtures/oversize.json`:

```json
{
  "schemaVersion": "1.0",
  "project": { "name": "fixture", "mainBranch": "main", "createdAt": "2026-04-26T00:00:00Z", "lastRunAt": null },
  "tasks": [
    { "id": "T-001", "title": "too big", "description": "", "steps": [], "estimated_files": 12, "depends_on": [], "category": "feat", "scope": "p", "verify_cmds": ["true"], "passes": false, "attempts": 0, "blocked": false, "blockReason": "", "lastError": "", "notes": "", "startedAt": null, "completedAt": null }
  ]
}
```

- [ ] **Step 2: 写 Pester 失败测试**

Create `dev-loop/tests/task_picker.Tests.ps1`:

```powershell
BeforeAll {
    . $PSScriptRoot/../scripts/lib/task_picker.ps1
    $script:FixtureDir = Join-Path $PSScriptRoot 'fixtures'
}

Describe 'Select-NextTask' {
    It '返回第一个 passes=false 且依赖已完成的任务' {
        $t = Select-NextTask -Path (Join-Path $script:FixtureDir 'valid_task.json')
        $t.id | Should -Be 'T-002'
    }

    It '依赖未 passed 的任务不会被选中' {
        $t = Select-NextTask -Path (Join-Path $script:FixtureDir 'valid_task.json')
        $t.id | Should -Not -Be 'T-003'
    }

    It '全部完成时返回 $null' {
        $tmpJson = Join-Path ([System.IO.Path]::GetTempPath()) 'allDone.json'
        @{ schemaVersion='1.0'; project=@{name='x';mainBranch='main';createdAt='2026-04-26T00:00:00Z';lastRunAt=$null}; tasks=@(
            @{id='T-001';title='';description='';steps=@();estimated_files=1;depends_on=@();category='c';scope='p';verify_cmds=@('true');passes=$true;attempts=1;blocked=$false;blockReason='';lastError='';notes='';startedAt=$null;completedAt=$null}
        ) } | ConvertTo-Json -Depth 10 | Set-Content $tmpJson
        Select-NextTask -Path $tmpJson | Should -BeNullOrEmpty
        Remove-Item $tmpJson
    }
}

Describe 'Assert-TaskJsonValid' {
    It '对 estimated_files 超限抛异常' {
        { Assert-TaskJsonValid -Path (Join-Path $script:FixtureDir 'oversize.json') -MaxFiles 5 } |
            Should -Throw '*estimated_files*'
    }

    It '对依赖环抛异常' {
        { Assert-TaskJsonValid -Path (Join-Path $script:FixtureDir 'cyclic_deps.json') -MaxFiles 5 } |
            Should -Throw '*cycle*'
    }

    It '合法 fixture 静默通过' {
        { Assert-TaskJsonValid -Path (Join-Path $script:FixtureDir 'valid_task.json') -MaxFiles 5 } |
            Should -Not -Throw
    }
}
```

- [ ] **Step 3: 运行测试验证失败**

```powershell
cd dev-loop
Invoke-Pester -Path tests/task_picker.Tests.ps1 -Output Detailed
```
Expected: 6 个 `Failed`（因为 `task_picker.ps1` 还不存在；错误形如 "`The term 'Select-NextTask' is not recognized`"）

- [ ] **Step 4: 写实现**

Create `dev-loop/scripts/lib/task_picker.ps1`:

```powershell
# dev-loop/scripts/lib/task_picker.ps1
# 函数：Select-NextTask、Assert-TaskJsonValid
# 单元测试：tests/task_picker.Tests.ps1

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Select-NextTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )
    $data = Get-Content $Path -Raw | ConvertFrom-Json
    $byId = @{}
    foreach ($t in $data.tasks) { $byId[$t.id] = $t }

    foreach ($t in $data.tasks) {
        if ($t.passes)   { continue }
        if ($t.blocked)  { continue }
        $ok = $true
        foreach ($dep in $t.depends_on) {
            if (-not $byId.ContainsKey($dep) -or -not $byId[$dep].passes) {
                $ok = $false
                break
            }
        }
        if ($ok) { return $t }
    }
    return $null
}

function Assert-TaskJsonValid {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [int]$MaxFiles = 5
    )
    $data = Get-Content $Path -Raw | ConvertFrom-Json

    foreach ($t in $data.tasks) {
        if ($t.estimated_files -gt $MaxFiles) {
            throw "Task $($t.id) estimated_files=$($t.estimated_files) > $MaxFiles"
        }
        if (-not $t.verify_cmds -or @($t.verify_cmds).Count -eq 0) {
            throw "Task $($t.id) verify_cmds is empty"
        }
    }

    $state = @{}
    foreach ($t in $data.tasks) { $state[$t.id] = 0 }
    $byId = @{}
    foreach ($t in $data.tasks) { $byId[$t.id] = $t }

    $visit = {
        param($id)
        if ($state[$id] -eq 1) { throw "dependency cycle detected at $id" }
        if ($state[$id] -eq 2) { return }
        $state[$id] = 1
        foreach ($dep in $byId[$id].depends_on) {
            if ($byId.ContainsKey($dep)) { & $visit $dep }
        }
        $state[$id] = 2
    }
    foreach ($t in $data.tasks) { & $visit $t.id }
}
```

- [ ] **Step 5: 运行测试验证通过**

```powershell
cd dev-loop
Invoke-Pester -Path tests/task_picker.Tests.ps1 -Output Detailed
```
Expected: `Tests Passed: 6, Failed: 0`

- [ ] **Step 6: Commit**

```powershell
git add dev-loop/scripts/lib/task_picker.ps1 `
        dev-loop/tests/task_picker.Tests.ps1 `
        dev-loop/tests/fixtures/valid_task.json `
        dev-loop/tests/fixtures/cyclic_deps.json `
        dev-loop/tests/fixtures/oversize.json
git commit -m "feat(dev-loop): 新增 task_picker 库与 Pester 测试

- Select-NextTask：选第一个可执行任务（passes/blocked/depends_on 复合判定）
- Assert-TaskJsonValid：estimated_files 上限、依赖环 DFS 检测、verify_cmds 非空
- 3 份 fixture（valid / cyclic / oversize）驱动 TDD"
```

## Task 5: lib/verify_runner.ps1（Pester TDD）

**Files:**
- Create: `dev-loop/scripts/lib/verify_runner.ps1`
- Create: `dev-loop/tests/verify_runner.Tests.ps1`

**函数契约：**
- `Invoke-VerifyRunner -Task <obj> -Config <obj>` → `$true` 或 `$false`
  - 合并 `config.verify.globalCmds` + `task.verify_cmds`
  - 顺序执行，每条命令走 `pwsh -NoProfile -Command <cmd>`，`$LASTEXITCODE ≠ 0` 即认为失败
  - 任一失败立即返回 `$false`；全部成功返回 `$true`

- [ ] **Step 1: 写 Pester 失败测试**

Create `dev-loop/tests/verify_runner.Tests.ps1`:

```powershell
BeforeAll {
    . $PSScriptRoot/../scripts/lib/verify_runner.ps1
    $script:TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "dev-loop-verify-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $script:TmpDir | Out-Null
}

AfterAll {
    Remove-Item $script:TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-VerifyRunner' {
    It '全部命令成功时返回 $true' {
        $task = [pscustomobject]@{ id = 'T-001'; verify_cmds = @('exit 0') }
        $cfg  = [pscustomobject]@{ verify = [pscustomobject]@{ globalCmds = @('exit 0') } }
        Invoke-VerifyRunner -Task $task -Config $cfg | Should -BeTrue
    }

    It 'globalCmd 失败时返回 $false（且 task.verify_cmds 不再执行）' {
        $marker = Join-Path $script:TmpDir 'task_did_run.txt'
        if (Test-Path $marker) { Remove-Item $marker }
        $task = [pscustomobject]@{ id = 'T-001'; verify_cmds = @("'x' | Out-File -Encoding utf8 '$marker'") }
        $cfg  = [pscustomobject]@{ verify = [pscustomobject]@{ globalCmds = @('exit 1') } }
        Invoke-VerifyRunner -Task $task -Config $cfg | Should -BeFalse
        Test-Path $marker | Should -BeFalse
    }

    It 'task.verify_cmd 失败时返回 $false' {
        $task = [pscustomobject]@{ id = 'T-001'; verify_cmds = @('exit 3') }
        $cfg  = [pscustomobject]@{ verify = [pscustomobject]@{ globalCmds = @('exit 0') } }
        Invoke-VerifyRunner -Task $task -Config $cfg | Should -BeFalse
    }

    It 'globalCmds 先于 task.verify_cmds 执行' {
        $marker = Join-Path $script:TmpDir 'order.txt'
        if (Test-Path $marker) { Remove-Item $marker }
        $task = [pscustomobject]@{ id = 'T-001'; verify_cmds = @("'task' | Out-File -Append -Encoding utf8 '$marker'") }
        $cfg  = [pscustomobject]@{ verify = [pscustomobject]@{ globalCmds = @("'global' | Out-File -Append -Encoding utf8 '$marker'") } }
        Invoke-VerifyRunner -Task $task -Config $cfg | Should -BeTrue
        ((Get-Content $marker) -join ',') | Should -Match 'global.*task'
    }

    It '空 globalCmds 也能运行' {
        $task = [pscustomobject]@{ id = 'T-001'; verify_cmds = @('exit 0') }
        $cfg  = [pscustomobject]@{ verify = [pscustomobject]@{ globalCmds = @() } }
        Invoke-VerifyRunner -Task $task -Config $cfg | Should -BeTrue
    }
}
```

- [ ] **Step 2: 运行测试验证失败**

```powershell
cd dev-loop
Invoke-Pester -Path tests/verify_runner.Tests.ps1 -Output Detailed
```
Expected: 5 个 `Failed`（函数未定义）

- [ ] **Step 3: 写实现**

Create `dev-loop/scripts/lib/verify_runner.ps1`:

```powershell
# dev-loop/scripts/lib/verify_runner.ps1
# 函数：Invoke-VerifyRunner
# 单元测试：tests/verify_runner.Tests.ps1

Set-StrictMode -Version 3.0

function Invoke-VerifyRunner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Task,
        [Parameter(Mandatory)][object]$Config
    )

    $cmds = @()
    if ($Config.verify -and $Config.verify.globalCmds) { $cmds += @($Config.verify.globalCmds) }
    if ($Task.verify_cmds)                             { $cmds += @($Task.verify_cmds) }

    foreach ($cmd in $cmds) {
        if ([string]::IsNullOrWhiteSpace($cmd)) { continue }
        Write-Host ">>> [verify] $cmd"
        & pwsh -NoProfile -Command $cmd
        $code = $LASTEXITCODE
        if ($code -ne 0) {
            Write-Host "    ^ FAILED (exit=$code)"
            return $false
        }
    }
    return $true
}
```

- [ ] **Step 4: 运行测试验证通过**

```powershell
cd dev-loop
Invoke-Pester -Path tests/verify_runner.Tests.ps1 -Output Detailed
```
Expected: `Tests Passed: 5, Failed: 0`

- [ ] **Step 5: Commit**

```powershell
git add dev-loop/scripts/lib/verify_runner.ps1 dev-loop/tests/verify_runner.Tests.ps1
git commit -m "feat(dev-loop): 新增 verify_runner 库与 Pester 测试

Invoke-VerifyRunner：按 globalCmds -> task.verify_cmds 顺序执行，
任一失败即短路返回 false；空 cmd 跳过；用 pwsh -NoProfile 启子进程避免污染环境。"
```

---

## Task 6: lib/claude_invoker.ps1（Pester TDD）

**Files:**
- Create: `dev-loop/scripts/lib/claude_invoker.ps1`
- Create: `dev-loop/tests/claude_invoker.Tests.ps1`

**函数契约：**
- `Build-Prompt -TaskId <id> -Attempt <n> [-PrevLogPath <path>] [-MaxAttempts <n>]` → string
  - 构造给 headless Claude 的 prompt
  - 必须包含 task id、当前 attempt 数、RUN.md 引用、"不要 git commit" 指令
  - attempt > 1 时追加上次错误日志路径
- `Invoke-HeadlessClaude -Prompt <str> -LogPath <path> [-TimeoutSec <n>]` → int（exit code，超时返回 -1）

**Pester 覆盖范围**：`Build-Prompt` 字符串契约。`Invoke-HeadlessClaude` 依赖外部 `claude` 可执行文件，留给 Task 13 dogfood 做 smoke test。

- [ ] **Step 1: 写 Pester 失败测试**

Create `dev-loop/tests/claude_invoker.Tests.ps1`:

```powershell
BeforeAll {
    . $PSScriptRoot/../scripts/lib/claude_invoker.ps1
}

Describe 'Build-Prompt' {
    It '包含 task id' {
        $p = Build-Prompt -TaskId 'T-042' -Attempt 1
        $p | Should -Match 'T-042'
    }

    It '包含 attempt 数' {
        $p = Build-Prompt -TaskId 'T-001' -Attempt 2
        $p | Should -Match 'Attempt:\s*2\s*/\s*3'
    }

    It 'attempt=1 时不含上次错误日志引用' {
        $p = Build-Prompt -TaskId 'T-001' -Attempt 1
        $p | Should -Not -Match 'Previous error log'
    }

    It 'attempt>1 时包含上次错误日志路径' {
        $p = Build-Prompt -TaskId 'T-001' -Attempt 2 -PrevLogPath '.devloop/logs/task_T-001_attempt_1.log'
        $p | Should -Match 'Previous error log'
        $p | Should -Match 'task_T-001_attempt_1\.log'
    }

    It '明确禁止 git commit' {
        $p = Build-Prompt -TaskId 'T-001' -Attempt 1
        $p | Should -Match 'Do not run git commit'
    }

    It '引用 RUN.md 路径' {
        $p = Build-Prompt -TaskId 'T-001' -Attempt 1
        $p | Should -Match 'RUN\.md'
    }
}
```

- [ ] **Step 2: 运行测试验证失败**

```powershell
cd dev-loop
Invoke-Pester -Path tests/claude_invoker.Tests.ps1 -Output Detailed
```
Expected: 6 个 `Failed`（`Build-Prompt` 未定义）

- [ ] **Step 3: 写实现**

Create `dev-loop/scripts/lib/claude_invoker.ps1`:

```powershell
# dev-loop/scripts/lib/claude_invoker.ps1
# 函数：Build-Prompt、Invoke-HeadlessClaude
# 单元测试：tests/claude_invoker.Tests.ps1（仅测 Build-Prompt）

Set-StrictMode -Version 3.0

function Build-Prompt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TaskId,
        [Parameter(Mandatory)][int]$Attempt,
        [string]$PrevLogPath = '',
        [int]$MaxAttempts = 3
    )
    $cwd = (Get-Location).Path
    $parts = @(
        "You are executing task ``$TaskId`` for the dev-loop harness.",
        "",
        "Read ~/.claude/skills/dev-loop/RUN.md and strictly follow the 7-step protocol.",
        "",
        "Context:",
        "- Working directory: $cwd",
        "- Task ID: $TaskId",
        "- Attempt: $Attempt / $MaxAttempts"
    )
    if ($Attempt -gt 1 -and $PrevLogPath) {
        $parts += "- Previous error log: $PrevLogPath (read first to avoid repeating the error)"
    }
    $parts += @(
        "",
        "Execute the task now. Do not run git commit / git push — run.ps1 handles those.",
        "When finished, update .devloop/task.json (your task's passes/attempts/lastError/notes fields) and exit."
    )
    return ($parts -join "`n")
}

function Invoke-HeadlessClaude {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter(Mandatory)][string]$LogPath,
        [int]$TimeoutSec = 1800
    )
    $logDir = Split-Path $LogPath -Parent
    if ($logDir -and -not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    }

    $job = Start-Job -ScriptBlock {
        param($p, $log)
        $p | & claude -p --dangerously-skip-permissions --output-format json 2>&1 |
            Tee-Object -FilePath $log
        return $LASTEXITCODE
    } -ArgumentList $Prompt, $LogPath

    $completed = Wait-Job -Job $job -Timeout $TimeoutSec
    if (-not $completed) {
        Stop-Job -Job $job
        Remove-Job -Job $job -Force
        Add-Content -Path $LogPath -Value "`n[TIMEOUT] killed after $TimeoutSec s"
        return -1
    }
    $exit = Receive-Job -Job $job
    Remove-Job -Job $job -Force
    return [int]$exit
}
```

- [ ] **Step 4: 运行测试验证通过**

```powershell
cd dev-loop
Invoke-Pester -Path tests/claude_invoker.Tests.ps1 -Output Detailed
```
Expected: `Tests Passed: 6, Failed: 0`

- [ ] **Step 5: Commit**

```powershell
git add dev-loop/scripts/lib/claude_invoker.ps1 dev-loop/tests/claude_invoker.Tests.ps1
git commit -m "feat(dev-loop): 新增 claude_invoker 库与 Pester 测试

- Build-Prompt: 构造 headless Claude prompt（task id/attempt/上次日志路径/禁 git commit）
- Invoke-HeadlessClaude: Start-Job + Wait-Job 实现超时控制，
  tee 输出到 log path；超时 kill 并返回 -1"
```

## Task 7: scripts/guard_commit.ps1（Pester TDD）

**Files:**
- Create: `dev-loop/scripts/guard_commit.ps1`
- Create: `dev-loop/tests/guard_commit.Tests.ps1`

**脚本职责**（作为 Claude Code PreToolUse hook）：

1. 从 stdin 读 JSON（hook 协议），取 `tool_input.command`
2. 命令不含 `git commit` → exit 0（放行）
3. 不在 dev-loop 项目（无 `.devloop/` 目录）→ exit 0（放行）
4. commit message 含 `[skip-devloop]` → exit 0 + 追加登记到 `.devloop/progress.md` 的 Overrides 节
5. 读 `.devloop/.current_task_id` 得到当前任务 id；文件缺失 → exit 1
6. 检查 `.devloop/logs/task_<id>_research.md` 存在 → 否则 exit 1
7. 读 `.devloop/task.json` 找到当前任务的 `notes`，必须含 `CR-6:` → 否则 exit 1
8. 若 CR-6 notes 声明"有"但 `lessons.md` 当日无新条目 → exit 1
9. 调 `verify_runner.ps1` 再验一遍 `verify_cmds` → 任一失败 exit 1
10. 全部通过 → exit 0

- [ ] **Step 1: 写 Pester 失败测试**

Create `dev-loop/tests/guard_commit.Tests.ps1`:

```powershell
BeforeAll {
    $script:ScriptPath = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/guard_commit.ps1')).Path
    $script:TmpBase    = Join-Path ([System.IO.Path]::GetTempPath()) "guard-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $script:TmpBase | Out-Null
}

AfterAll {
    Remove-Item $script:TmpBase -Recurse -Force -ErrorAction SilentlyContinue
}

function New-SandboxDir {
    $d = Join-Path $script:TmpBase ("sb-" + [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    return $d
}

function Invoke-Guard {
    param([string]$StdinJson, [string]$Cwd)
    Push-Location $Cwd
    try {
        $out = $StdinJson | & pwsh -NoProfile -File $script:ScriptPath 2>&1
        return @{ ExitCode = $LASTEXITCODE; Output = ($out | Out-String) }
    } finally { Pop-Location }
}

Describe 'guard_commit.ps1 - routing' {
    It '放行非 git commit 命令' {
        $sb = New-SandboxDir
        $r = Invoke-Guard -StdinJson '{"tool_input":{"command":"ls -la"}}' -Cwd $sb
        $r.ExitCode | Should -Be 0
    }

    It '在没有 .devloop 的目录里放行 git commit（视作非管理项目）' {
        $sb = New-SandboxDir
        $r = Invoke-Guard -StdinJson '{"tool_input":{"command":"git commit -m \"x\""}}' -Cwd $sb
        $r.ExitCode | Should -Be 0
    }
}

Describe 'guard_commit.ps1 - skip-devloop override' {
    It '[skip-devloop] 命令被放行并登记 Overrides' {
        $sb = New-SandboxDir
        New-Item -ItemType Directory -Force -Path (Join-Path $sb '.devloop') | Out-Null
        Set-Content -Path (Join-Path $sb '.devloop/progress.md') -Value "# Progress`n" -Encoding utf8
        $r = Invoke-Guard -StdinJson '{"tool_input":{"command":"git commit -m \"[skip-devloop] emergency\""}}' -Cwd $sb
        $r.ExitCode | Should -Be 0
        (Get-Content (Join-Path $sb '.devloop/progress.md') -Raw) | Should -Match '## Overrides'
    }
}

Describe 'guard_commit.ps1 - enforcement gates' {
    BeforeEach {
        $script:SB = New-SandboxDir
        New-Item -ItemType Directory -Force -Path (Join-Path $script:SB '.devloop/logs') | Out-Null
    }

    It '缺 .current_task_id 时拒绝' {
        $r = Invoke-Guard -StdinJson '{"tool_input":{"command":"git commit -m x"}}' -Cwd $script:SB
        $r.ExitCode | Should -Not -Be 0
        $r.Output   | Should -Match 'current_task_id'
    }

    It '缺 research.md 时拒绝' {
        Set-Content -Path (Join-Path $script:SB '.devloop/.current_task_id') -Value 'T-001' -NoNewline -Encoding ascii
        $r = Invoke-Guard -StdinJson '{"tool_input":{"command":"git commit -m x"}}' -Cwd $script:SB
        $r.ExitCode | Should -Not -Be 0
        $r.Output   | Should -Match 'research\.md'
    }

    It '缺 CR-6 notes 时拒绝' {
        Set-Content -Path (Join-Path $script:SB '.devloop/.current_task_id') -Value 'T-001' -NoNewline -Encoding ascii
        Set-Content -Path (Join-Path $script:SB '.devloop/logs/task_T-001_research.md') -Value '# research' -Encoding utf8
        $taskJson = @{ schemaVersion='1.0'; project=@{name='x';mainBranch='main';createdAt='2026-04-26T00:00:00Z';lastRunAt=$null}; tasks=@(
            @{id='T-001';title='x';description='';steps=@();estimated_files=1;depends_on=@();category='feat';scope='p';verify_cmds=@('exit 0');passes=$false;attempts=1;blocked=$false;blockReason='';lastError='';notes='';startedAt=$null;completedAt=$null}
        ) } | ConvertTo-Json -Depth 10
        Set-Content -Path (Join-Path $script:SB '.devloop/task.json') -Value $taskJson -Encoding utf8
        Set-Content -Path (Join-Path $script:SB '.devloop/config.json') -Value '{"verify":{"globalCmds":[]}}' -Encoding utf8
        $r = Invoke-Guard -StdinJson '{"tool_input":{"command":"git commit -m x"}}' -Cwd $script:SB
        $r.ExitCode | Should -Not -Be 0
        $r.Output   | Should -Match 'CR-6'
    }

    It '完整 gate 通过时放行' {
        Set-Content -Path (Join-Path $script:SB '.devloop/.current_task_id') -Value 'T-001' -NoNewline -Encoding ascii
        Set-Content -Path (Join-Path $script:SB '.devloop/logs/task_T-001_research.md') -Value '# research' -Encoding utf8
        $taskJson = @{ schemaVersion='1.0'; project=@{name='x';mainBranch='main';createdAt='2026-04-26T00:00:00Z';lastRunAt=$null}; tasks=@(
            @{id='T-001';title='x';description='';steps=@();estimated_files=1;depends_on=@();category='feat';scope='p';verify_cmds=@('exit 0');passes=$true;attempts=1;blocked=$false;blockReason='';lastError='';notes='CR-6: 超出描述=无 / 过度抽象=无 / 更简替代=无';startedAt=$null;completedAt=$null}
        ) } | ConvertTo-Json -Depth 10
        Set-Content -Path (Join-Path $script:SB '.devloop/task.json') -Value $taskJson -Encoding utf8
        Set-Content -Path (Join-Path $script:SB '.devloop/config.json') -Value '{"verify":{"globalCmds":["exit 0"]}}' -Encoding utf8
        # 需要 verify_runner.ps1 可被 guard_commit 加载；复制到 sandbox
        $libDst = Join-Path $script:SB '.devloop/scripts/lib'
        New-Item -ItemType Directory -Force -Path $libDst | Out-Null
        Copy-Item (Join-Path (Split-Path $script:ScriptPath) 'lib/verify_runner.ps1') $libDst
        # guard_commit 自身也复制到 sandbox 以便相对路径 dot-source lib
        Copy-Item $script:ScriptPath (Join-Path $script:SB '.devloop/scripts/guard_commit.ps1')
        # 用 sandbox 内的 guard 跑
        Push-Location $script:SB
        try {
            $out = '{"tool_input":{"command":"git commit -m x"}}' | & pwsh -NoProfile -File '.devloop/scripts/guard_commit.ps1' 2>&1
            $LASTEXITCODE | Should -Be 0
        } finally { Pop-Location }
    }
}
```

- [ ] **Step 2: 运行测试验证失败**

```powershell
cd dev-loop
Invoke-Pester -Path tests/guard_commit.Tests.ps1 -Output Detailed
```
Expected: 大部分 `Failed`（脚本不存在）

- [ ] **Step 3: 写实现**

Create `dev-loop/scripts/guard_commit.ps1`:

```powershell
# dev-loop/scripts/guard_commit.ps1
# Claude Code PreToolUse hook: 拦截未通过 CR Gates 的 git commit
# stdin: JSON { tool_input: { command: "<shell cmd>" } }
# exit 0 = 放行 / exit != 0 = 拒绝

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# === 1. 读 stdin hook 协议 ===
$stdin = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($stdin)) { exit 0 }
try { $req = $stdin | ConvertFrom-Json } catch { exit 0 }

$cmd = ''
if ($req.tool_input -and $req.tool_input.PSObject.Properties['command']) {
    $cmd = [string]$req.tool_input.command
}

# === 2. 只管 git commit ===
if ($cmd -notmatch '\bgit\s+commit\b') { exit 0 }

# === 3. 非 dev-loop 项目放行 ===
if (-not (Test-Path '.devloop')) { exit 0 }

# === 4. [skip-devloop] 豁免 ===
if ($cmd -match '\[skip-devloop\]') {
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm'
    $reason = '(no reason)'
    if ($cmd -match '\[skip-devloop\]\s*([^"'']*)') {
        $reason = $Matches[1].Trim()
        if ([string]::IsNullOrWhiteSpace($reason)) { $reason = '(no reason)' }
    }
    $progressPath = '.devloop/progress.md'
    if (-not (Test-Path $progressPath)) {
        Set-Content -Path $progressPath -Value "# Progress`n" -Encoding utf8
    }
    $content = Get-Content $progressPath -Raw
    if ($content -notmatch '## Overrides') {
        Add-Content -Path $progressPath -Value "`n## Overrides`n" -Encoding utf8
    }
    Add-Content -Path $progressPath -Value "- $ts - skip-devloop - $reason" -Encoding utf8
    exit 0
}

# === 5. 读当前 task id ===
$taskIdPath = '.devloop/.current_task_id'
if (-not (Test-Path $taskIdPath)) {
    Write-Error 'guard_commit: 未找到 .devloop/.current_task_id，无法判定当前任务。请通过 run.ps1 驱动或手动写入该文件。'
    exit 1
}
$taskId = (Get-Content $taskIdPath -Raw).Trim()

# === 6. research.md 必须存在 ===
$researchPath = ".devloop/logs/task_${taskId}_research.md"
if (-not (Test-Path $researchPath)) {
    Write-Error "guard_commit: 缺 CR-5 查证记录：$researchPath"
    exit 1
}

# === 7. task.json 中 notes 必须含 CR-6 ===
$taskJsonPath = '.devloop/task.json'
if (-not (Test-Path $taskJsonPath)) {
    Write-Error 'guard_commit: 缺 .devloop/task.json'
    exit 1
}
$data = Get-Content $taskJsonPath -Raw | ConvertFrom-Json
$currentTask = $data.tasks | Where-Object { $_.id -eq $taskId } | Select-Object -First 1
if (-not $currentTask) {
    Write-Error "guard_commit: task.json 中未找到 id=$taskId"
    exit 1
}
if ([string]::IsNullOrEmpty([string]$currentTask.notes) -or [string]$currentTask.notes -notmatch 'CR-6:') {
    Write-Error "guard_commit: 任务 $taskId 的 notes 缺少 CR-6 自省结论（需形如 'CR-6: 超出描述=无 / 过度抽象=无 / 更简替代=无'）"
    exit 1
}

# === 8. CR-6 声明"有"时，lessons.md 当日必须有新追加 ===
if ([string]$currentTask.notes -match 'CR-6:[^\r\n]*有') {
    $today = Get-Date -Format 'yyyy-MM-dd'
    $lessonsPath = '.devloop/lessons.md'
    $hasToday = (Test-Path $lessonsPath) -and ((Get-Content $lessonsPath -Raw) -match "## $today")
    if (-not $hasToday) {
        Write-Error "guard_commit: CR-6 声明有问题，但 .devloop/lessons.md 当日（$today）无新条目"
        exit 1
    }
}

# === 9. verify_cmds 复验 ===
$libPath = Join-Path $PSScriptRoot 'lib/verify_runner.ps1'
if (-not (Test-Path $libPath)) {
    Write-Error "guard_commit: 缺 verify_runner.ps1 （预期路径：$libPath）"
    exit 1
}
. $libPath
$configPath = '.devloop/config.json'
if (-not (Test-Path $configPath)) {
    Write-Error 'guard_commit: 缺 .devloop/config.json'
    exit 1
}
$config = Get-Content $configPath -Raw | ConvertFrom-Json
if (-not (Invoke-VerifyRunner -Task $currentTask -Config $config)) {
    Write-Error 'guard_commit: verify_cmds 复验失败，拒绝提交'
    exit 1
}

exit 0
```

- [ ] **Step 4: 运行测试验证通过**

```powershell
cd dev-loop
Invoke-Pester -Path tests/guard_commit.Tests.ps1 -Output Detailed
```
Expected: `Tests Passed: 7, Failed: 0`（7 个 It 块全过）

- [ ] **Step 5: Commit**

```powershell
git add dev-loop/scripts/guard_commit.ps1 dev-loop/tests/guard_commit.Tests.ps1
git commit -m "feat(dev-loop): 新增 guard_commit hook 与 Pester 测试

Claude Code PreToolUse hook，在 git commit 前强制 gate：
- 非 commit / 非 dev-loop 项目放行
- [skip-devloop] 豁免并登记 Overrides
- 必须存在 .current_task_id + research.md
- task.notes 必须含 CR-6 结论
- CR-6 声明有问题时 lessons.md 当日必须有新条目
- verify_cmds 脚本复验（不信 Claude 自报）"
```

## Task 8: scripts/run.ps1（Pester TDD）

**Files:**
- Create: `dev-loop/scripts/run.ps1`
- Create: `dev-loop/tests/run.Tests.ps1`

**脚本职责**：主循环驱动器。前置 guard → 选任务 → attempt 循环 → 脚本独立复验 → commit / rollback → 循环或停止。

**测试边界**：`Invoke-HeadlessClaude` 依赖真 `claude` 可执行文件，整段 `attempt` 循环留给 Task 13 dogfood 覆盖。本任务的 Pester 测试只覆盖 `Assert-*` 前置 guard 函数。run.ps1 暴露 `-LoadFunctionsOnly` 开关，让测试只 dot-source 函数定义而不启动循环。

- [ ] **Step 1: 写 Pester 失败测试**

Create `dev-loop/tests/run.Tests.ps1`:

```powershell
BeforeAll {
    $script:RunPath = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/run.ps1')).Path
    # 只加载函数定义，不跑主循环
    . $script:RunPath -LoadFunctionsOnly
    $script:TmpBase = Join-Path ([System.IO.Path]::GetTempPath()) "runps1-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $script:TmpBase | Out-Null
}

AfterAll {
    Remove-Item $script:TmpBase -Recurse -Force -ErrorAction SilentlyContinue
}

function New-GitRepo {
    param([string]$Branch = 'dev', [switch]$Dirty, [switch]$NoDevLoop)
    $d = Join-Path $script:TmpBase ("r-" + [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    Push-Location $d
    try {
        git init -q --initial-branch=main
        git config user.email 'test@example.com'
        git config user.name 'test'
        'init' | Out-File README.md -Encoding utf8
        git add README.md
        git commit -q -m 'init'
        if ($Branch -ne 'main') { git checkout -q -b $Branch }
        if (-not $NoDevLoop) {
            New-Item -ItemType Directory -Force -Path '.devloop/scripts/lib' | Out-Null
            '{"schemaVersion":"1.0","project":{"name":"t","mainBranch":"main","createdAt":"2026-04-26T00:00:00Z","lastRunAt":null},"tasks":[]}' |
                Out-File '.devloop/task.json' -Encoding utf8
            '{"verify":{"globalCmds":[]},"limits":{"maxFilesPerTask":5}}' |
                Out-File '.devloop/config.json' -Encoding utf8
        }
        if ($Dirty) { 'dirty' | Out-File 'dirty.txt' -Encoding utf8 }
    } finally { Pop-Location }
    return $d
}

Describe 'Assert-GitClean' {
    It '干净 repo 通过' {
        $d = New-GitRepo
        Push-Location $d
        try { { Assert-GitClean } | Should -Not -Throw } finally { Pop-Location }
    }
    It '脏 repo 抛异常' {
        $d = New-GitRepo -Dirty
        Push-Location $d
        try { { Assert-GitClean } | Should -Throw '*not clean*' } finally { Pop-Location }
    }
}

Describe 'Assert-BranchNotMain' {
    It '非 main 分支通过' {
        $d = New-GitRepo -Branch dev
        Push-Location $d
        try { { Assert-BranchNotMain } | Should -Not -Throw } finally { Pop-Location }
    }
    It 'main 抛异常' {
        $d = New-GitRepo -Branch main
        Push-Location $d
        try { { Assert-BranchNotMain } | Should -Throw '*main*' } finally { Pop-Location }
    }
}

Describe 'Assert-DevLoopInitialized' {
    It '缺 .devloop 抛异常' {
        $d = New-GitRepo -NoDevLoop
        Push-Location $d
        try { { Assert-DevLoopInitialized } | Should -Throw '*not initialized*' } finally { Pop-Location }
    }
    It '有 .devloop/task.json 通过' {
        $d = New-GitRepo
        Push-Location $d
        try { { Assert-DevLoopInitialized } | Should -Not -Throw } finally { Pop-Location }
    }
}
```

- [ ] **Step 2: 运行测试验证失败**

```powershell
cd dev-loop
Invoke-Pester -Path tests/run.Tests.ps1 -Output Detailed
```
Expected: 6 个 `Failed`（函数未定义）

- [ ] **Step 3: 写实现**

Create `dev-loop/scripts/run.ps1`:

```powershell
# dev-loop/scripts/run.ps1
# 主循环驱动器：选任务 -> 调 headless Claude -> 脚本复验 -> commit/rollback -> 循环

[CmdletBinding()]
param(
    [int]$MaxTasks = 0,
    [int]$MaxConsecBlocked = 3,
    [int]$MaxAttemptsPerTask = 3,
    [switch]$DryRun,
    [switch]$LoadFunctionsOnly     # 测试钩子：只 dot-source 函数定义
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# === 加载 lib ===
$libDir = Join-Path $PSScriptRoot 'lib'
. (Join-Path $libDir 'task_picker.ps1')
. (Join-Path $libDir 'verify_runner.ps1')
. (Join-Path $libDir 'claude_invoker.ps1')

# === 前置 guards ===
function Assert-GitClean {
    $status = git status --porcelain
    if ($LASTEXITCODE -ne 0) { throw 'not a git repo' }
    if ($status) { throw "working tree is not clean:`n$status" }
}

function Assert-BranchNotMain {
    $branch = (git branch --show-current).Trim()
    if ($branch -in @('main', 'master')) {
        throw "refuse to run on protected branch: $branch"
    }
}

function Assert-DevLoopInitialized {
    if (-not (Test-Path '.devloop/task.json') -or -not (Test-Path '.devloop/config.json')) {
        throw '.devloop is not initialized — run `/dev-loop init` first'
    }
}

# === 工具函数 ===
function Update-TaskField {
    param(
        [Parameter(Mandatory)][string]$Id,
        [hashtable]$Fields
    )
    $path = '.devloop/task.json'
    $data = Get-Content $path -Raw | ConvertFrom-Json
    $task = $data.tasks | Where-Object { $_.id -eq $Id } | Select-Object -First 1
    if (-not $task) { throw "task $Id not found" }
    foreach ($k in $Fields.Keys) {
        if ($task.PSObject.Properties[$k]) {
            $task.$k = $Fields[$k]
        } else {
            Add-Member -InputObject $task -NotePropertyName $k -NotePropertyValue $Fields[$k] -Force
        }
    }
    $data | ConvertTo-Json -Depth 20 | Set-Content -Path $path -Encoding utf8
}

function Append-Progress {
    param([string]$Line)
    $path = '.devloop/progress.md'
    if (-not (Test-Path $path)) {
        Set-Content -Path $path -Value "# Progress`n" -Encoding utf8
    }
    $today = Get-Date -Format 'yyyy-MM-dd'
    $content = Get-Content $path -Raw
    if ($content -notmatch "## $today") {
        Add-Content -Path $path -Value "`n## $today`n`n| Time  | Task  | Title | Status | Attempts | Notes |`n|-------|-------|-------|--------|----------|-------|" -Encoding utf8
    }
    Add-Content -Path $path -Value $Line -Encoding utf8
}

function Build-CommitMessage {
    param([object]$Task, [object]$Config)
    $tpl = $Config.git.commitTemplate
    $verifyCmds = ($Task.verify_cmds -join ', ')
    $tpl = $tpl.Replace('{category}', [string]$Task.category)
    $tpl = $tpl.Replace('{scope}',    [string]$Task.scope)
    $tpl = $tpl.Replace('{title}',    [string]$Task.title)
    $tpl = $tpl.Replace('{id}',       [string]$Task.id)
    $tpl = $tpl.Replace('{attempts}', [string]$Task.attempts)
    $tpl = $tpl.Replace('{verifyCmds}', $verifyCmds)
    return $tpl
}

function Get-LastError {
    param([string]$LogPath)
    if (-not (Test-Path $LogPath)) { return '(no log)' }
    $lines = Get-Content $LogPath -Tail 30
    return ($lines -join "`n")
}

# 测试钩子：不启动主循环
if ($LoadFunctionsOnly) { return }

# === 主循环 ===
Assert-GitClean
Assert-BranchNotMain
Assert-DevLoopInitialized
Assert-TaskJsonValid -Path '.devloop/task.json' -MaxFiles 5

$cfg = Get-Content '.devloop/config.json' -Raw | ConvertFrom-Json
$consecBlocked = 0
$done = 0

while ($true) {
    $task = Select-NextTask -Path '.devloop/task.json'
    if (-not $task) { Write-Host '✓ 全部任务完成'; break }

    Write-Host ""
    Write-Host ">>> 任务 $($task.id): $($task.title)"

    if ($DryRun) {
        Write-Host '[DryRun] 跳过 attempt 循环'
        $done++
        if ($MaxTasks -gt 0 -and $done -ge $MaxTasks) { break }
        continue
    }

    $verified = $false
    for ($attempt = 1; $attempt -le $MaxAttemptsPerTask; $attempt++) {

        # 2a. 写当前 task id（供 guard_commit 读）
        Set-Content -Path '.devloop/.current_task_id' -Value $task.id -NoNewline -Encoding ascii

        # 2b. 构造 prompt
        $prevLog = ".devloop/logs/task_$($task.id)_attempt_$($attempt - 1).log"
        $prompt  = Build-Prompt -TaskId $task.id -Attempt $attempt -PrevLogPath $prevLog -MaxAttempts $MaxAttemptsPerTask

        # 2c. 调 headless Claude
        $logPath = ".devloop/logs/task_$($task.id)_attempt_$attempt.log"
        $timeout = $cfg.limits.claudeTimeoutSec
        $exitCode = Invoke-HeadlessClaude -Prompt $prompt -LogPath $logPath -TimeoutSec $timeout

        # 2d. 重新载入 task（Claude 可能写过）
        $data = Get-Content '.devloop/task.json' -Raw | ConvertFrom-Json
        $task = $data.tasks | Where-Object { $_.id -eq $task.id } | Select-Object -First 1

        # 2e. 脚本独立复验
        $verified = Invoke-VerifyRunner -Task $task -Config $cfg
        if ($verified) { break }

        # 2f. 失败 -> 回滚工作区 + 记录 lastError
        git restore . *>&1 | Out-Null
        git clean -fd *>&1 | Out-Null
        Update-TaskField -Id $task.id -Fields @{
            attempts  = $attempt
            lastError = Get-LastError -LogPath $logPath
        }
    }

    # 清理 current_task_id
    Remove-Item '.devloop/.current_task_id' -ErrorAction SilentlyContinue

    # === 结果判定 ===
    $ts = Get-Date -Format 'HH:mm'
    if ($verified) {
        git add -A
        $msg = Build-CommitMessage -Task $task -Config $cfg
        git commit -m $msg | Out-Null
        Update-TaskField -Id $task.id -Fields @{ passes = $true; completedAt = (Get-Date).ToString('o') }
        Append-Progress "| $ts | $($task.id) | $($task.title) | ✓ done | $($task.attempts) | — |"
        $consecBlocked = 0
        $done++
    }
    else {
        $reason = if ($task.blockReason) { [string]$task.blockReason } else { 'attempts exhausted' }
        Update-TaskField -Id $task.id -Fields @{ blocked = $true; blockReason = $reason }
        Append-Progress "| $ts | $($task.id) | $($task.title) | ✗ blocked | $MaxAttemptsPerTask | $reason |"
        $consecBlocked++
        if ($consecBlocked -ge $MaxConsecBlocked) {
            Write-Error "连续 $MaxConsecBlocked 个任务 blocked，整体停止"
            exit 2
        }
    }

    if ($MaxTasks -gt 0 -and $done -ge $MaxTasks) { break }
}

Write-Host ""
Write-Host "完成: $done 任务"
$blockedCount = ((Get-Content '.devloop/task.json' -Raw | ConvertFrom-Json).tasks | Where-Object { $_.blocked }).Count
Write-Host "Blocked: $blockedCount"
Write-Host "查看进度: .devloop/progress.md"
```

- [ ] **Step 4: 运行 Pester 验证通过**

```powershell
cd dev-loop
Invoke-Pester -Path tests/run.Tests.ps1 -Output Detailed
```
Expected: `Tests Passed: 6, Failed: 0`

- [ ] **Step 5: Smoke test `-DryRun`（手工）**

在 tmp 目录建最小 dev-loop 仓库跑一次 `-DryRun`，验证主循环不炸：

```powershell
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) "smoke-$(Get-Random)"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
Push-Location $tmp
try {
    git init -q --initial-branch=main
    git config user.email 'test@example.com'
    git config user.name 'test'
    'init' | Out-File README.md -Encoding utf8
    git add README.md; git commit -q -m init
    git checkout -q -b dev
    New-Item -ItemType Directory -Force -Path .devloop | Out-Null
    @'
{
  "schemaVersion": "1.0",
  "project": {"name":"smoke","mainBranch":"main","createdAt":"2026-04-26T00:00:00Z","lastRunAt":null},
  "tasks": [
    {"id":"T-001","title":"smoke","description":"","steps":[],"estimated_files":1,"depends_on":[],"category":"chore","scope":"p","verify_cmds":["exit 0"],"passes":false,"attempts":0,"blocked":false,"blockReason":"","lastError":"","notes":"","startedAt":null,"completedAt":null}
  ]
}
'@ | Out-File .devloop/task.json -Encoding utf8
    '{"verify":{"globalCmds":[]},"limits":{"maxFilesPerTask":5,"claudeTimeoutSec":60},"git":{"commitTemplate":"{category}({scope}): {title}"}}' |
        Out-File .devloop/config.json -Encoding utf8
    & pwsh -NoProfile -File C:\Users\xiybh\.claude\skills\dev-loop\scripts\run.ps1 -DryRun -MaxTasks 1
} finally {
    Pop-Location
    Remove-Item $tmp -Recurse -Force
}
```
Expected: 输出 `>>> 任务 T-001` 和 `[DryRun] 跳过 attempt 循环`，exit 0

- [ ] **Step 6: Commit**

```powershell
git add dev-loop/scripts/run.ps1 dev-loop/tests/run.Tests.ps1
git commit -m "feat(dev-loop): 新增 run.ps1 主循环驱动器与 Pester 测试

- 前置 guards: Assert-GitClean / BranchNotMain / DevLoopInitialized / TaskJsonValid
- attempt 循环: 写 .current_task_id -> Build-Prompt -> Invoke-HeadlessClaude -> 复验
- 失败自动回滚: git restore . + git clean -fd；记录 lastError
- 成功 commit: 用 config.git.commitTemplate 模板
- 连续 3 blocked 停止 (a2+b1+c1 策略)
- -DryRun 支持干跑，-LoadFunctionsOnly 供 Pester 单测钩子"
```

## Task 9: RUN.md（headless Claude 单任务协议）

**Files:**
- Create: `dev-loop/RUN.md`

- [ ] **Step 1: 写 RUN.md 完整内容**

内容直接来自 spec §5.2 末段。Create `dev-loop/RUN.md`:

```markdown
# RUN.md — 单任务执行协议

当 `run.ps1` 启动你时，严格按以下 7 步执行。不得跳步。

## 1. 必读清单（冷启动上下文重建）

按顺序读取：
- `.devloop/task.json` → 定位 id=`<TASK_ID>` 的任务
- `architecture.md` → 项目架构与 [A/B/C] 证据等级
- `CLAUDE.md` → 工作流规则
- `.devloop/lessons.md` → 历史避坑经验（必读）
- `.devloop/logs/task_<TASK_ID>_attempt_<N-1>.log`（若 attempt > 1）

## 2. CR-5：任务启动前批判性审查

列出本任务要用到的所有非标准 API / 库 / 配置。
每一项回答：「我是训练数据里记得，还是真的查证过？」
不确定项必须：

  a. context7 MCP 查 latest docs（若 `config.claude.mcp.context7Available=true`）
  b. 无命中或 MCP 不可用 → WebSearch
  c. 仍无 → 读项目源码

查证记录落盘到 `.devloop/logs/task_<TASK_ID>_research.md`。
若本任务所有 API 均来自 architecture.md 的 [A] 级选型，写 `## NO_RESEARCH_NEEDED` 章节并给出依据。

## 3. 实现

- 严格按 `task.steps` 实现
- 不得超过 `task.estimated_files` 文件数（超出必须在 `task.notes` 写明原因）
- 不得偏离 `task.description` 范围
- 如果发现 `architecture.md` 有错 → 停止实现，在 `task.lastError` 写「架构需修订：...」退出

## 4. 自我验证（非正式）

跑 `task.verify_cmds` 每条命令。任何失败 → 定位 → 修复 → 重跑。
注意：这是你的自检，`run.ps1` 会独立再跑一次以最终裁决。

## 5. CR-6：commit 前批判性审查

回答 3 个问题：
  ① 改动有没有超出任务描述？           → 是 → revert 多余
  ② 有没有引入过度抽象 / 过度工程？    → 是 → 简化
  ③ 有没有更简单的替代实现？           → 是 → 回到原点重做

任何"是"必须调整，并在 `.devloop/lessons.md` 追加一条记录。

## 6. 汇报

更新 `.devloop/task.json` 中 id=`<TASK_ID>` 的条目：
- `passes`      = true / false（你的自判，脚本会复核）
- `attempts`    = 当前 attempt
- `lastError`   = 失败时具体原因
- `blockReason` = 若任务无法完成，写明根因
- `notes`       = `"CR-6: 超出描述=<无/有...> / 过度抽象=<...> / 更简替代=<...>"`

不要运行 `git add` / `git commit` / `git push` —— 这些由 `run.ps1` 完成。

## 7. 退出

执行完毕直接退出。`run.ps1` 会读取 `task.json` 和 `verify_cmds` 结果做最终判定。
```

- [ ] **Step 2: 验证关键 section 存在**

```powershell
$req = @('## 1. 必读清单', '## 2. CR-5', '## 3. 实现', '## 4. 自我验证', '## 5. CR-6', '## 6. 汇报', '## 7. 退出')
$c = Get-Content dev-loop/RUN.md -Raw
foreach ($s in $req) {
    if ($c -notmatch [regex]::Escape($s)) { throw "Missing: $s" }
}
'All 7 steps present'
```
Expected: `All 7 steps present`

- [ ] **Step 3: Commit**

```powershell
git add dev-loop/RUN.md
git commit -m "feat(dev-loop): 新增 RUN.md headless Claude 单任务 7 步协议

含必读清单、CR-5 查证、实现约束、CR-6 自省、task.json 汇报契约。"
```

---

## Task 10: INIT.md（四段对话协议）

**Files:**
- Create: `dev-loop/INIT.md`

- [ ] **Step 1: 写 INIT.md 完整内容**

内容来自 spec §5.1。Create `dev-loop/INIT.md`:

```markdown
# INIT.md — 四段对话初始化协议

当用户执行 `/dev-loop init`（在目标项目根目录）时，严格按 4 段走，每段末用户审批后推进。

## 段 1：目标 & 测试判定规则

按顺序问 6 组问题，每组 1–2 问：

| # | 问 | 目的 |
|---|---|---|
| Q1 | 项目用途、目标用户、MVP 范围 | 明确 scope |
| Q2 | 技术栈（语言/框架/运行时） | 为段 2 定锚 |
| Q3 | **测试判定规则**（按项目形态分类） | 核心，见下 |
| Q4 | commit category 枚举 | feat/fix/refactor/docs/test/chore |
| Q5 | git 主分支名、远程情况 | 供提交和 guard 使用 |
| Q6 | 是否已配置 context7 MCP | 决定 CR-5 查证流程 |

### Q3 细分（按项目形态）

- **自动化命令**（必填）：lint / typecheck / unit test / build 各自的命令
- **UI/浏览器测试**（若适用）：「控制台 0 error」+「指定元素存在」+「截图存档」
- **后端 API 测试**（若适用）：「指定 endpoint 返回预期 schema」+「exit code 0」
- **UE 插件**（若适用）：「RunUAT BuildPlugin 成功」+「Editor 启动无 log warning」
- **手动验证**（兜底）：每次怎么确认的清单

### CR-1 触发

答案里出现「随便 / 你看着办 / 不确定 / 应该 / 可能」任一词 →  
**必须**进入查证模式（context7 / WebSearch）再给建议。

### 落盘

暂存结构化 JSON 到 `.devloop/init/stage1.json`，**不写** `architecture.md`。用户审批后进段 2。

## 段 2：architecture.md + CR-2 证据等级

1. 读 `stage1.json`
2. 生成 `architecture.md` 草稿，**每个技术决策必须标** `[A/B/C]` 等级
3. **CR-2 自动触发**：扫描所有 `[C]`，逐个升级流程：
   - `context7` 查 latest docs → 升级到 A 或降级
   - 无命中 → `WebSearch` → 升级到 B
   - 仍无 → 明确标 `[C — 未验证]` 并写入 `lessons.md`
4. 查证产物落盘 `.devloop/init/decisions.json`
5. 交用户审；落盘 `architecture.md` 到项目根

## 段 3：task.json + CR-3 拆分自检

1. 读 `architecture.md` + `decisions.json`
2. 按粗粒度 + 单任务 ≤ 5 文件拆分
3. 每条 task schema（见 spec §6.1）必须完整
4. **CR-3 自动触发**：自问 4 问题
   - `estimated_files > 5`？
   - 依赖图有环？
   - 两任务改动重叠？
   - `verify_cmds` 非空且可执行？
5. 任一未通过 → 重拆并重跑 CR-3
6. 交用户审；落盘 `.devloop/task.json`

## 段 4：配套文件 + CR-4 命令验证

一次性生成：

| 生成物 | 来源 |
|---|---|
| `CLAUDE.md`（根） | `templates/CLAUDE.md.tpl` + 前三段产物 |
| `.devloop/config.json` | `templates/config.json.tpl` + Q3 verify_cmds |
| `.devloop/scripts/run.ps1` | 从 skill scripts 拷贝 |
| `.devloop/scripts/guard_commit.ps1` | 从 skill scripts 拷贝 |
| `.devloop/scripts/lib/*.ps1` | 从 skill scripts/lib 拷贝 |
| `.claude/settings.json` | `templates/claude-settings.json.tpl` |
| `.gitignore`（追加） | `templates/gitignore.tpl` |
| `.devloop/progress.md` | 模板初始化为空 |
| `.devloop/lessons.md` | 模板初始化为空 |

**CR-4 自动触发**：对 `config.json` 每条命令做两类验证：

1. **可执行程序检测**：提取首个 token（`npm run build` → `npm`），跑 `<token> --version`
2. **Script/任务存在性**：
   - npm scripts → 解析 `package.json.scripts`
   - make targets → 解析 `Makefile`
   - 其他复合命令 → `cmd_check.json` 标 `unverifiable:true`，留给 run.ps1 首次运行兜底

失败项写入 `.devloop/init/cmd_check.json` `status:fail`，必须让用户澄清或修正。

### 段 4 收尾

```powershell
git add -A
git commit -m "chore(dev-loop): 初始化 dev-loop harness

- architecture.md: 架构与证据等级
- .devloop/task.json: <N> 个粗粒度任务
- CLAUDE.md: 工作流定义
- .devloop/scripts/run.ps1: 循环驱动器"
```

输出给用户：

```
✓ init 完成，<N> 个任务已就绪
  查看架构：architecture.md
  查看任务：.devloop/task.json

开始循环执行：
  .\.devloop\scripts\run.ps1

建议先干跑验证一次：
  .\.devloop\scripts\run.ps1 -DryRun -MaxTasks 1
```
```

- [ ] **Step 2: 验证 4 段结构存在**

```powershell
$req = @('## 段 1', '## 段 2', '## 段 3', '## 段 4', 'CR-1 触发', 'CR-2 自动触发', 'CR-3 自动触发', 'CR-4 自动触发')
$c = Get-Content dev-loop/INIT.md -Raw
foreach ($s in $req) {
    if ($c -notmatch [regex]::Escape($s)) { throw "Missing: $s" }
}
'All 4 stages + 4 CR gates present'
```
Expected: `All 4 stages + 4 CR gates present`

- [ ] **Step 3: Commit**

```powershell
git add dev-loop/INIT.md
git commit -m "feat(dev-loop): 新增 INIT.md 四段对话协议

含段 1-4 顺序（目标+测试规则 / architecture / task.json / 脚本配置）
与 CR-1~CR-4 每段末强制审查。内容按 spec §5.1。"
```

---

## Task 11: CRITICAL_REVIEW.md（6 个 Gate 完整准则）

**Files:**
- Create: `dev-loop/CRITICAL_REVIEW.md`

- [ ] **Step 1: 写 CRITICAL_REVIEW.md 完整内容**

内容来自 spec §7。Create `dev-loop/CRITICAL_REVIEW.md`:

```markdown
# CRITICAL_REVIEW.md — 6 个批判性审查闸门

## 四层强制原则

任何 skill 规则都不应仅依赖 prompt。6 个 CR Gate 按四层叠加：

| 层 | 机制 | 防的 |
|---|---|---|
| 1 | Prompt 硬条文（INIT/RUN.md） | 模型遗忘 |
| 2 | Schema 必填字段（文件结构要求字段非空） | 模型敷衍写"done" |
| 3 | 产物文件存在性（可 Test-Path 的工件） | 模型声称做过但没做 |
| 4 | Git hook 拦截（guard_commit.ps1） | 模型绕开工件直接提交 |

每个 gate **至少**有 2 层保护；层 3 和层 4 是结构性强制，不依赖 Claude 自觉。

---

## 6 Gate × 4 层机制对照

| Gate | 位置 | 层 1 Prompt | 层 2 Schema | 层 3 工件 | 层 4 Guard |
|---|---|---|---|---|---|
| CR-1 | init 段 1 后 | INIT.md §1 | `stage1.json.uncertainties` 必存在 | `research-stage1.md` | Claude 自检覆盖面 |
| CR-2 | init 段 2 落盘前 | INIT.md §2 | `architecture.md` 每行含 `[A-C]` 正则 | `decisions.json` | `Select-String "\[C\]"` 自检 |
| CR-3 | init 段 3 后 | INIT.md §3 | `estimated_files ≤ maxFilesPerTask` | task.json 本身 | `run.ps1` 启动 guard |
| CR-4 | init 段 4 后 | INIT.md §4 | `cmd_check.json.status` 必有 | `cmd_check.json` | run.ps1 首次复验 |
| CR-5 | run 每任务启动前 | RUN.md §2 | `research.md` 章节非空或 NO_RESEARCH_NEEDED | `task_<id>_research.md` | `guard_commit.ps1` |
| CR-6 | run 每任务 commit 前 | RUN.md §5 | `task.notes` 含 CR-6 字段 | lessons.md 当日条目 | `guard_commit.ps1` |

---

## CR-5 的 `NO_RESEARCH_NEEDED` 诚实出口

允许 `task_<id>_research.md` 只含一个章节：

```markdown
## NO_RESEARCH_NEEDED

本任务所有 API 均来自 architecture.md 的 [A] 级选型：
- Prisma client: architecture.md §技术栈 [A]
- Fastify route: architecture.md §技术栈 [A]

无新增不确定项。
```

**为什么允许**：避免模型为应付规则而水查证。诚实"无需查证"+ 给出引用依据，优于虚假的走过场。

---

## `[skip-devloop]` 豁免机制

commit message 以 `[skip-devloop]` 开头 → `guard_commit.ps1` 放行。
供紧急情况（如 stash 半成品到 WIP 分支）。
豁免本身会被记录到 `.devloop/progress.md` 的「Overrides」章节，供审计。

---

## 证据等级（A/B/C）

| 等级 | 含义 | 典型来源 |
|---|---|---|
| A | 官方文档 / 源码验证 | context7 命中、官方 docs、GitHub release note、源码行号 |
| B | 开源项目广泛实践 | 主流库使用案例、技术博客权威文章、Stack Overflow high-vote |
| C | 训练数据假设 | Claude 凭印象给出，未经实时验证 |

CR-2 规则：**所有 C 级必须升级到 A/B 才能落盘 `architecture.md`**，除非显式标 `[C — 未验证]` 并写入 `lessons.md` 登记未来复查触发条件。
```

- [ ] **Step 2: 验证关键 section 存在**

```powershell
$req = @('四层强制原则', '6 Gate', 'NO_RESEARCH_NEEDED', 'skip-devloop', '证据等级')
$c = Get-Content dev-loop/CRITICAL_REVIEW.md -Raw
foreach ($s in $req) {
    if ($c -notmatch [regex]::Escape($s)) { throw "Missing: $s" }
}
'All sections present'
```
Expected: `All sections present`

- [ ] **Step 3: Commit**

```powershell
git add dev-loop/CRITICAL_REVIEW.md
git commit -m "feat(dev-loop): 新增 CRITICAL_REVIEW.md 6 gate 判定准则

含四层强制原则、6 gate × 4 层对照表、CR-5 诚实出口、
skip-devloop 豁免、证据等级 A/B/C 判定。内容按 spec §7。"
```

## Task 12: references/ 六份参考文档

**Files:**
- Create: `dev-loop/references/schemas.md`
- Create: `dev-loop/references/failure-playbook.md`
- Create: `dev-loop/references/headless-gotchas.md`
- Create: `dev-loop/references/evidence-levels.md`
- Create: `dev-loop/references/task-granularity.md`
- Create: `dev-loop/references/ROADMAP.md`

**设计原则**：`references/` 是 Claude **按需**查阅的底层参考资料，不默认加载到上下文。每份文档保持紧凑（50–80 行），聚焦一个主题。

- [ ] **Step 1: schemas.md**

```markdown
# schemas.md — task.json / config.json 完整 JSON Schema

## task.json（顶层）

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| schemaVersion | string | ✓ | 当前固定 `"1.0"` |
| project.name | string | ✓ | 项目名 |
| project.mainBranch | string | ✓ | 主分支名（run.ps1 guard 用） |
| project.createdAt | ISO-8601 | ✓ | init 时间 |
| project.lastRunAt | ISO-8601 \| null | ✓ | 最后一次 run.ps1 启动 |
| tasks | array | ✓ | 任务清单 |

## tasks[] 每条

| 字段 | 类型 | 必填 | 写权限 |
|---|---|---|---|
| id | string (T-NNN) | ✓ | init 固化 |
| title | string | ✓ | init 固化 |
| description | string | ✓ | init 固化 |
| steps | string[] | ✓ | init 固化 |
| estimated_files | int (≤ maxFilesPerTask) | ✓ | init 固化 |
| depends_on | string[] | ✓ | init 固化 |
| category | string (feat/fix/...) | ✓ | init 固化 |
| scope | string | ✓ | init 固化 |
| verify_cmds | string[] (非空) | ✓ | init 固化 |
| passes | bool | ✓ | Claude 自判 → run.ps1 复核锁定 |
| attempts | int | ✓ | run.ps1 |
| blocked | bool | ✓ | run.ps1 |
| blockReason | string | ✓ | Claude (CR-6) |
| lastError | string | ✓ | run.ps1 (从 log 提取) |
| notes | string | ✓ | Claude (含 CR-6 字段) |
| startedAt | ISO-8601 \| null | ✓ | run.ps1 |
| completedAt | ISO-8601 \| null | ✓ | run.ps1 |

## config.json 关键字段

见 `dev-loop/templates/config.json.tpl` 默认值注释。

## 禁止修改

Claude **不得**修改：`config.json` 整个文件、task.json 的 tasks 数组长度、其他 task 的字段、project 块。
```

- [ ] **Step 2: failure-playbook.md**

```markdown
# failure-playbook.md — 失败策略决策树

## 三级保护（a2 + b1 + c1）

### 单任务级（a2）

失败 ≤ 3 次自动重试，第 4 次标 `blocked`。每次 attempt 把上次 `lastError` + log 路径喂给下一次 Claude 会话。

### 循环级（b1）

连续 3 个任务 `blocked` → 整体停止 `exit 2`，等人介入。防止同类问题（如依赖装错）把所有任务全卡死。

### 失败现场（c1）

失败任务的 WIP 改动 `git restore . && git clean -fd`，回到干净状态再跑下一任务。

## 失败时的产物

每次 attempt 失败：
- `.devloop/logs/task_<id>_attempt_<n>.log` 保留完整 Claude 输出
- `task.json` 对应任务：`attempts` 递增、`lastError` 填充（最后 30 行）

## 手工接手失败任务

任务 `blocked=true` 且 `blockReason` 非空 → 人类可：

1. 读 `blockReason` 判断根因
2. 修复或重设计（改 `task.steps` / `verify_cmds`）
3. 手动将 `blocked` 改回 `false`、`attempts` 改回 0
4. 重新跑 `run.ps1`

## stuck 排查步骤

| 症状 | 检查 |
|---|---|
| 启动即 exit | git 脏 / 在 main 分支 / `.devloop` 未初始化 |
| 连续失败同类错 | `lessons.md` 中是否缺失相关教训 |
| 所有任务 skip | `depends_on` 链条是否有断裂（被 blocked 的任务挡路） |
| guard_commit 拒绝 | research.md 缺失 / CR-6 notes 缺失 / verify_cmds 复验失败 |
```

- [ ] **Step 3: headless-gotchas.md**

```markdown
# headless-gotchas.md — Windows + headless Claude 已知坑

## PowerShell 编码

默认 PowerShell 7 输出 UTF-8 无 BOM。但某些命令（特别是 `Out-File` / `Set-Content` 不带 `-Encoding`）可能写入 UTF-16 LE。

**规则**：所有写文件操作必须显式 `-Encoding utf8`。

## claude -p 的 stdin 传入

长 prompt 或含特殊字符时，不要用 `claude -p "<prompt>"`（argv 易被 shell 解析错误）。改用管道：

```powershell
$prompt | & claude -p --dangerously-skip-permissions --output-format json
```

## --dangerously-skip-permissions 行为

该标志必须存在，否则每个 Edit/Write/Bash 都会被 prompt 拦住，headless 循环失效。
使用该标志即等于"授权所有 Claude 操作" — 只在沙箱或可控项目使用。

## Start-Job 超时

`Invoke-HeadlessClaude` 用 Start-Job + Wait-Job -Timeout 实现。**坑**：Wait-Job 返回 `$null` 表示超时，之后 `Stop-Job` + `Remove-Job -Force`，否则 job 残留。

## Tee-Object 在 pipe 最后

想同时落盘 + 继续 pipe 时，`Tee-Object -FilePath` 放 pipe 末尾即可；放中间会把后续命令的输入改成 Tee 的输出对象。

## git 中文路径

Windows + git 遇中文路径可能出现 octal escape。设：

```powershell
git config --global core.quotepath false
```

## Pester 5.x 断言

Pester 5 的 `Should -Throw` 匹配**异常消息**用 `*...*` glob 模式，不是 regex。要 regex 用 `Should -Match`（对输出字符串）。

## PSScriptRoot 在 dot-sourcing 后

dot-source 脚本时 `$PSScriptRoot` 指向**被 source 的脚本**的目录。在 `guard_commit.ps1` 中用 `Join-Path $PSScriptRoot 'lib/...'` 才能稳定定位 lib。
```

- [ ] **Step 4: evidence-levels.md**

```markdown
# evidence-levels.md — A/B/C 证据等级判定与升级

## 判定标准

| 等级 | 证据类型 | 示例 |
|---|---|---|
| A | 官方一手来源 | context7 命中、官方文档 URL、GitHub release notes、源码行号 |
| B | 权威二手来源 | 知名开源项目代码、技术团队博客、Stack Overflow 高赞答案、公认 best practice |
| C | 未验证假设 | Claude 训练数据记忆、"应该是这样"、未查证的推测 |

## 升级流程（CR-2）

任何 `[C]` 必须按下列顺序尝试升级：

```
[C] → context7 查 latest docs？
  命中 → [A]，记 link
  未命中 → WebSearch 关键词
    找到权威来源 → [B]，记 link
    找不到 → 读相关开源项目源码
      找到 → [A]，记 repo+path+line
      仍然没有 → 保留 [C — 未验证]，同步写入 lessons.md 登记复查触发条件
```

## 典型反例（禁止）

- `"React 19 引入了 useOptimistic" [A]` ← 错，没给链接
- `"Prisma 支持 OR 查询" [A]` ← 错，太泛泛，没指到具体文档
- `"Postgres 是主流选型 [B]"` ← 错，"主流"不是证据

## 典型正例

- `"React 19 引入 useOptimistic [A — https://react.dev/reference/react/useOptimistic]"`
- `"Prisma 的 findMany 支持 where.OR 数组 [A — context7 /prisma/docs §where-operators]"`
- `"选 Postgres 而非 MySQL：Neon/Supabase 主流选 Postgres [B — https://neon.tech/docs]"`
```

- [ ] **Step 5: task-granularity.md**

```markdown
# task-granularity.md — 粗粒度 + 5 文件约束判例

## 核心规则

- **粗粒度**：一个可独立交付的功能（非单文件单函数）
- **≤ 5 文件**：单次 Claude 会话认知负担上限

## 判例

### ✅ 合格粒度

| 任务 | 文件数 | 为什么合格 |
|---|---|---|
| "实现 JWT 登录端点（路由+中间件+测试）" | 3-4 | 功能完整，单次会话可握 |
| "为 UserService 添加 CRUD" | 2-3 | 单一 service 横向扩展 |
| "配置 ESLint + Prettier + husky" | 3-4 | 工具链配置，紧密耦合 |

### ❌ 过细（需合并）

| 任务 | 问题 |
|---|---|
| "添加 login route" | 单文件，过细，应和中间件合并 |
| "改一行 import" | 琐碎，应合并到相关功能任务 |
| "添加一个字段到 User schema" | 单字段，应合并到 User CRUD |

### ❌ 过粗（需拆分）

| 任务 | 问题 | 拆法 |
|---|---|---|
| "实现整个认证系统" | 涉及 10+ 文件 | 拆：登录/注册/中间件/RBAC |
| "迁移到 Prisma" | 涉及所有 DB 代码 | 按模块拆：User/Post/Comment |
| "重构前端状态管理" | 影响面大 | 按 feature 拆 |

## 拆分决策树

```
任务描述写出来 → 估算文件数
  ≤ 5 且功能完整 → OK
  ≤ 5 但只是片段 → 合并到相邻任务
  > 5 → 按"可独立交付"维度拆：
    横向拆（多 entity） vs 纵向拆（单 entity 多层）
    优先横向（更独立）
```

## 超文件数的正当例外

CR-3 允许 `estimated_files > 5` 但必须在 `task.notes` 写明原因。可接受场景：

- 初始化任务（搭骨架，无法避免多文件）
- 跨模块重命名（N 个文件都是同类改动）

不可接受场景：
- 任务本身该拆但偷懒
- "顺便改点别的"
```

- [ ] **Step 6: ROADMAP.md**

```markdown
# ROADMAP.md — v0.2+ 扩展计划

## v0.2（预计）

### 跨平台支持
- 产出 `run.sh` / `guard_commit.sh`
- `scripts/lib/*.sh` 镜像 PowerShell 版本
- 保留 v0.1 PS 版本，双轨并行

### 并行执行
- `depends_on` DAG 已就位，增加 `--parallel N` 参数
- 需处理：同时 commit 冲突、verify_cmds 串行化

## v0.3（预计）

### 浏览器测试内置
- `config.verify.browserTests.enabled=true` 时
- run.ps1 在每任务 verify 阶段调 playwright / chrome-devtools MCP
- 断言：console 无 error + requiredSelectors 存在 + 截图存档

### 独立 plugin
- 从 `~/.claude/skills/dev-loop/` 升级为 `claude-code-plugins/dev-loop/`
- 含自己的 commands/hooks/agents

## v0.4（预计）

### Dashboard
- 读 task.json / progress.md / lessons.md
- Web UI 展示进度、失败、证据等级分布
- 外挂，不嵌入 skill

### 外部工具集成
- Linear / Jira 双向同步（task 创建 / blocked 同步）
- Slack 通知（blocked 触发 / 循环结束）

## 预留接口（v0.1 已实现）

| 字段 | 目的 | v0.1 行为 |
|---|---|---|
| `config.claude.mcp.context7Available` | v0.3 扩展其他 MCP | 仅 context7 |
| `config.git.autoPush` | v0.3 自动推送 | 仅 false |
| `config.verify.browserTests.enabled` | v0.3 浏览器测试 | 仅 false |
| `task.depends_on` | v0.2 并行 | 串行按 DAG 顺序 |
```

- [ ] **Step 7: 批量验证所有 6 份存在**

```powershell
@('schemas','failure-playbook','headless-gotchas','evidence-levels','task-granularity','ROADMAP') | ForEach-Object {
    $p = "dev-loop/references/$_.md"
    if (-not (Test-Path $p)) { throw "Missing: $p" }
    if ((Get-Item $p).Length -lt 200) { throw "Too short: $p" }
}
'All 6 references OK'
```
Expected: `All 6 references OK`

- [ ] **Step 8: Commit**

```powershell
git add dev-loop/references/schemas.md dev-loop/references/failure-playbook.md `
        dev-loop/references/headless-gotchas.md dev-loop/references/evidence-levels.md `
        dev-loop/references/task-granularity.md dev-loop/references/ROADMAP.md
git commit -m "feat(dev-loop): 新增 6 份 references 参考文档

schemas / failure-playbook / headless-gotchas / evidence-levels /
task-granularity / ROADMAP。Claude 按需查阅，不默认加载上下文。"
```

---

## Task 13: 端到端 Dogfooding（烟雾测试）

**目的**：验证 v0.1 skill 在真实空项目上跑通 init 段 4 + run.ps1 -DryRun。

**前置**：Task 1-12 全部完成并 commit。

**Files:**
- （临时）`C:\Temp\dev-loop-dogfood\` — 测试沙箱，测完删除

- [ ] **Step 1: 建立 dogfood 沙箱**

```powershell
$dogfood = 'C:\Temp\dev-loop-dogfood'
if (Test-Path $dogfood) { Remove-Item $dogfood -Recurse -Force }
New-Item -ItemType Directory -Force -Path $dogfood | Out-Null
Push-Location $dogfood
git init -q --initial-branch=main
git config user.email 'dogfood@test.local'
git config user.name 'dogfood'
'# Dogfood Project' | Out-File README.md -Encoding utf8
git add README.md
git commit -q -m 'init'
git checkout -q -b dev
```

- [ ] **Step 2: 手工模拟 init 段 4 的产物**

（不走真对话，直接写出段 4 应该生成的文件，验证脚本能消费）

```powershell
New-Item -ItemType Directory -Force -Path .devloop/scripts/lib, .devloop/logs, .claude | Out-Null

# 拷贝 skill 脚本与 lib
$skillRoot = 'C:\Users\xiybh\.claude\skills\dev-loop'
Copy-Item "$skillRoot/scripts/run.ps1"           .devloop/scripts/
Copy-Item "$skillRoot/scripts/guard_commit.ps1"  .devloop/scripts/
Copy-Item "$skillRoot/scripts/lib/*.ps1"         .devloop/scripts/lib/

# 填写最小 task.json + config.json
@'
{
  "schemaVersion": "1.0",
  "project": {"name":"dogfood","mainBranch":"main","createdAt":"2026-04-26T00:00:00Z","lastRunAt":null},
  "tasks": [
    {"id":"T-001","title":"write hello.txt","description":"create hello.txt with content 'hi'","steps":["create hello.txt"],"estimated_files":1,"depends_on":[],"category":"chore","scope":"dogfood","verify_cmds":["if (-not (Test-Path hello.txt)) { exit 1 }"],"passes":false,"attempts":0,"blocked":false,"blockReason":"","lastError":"","notes":"","startedAt":null,"completedAt":null}
  ]
}
'@ | Out-File .devloop/task.json -Encoding utf8

@'
{
  "schemaVersion":"1.0",
  "verify":{"globalCmds":[]},
  "limits":{"maxAttemptsPerTask":3,"maxConsecBlocked":3,"maxFilesPerTask":5,"claudeTimeoutSec":60},
  "git":{"mainBranch":"main","autoPush":false,"autoPR":false,"commitTemplate":"{category}({scope}): {title}\n\nTask-ID: {id}\nAttempts: {attempts}"}
}
'@ | Out-File .devloop/config.json -Encoding utf8

Set-Content -Path .devloop/progress.md -Value "# Progress`n" -Encoding utf8
Set-Content -Path .devloop/lessons.md  -Value "# Lessons`n"  -Encoding utf8

git add -A; git commit -q -m 'chore(dogfood): init harness'
```

- [ ] **Step 3: 跑 -DryRun 验证主循环骨架**

```powershell
.\.devloop\scripts\run.ps1 -DryRun -MaxTasks 1
```
Expected:
```
>>> 任务 T-001: write hello.txt
[DryRun] 跳过 attempt 循环
完成: 1 任务
Blocked: 0
```

- [ ] **Step 4: 手工模拟一次完整任务的产物 → 跑 guard_commit**

验证 guard 正确放行一个完全合规的任务：

```powershell
# 手工完成任务：写 hello.txt
'hi' | Out-File hello.txt -Encoding utf8

# 登记当前 task id
Set-Content .devloop/.current_task_id -Value 'T-001' -NoNewline -Encoding ascii

# 写 CR-5 research（NO_RESEARCH_NEEDED 出口）
@'
## NO_RESEARCH_NEEDED
本任务无外部 API 依赖。
'@ | Out-File .devloop/logs/task_T-001_research.md -Encoding utf8

# 更新 task.notes（CR-6）
$data = Get-Content .devloop/task.json -Raw | ConvertFrom-Json
$data.tasks[0].notes = 'CR-6: 超出描述=无 / 过度抽象=无 / 更简替代=无'
$data | ConvertTo-Json -Depth 20 | Set-Content .devloop/task.json -Encoding utf8

# 模拟 Claude Code hook 调用 guard_commit
git add -A
$stdin = '{"tool_input":{"command":"git commit -m feat(dogfood): T-001"}}'
$stdin | & pwsh -NoProfile -File .devloop/scripts/guard_commit.ps1
$LASTEXITCODE
```
Expected: `0`（guard 放行）

- [ ] **Step 5: 验证 guard 在缺产物时拒绝**

```powershell
# 删除 research.md 模拟 Claude 跳过 CR-5
Remove-Item .devloop/logs/task_T-001_research.md
$stdin = '{"tool_input":{"command":"git commit -m feat(dogfood): T-001"}}'
$stdin | & pwsh -NoProfile -File .devloop/scripts/guard_commit.ps1 2>&1
$LASTEXITCODE
```
Expected: `1` + stderr 含 `research.md`

- [ ] **Step 6: 清理沙箱**

```powershell
Pop-Location
Remove-Item $dogfood -Recurse -Force
```

- [ ] **Step 7: 记录 dogfood 结果**

如果 Step 3-5 全部按 Expected 输出 → v0.1 烟雾测试通过。若有偏差，回到对应 Task 修复并重跑。

通过后，在 skills 仓库根做一个 marker commit：

```powershell
cd C:\Users\xiybh\.claude\skills
# 新建（或追加到已有）dev-loop/CHANGELOG.md
if (-not (Test-Path dev-loop/CHANGELOG.md)) {
    @'
# Dev-Loop Skill Changelog

## v0.1 (2026-04-26)

初版发布，含：
- SKILL.md 入口与触发规则
- INIT.md 四段对话协议
- RUN.md 单任务 7 步协议
- CRITICAL_REVIEW.md 6 gate 判定准则
- 8 份 templates
- run.ps1 主循环 + guard_commit hook
- task_picker / verify_runner / claude_invoker 三个 lib（Pester 测试覆盖）
- 6 份 references

范围：Windows + PowerShell 7 only。
Dogfood 烟雾测试于 2026-04-26 通过。
'@ | Out-File dev-loop/CHANGELOG.md -Encoding utf8
}
git add dev-loop/CHANGELOG.md
git commit -m "docs(dev-loop): v0.1 CHANGELOG + dogfood 通过"
```

## Task 14: v0.1 README 入口与 git tag

**Files:**
- Create: `dev-loop/README.md`
- Git tag: `dev-loop-v0.1.0`

- [ ] **Step 1: 写 dev-loop/README.md**

```markdown
# dev-loop

通用开发循环 harness skill，基于 Anthropic《effective harnesses for long-running agents》思想。

两阶段工作流：

- **`/dev-loop init`** — 交互式四段对话，为目标项目生成完整的 `.devloop/` 工作流（架构文档、任务清单、主循环脚本、guard hook、教训登记簿）
- **`/dev-loop run`** — 驱动 `.devloop/scripts/run.ps1`，headless Claude 循环消费任务直到全部完成或触发停止

## 特性

- 6 个 Critical Review Gates（四层强制：Prompt / Schema / 工件 / Hook），防止模型跳过批判性审查
- 16 道 safety guard，即使 Claude 完全不守规矩也兜得住
- 失败策略：单任务 ≤3 重试 / 连续 3 blocked 停 / 失败自动回滚工作区
- `task.json` 共享黑板 + 脚本独立复验 `verify_cmds`，不信 Claude 自报
- 证据等级 `[A/B/C]` 强制标注，`[C]` 必须升级到 A/B 才能落盘
- 只追加的 `lessons.md`，保留被否决的方案作为反向证据

## 快速上手

1. 在任意新项目根目录运行 `/dev-loop init`
2. 按四段对话回答 Claude 的问题
3. 审批每段产物（目标 / 架构 / 任务 / 配套）
4. 跑 `./.devloop/scripts/run.ps1 -DryRun -MaxTasks 1` 验证
5. 去掉 `-DryRun` 开始真实循环

## 范围（v0.1）

- 平台：Windows + PowerShell 7
- 测试框架：Pester 5.x（skill 自身单元测试）

v0.2+ 扩展见 `references/ROADMAP.md`。

## 文件布局

- `SKILL.md` / `INIT.md` / `RUN.md` / `CRITICAL_REVIEW.md` — 认知骨架
- `templates/` — 8 份静态模板
- `scripts/run.ps1` + `guard_commit.ps1` + `lib/` — PowerShell 执行骨架
- `tests/` — Pester 单元测试
- `references/` — 按需查阅参考（schemas / failure-playbook / ...）
- `docs/specs/` — 设计规格
- `docs/plans/` — 实施计划

## 文档

- [设计规格](docs/specs/2026-04-26-dev-loop-skill-design.md) — 完整架构与决策理由
- [实施计划](docs/plans/2026-04-26-dev-loop-skill.md) — 按任务执行顺序
- [CHANGELOG](CHANGELOG.md) — 版本变更
```

- [ ] **Step 2: 验证 README 有关键 section**

```powershell
$req = @('## 特性', '## 快速上手', '## 范围', '## 文件布局', '## 文档')
$c = Get-Content dev-loop/README.md -Raw
foreach ($s in $req) {
    if ($c -notmatch [regex]::Escape($s)) { throw "Missing: $s" }
}
'README sections OK'
```
Expected: `README sections OK`

- [ ] **Step 3: Commit + tag**

```powershell
git add dev-loop/README.md
git commit -m "docs(dev-loop): v0.1 README 入口文档"
git tag -a dev-loop-v0.1.0 -m "dev-loop skill v0.1.0 - initial release

完整功能见 dev-loop/CHANGELOG.md 与 dev-loop/README.md。
Windows + PowerShell 7 only. Dogfood 烟雾测试通过。"
```

- [ ] **Step 4: 最终检查（不推送）**

```powershell
git log --oneline -20
git tag -l 'dev-loop-*'
```
Expected: 能看到 `dev-loop-v0.1.0` tag；最近 log 形如：

```
<hash> docs(dev-loop): v0.1 README 入口文档
<hash> docs(dev-loop): v0.1 CHANGELOG + dogfood 通过
<hash> feat(dev-loop): 新增 6 份 references 参考文档
<hash> feat(dev-loop): 新增 CRITICAL_REVIEW.md 6 gate 判定准则
...
```

`git push` 由用户显式决定（v0.1 设计原则：不自动 push）。

---

## Self-Review

按 writing-plans skill 要求做一次自审。

### 1. Spec 覆盖检查

| spec 章节 | 对应 task |
|---|---|
| §3 Skill 目录结构 | Task 1 |
| §4 目标项目文件布局 | Task 3 + Task 10（INIT.md §4）|
| §5.1 Init 四段对话 | Task 10 |
| §5.2 Run 主循环 + RUN.md | Task 8 + Task 9 |
| §6.1 task.json schema | Task 2 + references/schemas.md（Task 12）|
| §6.2 config.json schema | Task 2 + references/schemas.md |
| §6.3 progress.md 格式 | Task 3 + run.ps1 `Append-Progress`（Task 8） |
| §6.4 lessons.md 格式 | Task 3 |
| §6.5 architecture.md 结构 | Task 3 + INIT.md §2（Task 10）|
| §7.1 6 Gate 汇总 | Task 11 |
| §7.2 4 层机制对照 | Task 11 |
| §7.3 MCP 可用性降级 | Task 2 (config schema) + Task 10 (INIT §1 Q6) + Task 9 (RUN §2) |
| §7.4 NO_RESEARCH_NEEDED | Task 9 RUN §2 + Task 11 |
| §7.5 `[skip-devloop]` 豁免 | Task 7 guard_commit + Task 11 |
| §8 Safety Guard 汇总 | Task 4-8 分别实现，Task 11 汇总 |
| §9 MVP 范围与 Roadmap | Task 12 references/ROADMAP.md |

全部 spec 章节都有对应 task 实现。✓

### 2. Placeholder 扫描

plan 中出现的 `<由 init 段 X 填充>` / `<PROJECT_NAME>` / `<TASK_ID>` 等占位符**都在目标项目的模板文件中**，是 init 阶段 Claude 要填的值——这是模板的**必要**占位符，不是 plan 本身的 placeholder。

plan 任务本身无 `TBD` / `fill in details` / `similar to Task N` 类问题。✓

### 3. 类型/签名一致性

| 函数 | 定义处 | 使用处 | 一致？ |
|---|---|---|---|
| `Select-NextTask -Path <str>` → task\|$null | Task 4 | Task 8 run.ps1 主循环 | ✓ |
| `Assert-TaskJsonValid -Path <str> -MaxFiles <int>` | Task 4 | Task 8 run.ps1 前置 | ✓ |
| `Invoke-VerifyRunner -Task <obj> -Config <obj>` → bool | Task 5 | Task 7 guard_commit + Task 8 run.ps1 | ✓ |
| `Build-Prompt -TaskId <str> -Attempt <int> -PrevLogPath <str> -MaxAttempts <int>` | Task 6 | Task 8 run.ps1 主循环 | ✓ |
| `Invoke-HeadlessClaude -Prompt <str> -LogPath <str> -TimeoutSec <int>` → int | Task 6 | Task 8 run.ps1 主循环 | ✓ |
| `Update-TaskField` / `Append-Progress` / `Build-CommitMessage` / `Get-LastError` | Task 8 run.ps1 内联 | Task 8 主循环 | ✓ |

所有跨 task 调用的函数签名一致。✓

### 4. 依赖顺序

Task 执行顺序对依赖关系：

```
Task 1 (目录 + SKILL.md)
  ↓
Task 2 (JSON templates) → Task 3 (markdown templates)
  ↓
Task 4 (task_picker) → Task 5 (verify_runner) → Task 6 (claude_invoker)
  ↓                     ↓                         ↓
  └─────────────────────┴─────────────────────────┘
  ↓
Task 7 (guard_commit, 依赖 Task 5 verify_runner)
  ↓
Task 8 (run.ps1, 依赖 Task 4/5/6)
  ↓
Task 9 (RUN.md) / Task 10 (INIT.md) / Task 11 (CRITICAL_REVIEW.md)  // 可并行
  ↓
Task 12 (references, 可与 9-11 并行)
  ↓
Task 13 (dogfood，依赖全部前置)
  ↓
Task 14 (README + tag)
```

若用 `subagent-driven-development` 执行，Task 9/10/11/12 可派并行 subagent（均为独立 markdown，无相互依赖）。

### 5. 风险项

| 风险 | 缓解 |
|---|---|
| `claude -p` 在 Windows 的 stdin 传递可能被 PowerShell 编码影响 | Task 13 dogfood 验证；若失败可改用 `--input-format text` 或 base64 编码 |
| Pester 5.x 的 `Should -Throw` glob 匹配与 regex 混淆 | 测试中使用 `*...*` glob 模式 |
| `git restore . && git clean -fd` 可能误删用户未追踪的本地配置 | run.ps1 启动前 `Assert-GitClean` 已拒绝工作区脏的情况 |
| `Start-Job` 内 dot-sourcing lib 的路径问题 | Task 8 run.ps1 用 `$PSScriptRoot/lib/` 明确相对路径 |

---

## Execution Handoff

Plan 完整写完，已 commit 到 skills 仓库：
- `dev-loop/docs/plans/2026-04-26-dev-loop-skill.md`

两种执行方式，选一个：

### 1. Subagent-Driven（推荐）

- **SUB-SKILL**：`superpowers:subagent-driven-development`
- 每个 task 派一个新 subagent，主会话 review
- 优势：上下文隔离（符合 dev-loop 自身的设计哲学，也是最好的 dogfood）、Task 9-12 可并行
- 适合：你想保持主会话干净、关注 review

### 2. Inline 执行

- **SUB-SKILL**：`superpowers:executing-plans`
- 主会话里按 task 顺序逐个做，定期 checkpoint
- 优势：单会话全可见、调试方便
- 适合：你想全程跟进每一步、Task 较少（14 个其实属于偏多）

---

**选哪个？**（回 "subagent" 或 "inline" 即可；或先让我把 plan 也 commit 后再决定）
