# 保存目标与输出规则

## 架构

本 skill 是 Obsidian + Claudian Wiki 生态的**上游摘抄工具**，只负责"URL → InBox 的一篇资料"。下游的 wiki 化（主题提取、双向链接、领域分类）由 vault 根目录的 Claudian（`CLAUDE.md`）在 Ingest 阶段做。

```
[URL] ── clip-and-summarize ──▶ vault/InBox/<中文标题>.md
                                          │
                                          └─ 用户: "处理 InBox"
                                                    │
                                                    ▼
                                         Claudian Ingest
                                                    │
                                         ┌──────────┴──────────┐
                                         ▼                     ▼
                                  sources/YYYY/MM/       wiki/topics/*.md
                                  (原始资料归档)         (主题页更新)
```

## Vault 路径配置

vault 路径存放在 **skill 工作目录** `<skill>/config/local.json`（已在 `.gitignore` 保护，跨机器不同步）。

解析顺序：
1. CLI 参数 `--vault-root <path>`（单次覆盖）
2. `<skill>/config/local.json` 的 `vault_root` 字段（持久配置）
3. 以上都没 → 脚本报错提示用户运行 `setup_vault.py`

**首次设置**（由 Claude 在首次 clip 请求时引导，或用户直接运行）：

```bash
python scripts/setup_vault.py --vault-root "E:/Obsidian/XIYBHK_Obsidian"
```

该命令会：
- 校验路径存在
- 自动创建 `<vault>/InBox/` 子目录（clip 默认落盘位置）
- 把路径写入 `config/local.json`

后续运行 `clip_router.py` 时自动读取，不用每次重复传。

## 保存目标与 folder 约定

| `--target` | 保存到 | 默认 folder |
|---|---|---|
| `obsidian`（默认） | `<vault>/<folder>/<文件名>.md` | `InBox/` |
| `markdown` | CLI `--output <path>` 指定的任意 md 文件 | 无 |

### 为什么默认 `InBox/`

Claudian Schema §1 明确 `InBox/` 是"待处理资料的收件箱（写入方：用户）"。clip 扮演的是"快速入库"角色，**不应**直接写到 `sources/YYYY/MM/` 或 `wiki/topics/`——这些是 Claudian 才能动的区域，越界会破坏 schema 约束（见 CLAUDE.md §4 禁止事项）。

### 允许覆盖默认 folder

如果需要把链接落到 `B站笔记/` `知乎/` `微信公众号/` 这种扁平分类（而不是走 wiki 化流程），用 `--folder`：
```bash
python scripts/clip_router.py \
  --url <URL> \
  --vault-root "$OBSIDIAN_VAULT" \
  --folder "B站笔记"
```

## 文件命名规范（Claudian Schema §1）

- **中文标题**，≤20 字为宜
- 空格分隔单词（不用 kebab-case 英文 slug）
- 非法 Windows 文件名字符（`:*?"<>|\/`）替换为空格或全角符号
- 若原文有合适中文标题 → 直接沿用
- 若原文仅 URL / 纯英文标题 → AI 根据内容拟定简洁中文标题

### 示例

| 来源标题 | 保存文件名 |
|---|---|
| `UE5 K2Node 开发教训与改进清单` | `UE5 K2Node 开发教训.md` |
| `How to configure Windows Terminal for Claude Code` | `Windows Terminal 配置 Claude Code 工作流.md` |
| （仅 URL，内容讲 "fake IP and SSRF"） | `Clash fake-IP 触发 SSRF 问题.md` |

## Frontmatter 模板（与 Claudian `sources/**` 对齐）

```yaml
---
title: 中文标题
source: https://原始 URL
type: zhihu-answer | zhihu-article | bilibili-video | wechat-article | generic-web
author: <作者，可选>
date: YYYY-MM-DD   # 原文发布日期，Claudian Ingest 按此归档到 sources/YYYY/MM/
tags:
  - 摘抄
---
```

