# Dev-Loop Skill Changelog

## v0.1.2 (2026-04-26)

用户基于原文再次反核验提出 6 项补丁，逐条修复。**P1-1/P1-2 是根本设计
缺陷修复**，其他是配套和扩展：

- **P1-1** `scripts/lib/gate_runner.ps1` — 抽出 `Test-DevLoopGates`，两条
  路径（Claude 手动 via guard_commit hook / run.ps1 自动）共享。原设计
  里 run.ps1 直接 git commit 完全绕过 guard_commit hook，导致 CR-5/6/
  P0-2 diff 等 gate 在自动路径上全是装饰。
- **P1-2** `run.ps1` 事务顺序纠正 + `git restore --staged` —— 原 commit →
  update → progress 顺序导致 HEAD 永远滞后一拍，下轮冷启动看到的是半成
  状态。v0.1.2 改为 update → add -A → commit → 检查 $LASTEXITCODE。
- **P1-3** RUN.md §1 必读清单补 `git log --oneline -20` 与 progress.md。
- **P1-4** `run.ps1` 默认值 `-1` 哨兵，未指定时从 `config.limits.*` 读。
- **P1-5** `scripts/browser_verify.ps1` + `references/browser-testing.md`
  —— browserTests 不再是空字段，生成临时 Playwright .mjs 跑 URL 打开 /
  console error / selectors / 截图；通过 globalCmds 集成零侵入。
- **P1-6** `scripts/materialize.ps1` —— INIT §段 4 的 9 项落盘从"Claude
  自觉手写"改为脚本确定性执行，Claude 只填 `payload.json`。
- **P1-7** `CRITICAL_REVIEW.md` 表格纠正为双路径对比，诚实标注哪些 gate
  在 v0.1/v0.1.1 的自动路径上是虚的，v0.1.2 起才真生效。

Pester: 51/51（含 P1-1 新增 gate_runner 6 测试 + P1-4 新增 Get-CfgLimit
3 测试）。P1-5 / P1-6 单元测试延至项目集成阶段（依赖外部 npx/playwright
与真实 templates）。

## v0.1.1 (2026-04-26)

基于 Anthropic《effective harnesses for long-running agents》反核验补丁：

- **P0-1**: `run.ps1` 每任务进入 attempt loop 前跑 `config.init.cmds` 做项目
  健康度 smoke（对齐前作 init.sh 语义），任一失败 → exit 3 halt
- **P0-2**: `guard_commit.ps1` 加第 9 道 gate：对比 HEAD:.devloop/task.json
  防止 Claude 绕过 prompt/schema 改 task.json（禁删 task / 禁改 id /
  禁空 verify_cmds）
- **P0-3**: INIT.md §段 4 加硬规则：UI 形态项目 `browserTests.enabled`
  默认 `true`（对齐原文"像用户一样测试"核心原则），其他形态 `false`

Pester: run.Tests 10/10, guard_commit.Tests 10/10。

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
