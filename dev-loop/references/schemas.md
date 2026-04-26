# schemas.md — task.json / config.json 完整 JSON Schema

## task.json（顶层）

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| schemaVersion | string | ✓ | 当前固定 `"1.0"` |
| project.name | string | ✓ | 项目名 |
| project.mainBranch | string | ✓ | 主分支名（run.ps1 guard 用） |
| project.createdAt | ISO-8601 | ✓ | init 时间 |
| project.lastRunAt | ISO-8601 \| null | ✓ | 预留字段；v0.1.6 `run.ps1` 暂不更新 |
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
| passes | bool | ✓ | Claude 可先写；v0.1.6 只有 verify + gate 通过后由 `run.ps1` 锁定为 true |
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

---

## 字段命名约定

v0.1 schema 采用**混合命名风格**，规则：

| 风格 | 使用场景 | 示例 |
|---|---|---|
| `snake_case` | 由 init 段 3 从自然语言需求拆分出、用户直接编辑的字段 | `estimated_files`, `depends_on`, `verify_cmds` |
| `camelCase` | 由 run.ps1 / guard_commit 自动写入、运行时状态字段 | `schemaVersion`, `blockReason`, `lastError`, `startedAt`, `completedAt`, `mainBranch` |
| `camelCase`（全 config） | `config.json` 所有字段统一 camelCase | `maxFilesPerTask`, `claudeTimeoutSec`, `commitTemplate`, `context7Available` |

**为什么混合**：`snake_case` 字段更接近"任务描述"，用户在 init 对话和 task.json 人工审阅时更易读；`camelCase` 字段贴近 PS/JSON 惯例，run.ps1 的 `$task.startedAt` 等访问更自然。一致性让位于可读性。

**v0.2 预留**：如统一风格，计划全量切到 `camelCase` + schemaVersion bump `"1.0" → "2.0"`，迁移脚本 `migrations/schema-1-to-2.ps1`。

---

## config.json 特殊字段语义

| 字段 | 类型 | 默认 | 语义 |
|---|---|---|---|
| `limits.totalBudgetMinutes` | int | `0` | 整次 run.ps1 的总时长预算（分钟）。**`0` 表示不限制**。v0.1 run.ps1 **暂未消费**此字段，预留供 v0.2 实现"整体超时停机"；用户可先填数值，切换到 v0.2 时自动生效 |
| `limits.maxAttemptsPerTask` | int | `3` | 单任务最大 attempt 次数（a2 策略） |
| `limits.maxConsecBlocked` | int | `3` | 连续 blocked 停机阈值（b1 策略） |
| `limits.maxFilesPerTask` | int | `5` | task schema 中 `estimated_files` 的上限；v0.1.6 `Assert-TaskJsonValid` 已消费 |
| `limits.claudeTimeoutSec` | int | `1800` | 单次 Invoke-HeadlessClaude 超时（秒） |
| `git.autoPush` | bool | `false` | 是否每任务 commit 后自动 git push。v0.1 仅 `false`，预留 v0.3 |
| `claude.model` | string \| null | `null` | 预留字段；v0.1.6 `Invoke-HeadlessClaude` 暂不消费，实际走 claude CLI 默认 |
| `claude.dangerouslySkipPermissions` | bool | `true` | 预留字段；v0.1.6 命令行固定传 `--dangerously-skip-permissions` |
| `claude.outputFormat` | string | `json` | 预留字段；v0.1.6 命令行固定传 `--output-format json` |
| `claude.mcp.context7Available` | bool | `false` | context7 MCP 可用性声明。`true` 时 CR-5 查证优先走 MCP；`false` 时走 WebSearch 兜底 |
| `verify.browserTests.enabled` | bool | 模板 `false` / INIT 段 4 覆盖 | **v0.1.2 起真实消费**：UI 项目由 `materialize.ps1` 置为 `true`，并把 `browser_verify.ps1` 追加到 `verify.globalCmds` |

**为什么保留 `totalBudgetMinutes=0` 而不是删字段**：v0.2 并行/超时停机是明确路线图，字段先稳定在 schema 里，比到时再破坏 `schemaVersion` 好。

**当前未消费字段**：`project.lastRunAt`、`limits.totalBudgetMinutes`、
`git.autoPush`、`claude.model`、`claude.dangerouslySkipPermissions`、
`claude.outputFormat` 是向后兼容的预留字段；文档或配置中出现不代表
v0.1.6 运行时会读取它们。
