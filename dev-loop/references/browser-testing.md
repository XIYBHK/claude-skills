# browser-testing.md — UI/浏览器 E2E 验证（v0.1.2 起生效）

## 目的

对齐 Anthropic《effective harnesses for long-running agents》核心原则：**像用户一样测试**。仅跑 lint / unit test / curl 不足以发现真实 UI 问题——console error、布局错位、selector 缺失只在实际浏览器里暴露。

v0.1 `browserTests` 只是空壳配置字段，runner 不消费。
**v0.1.2 起**由 `scripts/browser_verify.ps1` 真实实装。

## 工作流

1. **INIT 段 4** 识别到段 1 Q3 为"UI / 浏览器测试"项目时：
   - 把 `verify.browserTests.enabled` 设为 `true`
   - 把 `pwsh -NoProfile -File .devloop/scripts/browser_verify.ps1` 追加到 `verify.globalCmds`
   - 要求用户填 `verify.browserTests.url` 和至少 1 个 `requiredSelectors`
2. **run.ps1 每任务 verify 阶段**：`Invoke-VerifyRunner` 遍历 globalCmds 时执行 `browser_verify.ps1`
3. **browser_verify.ps1** 读 config → 生成临时 Playwright `.mjs` → 跑 → 截图落盘 → 返回 exit code

## 前置依赖

用户项目根目录必须有：
- Node.js
- `@playwright/test` 或 `playwright` 包（`npm i -D @playwright/test`）

脚本首次运行时会自动 `npx playwright install chromium`。

若项目没有 Node/Playwright 而 `browserTests.enabled=true` → 脚本会直写 stderr 并显式 exit 1，让用户装依赖或关闭 enabled。

## 配置字段

| 字段 | 类型 | 默认 | 说明 |
|---|---|---|---|
| `verify.browserTests.enabled` | bool | `false`（UI 项目 INIT 覆盖为 `true`） | 总开关 |
| `verify.browserTests.url` | string | `http://localhost:3000` | 被测 URL |
| `verify.browserTests.consoleErrorCheck` | bool | `true` | 是否把 console error 视为失败 |
| `verify.browserTests.requiredSelectors` | string[] | `[]` | CSS/Playwright selector 列表，任一缺失 → 失败 |
| `verify.browserTests.screenshotDir` | string | `.devloop/logs/screenshots` | 截图落盘目录（追加时间戳） |

## Exit code 约定

| code | 含义 |
|---|---|
| 0 | 全部通过 |
| 1 | 前置错误（缺 config / 缺 npx / 缺 playwright） |
| 2 | 导航失败（URL 打不开或 status 非 2xx） |
| 3 | 某个 requiredSelector 不存在 |
| 4 | 检测到 console error（且 consoleErrorCheck=true） |

## 与 verify_cmds 的关系

`browser_verify.ps1` 作为 `verify.globalCmds` 里的**普通一条命令**被 `Invoke-VerifyRunner` 调用——不侵入 runner 逻辑。因此它对所有任务生效；这通常正是 UI 项目的意图。

## 手工关闭

v0.1.6 没有 per-task 浏览器跳过开关。只要 `browser_verify.ps1` 位于
`verify.globalCmds`，它就会对所有任务生效；改某个 task 的 `verify_cmds`
不能跳过全局浏览器检查。

临时关闭只能由人类显式修改 `.devloop/config.json`，Claude 不应自行改：
- 将 `verify.browserTests.enabled` 改为 `false`；或
- 从 `verify.globalCmds` 移除 `pwsh -NoProfile -File .devloop/scripts/browser_verify.ps1`

更好的做法：**v0.2** 增加 per-task 的 `skip_browser_tests` 字段。

## 为什么不用 chrome-devtools MCP

- MCP 只在 Claude Code 上下文内可用
- `run.ps1` 是 headless 外部脚本，跑不了 MCP
- Playwright 是跨环境、CLI 可调用的最小依赖
