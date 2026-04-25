# `dev-loop` Skill · 设计规格

| 字段 | 值 |
|---|---|
| 文档日期 | 2026-04-26 |
| 状态 | Design (pending user review) |
| 作者 | XIYBHK |
| 设计方法 | `superpowers:brainstorming` 七节式对话澄清 |
| 灵感来源 | Anthropic 博客《effective harnesses for long-running agents》+ `SKELOT5.6` 项目里经过实战的 harness 工作流 |

---

## 0. 摘要

`dev-loop` 是一个通用的、项目无关的**开发循环 harness**。其核心能力：

1. **Init 阶段**（一次性，交互式）：通过四段分审批的对话，在目标项目里生成一整套持久化工件（`CLAUDE.md` / `architecture.md` / `.devloop/task.json` / `config.json` / `progress.md` / `lessons.md` / `run.ps1` / `guard_commit.ps1`）。
2. **Run 阶段**（循环，无人值守）：由 `run.ps1` 驱动 headless Claude（`claude -p`）一次完成一个任务；脚本独立复验 → commit → 推进下一个。
3. **Critical Review Gates**：6 个强制批判性审查闸门，通过「Prompt / Schema / 产物 / Hook」四层机制保证 Claude 不能跳过。

设计的核心信念：**harness 的稳健性来自 `.devloop/task.json` 这块共享黑板 + 脚本不信任模型自报 + 每个 gate 都有结构性强制落盘**，而不是靠提示词的"请你必须..."。

---

## 1. 背景与目标

### 1.1 背景

Anthropic 博客强调了 long-running agent 需要的几个核心能力：context engineering、verification loops、persistent memory、subagent dispatch、critical feedback。`SKELOT5.6` 项目里的 `CLAUDE.md` + `docs/DEV_NOTES.md` + `docs/TASK_LIST.md` + `.claude/settings.json` 的组合已经在实战里跑通了这套思想的本地化版本，**本 skill 是对该实践的抽象与泛化**，使其能直接套用到任意新项目。

### 1.2 目标

| 目标 | 度量 |
|---|---|
| 新项目冷启动即可用 | 用户说一句 `/dev-loop init` → 四段对话 → 生成完整 harness |
| 跨项目通用 | 命令配置化，不对 Web/Backend/UE 等任一类型做硬编码假设 |
| Headless Claude 可冷启动 | 每次 `claude -p` 新会话，靠文件重建上下文而非对话记忆 |
| 批判性机制结构化 | 6 个 CR Gate 通过 4 层机制强制执行，模型无法跳过 |
| 失败兜底 | 单任务 ≤3 次重试 → blocked / 连续 3 blocked → 停；失败自动回滚工作区 |

### 1.3 非目标（v0.1 不做）

- 跨平台（仅 Windows + PowerShell 7）
- 多任务并行执行
- 自动 `git push` / 自动 `gh pr create`
- 浏览器测试的**具体执行器**（只留 config 字段）
- Web dashboard / Linear 等外部工具集成
- 失败后的自动诊断（只归档日志供人类查阅）

---

## 2. 核心设计原则

### 2.1 外部脚本驱动 + Headless Claude

`run.ps1` 是**调度器**（选任务、调用 Claude、复验、提交、回滚），Claude 是**执行器**（读任务、写代码、写查证记录、汇报结果）。两者通过 `.devloop/task.json` 这块黑板交互。

此选型的核心是**上下文干净**：每次任务一次 headless 冷会话，不积累污染。代价是 Claude 每次必须重建上下文——通过设计严格的"必读清单"+ 持久化文件弥补。

### 2.2 四层强制机制

任何 skill 规则都不应仅依赖 prompt。6 个 CR Gate 都按四层叠加：

| 层 | 机制 | 防的是 |
|---|---|---|
| 1 | Prompt 硬条文 | 模型遗忘 |
| 2 | Schema 必填字段 | 模型敷衍写"done" |
| 3 | 产物文件存在性 | 模型声称做过但没做 |
| 4 | Git hook 拦截 | 模型绕开工件直接提交 |

### 2.3 脚本不信任模型自报

`run.ps1` 会独立复跑 `verify_cmds`——即使 Claude 在 `task.json.passes` 写了 `true`，脚本复验不过依旧判定失败。这是 Anthropic 文章"verification before completion"的直接落地。

### 2.4 Source of Truth 单一化

- 任务状态的唯一事实源：`.devloop/task.json`
- 配置策略的唯一事实源：`.devloop/config.json`
- 架构决策的唯一事实源：`architecture.md`
- 历史教训的唯一事实源：`.devloop/lessons.md`

