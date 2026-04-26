# CLAUDE.md · <PROJECT_NAME>

> 此文件由 `/dev-loop init` 生成。Claude Code 会话启动时自动加载。

## 每任务必读清单（run 阶段冷启动）

按顺序读取：
1. `.devloop/task.json` — 定位当前任务
2. `architecture.md` — 项目架构与 [A/B/C] 证据等级
3. `.devloop/lessons.md` — 历史避坑经验
4. （attempt > 1 时）`.devloop/logs/task_<id>_attempt_<n-1>.log` — 上次错误

## 开发循环（run.ps1 驱动）

初始化 → 选任务 → 实现 → 测试验证 → 更新进度 → 提交

详细执行协议见 `~/.claude/skills/dev-loop/RUN.md`。

## 关键规则

1. **不要** 手动创建任务到 `task.json`——结构由 init 固化
2. **不要** 修改 `.devloop/config.json`——init 后只读
3. **不要** 运行 `git commit`——由 `run.ps1` 在验证通过后统一提交
4. **必须** 每任务开始前过 CR-5（查证不确定 API）
5. **必须** 每任务 commit 前过 CR-6（自省 3 问）

## 测试判定规则

<由 init 段 1 Q3 的回答填充>

## Commit 类型枚举

<由 init 段 1 Q4 填充，例如：feat / fix / refactor / chore / docs / test>

## Git 配置

- 主分支：<由 init 段 1 Q5 填充>
- AutoPush：关（显式手动推送）
- AutoPR：关
