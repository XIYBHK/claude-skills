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
- `scripts/run.ps1` + `materialize.ps1` + `guard_commit.ps1` + `browser_verify.ps1` + `lib/` — PowerShell 执行骨架
- `tests/` — Pester 单元测试
- `references/` — 按需查阅参考（schemas / failure-playbook / ...）
- `docs/specs/` — v0.1 初始设计归档（历史，不是当前 SSoT）
- `docs/plans/` — v0.1 初始实施计划归档（历史，不是当前 SSoT）

## 文档

- [INIT](INIT.md) / [RUN](RUN.md) / [CRITICAL_REVIEW](CRITICAL_REVIEW.md) — 当前运行协议
- [references](references/) — schemas / failure-playbook / browser-testing / roadmap
- [CHANGELOG](CHANGELOG.md) — 版本变更
- [设计规格](docs/specs/2026-04-26-dev-loop-skill-design.md) — v0.1 历史设计归档
- [实施计划](docs/plans/2026-04-26-dev-loop-skill.md) — v0.1 历史实施归档

## 发布流程

本 skill 的 patch/minor release 走固定流程，避免"看起来推上去了但实际没"的漂移：

1. `dev-loop-vX.Y.Z-patch` 分支起自最新 `main`，完整改动 + 对应 Pester 新增/加强
2. `Invoke-Pester -Path tests`：必须全绿；记录 Pass/Fail 数入 CHANGELOG
3. `git tag -a dev-loop-vX.Y.Z -m "..."` 统一用 annotated tag（与历史 v0.1.0/0.1.1/0.1.2/0.1.4+ 一致）
4. `git push -u origin dev-loop-vX.Y.Z-patch && git push origin dev-loop-vX.Y.Z`
5. `git checkout main && git merge --ff-only dev-loop-vX.Y.Z-patch && git push origin main`
6. 清理分支：`git branch -d dev-loop-vX.Y.Z-patch && git push origin --delete dev-loop-vX.Y.Z-patch`
7. **远端核验（非可选）**：
   ```bash
   git fetch origin --tags --prune
   git ls-remote --heads --tags origin main 'refs/tags/dev-loop-v*'
   git cat-file -t dev-loop-vX.Y.Z    # 期望 'tag'（annotated），不应为 'commit'（lightweight）
   ```
   若 `git ls-remote` 因网络临时失败，稍后重试直至成功；不可跳过。
