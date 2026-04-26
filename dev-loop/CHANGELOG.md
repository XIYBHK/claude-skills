# Dev-Loop Skill Changelog

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
