# ROADMAP.md — v0.2+ 扩展计划

## 已完成（v0.1.x）

- v0.1.2 起：`browserTests` 已由 `scripts/browser_verify.ps1` 实装，并通过
  `verify.globalCmds` 接入 `Invoke-VerifyRunner`。
- v0.1.2 起：`materialize.ps1` 接管 INIT 段 4 的确定性落盘。
- v0.1.6 起：`Exit-WithError` 内联 helper 统一 exit 2/3/4/5 语义。

## v0.2（预计）

### 跨平台支持
- 产出 `run.sh` / `guard_commit.sh`
- `scripts/lib/*.sh` 镜像 PowerShell 版本
- 保留 v0.1 PS 版本，双轨并行

### 并行执行
- `depends_on` DAG 已就位，增加 `--parallel N` 参数
- 需处理：同时 commit 冲突、verify_cmds 串行化

### 浏览器验证增强
- per-task `skip_browser_tests` 或 `browserTests.mode`
- 多 URL / 多 viewport / trace/video 产物
- 更细的 selector 分组与失败截图索引

## v0.3（预计）

### planner / generator / evaluator 三层架构
- planner 负责任务重排、依赖诊断、blocked 归因
- generator 负责单任务实现
- evaluator 负责验证命令、浏览器证据、CR gate 的独立判定
- 目标：把当前单 loop 扩展为更清晰的 long-running agent harness

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

## 预留/已实现接口（v0.1.6）

| 字段 | 目的 | v0.1.6 行为 |
|---|---|---|
| `config.claude.mcp.context7Available` | v0.3 扩展其他 MCP | 仅 context7 |
| `config.git.autoPush` | v0.3 自动推送 | 仅 false |
| `config.verify.browserTests.enabled` | UI E2E 验证 | 已实现；通过 `browser_verify.ps1` + `verify.globalCmds` 接入 |
| `task.depends_on` | v0.2 并行 | 串行按 DAG 顺序 |
