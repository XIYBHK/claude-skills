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
