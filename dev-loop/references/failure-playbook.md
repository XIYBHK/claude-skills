# failure-playbook.md — 失败策略决策树

## 三级保护（a2 + b1 + c1）

### 单任务级（a2）

失败 ≤ 3 次自动重试，第 4 次标 `blocked`。每次 attempt 把上次 `lastError` + log 路径喂给下一次 Claude 会话。

### 循环级（b1）

连续 3 个任务 `blocked` → 整体停止 `exit 2`，等人介入。防止同类问题（如依赖装错）把所有任务全卡死。

### 失败现场（c1）

失败任务的 WIP 改动 `git restore . && git clean -fd`，回到干净状态再跑下一任务。

## 失败时的产物

每次 attempt 失败：
- `.devloop/logs/task_<id>_attempt_<n>.log` 保留完整 Claude 输出
- `task.json` 对应任务：`attempts` 递增、`lastError` 填充（最后 30 行）

## 手工接手失败任务

任务 `blocked=true` 且 `blockReason` 非空 → 人类可：

1. 读 `blockReason` 判断根因
2. 修复或重设计（改 `task.steps` / `verify_cmds`）
3. 手动将 `blocked` 改回 `false`、`attempts` 改回 0
4. 重新跑 `run.ps1`

## stuck 排查步骤

| 症状 | 检查 |
|---|---|
| 启动即 exit | git 脏 / 在 main 分支 / `.devloop` 未初始化 |
| 连续失败同类错 | `lessons.md` 中是否缺失相关教训 |
| 所有任务 skip | `depends_on` 链条是否有断裂（被 blocked 的任务挡路） |
| guard_commit 拒绝 | research.md 缺失 / CR-6 notes 缺失 / verify_cmds 复验失败 |