**关键约束**：
- 只放 `摘抄` tag
- **不加** `领域/*` `主题/*` `状态/*` tag（Claudian Schema §3 规则 2：sources 不加 tag，tag 只用于 wiki 主题页）
- `date` 尽量抓取文章原始发布日期；抓不到则用今天

## 正文结构

```markdown
# 中文标题

## 摘要

- 一到两条关键点（AI 改写式优先，抽取式只作兜底）

## 原文

<markdown 正文 / 字幕整理 / 原文内容，保留图片引用>
```

> 头部摘要应优先是"更像人写的总结"，生硬的抽取式摘句不应长期停留。

## 附件管理

### 目录结构

```
<vault>/InBox/
├── UE5 K2Node 开发教训.md
├── UE5 K2Node 开发教训/          ← 附件子目录（与笔记同名）
│   ├── <原始图片文件>.png
│   └── ...
└── ...
```

笔记里的图片引用格式：**Obsidian wikilink embed**，仅文件名、无路径：

```markdown
![[图片文件名.png]]
```

**不用** markdown link `![alt](path/file.png)` —— 原因：

- Obsidian 对 wikilink 做全 vault 解析，图片移动 / rename 时自动追踪
- Attachment Management 插件只跟踪 wikilink 引用，rename 附件时会同步更新笔记内引用
- 与 vault 现有笔记（`sources/**`）风格一致（见 `obsidian-markdown` skill 的权威约定）

图片物理路径仍放在 `<笔记名>/` 子目录下，只是笔记里的引用不带路径——Obsidian 自会找到。

### 与 Attachment Management 插件的配合

- clip 脚本保存时**用原始下载的文件名**（不强行 rename）
- 用户在 Obsidian 中打开该笔记时，Attachment Management 插件会按配置自动把附件 rename 成 `IMG-YYYYMMDDHHmmssSSS.<ext>`，并同步更新 md 里的图片引用
- **不要**让 clip 脚本模拟插件命名，因为插件策略可能变化

## 各来源抓取要点

### 知乎

- API v4 优于 HTML 抓取
- Cookie 认证：`_xsrf` + `z_c0`
- **图片 URL 三优先**：`data-actualsrc` > `data-original` > `src`
  - `data-actualsrc` 通常直接是动图 `_1440w.gif` 真身（Claudian Schema §4.0.1 要求）
  - `src` 多半是静态封面 `_b.jpg` 或 SVG 占位
- SVG 占位图 (`data:image/svg+xml,...`) 必须过滤
- `markdownify` 会把 `_` 转义为 `\_`，转换后需要还原（脚本已处理）

### B 站

- 字幕优先（`BILIBILI_SESSDATA` cookie）
- 无字幕视频 → 只生成元数据笔记（标题 + 描述 + 链接），标注"无字幕可用"
- 需要转写时由用户显式请求另行处理

### 微信公众号

- 走外部包 `wechat-article-to-markdown`
- wrapper 强制子进程 UTF-8（`PYTHONUTF8=1`、`PYTHONIOENCODING=utf-8`、`-X utf8`）
- 后处理 `images/` 目录改为 `<笔记名>/`
- 抓取前先验证 URL 仍可访问（公众号有时禁转）

### 通用网页

- 走 Jina Reader：`https://r.jina.ai/<url>`
- 绕过本地 DNS 问题（Clash fake-IP 等 SSRF 场景）
- 输出沿用同样的 frontmatter + 摘要 + 正文结构

## 与 Claudian Ingest 的交接

用户在 vault 里触发 `"处理 InBox"` / `"ingest X"` 时，Claudian 会（见 CLAUDE.md §4）：

1. 扫描 `InBox/*.md`
2. 按 frontmatter `date` 归档到 `sources/YYYY/MM/<slug>.md`
3. 读取内容，识别主题（1-5 个）
4. 更新或新建 `wiki/topics/<主题>.md`
5. 抽取关键事实，加 `^srcN` block ID
6. 更新 `wiki/index.md` 和 `wiki/log.md`

clip 脚本不要在上述任何阶段越界插手。
