---
name: skill-frontmatter-zh 技能中文化
description: 扫描 skills 目录下所有 SKILL.md 的 YAML frontmatter，自动为 name 和 description 添加中文翻译。触发时机：用户要求"中文化 skills"、"翻译 skill 的 name/description"、"给 skill 加中文说明"、"批量处理 SKILL.md frontmatter"、"skill 元数据中文化"、"同步上游 skill 后重新中文化"。默认目录 ~/.claude/skills/，可传入其他路径（如项目级 .claude/skills/）。只改 name 和 description 两个字段，保留 license/metadata/allowed-tools 等其他 frontmatter 字段不变，不触及 SKILL.md 正文。
---

# skill-frontmatter-zh: 技能 Frontmatter 中文化

批量为 Claude Code skills 的 SKILL.md frontmatter 添加中文，便于在中文环境下浏览和检索。

## 目标格式

```yaml
---
name: <英文名> <中文说明>   # 中文说明 4-6 字
description: <完整中文翻译，保留关键触发词>
...                         # 其他字段保持原样
---
```

**示例**：

修改前：
```yaml
name: canvas-design
description: Create beautiful visual art in .png and .pdf documents using design philosophy...
license: Complete terms in LICENSE.txt
```

修改后：
```yaml
name: canvas-design 静态设计
description: 使用设计理念在 .png 和 .pdf 文档中创作精美视觉艺术。当用户要求制作海报、艺术作品、设计或其他静态作品时使用此 skill。创建原创设计，避免复制他人作品以防侵权。
license: Complete terms in LICENSE.txt
```

## 工作流程

### 1. 扫描目录

默认 `~/.claude/skills/`，用户指定则用用户路径。用 Glob 匹配 `*/SKILL.md`。

### 2. 批量抓取 frontmatter

用 Grep 匹配 `^(name|description):` 获取每个文件的头部字段。对 description 被省略（含特殊字符触发 Grep 截断）或多行格式（`|`、`>`、折叠式）的 skill，额外用 Read 查看前 10-15 行以确认完整格式。

### 3. 判断是否需要处理

- **name**：已包含 CJK 字符（中文/日文/韩文）视为已处理，跳过。
- **description**：开头已是中文视为已处理；中英混合（如用英文扩展触发词）也视为已处理，不重写。

这样设计的原因：用户通常已经针对某些 skill 做过精心中文化，再次运行本 skill 不应覆盖他们的成果。

### 4. 生成翻译

**name 后缀**（4-6 字）：根据 description 归纳主功能。常见模式参考：

| 原 name 模式 | 中文后缀建议 |
|---|---|
| `xxx-creator` / `xxx-builder` | xxx 创建 / xxx 构建 |
| `xxx-design` / `xxx-art` | xxx 设计 / xxx 艺术 |
| `obsidian-xxx` | Obsidian xxx |
| 文件格式（pdf/docx/pptx/xlsx） | PDF 处理 / Word 文档 / 演示文稿 / 电子表格 |
| `xxx-testing` / `xxx-review` | xxx 测试 / xxx 审查 |
| `xxx-cli` / `xxx-tool` | xxx 命令行 / xxx 工具 |

对照表只是参考——真正的选词应该反映 description 里的核心能力。

**description 翻译**：
- 完整译为中文，不要显著缩短，保持信息密度。
- 保留关键技术术语与触发词的英文：API、SDK、MCP、prompt caching、TRIGGER/SKIP、文件扩展名（.docx/.xlsx 等）、import 包名（`anthropic`/`@anthropic-ai/sdk`）。保留英文让中英文用户都能成功触发。
- 保留原有的"触发时机 + 跳过条件"结构（若原文有 TRIGGER/SKIP 两段）。

### 5. 保留原 YAML 格式

description 的 YAML 书写形式多样，修改时必须匹配原格式：

| 原格式 | 改后应当 |
|---|---|
| `description: Create...`（无引号单行） | 译文无特殊字符时保持无引号 |
| `description: "Use this..."`（双引号单行） | 保留双引号，内部 `"` 需转义为 `\"` |
| `description: \|` + 缩进行 | 块标量，保持 `\|` 和缩进 |
| `description:` + 缩进行（折叠式） | 保持缩进，不加 `\|` |

若译文含 `:`、`#`、`"` 等 YAML 特殊字符而原文无引号，需要加双引号或改用块标量。

### 6. 应用修改

用 Edit 工具替换 name 行和 description 行（或多行 description 的对应区域）。`old_string` 要精确包含原始内容（含换行）。

文件编码：所有 SKILL.md 按 UTF-8 处理（Edit 工具默认支持）。

### 7. 汇报

```
扫描 N 个 skill
├─ 已中文化、跳过 X 个：[列表]
├─ 新翻译 Y 个：[列表]
└─ 格式异常需手动处理 Z 个：[列表及原因]
```

## 硬性规则

- **只改 name 和 description** 两字段，license/metadata/allowed-tools/compatibility/github 等字段一字不动。
- **不改 SKILL.md 正文**，不改代码，不改目录结构。
- **不 commit**，只修改文件，用户 review 后自行提交。
- **不删除英文名**：name 格式是 `英文 中文`，**追加**中文而不是替换。
- **不删除英文触发词**：description 译文中保留 import 路径、API 名称、TRIGGER/SKIP 等英文关键词，方便双语触发。

## 常见跳过场景

以下 skill 即使 name 纯英文，description 内容也视为"已中文化"，跳过：
- name 已是 `xxx-zh` 等带语言后缀，且 description 是中文的（如 `humanizer-zh`）
- description 以中文开头，后续含英文触发词的混合格式
- 用户在调用 skill 时明确指定排除的 skill

## 可能的副作用（请用户知悉）

给 name 追加中文会让 frontmatter 的 `name` 字段不再是纯 kebab-case 标识符。目前 Claude Code 的 skill 识别以目录名为主，name 字段作为显示标签，因此追加中文不影响触发。但如果将来有工具按 name 字段做精确匹配，可能需要去掉中文后缀。

如果用户希望更保守，可选方案：
- 仅翻译 description，不动 name（运行前让用户确认）
- 把中文说明放到 frontmatter 的 `metadata.zh_name` 等自定义字段而非 name 本身
