# INIT.md — 四段对话初始化协议

当用户执行 `/dev-loop init`（在目标项目根目录）时，严格按 4 段走，每段末用户审批后推进。

## 段 1：目标 & 测试判定规则

按顺序问 6 组问题，每组 1–2 问：

| # | 问 | 目的 |
|---|---|---|
| Q1 | 项目用途、目标用户、MVP 范围 | 明确 scope |
| Q2 | 技术栈（语言/框架/运行时） | 为段 2 定锚 |
| Q3 | **测试判定规则**（按项目形态分类） | 核心，见下 |
| Q4 | commit category 枚举 | feat/fix/refactor/docs/test/chore |
| Q5 | git 主分支名、远程情况 | 供提交和 guard 使用 |
| Q6 | 是否已配置 context7 MCP | 决定 CR-5 查证流程 |

### Q3 细分（按项目形态）

- **自动化命令**（必填）：lint / typecheck / unit test / build 各自的命令
- **UI/浏览器测试**（若适用）：「控制台 0 error」+「指定元素存在」+「截图存档」
- **后端 API 测试**（若适用）：「指定 endpoint 返回预期 schema」+「exit code 0」
- **UE 插件**（若适用）：「RunUAT BuildPlugin 成功」+「Editor 启动无 log warning」
- **手动验证**（兜底）：每次怎么确认的清单

### CR-1 触发

答案里出现「随便 / 你看着办 / 不确定 / 应该 / 可能」任一词 →
**必须**进入查证模式（context7 / WebSearch）再给建议。

### 落盘

暂存结构化 JSON 到 `.devloop/init/stage1.json`，**不写** `architecture.md`。用户审批后进段 2。

## 段 2：architecture.md + CR-2 证据等级

1. 读 `stage1.json`
2. 生成 `architecture.md` 草稿，**每个技术决策必须标** `[A/B/C]` 等级
3. **CR-2 自动触发**：扫描所有 `[C]`，逐个升级流程：
   - `context7` 查 latest docs → 升级到 A 或降级
   - 无命中 → `WebSearch` → 升级到 B
   - 仍无 → 明确标 `[C — 未验证]` 并写入 `lessons.md`
4. 查证产物落盘 `.devloop/init/decisions.json`
5. 交用户审；落盘 `architecture.md` 到项目根

## 段 3：task.json + CR-3 拆分自检

1. 读 `architecture.md` + `decisions.json`
2. 按粗粒度 + 单任务 ≤ 5 文件拆分
3. 每条 task schema（见 `references/schemas.md`）必须完整
4. **CR-3 自动触发**：自问 4 问题
   - `estimated_files > 5`？
   - 依赖图有环？
   - 两任务改动重叠？
   - `verify_cmds` 非空且可执行？
5. 任一未通过 → 重拆并重跑 CR-3
6. 交用户审；落盘 `.devloop/task.json`

## 段 4：配套文件 + CR-4 配置审查

**v0.1.2 起**：Claude 只产出一份 `.devloop/init/payload.json`（段 1-3 的结构化汇总），具体文件拷贝/项目名占位符替换/`.gitignore` 追加/`browserTests` 映射等**全部由 `scripts/materialize.ps1` 确定性完成**。

```powershell
pwsh -File ~/.claude/skills/dev-loop/scripts/materialize.ps1 `
     -InitPayload .devloop/init/payload.json `
     -ProjectRoot .
```

`payload.json` schema 见 `scripts/materialize.ps1` 顶部注释块，字段：
- `project` / `q3` / `commitCategories` / `context7Available` / `architectureMd` / `tasks`

其中 `commitCategories` 当前不被 `materialize.ps1` 消费，仅作为 payload 审计
和未来模板扩展的预留字段；运行时以 `tasks[].category` 为准。

落盘产物（由脚本一次性生成）：