禁止任何信息在两处各存一份。

---

## 3. Skill 自身目录结构

落位：`~/.claude/skills/dev-loop/`（用户个人 skills 仓库）。

```
~/.claude/skills/dev-loop/
├── SKILL.md                          # skill 入口（frontmatter + 触发规则 + 决策流程图 + 红线清单）
├── INIT.md                           # init 阶段 4 段式对话脚本
├── RUN.md                            # run 阶段单任务执行协议（headless Claude 读）
├── CRITICAL_REVIEW.md                # 6 个 gate 的完整判定准则 + 示例
├── templates/                        # 拷贝到目标项目的静态模板
│   ├── CLAUDE.md.tpl
│   ├── architecture.md.tpl
│   ├── task.json.tpl
│   ├── progress.md.tpl
│   ├── config.json.tpl
│   ├── lessons.md.tpl
│   ├── gitignore.tpl
│   └── claude-settings.json.tpl
├── scripts/                          # 拷贝到目标项目 .devloop/scripts/
│   ├── run.ps1
│   ├── guard_commit.ps1
│   └── lib/
│       ├── task_picker.ps1
│       ├── verify_runner.ps1
│       └── claude_invoker.ps1
├── references/                       # 按需查阅，不默认加载
│   ├── schemas.md
│   ├── failure-playbook.md
│   ├── headless-gotchas.md
│   ├── evidence-levels.md
│   ├── task-granularity.md
│   └── ROADMAP.md
└── docs/specs/                       # skill 自身的设计文档
    └── 2026-04-26-dev-loop-skill-design.md  # 本文档
```

### 三份入口文档的职责

| 文档 | 何时被 Claude 读 | 内容 |
|---|---|---|
| `SKILL.md` | 每次触发 `/dev-loop *` 时自动加载 | frontmatter + 触发规则 + 决策流程图 + 红线 |
| `INIT.md` | `/dev-loop init` 时主动 Read | 4 段对话完整脚本 + CR-1~CR-4 触发时机 |
| `RUN.md` | headless Claude 每次被 `run.ps1` 启动时 Read | 单任务执行 7 步协议 + CR-5/CR-6 |

`INIT.md` 和 `RUN.md` 分开的根本原因：**headless Claude 在 run 阶段不应被 init 流程污染**。它的 prompt 只说"读 RUN.md 执行 task #N"，不给它看 INIT.md。这是 context engineering 的具体落地。

---

## 4. 目标项目的文件布局（init 后的产物）

```
目标项目根/
├── CLAUDE.md                         # 流程定义（Claude 自动加载），必读清单
├── architecture.md                   # 架构门面文档（带 [A/B/C] 证据等级）
├── .claude/
│   └── settings.json                 # guard_commit.ps1 hook 配置
├── .devloop/
│   ├── task.json                     # 任务黑板（核心交互介质）
│   ├── config.json                   # 命令/策略配置（init 后只读）
│   ├── progress.md                   # 时间线日志（只追加）
│   ├── lessons.md                    # 教训登记簿（只追加）
│   ├── scripts/
│   │   ├── run.ps1                   # 主循环驱动器
│   │   └── guard_commit.ps1          # PreToolUse hook 实现
│   ├── logs/                         # 每次 attempt 的 Claude 输出归档（.gitignore）
│   │   ├── task_<id>_attempt_<n>.log
│   │   ├── task_<id>_research.md     # CR-5 查证记录（必需存在）
│   │   └── screenshots/              # 浏览器测试截图（若启用）
│   └── init/                         # init 阶段临时工件（.gitignore）
│       ├── stage1.json               # 段 1 目标/测试规则的结构化记录
│       ├── decisions.json            # 段 2 架构决策证据
│       └── cmd_check.json            # 段 4 命令可执行性验证结果
└── .gitignore                        # 追加 .devloop/logs/ 和 .devloop/init/
```

### 布局设计要点

1. `CLAUDE.md` 必须在项目根——Claude 自动加载机制决定
2. `architecture.md` 放根做门面——与 README 并列，人类打开仓库一眼可见
3. 运行时数据全部下沉 `.devloop/`，不污染仓库
4. `.devloop/logs/` 和 `.devloop/init/` 加入 `.gitignore`（日志和 init 工件不入库）
5. `.devloop/task.json` / `config.json` / `progress.md` / `lessons.md` **必须 commit**（状态和教训的 source of truth）

---

## 5. 两阶段流程

### 5.1 Init 阶段：四段式对话

