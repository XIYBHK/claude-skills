---
name: clip-and-summarize 摘抄收藏
description: 把用户发来的链接抓取、摘要并保存为 Markdown 笔记，作为 Obsidian/Claudian Wiki 的上游"摘抄收件箱"工具。支持知乎、B 站字幕、微信公众号和通用网页，自动生成中文文件名、摘要、frontmatter。触发时机：用户说 摘抄、收藏、保存、总结 link、把这个存下来、加入 InBox、clip it、save this article，或发来知乎/B站/微信公众号链接要求落盘。默认保存到 Obsidian vault 的 InBox/（再由 Claudian Ingest 流程归档到 sources/ + 更新 wiki/topics/）；也支持直接保存到普通 Markdown 文件。对接 Attachment Management 插件的附件命名。
license: MIT
compatibility: 需要 Python 3.10+、requests、markdownify；微信公众号抓取需额外 pip install wechat-article-to-markdown；B 站字幕抓取需 BILIBILI_SESSDATA cookie；知乎需 _xsrf 和 z_c0 cookie。Obsidian 输出建议配合 Attachment Management 插件自动管理附件。
---

# clip-and-summarize: 摘抄收藏

把一个链接变成一篇放在 `InBox/` 的 Markdown 资料，等待 Claudian Ingest 后续处理。

## 角色定位

```
用户发链接
   │
   ▼
┌──────────────────────────────────┐
│  clip-and-summarize (本 skill)    │
│  - 识别来源 (知乎/B站/微信/通用)  │
│  - 抓取 + 转 Markdown             │
│  - 生成 frontmatter + 摘要        │
│  - 保存到 vault/InBox/<中文标题>   │
└──────────────────────────────────┘
   │
   ▼ 用户下次说"处理 InBox"
┌──────────────────────────────────┐
│  Claudian (vault/CLAUDE.md)       │
│  - 归档到 sources/YYYY/MM/        │
│  - 抽取事实更新 wiki/topics/      │
│  - 更新 index / log               │
└──────────────────────────────────┘
```

**本 skill 职责边界**：只负责"链接 → InBox 资料"，**不**触达 `sources/` `wiki/topics/` `wiki/index.md`。这些由 Claudian 在 Ingest 阶段管。

## 默认行为（面向 Claudian Wiki）

| 配置项 | 默认值 | 来源 |
|---|---|---|
| Vault 根目录 | `config/local.json` 的 `vault_root` 字段（首次使用时由 Claude 询问用户） | — |
| 保存目录 | `<vault>/InBox/` | Claudian Schema §1 路径规范 |
| 文件命名 | 中文标题 ≤20 字 | Claudian Schema §1 命名规范 |
| 附件子目录 | `<vault>/InBox/<笔记名>/` | 兼容 Attachment Management 插件 |
| 图片命名 | 原始文件名；由 Attachment Management 插件后续接管为 `IMG-YYYYMMDDHHmmssSSS.<ext>` | Claudian Schema §1 |
| 知乎图片 | `data-actualsrc` 优先抽取（等价于 `_1440w.gif` 动图真身） | Claudian Schema §4.0.1 |

若不想走 Claudian 流程，用 `--target markdown --output <path>` 直接保存成普通 md 文件。

## 前置配置

### 配置文件位置（skill 工作目录下）

```
clip-and-summarize/
└── config/
    ├── clip-auth.example.json   ← 示例（被 git 追踪）
    ├── local.json               ← 本机偏好：vault_root 等（.gitignore 保护）
    └── clip-auth.json           ← 本机密钥：cookies（.gitignore 保护）
```

两个 `.json` 都在 `.gitignore` 里，**跨机器 git 同步时各自保留本地值，不会泄露也不会被覆盖**。

### 1. Vault 路径（首次使用交互式询问）

**Claude 在首次接到 clip 任务时的流程**：