| 生成物 | 来源 |
|---|---|
| `CLAUDE.md`（根） | `templates/CLAUDE.md.tpl` + `project.name` |
| `.devloop/config.json` | `templates/config.json.tpl` + Q3 verify_cmds |
| `.devloop/scripts/run.ps1` | 从 skill scripts 拷贝 |
| `.devloop/scripts/guard_commit.ps1` | 从 skill scripts 拷贝 |
| `.devloop/scripts/browser_verify.ps1` | 从 skill scripts 拷贝 |
| `.devloop/scripts/lib/*.ps1` | 从 skill scripts/lib 拷贝 |
| `.claude/settings.json` | `templates/claude-settings.json.tpl` |
| `.gitignore`（追加） | `templates/gitignore.tpl` |
| `.devloop/progress.md` | 模板初始化为空 |
| `.devloop/lessons.md` | 模板初始化为空 |

### Q3 形态 → `browserTests` 默认映射（v0.1.1，v0.1.2 起真实实装）

基于段 1 Q3 识别的项目形态，生成 `config.json` 时**必须**按下表设置 `verify.browserTests.enabled`：

| Q3 形态 | `browserTests.enabled` | 理由 |
|---|---|---|
| UI / 浏览器测试 | `true` | 对齐《effective harnesses》原则：UI 项目必须像用户一样端到端测 |
| 后端 API | `false` | API 用 schema + exit code 验证更直接 |
| UE 插件 / CLI / 库 | `false` | 无浏览器可测 |
| 手动验证兜底 | `false` | 无法自动化 |

UI 项目开 `browserTests.enabled=true` 时：
1. 必须同时填 `verify.browserTests.url` 和 `requiredSelectors` 至少 1 项；否则必须让用户补充后再落盘
2. 必须把 `pwsh -NoProfile -File .devloop/scripts/browser_verify.ps1` **追加到** `verify.globalCmds`（v0.1.2 起由 `scripts/browser_verify.ps1` 真实消费，详见 `references/browser-testing.md`）
3. 用户项目须有 Node.js + `@playwright/test`（首次运行自动 `npx playwright install chromium`）

**CR-4 当前语义（v0.1.6）**：段 4 不再承诺生成 `cmd_check.json`。
Claude 在用户审批前必须对 `config.json` 中的命令做静态可解释性审查，
但真正的可执行性以 run 阶段实跑为准：

1. **可执行程序检测**：提取首个 token（`npm run build` → `npm`），跑 `<token> --version`
2. **Script/任务存在性**：
   - npm scripts → 解析 `package.json.scripts`
   - make targets → 解析 `Makefile`
   - 其他复合命令 → 标记为“人工确认”，让用户确认后再落盘
3. **运行时兜底**：
   - `config.init.cmds` 由 `run.ps1` 的 `Invoke-InitCmds` 实跑，失败时 exit 3
   - `verify.globalCmds` + `task.verify_cmds` 由 `Invoke-VerifyRunner` 实跑，失败则该 attempt 不通过
   - UI 项目的 `browser_verify.ps1` 作为一条 `verify.globalCmds` 被同一机制调用

若静态审查发现缺命令、缺 npm script、缺 browser selector 或无法解释的验证链，
必须让用户澄清或修正；不要虚构 `.devloop/init/cmd_check.json` 作为证据。

### 段 4 收尾

```powershell
git add -A
git commit -m "chore(dev-loop): 初始化 dev-loop harness

- architecture.md: 架构与证据等级
- .devloop/task.json: <N> 个粗粒度任务
- CLAUDE.md: 工作流定义
- .devloop/scripts/run.ps1: 循环驱动器
- .devloop/scripts/browser_verify.ps1: UI 浏览器验证器"
```

输出给用户：

```
✓ init 完成，<N> 个任务已就绪
  查看架构：architecture.md
  查看任务：.devloop/task.json

开始循环执行：
  .\.devloop\scripts\run.ps1

建议先干跑验证一次：
  .\.devloop\scripts\run.ps1 -DryRun -MaxTasks 1
```