**入口命令**：用户在目标项目里说 `/dev-loop init`（可选附一句话描述）。

#### 段 1 · 目标与测试判定规则

Claude 按顺序问 5 组问题：

| # | 问 | 目的 |
|---|---|---|
| Q1 | 项目用途、目标用户、MVP 范围 | 明确 scope |
| Q2 | 技术栈（语言/框架/运行时） | 为段 2 定锚 |
| Q3 | **测试判定规则**（按项目形态分类）| 核心，见下 |
| Q4 | commit category 枚举 | feat/fix/refactor/docs/test/chore |
| Q5 | git 主分支名、远程情况 | 供提交和启动 guard 使用 |
| Q6 | 项目是否已配置 context7 MCP | 决定 CR-5 查证流程是否可用 context7 |

Q3 细分：

- **自动化命令**（必填）：lint / typecheck / unit test / build 各自的命令
- **UI/浏览器测试**（若适用）：判定 = 「控制台 0 error」+「指定元素存在」+「截图存档」
- **后端 API 测试**（若适用）：判定 = 「指定 endpoint 返回预期 schema」+「exit code 0」
- **UE 插件**（若适用）：判定 = 「RunUAT BuildPlugin 成功」+「Editor 启动无 log warning」
- **手动验证**（兜底）：用户必须给出「每次怎么确认」的清单

**CR-1 触发**：用户答案里出现「随便 / 你看着办 / 不确定 / 应该 / 可能」任一词 → Claude 必须进入查证模式（`context7` / `WebSearch`）再给建议。

**落盘**：`.devloop/init/stage1.json`（内部工件）；不写 `architecture.md`。用户审批后进段 2。

#### 段 2 · architecture.md + CR-2 证据等级

Claude 读 `stage1.json`，生成 `architecture.md` 草稿。**每个技术决策必须标证据等级**：

