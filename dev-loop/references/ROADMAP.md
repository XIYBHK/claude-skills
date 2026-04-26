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
