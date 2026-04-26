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

## 6 Gate × 4 层机制对照（v0.1.6）

**重要澄清**：`guard_commit.ps1` 是 Claude Code PreToolUse hook，只拦 Claude 通过 Bash 调用的 `git commit`。`run.ps1` 自动循环路径的 commit 是 PS 进程内直接调用，**不触发 hook**。v0.1/v0.1.1 下 CR-5/6/P0-2 diff 等 gate 在自动路径上是虚的——只有 `verify_cmds` 复验生效。

v0.1.2 起抽出 `lib/gate_runner.ps1` 的 `Test-DevLoopGates`，由两条路径共享调用，其他 gate 才真正双路径生效。

### Init 阶段 gate（仅 Claude 手动触发，无自动路径）

| Gate | 位置 | 层 1 Prompt | 层 2 Schema | 层 3 工件 |
|---|---|---|---|---|
| CR-1 | init 段 1 后 | INIT.md §1 | `stage1.json.uncertainties` 必存在 | `research-stage1.md` |
| CR-2 | init 段 2 落盘前 | INIT.md §2 | `architecture.md` 每行含 `[A-C]` 正则 | `decisions.json` |
| CR-3 | init 段 3 后 | INIT.md §3 | `estimated_files ≤ maxFilesPerTask` | task.json 本身 |
| CR-4 | init 段 4 后 | INIT.md §4 | `config.verify.globalCmds` 可解释；`task.verify_cmds` 非空 | `payload.json` + `config.json`；v0.1.6 不生成 `cmd_check.json` |

CR-4 的真实执行兜底在 run 阶段：
`config.init.cmds` 失败 → `run.ps1` exit 3；
`verify.globalCmds` / `task.verify_cmds` 失败 → 当前 attempt 不通过；
UI 浏览器检查通过 `browser_verify.ps1` 作为 `verify.globalCmds` 中的一条命令执行。

### Run 阶段 gate（双路径对比）

| Gate | Claude 手动路径<br/>`guard_commit` hook | run.ps1 自动路径<br/>`Test-DevLoopGates` + `Invoke-VerifyRunner` |
|---|---|---|
| CR-5：research.md 存在 | ✓ v0.1 起 | ✗ v0.1 虚 → ✓ **v0.1.2 起真生效** |
| CR-6：task.notes 含 `CR-6:` | ✓ v0.1 起 | ✗ v0.1 虚 → ✓ **v0.1.2 起真生效** |
| CR-6 "有" → lessons 当日条目 | ✓ v0.1 起 | ✗ v0.1 虚 → ✓ **v0.1.2 起真生效** |
| P0-2：task.json 结构防篡改 | ✓ v0.1.1 起 | ✗ 虚 → ✓ **v0.1.2 起真生效** |
| verify_cmds 复验 | ✓ v0.1 起（`Invoke-VerifyRunner`） | ✓ v0.1 起（run.ps1 attempt loop 内调） |
| `[skip-devloop]` 豁免 | ✓ 生效（hook 放行） | ✗ 不适用（run.ps1 不看 commit message） |

**两条路径的角色**：
- **手动路径**：人类或 Claude 临时手工 commit 时的兜底防线（外层）
- **自动路径**：run.ps1 成功路径上的事务边界（内层）。v0.1.6 事务顺序：
  headless Claude exit code 为 0 → `Invoke-VerifyRunner` ✓ →
  `Test-DevLoopGates` ✓ → update task/progress → `git add -A` →
  `git commit` → 检查 `$LASTEXITCODE`。

## run.ps1 exit code 语义（v0.1.6）

| code | 含义 |
|---|---|
| 0 | 全部 runnable 任务完成，或按 `-MaxTasks` 正常停止 |
| 2 | 连续 blocked 达到 `maxConsecBlocked` |
| 3 | harness precondition 失败，例如 `config.init.cmds` 非零 |
| 4 | 验证与 gate 已通过，但 `git commit` 失败 |
| 5 | 无 runnable task，但仍有 blocked 或 pending 任务 |

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
