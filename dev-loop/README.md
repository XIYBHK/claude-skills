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