1. **先**调用 `scripts/config_store.py` 检查（或直接 Read `config/local.json`）是否已有 `vault_root`。
2. 若**没有**：用 `AskUserQuestion` 向用户询问 Obsidian vault 绝对路径，例如：
   - 问题："请提供 Obsidian vault 的绝对路径（用于保存 clip 笔记到 InBox/）"
   - 示例默认值："E:\Obsidian\XIYBHK_Obsidian"
3. 拿到路径后立即执行：
   ```bash
   python scripts/setup_vault.py --vault-root "<用户提供的路径>"
   ```
   该脚本会校验路径存在、自动创建 `<vault>/InBox/`、持久化到 `config/local.json`。
4. 继续原本的 clip 流程。

后续运行直接读 `config/local.json`，不再询问。若单次想覆盖，加 `--vault-root <path>` 参数。

### 2. 认证（知乎 / B 站，可选，用到时再配）

```bash
# 复制示例
cp config/clip-auth.example.json config/clip-auth.json
# 编辑 config/clip-auth.json 填入真实 cookie
```

或用环境变量：`ZHIHU_XSRF` / `ZHIHU_Z_C0` / `BILIBILI_SESSDATA`（仅当无 config 文件时兜底）。

### 3. 依赖

```bash
pip install requests markdownify
# 微信公众号（可选）
pip install wechat-article-to-markdown
```

## 主入口：`clip_router.py`

根据 URL 自动分发到具体抓取器。

```bash
# 默认 → 保存到 vault/InBox/<中文标题>.md
python scripts/clip_router.py \
  --url "https://www.zhihu.com/question/123/answer/456" \
  --vault-root "$OBSIDIAN_VAULT"

# 保存为普通 Markdown 文件
python scripts/clip_router.py \
  --url "https://www.zhihu.com/question/123/answer/456" \
  --target markdown \
  --output "notes/zhihu-demo.md"

# 指定 vault 内的其他 folder（覆盖默认 InBox/）
python scripts/clip_router.py \
  --url "https://www.bilibili.com/video/BV1xx411c7xx" \
  --vault-root "$OBSIDIAN_VAULT" \
  --folder "B站笔记"
```

## 支持的来源

| 来源 | 脚本 | 说明 |
|---|---|---|
| 知乎回答/文章 | `fetch_zhihu.py` | API v4；抽图优先 `data-actualsrc` 保证动图 URL（`_1440w.gif`），过滤 SVG 占位图 |
| B 站视频 | `fetch_bilibili.py` | 字幕优先；无字幕时退回元数据笔记 |
| 微信公众号 | `fetch_wechat.py` → `wechat-article-to-markdown` | wrapper 强制 UTF-8 子进程环境（`PYTHONUTF8=1`、`PYTHONIOENCODING=utf-8`），后处理图片目录 `images/` → `<笔记名>/` |
| 通用网页 | `fetch_generic.py` | 走 Jina Reader `r.jina.ai/<url>`，绕过本地 DNS/SSRF |

## 输出格式（对齐 Claudian sources 原始资料）

文件落在 `<vault>/InBox/<中文标题>.md`，结构如下：

```markdown
---
title: 中文标题（≤20 字）
source: https://原始 URL
type: zhihu-answer | zhihu-article | bilibili-video | wechat-article | generic-web
author: 作者（可选）
date: YYYY-MM-DD（文章原始发布日期，用于 Claudian 归档到 sources/YYYY/MM/）
tags:
  - 摘抄
---

# 中文标题

## 摘要

- 一两条关键点（抽取式为兜底，AI 改写式优先）

## 原文

<正文 / 字幕整理 / 原文内容>
```

> [!note] 为什么 sources 笔记不加 `领域/` `主题/` tag
> Claudian Schema §3 明确：原始资料（`sources/**`）**不**加领域/主题 tag，tag 只用于 wiki 主题页。这里只加 `摘抄` 作为来源标记。

## 文件名规则（Claudian Schema §1）

