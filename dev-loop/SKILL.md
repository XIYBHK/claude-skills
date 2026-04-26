---
name: dev-loop
description: 用于项目启动和循环执行开发任务的 harness。TRIGGER 当用户要：(1) 为新项目搭建自动化开发循环（"做个循环执行脚本"/"帮我拆任务自动跑"/"基于任务列表自动开发"）；(2) 在已有 .devloop/ 项目执行 `/dev-loop init` 或 `/dev-loop run`；(3) 讨论"长期运行 agent 的 harness 设计"。SKIP 当：任务是一次性实现、debug、code review，或项目没有明确的任务清单需求。
---

# Dev-Loop Skill

两阶段 harness：init 四段对话生成 `.devloop/` 工作流，`run.ps1` 驱动 headless Claude 循环执行任务。

## 决策流程图

```dot
digraph dev_loop {
    "User triggers /dev-loop" [shape=doublecircle];
    "Which subcommand?" [shape=diamond];
    "Read INIT.md and execute 4-stage dialog" [shape=box];
    "Point user to .\\.devloop\\scripts\\run.ps1" [shape=box];

    "User triggers /dev-loop" -> "Which subcommand?";
    "Which subcommand?" -> "Read INIT.md and execute 4-stage dialog" [label="init"];
    "Which subcommand?" -> "Point user to .\\.devloop\\scripts\\run.ps1" [label="run"];
}
```

## 两个入口命令

- `/dev-loop init` — 交互式四段对话生成完整 harness（Read `INIT.md`）
- `/dev-loop run` — 提示用户从 PowerShell 执行 `.\.devloop\scripts\run.ps1`（Claude 不在会话内循环）

## 必读文档（按需）

- `INIT.md` — init 阶段 Claude 主动 Read
- `RUN.md` — run 阶段 headless Claude 冷启动时 Read
- `CRITICAL_REVIEW.md` — 6 个 CR Gate 完整判定准则
- `docs/specs/2026-04-26-dev-loop-skill-design.md` — 完整设计规格（SSoT）

## 绝不做的事（红线）

1. 禁止直接创建 task.json 而跳过 INIT.md 的 4 段对话
2. 禁止在未触发 CR-2（证据等级审查）的情况下生成 architecture.md
3. 禁止把 run.ps1 的循环逻辑写进 Claude 对话里"自己循环"——Claude 不负责循环调度
4. 禁止自动 push / 自动 PR
5. 禁止修改已落盘的 `.devloop/config.json`（init 一次写入，run 阶段只读）
6. 禁止为了过 CR gate 而伪造查证记录——CR-5 允许 `NO_RESEARCH_NEEDED` 诚实出口

## 引用资料

按需查阅 `references/` 目录：
- `schemas.md` — task.json / config.json 完整 JSON Schema
- `failure-playbook.md` — 失败策略决策树（a2+b1+c1）
- `headless-gotchas.md` — Windows + headless Claude 已知坑
- `evidence-levels.md` — A/B/C 证据等级判定与升级流程
- `task-granularity.md` — 粗粒度 + 5 文件约束判例
- `ROADMAP.md` — v0.2+ 扩展计划