```markdown
- 数据库选用 PostgreSQL 15+  `[证据: C]`
- ORM 选用 Prisma 5.x  `[证据: A — 官方文档 https://...]`
```

**CR-2 自动触发**：扫描所有 `[C]`（训练数据假设），逐个走升级流程：

1. `context7` 查 latest docs → 升级到 A 或降级（发现选型错误）
2. context7 无命中 → `WebSearch` 查权威实践 → 升级到 B
3. 查不到 → 明确标 `[C — 未验证]` 并追加到 `lessons.md` 供未来复查

查证产物落盘 `.devloop/init/decisions.json`。

**落盘**：`architecture.md`（根目录）+ `decisions.json`。用户审批后进段 3。

#### 段 3 · task.json + CR-3 粒度自检

按**粗粒度 + 单任务 ≤ 5 文件**规则拆分。每条 task schema 见 §6.1。

**CR-3 自动触发**——Claude 必须自问 4 个问题：

1. 有无任务 `estimated_files > 5`？（若有必须拆）
2. 依赖图是否有环？（必须无环）
3. 有无两个任务改动重叠严重？（必须合并或重切）
4. 每条 task 的 `verify_cmds` 是否非空且可执行？

任一未通过 → 重拆并重跑 CR-3。

**落盘**：`.devloop/task.json`。用户审批后进段 4。

#### 段 4 · 配套文件生成 + CR-4 命令验证

一次性生成 7 份文件：

| 文件 | 来源 |
|---|---|
| `CLAUDE.md`（根） | `templates/CLAUDE.md.tpl` + 前三段产物填充 |
| `.devloop/config.json` | `templates/config.json.tpl` + Q3 verify_cmds |
| `.devloop/scripts/run.ps1` | `skill/scripts/run.ps1` 直接拷贝 |
| `.devloop/scripts/guard_commit.ps1` | `skill/scripts/guard_commit.ps1` 直接拷贝 |
| `.claude/settings.json` | `templates/claude-settings.json.tpl` |
| `.gitignore`（追加） | `.devloop/logs/`、`.devloop/init/` |
| `.devloop/progress.md`、`lessons.md` | 初始化为空模板 |

**CR-4 自动触发**：对 `config.json` 每条 `init.cmds` / `verify.globalCmds` 做两类验证：

1. **可执行程序检测**：提取命令首个 token（如 `npm run build` → `npm`、`./mvnw test` → `./mvnw`），跑 `<token> --version` 验证二进制存在
2. **Script/任务存在性检测**：
   - npm scripts（`npm run <x>`）→ 解析 `package.json.scripts` 中是否有 `<x>` 键
   - make targets（`make <x>`）→ 解析 `Makefile` 中是否有 `<x>:` 目标
   - 其他复合命令 → 仅做 #1 并在 `cmd_check.json` 标 `unverifiable: true`，留给 run.ps1 首次运行时实跑兜底

失败项写入 `.devloop/init/cmd_check.json` `status: fail`，必须让用户澄清或修正，不能落盘到 `config.json`。

**段 4 收尾**：一次性 commit

```powershell
git add -A
git commit -m "chore(dev-loop): 初始化 dev-loop harness

- architecture.md: 架构与证据等级
- .devloop/task.json: <N> 个粗粒度任务
- CLAUDE.md: 工作流定义
- .devloop/scripts/run.ps1: 循环驱动器"
```

Claude 最后输出：

```
✓ init 完成，<N> 个任务已就绪
  查看架构：architecture.md
  查看任务：.devloop/task.json

开始循环执行：
  .\.devloop\scripts\run.ps1

建议先干跑验证一次：
  .\.devloop\scripts\run.ps1 -DryRun -MaxTasks 1
```

---

### 5.2 Run 阶段：外部脚本循环

**入口**：用户在目标项目 PowerShell 里运行：

```powershell
.\.devloop\scripts\run.ps1              # 跑到全部完成或触发停止
.\.devloop\scripts\run.ps1 -MaxTasks 5  # 只跑 5 个
.\.devloop\scripts\run.ps1 -DryRun      # 只打印不执行
```

#### run.ps1 主循环骨架

```powershell
param(
    [int]$MaxTasks = 0,
    [int]$MaxConsecBlocked = 3,
    [int]$MaxAttemptsPerTask = 3,
    [switch]$DryRun
)

# === 前置 guard ===
Assert-GitClean
Assert-BranchNotMain
Assert-DevLoopInitialized
Assert-TaskJsonPassesCR3            # 文件数、依赖环、verify_cmds 等 4 问
Assert-ConfigCmdsExecutable         # CR-4 复验

$cfg = Get-Content .devloop/config.json | ConvertFrom-Json
$consecBlocked = 0
$done = 0

while ($true) {
    # --- 1. 选任务 ---
    $task = Select-NextTask -Path .devloop/task.json
    if (-not $task) { Write-Host "✓ 全部任务完成"; break }

    # --- 2. 单任务 attempt 循环 ---
    $verified = $false
    for ($attempt = 1; $attempt -le $MaxAttemptsPerTask; $attempt++) {

        # 2a. 写当前任务 id（供 guard_commit.ps1 读）
        Set-Content .devloop/.current_task_id $task.id -NoNewline

        # 2b. 构造 prompt
        $prompt = Build-Prompt -TaskId $task.id -Attempt $attempt

        # 2c. 调 headless Claude，全部输出存档
        $logPath = ".devloop/logs/task_$($task.id)_attempt_$attempt.log"
        claude -p $prompt --dangerously-skip-permissions --output-format=json 2>&1 |
            Tee-Object -FilePath $logPath

        # 2d. 脚本独立复验（不信 Claude 自报）
        $verified = Invoke-VerifyRunner -Task $task -Config $cfg
        if ($verified) { break }

        # 2e. 失败 → 回滚 + 记录
        git restore . ; git clean -fd
        Update-TaskField -Id $task.id -attempts $attempt `
                        -lastError (Get-LastError $logPath)
    }
    Remove-Item .devloop/.current_task_id -ErrorAction SilentlyContinue

    # --- 3. 判定 ---
    if ($verified) {
        git add -A
        git commit -m (Build-CommitMessage $task $cfg)
        Update-TaskField -Id $task.id -passes $true
        Append-Progress "✓ $($task.id) done (attempts=$attempt)"
        $consecBlocked = 0; $done++
    } else {
        $reason = Extract-BlockReason $logPath
        Update-TaskField -Id $task.id -blocked $true -blockReason $reason
        Append-Progress "✗ $($task.id) BLOCKED after $MaxAttemptsPerTask attempts"
        $consecBlocked++
        if ($consecBlocked -ge $MaxConsecBlocked) {
            Write-Error "连续 $MaxConsecBlocked 个任务 blocked, 整体停止"
            exit 2
        }
    }

    if ($MaxTasks -gt 0 -and $done -ge $MaxTasks) { break }
}
```

#### RUN.md：headless Claude 的 7 步执行协议

```markdown
# RUN.md — 单任务执行协议

当 run.ps1 启动你时，严格按以下 7 步执行。不得跳步。

## 1. 必读清单（冷启动上下文重建）
按顺序读取：
- .devloop/task.json → 定位 id=<TASK_ID> 的任务
- architecture.md → 项目架构与证据等级
- CLAUDE.md → 工作流规则
- .devloop/lessons.md → 历史避坑经验（必读）
- .devloop/logs/task_<TASK_ID>_attempt_<N-1>.log（若 attempt > 1）

## 2. CR-5: 任务启动前批判性审查
列出本任务要用到的所有非标准 API / 库 / 配置。
每一项回答：「我是训练数据里记得，还是真的查证过？」
不确定项必须：
  a. context7 MCP 查 latest docs
  b. 无命中 → WebSearch
  c. 仍无 → 读项目源码
查证记录落盘到 .devloop/logs/task_<TASK_ID>_research.md。
若本任务所有 API 均来自 architecture.md [A] 级选型，写 ## NO_RESEARCH_NEEDED 章节 + 依据。

## 3. 实现
- 严格按 task.steps 实现
- 不得超过 task.estimated_files 文件数（超出必须在 task.notes 写明原因）
- 不得偏离 task.description 范围
- 如果发现 architecture.md 有错 → 停止实现，在 task.lastError 写「架构需修订：...」退出

## 4. 自我验证（非正式）
跑 task.verify_cmds 每条命令。任何失败 → 定位 → 修复 → 重跑。
注意：这是你的自检，run.ps1 会独立再跑一次。

## 5. CR-6: commit 前批判性审查
回答 3 个问题：
  ① 改动有没有超出任务描述？        → 是 → revert 多余
  ② 有没有引入过度抽象 / 过度工程？  → 是 → 简化
  ③ 有没有更简单的替代实现？        → 是 → 回到原点重做
任何"是"必须调整，并在 .devloop/lessons.md 追加一条记录。

## 6. 汇报
更新 .devloop/task.json 中 id=<TASK_ID> 的条目：
  - passes        = true / false（自判）
  - attempts      = <当前 attempt>
  - lastError     = 失败时具体原因
  - blockReason   = 若任务无法完成，写明根因
  - notes         = "CR-6: 超出描述=<无/有...> / 过度抽象=<...> / 更简替代=<...>"

不要运行 git add / git commit / git push —— 这些由 run.ps1 完成。

## 7. 退出
执行完毕直接退出。
```

---

## 6. 持久化文件 Schema

### 6.1 `.devloop/task.json`

```json
{
  "schemaVersion": "1.0",
  "project": {
    "name": "my-blog-backend",
    "mainBranch": "main",
    "createdAt": "2026-04-26T10:00:00Z",
    "lastRunAt": null
  },
  "tasks": [
    {
      "id": "T-001",
      "title": "搭建项目骨架与依赖管理",
      "description": "初始化 package.json、tsconfig、eslint...",
      "steps": ["npm init -y", "安装依赖", "配置 tsconfig"],
      "estimated_files": 4,
      "depends_on": [],
      "category": "chore",
      "scope": "project",
      "verify_cmds": ["npm run lint", "npm run build"],

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

**字段写入权限**：

| 字段 | 写入方 |
|---|---|
| `id` / `title` / `description` / `steps` / `verify_cmds` / `depends_on` / `estimated_files` / `category` / `scope` | init 生成后不可改 |
| `passes` | Claude 自判 → run.ps1 复核后锁定 |
| `attempts` / `lastError` | run.ps1 |
| `blocked` | run.ps1（3 次 attempt 全败后）|
| `blockReason` | Claude（CR-6 分析）|
| `notes` | Claude（含 CR-6 字段，超文件数原因等）|

**Claude 写入约束**：只改自己那条 task 的允许字段；禁止增删 tasks 数组、禁止改 project 块。

### 6.2 `.devloop/config.json`

```json
{
  "schemaVersion": "1.0",
  "projectType": "Node.js Backend (Fastify + Prisma)",

  "init": {
    "cmds": ["npm install"],
    "markerFile": ".devloop/.initialized"
  },

  "verify": {
    "globalCmds": ["npm run lint", "npm run build"],
    "browserTests": {
      "enabled": false,
      "url": "http://localhost:3000",
      "consoleErrorCheck": true,
      "requiredSelectors": ["[data-testid=app-ready]"],
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

**只读约定**：init 阶段写一次；run 阶段任何人（包括 Claude）都不许改。

### 6.3 `.devloop/progress.md`

```markdown
# Dev Loop Progress

## 2026-04-26 (Day 1)

| Time  | Task  | Title              | Status     | Attempts | Notes               |
|-------|-------|--------------------|-----------|----------|---------------------|
| 10:15 | T-001 | 搭建项目骨架        | ✓ done    | 1        | —                   |
| 10:32 | T-002 | 添加登录端点        | ✗ blocked | 3        | OAuth 库未决定      |
| 10:45 | T-003 | 实现用户模型        | ✓ done    | 2        | attempt 1: schema 错 |
```

规则：run.ps1 只追加，不改历史行；跨天自动开新 `## YYYY-MM-DD (Day N)` 节；Notes 列 ≤ 50 字符。

### 6.4 `.devloop/lessons.md`

```markdown
# Dev Loop Lessons

> 此文件只追加。每次 CR-2/CR-6 触发修正时 Claude 追加一条。
> 每次任务启动前 Claude 必读（见 RUN.md 第 1 步）。

---

## 2026-04-26 · T-002 · 技术选型修正 (CR-2)
- **被否决建议**：使用 passport-jwt 库
- **否决理由**：context7 查证显示 passport-jwt 最后 commit 在 2021 年，已 3 年未维护
  - 证据：https://github.com/mikenicholson/passport-jwt
- **采用替代**：jose 5.x（context7 命中，官方维护）
- **适用场景**：Node 20+ / ESM 项目
```

**硬约束**：

- 不允许删除历史条目
- 若条目后续失效 → 追加新条目说明"此条在 X 场景失效"，不改原条目
- 每条必含 4 字段：被否决建议 / 否决理由（带证据源）/ 采用替代 / 适用场景

### 6.5 `architecture.md`

```markdown
# <项目名> · 架构

## 项目目标
...

## 测试判定规则
- **自动化**：`npm run lint`、`npm run build`、`npm run test`
- **浏览器**：启动 http://localhost:3000，检测 console 无 error + `[data-testid=app]` 存在 + 截图存档
- **手动**：无

## 技术栈（证据等级）
| 层 | 选型 | 证据 |
|---|---|---|
| 运行时 | Node.js 20 LTS | `[A]` https://nodejs.org/en/about/previous-releases |
| Web 框架 | Fastify 4.x | `[A]` context7 /fastify/fastify |
| 数据库 | PostgreSQL 15 | `[B]` 主流选型，稳定 |
| ORM | Prisma 5.x | `[A]` context7 /prisma/docs |

## 模块划分
### `auth/`
- 职责：JWT 签发与校验
- 对外：`POST /api/auth/login`、`POST /api/auth/refresh`
- 依赖：`jose`、`prisma.user`

...

## 数据流
Request → Fastify route → Service 层 → Prisma → PostgreSQL

## 未决事项（[C — 未验证]）
- 缓存：Redis vs 内存 LRU — 待 P50 > 100ms 时再评估
```

**结构硬约束**：

- 每项技术选型必须带 `[A/B/C]` + 来源
- 「未决事项」章节所有条目必须标 `[C]`
- 模块划分必须列「对外接口」和「依赖」

### 6.6 读写矩阵

| 文件 | init 写 | run.ps1 读 | run.ps1 写 | Claude 读 | Claude 写 |
|---|---|---|---|---|---|
| `task.json` | ✓ | ✓ | ✓（attempts/passes/lastError/blocked）| ✓ | ✓（自己那条 task 的汇报字段）|
| `config.json` | ✓ | ✓ | ✗ | ✓（按需）| ✗ |
| `progress.md` | 初始化空 | ✗ | ✓（append）| ✗ | ✗ |
| `lessons.md` | 初始化空 | ✗ | ✗ | ✓（每任务前必读）| ✓（append）|
| `architecture.md` | ✓ | ✗ | ✗ | ✓（每任务必读）| 原则上不改，除非 `task.lastError` 标「架构需修订」|

---

## 7. Critical Review Gates

### 7.1 六个 Gate 汇总

| Gate | 位置 | 核心动作 | 产物 |
|---|---|---|---|
| CR-1 | init 段 1 后 | 列出假设，不确定项触发查证 | `stage1.json.uncertainties` + `research-stage1.md` |
| CR-2 | init 段 2 落盘前 | 每个技术选型标 [A/B/C]，C 级必须升级 | `decisions.json` + `architecture.md` 标记 |
| CR-3 | init 段 3 后 | task 拆分 4 问自检 | `task.json` 本身 |
| CR-4 | init 段 4 后 | config 每条命令 `--version` 验证 | `cmd_check.json` |
| CR-5 | run 每任务启动前 | 列出非标准 API，不确定项查证 | `task_<id>_research.md` |
| CR-6 | run 每任务 commit 前 | 3 问自省（超出描述/过度抽象/更简替代）| `task.notes` CR-6 字段 + lessons.md |

### 7.2 四层机制 × Gate 对照

| Gate | 层 1 Prompt | 层 2 Schema | 层 3 工件 | 层 4 Hook/Guard |
|---|---|---|---|---|
| CR-1 | INIT.md §1 | `stage1.json.uncertainties` 必存在 | `research-stage1.md` | Claude 自检覆盖面 |
| CR-2 | INIT.md §2 | `architecture.md` 每行含 `[A-C]` 正则 | `decisions.json` | `Select-String "\[C\]"` 自检 |
| CR-3 | INIT.md §3 | `estimated_files ≤ maxFilesPerTask` | task.json 自身 | run.ps1 启动 guard |
| CR-4 | INIT.md §4 | `cmd_check.json.status` 必有 | `cmd_check.json` | run.ps1 首次复验 |
| CR-5 | RUN.md §2 | `research.md` 章节非空或 NO_RESEARCH_NEEDED | `task_<id>_research.md` | guard_commit.ps1 拦截 |
| CR-6 | RUN.md §5 | `task.notes` 含 CR-6 字段 | lessons.md 当日条目 | guard_commit.ps1 拦截 |

### 7.3 MCP 可用性假设

CR-5 的"context7 查证"流程隐含依赖目标项目配置了 context7 MCP。处理方式：

- Init 段 1 **必须**询问用户"目标项目是否已配置 context7 MCP"
- 结果写入 `config.json.claude.mcp.context7Available`（布尔）
- CR-5 执行时：
  - `context7Available = true` → 正常三步流程（context7 → WebSearch → 源码）
  - `context7Available = false` → 降级为两步（WebSearch → 源码）
- 降级事实会被 `lessons.md` 记录一次，提示用户考虑配置 MCP 以提高查证质量

### 7.4 CR-5 的 `NO_RESEARCH_NEEDED` 诚实出口

允许 `task_<id>_research.md` 只含一个章节：

```markdown
## NO_RESEARCH_NEEDED

本任务所有 API 均来自 architecture.md 中 [A] 级选型：
- Prisma client: architecture.md §技术栈 [A]
- Fastify route: architecture.md §技术栈 [A]

无新增不确定项。
```

**为什么允许**：避免 Claude 为应付规则而水"查证"，允许诚实"无需查证"但要给出引用依据。

### 7.5 `[skip-devloop]` 豁免机制

commit message 以 `[skip-devloop]` 开头 → guard_commit.ps1 放行。供紧急情况使用（如 stash 半成品到 WIP 分支）。豁免本身会被记录到 `.devloop/progress.md` 的「Overrides」章节供审计。

---

## 8. Safety Guard 汇总

共 16 道闸门，按时机排列：

| # | 时机 | Guard | 位置 | 失败行为 |
|---|---|---|---|---|
| 1 | init 段 1→2 | `stage1.uncertainties` 已答 | INIT.md §1 | 补查证推进 |
| 2 | init 段 2→3 | `architecture.md` [A/B/C] 全标 | INIT.md §2 | 拒绝 commit init |
| 3 | init 段 3→4 | 4 问自检通过 | INIT.md §3 | 重拆任务 |
| 4 | init 段 4 末 | `cmd_check.json` 全 ok | INIT.md §4 | 让用户澄清 |
| 5 | run.ps1 启动 | 工作区干净 | run.ps1 前置 | 拒启动 |
| 6 | run.ps1 启动 | 当前分支 ≠ main | run.ps1 前置 | 拒启动 |
| 7 | run.ps1 启动 | `.devloop/` 已初始化 | run.ps1 前置 | 拒启动，提示跑 init |
| 8 | run.ps1 启动 | task.json 过 CR-3 4 问 | run.ps1 前置 | 拒启动 |
| 9 | run.ps1 首次 | `verify_cmds --version` 全 ok | run.ps1 前置 | 拒启动 |
| 10 | 每任务前 | depends_on 全 passed | Select-NextTask | 自动跳任务 |
| 11 | 每 attempt 后 | 脚本独立复跑 verify_cmds | Invoke-VerifyRunner | 不信 Claude 自报 |
| 12 | commit 前 | `task_<id>_research.md` 存在 | guard_commit.ps1 | 拒 commit |
| 13 | commit 前 | `task.notes` 含 CR-6 字段 | guard_commit.ps1 | 拒 commit |
| 14 | commit 前 | verify_cmds 复跑通过 | guard_commit.ps1 | 拒 commit |
| 15 | 单任务失败 | attempts ≥ 3 → blocked | run.ps1 | 跳下一任务 |
| 16 | 循环级 | consecBlocked ≥ 3 | run.ps1 | 停循环 exit 2 |

**观察**：#5–#9 + #12–#14 是"结构性兜底"——即使 Claude 完全不守规矩，这两组也能兜住。

---

## 9. MVP 范围与 Roadmap

### 9.1 v0.1 必做

- `~/.claude/skills/dev-loop/` 完整结构（SKILL.md / INIT.md / RUN.md / CRITICAL_REVIEW.md）
- 8 份 templates
- `run.ps1` 主循环
- `guard_commit.ps1`
- 6 个 CR Gates 全部生效（四层机制）
- 5 份持久化文件 schema
- Windows + PowerShell 7

### 9.2 v0.1 明确不做

- 跨平台 / `*.sh` 脚本
- 浏览器测试的**具体执行**（仅留 config 字段）
- 自动 push / 自动 PR
- 多任务并行
- 依赖图可视化
- 失败自动诊断（仅归档日志）
- Web dashboard / Linear 集成

### 9.3 Roadmap（已预留接口）

| 版本 | 扩展 | 当前已预留 |
|---|---|---|
| v0.2 | 并行执行 | `task.depends_on` 已是 DAG 基础 |
| v0.2 | Linux/Mac | 脚本封装在 lib/，复制 .sh |
| v0.3 | 浏览器测试内置 | `config.verify.browserTests` 字段 |
| v0.3 | 独立 plugin | 整个 `~/.claude/skills/dev-loop/` 迁移 |
| v0.4 | Dashboard | 所有状态已结构化，外挂 web 读即可 |

关键约束：**v0.1 预留字段但不实现**——`browserTests.enabled` 默认 false 但字段存在；`autoPush` 字段存在但只接受 false。这样 v0.2+ 不改 schema，只加 handler。

---

## 10. 关键决策回顾

| 决策点 | 选择 | 理由简述 |
|---|---|---|
| 驱动方式 | 外部 PS 脚本 + headless Claude | 保证上下文干净；代价是每次冷启动由文件重建 |
| 项目类型 | 无预设模板，纯 init 对话填充 | 避免预设限制通用性；依赖 Claude 当时对话质量 |
| 任务粒度 | 粗粒度 + 单任务 ≤ 5 文件 | 平衡 commit 干净度与单次会话认知负担 |
| 目录布局 | `CLAUDE.md` + `architecture.md` 放根；其他下沉 `.devloop/` | 根做门面；运行时下沉 |
| Init 节奏 | 四段分审批 | 每段可独立修，错不到最后才发现 |
| 失败策略 | 单任务 ≤3 重试 / 连续 3 blocked 停 / 失败自动回滚 | Claude 有纠错空间但不无限消耗 |
| 提交策略 | 每任务一次 commit / 默认不 push / 不自动 PR | push 是影响远程动作，默认人工确认 |
| 平台支持 | v0.1 仅 Windows + PowerShell | 用户实际工作平台 |
| CR 执行 | 四层机制叠加（Prompt / Schema / 产物 / Hook）| 纯 prompt 不可信，需结构性强制 |

---

## 11. 附录：术语表

| 术语 | 含义 |
|---|---|
| **Harness** | 围绕 LLM agent 构建的稳定工作容器（context / tools / feedback loops / persistence） |
| **Headless Claude** | 通过 `claude -p "<prompt>"` 无交互调用，每次独立会话 |
| **CR Gate** | Critical Review Gate，本 skill 6 个强制批判性审查节点 |
| **证据等级** | A=官方文档/源码；B=开源项目实践；C=训练数据假设 |
| **黑板（Blackboard）** | `.devloop/task.json` 作为 Claude 和脚本共享的状态交换介质 |
| **粗粒度任务** | 一个可独立交付的功能，约束 ≤ 5 个文件改动 |
| **只追加** | 文件仅追加不修改历史（lessons.md / progress.md）|
| **工件（Artifact）** | CR Gate 要求的可 `Test-Path` 的文件产物（research.md / decisions.json 等）|

---

## 12. 后续步骤

1. **用户复核本 spec**——确认设计满足预期
2. **进入 `superpowers:writing-plans`**——将本 spec 分解为可执行的实施计划（按文件粒度拆分开发任务）
3. **实施**——按 plan 逐步构建 `~/.claude/skills/dev-loop/` 的实际文件
4. **首次 dogfooding**——用 `dev-loop` skill 本身管理另一个新项目的开发，验证设计