- **≤20 字的中文标题**，空格分隔单词
- ✅ `UE5 K2Node 开发教训.md`、`Windows Terminal 配置 Claude Code 工作流.md`
- ❌ `ue5-k2node-lessons.md`（不用英文 slug）
- 若原文无中文标题（仅 URL），由 AI 根据内容拟定
- 若标题含非法文件名字符（`:*?"<>|\/`），替换为空格或全角符号

## 知乎动图优先（Claudian Schema §4.0.1）

知乎 HTML 里：

| 属性 | 内容 | 是否保留 |
|---|---|---|
| `<img src="...v2-xxx_b.jpg">` | 静态封面 | ❌ 不要 |
| `<img data-actualsrc="...v2-xxx_1440w.gif">` | 动图真身 | ✅ 优先用 |
| `<img data-original="...">` | 原图 | 备选 |
| SVG 占位 `<img src="data:image/svg+xml,...">` | 占位 | ❌ 过滤 |

`fetch_zhihu.py` 内在转 Markdown 前会 preprocess：把 `data-actualsrc` / `data-original` 值覆盖到 `src`，再交 markdownify。

## WeChat 抓取特别说明

微信公众号抓取走外部 Python 包 `wechat-article-to-markdown`。本 skill 的 wrapper `fetch_wechat.py` 负责：

1. 用 `scripts/clip_router.py` 统一入口，**不**直接 `python -m wechat_article_to_markdown`
2. 子进程强制 UTF-8（`PYTHONUTF8=1`、`PYTHONIOENCODING=utf-8`、`-X utf8`），防 Windows GBK console 崩溃
3. 后处理图片目录 `images/` → `<笔记名>/`
4. 生成 frontmatter + `摘抄` tag + 摘要

## 安全与卫生

- ❌ 禁止在 skill 文件里 hardcode cookies / SESSDATA / API key
- ✅ secrets 只在 `~/.claude/config/clip-auth.json` 或环境变量
- 若旧的 `tools/content-collectors/private/auth.json` 仍存在，脚本会作为 legacy 回退读取（方便过渡），但新位置是 `~/.claude/config/`

## 何时**不**触发本 skill

- 用户只是问"这个链接是什么" → 用 `defuddle` / `web-access` 读，不要落盘
- 用户只要个一句话摘要 → 直接答，不要写文件
- 用户要"ingest 到 wiki/topics" → 这是 **Claudian** 的活（见 vault/CLAUDE.md §4），不要越界

## Agent 执行时的内部委托（对用户无感）

Claude 执行本 skill 时，以下场景**自动**通过 `Skill(...)` 委托给相关 skill，**不**询问用户，**不**出现在对话输出里：

| 触发条件 | 自动调用的 skill | 用途 |
|---|---|---|
| 需要用到不常见的 Obsidian 扩展语法（嵌套 callout、embed 指定页数、block id、wikilink 别名等）| `obsidian-markdown` | 拿权威语法，不要猜测 |
| 需要判断 vault 里是否已有同标题笔记（去重）、读取/查询现有内容、设置 frontmatter 属性、触发 Obsidian 端动作 | `obsidian-cli` | 直接 CLI 驱动运行中的 Obsidian |
| 用户后续说"处理 InBox"、"ingest" | 不自己做，把控制权交还 | Claudian（vault/CLAUDE.md §4）负责归档 + 更新 wiki/topics/ |

### 常见约定已内化在代码里，默认无需 re-query

为避免每次 clip 都重新查 `obsidian-markdown`，高频约定已编码在 `save_note.py` / `clip_router.py` 里：

- **图片引用**：wikilink embed `![[filename.png]]`（仅文件名，不带路径）
- **Frontmatter tags**：原始资料只打 `摘抄`（Claudian Schema §3 —— sources/ 不加领域/主题 tag）
- **文件命名**：中文标题 ≤20 字，非法字符由 `sanitize_filename` 清理
- **附件目录**：与笔记同名 `<笔记名>/`，让 Attachment Management 插件接管 rename

这些约定变化时，改 `save_note.py` / `clip_router.py` 即可；**不需要**在每次 clip 会话中重复加载 obsidian-markdown。
