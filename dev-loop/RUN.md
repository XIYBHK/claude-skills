# RUN.md — 单任务执行协议

当 `run.ps1` 启动你时，严格按以下 7 步执行。不得跳步。

## 1. 必读清单（冷启动上下文重建）

按顺序读取：
- `git log --oneline -20` → 查看最近 20 次提交，理解项目近期轨迹与 HEAD 状态
- `.devloop/task.json` → 定位 id=`<TASK_ID>` 的任务
- `architecture.md` → 项目架构与 [A/B/C] 证据等级
- `CLAUDE.md` → 工作流规则
- `.devloop/progress.md` → 过往任务的完成/阻塞轨迹
- `.devloop/lessons.md` → 历史避坑经验（必读）
- `.devloop/logs/task_<TASK_ID>_attempt_<N-1>.log`（若 attempt > 1）

## 2. CR-5：任务启动前批判性审查

列出本任务要用到的所有非标准 API / 库 / 配置。
每一项回答：「我是训练数据里记得，还是真的查证过？」
不确定项必须：

  a. context7 MCP 查 latest docs（若 `config.claude.mcp.context7Available=true`）
  b. 无命中或 MCP 不可用 → WebSearch
  c. 仍无 → 读项目源码

查证记录落盘到 `.devloop/logs/task_<TASK_ID>_research.md`。
若本任务所有 API 均来自 architecture.md 的 [A] 级选型，写 `## NO_RESEARCH_NEEDED` 章节并给出依据。

## 3. 实现

- 严格按 `task.steps` 实现
- 不得超过 `task.estimated_files` 文件数（超出必须在 `task.notes` 写明原因）
- 不得偏离 `task.description` 范围
- 如果发现 `architecture.md` 有错 → 停止实现，在 `task.lastError` 写「架构需修订：...」退出

## 4. 自我验证（非正式）

跑 `task.verify_cmds` 每条命令。任何失败 → 定位 → 修复 → 重跑。
注意：这是你的自检，`run.ps1` 会独立再跑一次以最终裁决。

## 5. CR-6：commit 前批判性审查

回答 3 个问题：
  ① 改动有没有超出任务描述？           → 是 → revert 多余
  ② 有没有引入过度抽象 / 过度工程？    → 是 → 简化
  ③ 有没有更简单的替代实现？           → 是 → 回到原点重做

任何"是"必须调整，并在 `.devloop/lessons.md` 追加一条记录。

## 6. 汇报

更新 `.devloop/task.json` 中 id=`<TASK_ID>` 的条目：
- `passes`      = true / false（你的自判，脚本会复核）
- `attempts`    = 当前 attempt
- `lastError`   = 失败时具体原因
- `blockReason` = 若任务无法完成，写明根因
- `notes`       = `"CR-6: 超出描述=<无/有...> / 过度抽象=<...> / 更简替代=<...>"`

不要运行 `git add` / `git commit` / `git push` —— 这些由 `run.ps1` 完成。

## 7. 退出

执行完毕直接退出。`run.ps1` 会读取 `task.json` 和 `verify_cmds` 结果做最终判定。
