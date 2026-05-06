---
name: skill-frontmatter-zh 技能中文化
description: 扫描 skills 目录下所有 SKILL.md 的 YAML frontmatter，自动为 name 和 description 添加中文翻译；内置 translations.json 翻译缓存，英文原文未变则复用上次译文、已变则重翻并更新缓存，用户对 SKILL.md 的手动润色会被回收进缓存（越用越精准）；并支持同步 fork/submodule 的上游更新后再判断是否需要重新中文化。触发时机：用户要求"中文化 skills"、"翻译 skill 的 name/description"、"给 skill 加中文说明"、"批量处理 SKILL.md frontmatter"、"skill 元数据中文化"、"同步上游 skill 后重新中文化"、"拉取 fork 上游更新"、"更新 submodule 后中文化"、"检查 skill 有没有新版本"。默认目录 ~/.claude/skills/，可传入其他路径（如项目级 .claude/skills/）。只改 name 和 description 两个字段，保留 license/metadata/allowed-tools 等其他 frontmatter 字段不变，不触及 SKILL.md 正文。
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

## 翻译缓存 translations.json

缓存文件位于 `skill-frontmatter-zh/translations.json`，随 skill 一起 git 同步。目的是：同一英文原文始终得到同一中文译文，且用户的手动润色会被收集进缓存，越用越精准。

### Schema

```json
{
  "<skill-dir-name>": {
    "name": {
      "en": "<原 name，kebab-case>",
      "zh_suffix": "<追加到 name 后面的中文后缀，如 静态设计>"
    },
    "description": {
      "en": "<英文原文，完整字符串>",
      "zh": "<中文译文，完整字符串>"
    },
    "updated_at": "YYYY-MM-DD"
  }
}
```

- key 是 skill 的目录名（如 `canvas-design`），与 `~/.claude/skills/<key>/SKILL.md` 对应。
- `en` 与 `zh` 都是完整字符串，便于 diff 审阅，而非哈希。
- 字段顺序稳定，便于 git diff 最小化。

### 使用规则

1. **运行开始时**一次性 Read `translations.json` 载入内存；结束前一次性 Write 回盘。中途不反复读写。
2. **查缓存**：对每个 skill，用其目录名到缓存里查。
3. **命中判断**：缓存存在且 `cached.description.en` **逐字符等于** 当前 SKILL.md 的 description 英文原文 → 命中。name 不参与命中判断（同一 skill 的 name 很少变）。
4. **命中时**：直接取 `cached.description.zh` 作为译文，`cached.name.zh_suffix` 作为 name 后缀，跳过 LLM 翻译，直接进入步骤 5-6 写回 SKILL.md，同时把 `updated_at` 刷新为今天。
5. **未命中时**（缓存无此 key、或 en 已变）：走正常翻译流程（步骤 4），翻译完写回 SKILL.md **并** 写入/更新缓存该 key 的 `en`/`zh`/`zh_suffix`/`updated_at`。
6. **SKILL.md 已中文化（含 CJK）**的情况分两类：
   - 缓存有该 key、且 `cached.description.en` 还在 → 从 SKILL.md 里提取当前中文（包括 name 的中文后缀和整段 description），与缓存的 zh 比较；**不一致时以 SKILL.md 为准，覆盖缓存 zh + zh_suffix + updated_at**（用户手动润色被回收）。
   - 缓存无该 key → **不写入缓存**（没有英文原文对照，写进去也没意义）。跳过，沿用现有 skip 逻辑。

### git 约定

`translations.json` 必须 commit，不放 .gitignore。跨机器/团队使用时 pull 下来就能共享译文基线。更新缓存后，用户应当在同一次提交里一并带上 SKILL.md 和 translations.json 的改动。

## 辅助脚本

skill 自带两个 Python 脚本（无第三方依赖，纯标准库），放在 `skill-frontmatter-zh/scripts/` 下。Claude 调用它们来完成机械化的扫描与缓存写回，翻译本身仍由 Claude 做。

### scripts/inventory.py — 盘点

一次性扫描全部 `*/SKILL.md` 的 frontmatter，对照缓存，输出分类 JSON 到 stdout。手动解析 frontmatter（支持单行、块标量 `|`/`>`、缩进折叠、带引号），不依赖 PyYAML，对 description 里的 `": "` 免疫。

```bash
python skill-frontmatter-zh/scripts/inventory.py --skills-dir ~/.claude/skills
```

输出结构：

```json
{
  "skills_dir": "...",
  "cache_path": "...",
  "summary": {"need_translate": N, "cache_hit": N, "skip_cjk_no_cache": N, "reclaim_polish": N, "format_anomaly": N},
  "buckets": { "need_translate": ["skill_key", ...], ... },
  "details": {
    "<skill_key>": {
      "name": "...", "description": "...",
      "reason": "no_cache | en_changed",
      "prev_cached_desc_en": "...",
      "cached_zh": "...",          // cache_hit 场景
      "cached_zh_suffix": "...",
      "cached_desc_en": "...",      // reclaim_polish 场景（全量对照）
      "cached_desc_zh": "...",
      "current_name": "...",
      "current_description": "..."
    }
  }
}
```

退出码：`0` 正常；`1` skills 目录不存在；`3` 缓存文件 JSON 损坏。

### scripts/cache_writer.py — 缓存写回

接收 patch JSON（文件或 stdin），原子写回 `translations.json`。自动按 key 字母序排序、2 空格缩进、UTF-8 无 BOM、末尾换行、自动填 `updated_at = 今天`、内容未变则不刷新时间戳（不产生空 diff）。

```bash
# 写入/更新
python skill-frontmatter-zh/scripts/cache_writer.py \
    --cache skill-frontmatter-zh/translations.json \
    --patch patch.json

# 移除条目
python skill-frontmatter-zh/scripts/cache_writer.py \
    --cache skill-frontmatter-zh/translations.json \
    --remove obsolete-skill-key
```

patch 结构（每个 skill 必须有全四字段，否则报 errors）：

```json
{
  "<skill_key>": {
    "name": {"en": "...", "zh_suffix": "..."},
    "description": {"en": "...", "zh": "..."}
  }
}
```

stdout 是执行报告（changed / skipped_no_change / removed / errors）。退出码：`0` 正常；`3` JSON 损坏；`4` 有 entry 字段不全。

## 工作流程

### 1. 扫描与盘点

调用 `inventory.py --skills-dir <目标>`，一次拿到全量分类 JSON。用户未指定路径时默认 `~/.claude/skills/`。

### 2. 按桶决策

根据 `buckets` 分四路处理：

| 桶 | 动作 |
|---|---|
| `need_translate` | 对每个 skill，走步骤 3（LLM 翻译） → 步骤 4 写回 SKILL.md；翻译结果累积到 patch |
| `cache_hit` | 直接用 `details.cached_zh` 和 `details.cached_zh_suffix` 走步骤 4 写回 SKILL.md；同条目也进 patch（仅为刷新 `updated_at`，字段内容不变则 cache_writer 自动 skip） |
| `reclaim_polish` | SKILL.md **不动**；把 `details.current_description` 与新解析出的 name 后缀写进 patch，由 cache_writer 更新缓存 zh |
| `skip_cjk_no_cache` | 完全跳过，不进 patch |
| `format_anomaly` | 跳过，作为汇报里的"需手动处理"清单 |

### 3. 生成翻译（仅 `need_translate` 桶）

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

### 4. 写回 SKILL.md（`need_translate` + `cache_hit` 两桶）

用 Edit 工具替换 name 行和 description 行（或多行 description 的对应区域）。`old_string` 要精确包含原始内容（含换行）。`reclaim_polish` 和 `skip_cjk_no_cache` 两桶在本步跳过。

**保留原 YAML 格式**，按源文件风格匹配：

| 原格式 | 改后应当 |
|---|---|
| `description: Create...`（无引号单行） | 译文无特殊字符时保持无引号 |
| `description: "Use this..."`（双引号单行） | 保留双引号，内部 `"` 需转义为 `\"` |
| `description: \|` + 缩进行 | 块标量，保持 `\|` 和缩进 |
| `description:` + 缩进行（折叠式） | 保持缩进，不加 `\|` |

若译文含 `:`、`#`、`"` 等 YAML 特殊字符而原文无引号，需要加双引号或改用块标量。

文件编码：所有 SKILL.md 按 UTF-8 处理（Edit 工具默认支持）。

### 5. 写回缓存（cache_writer.py）

累积本次所有应该入缓存的条目为一个 patch 对象：

- `need_translate` 桶：用新翻译的 name 后缀与 description 译文填入，`en` 用 inventory 给出的 `details.name`/`details.description`。
- `cache_hit` 桶：也加进 patch（值与当前缓存相同，cache_writer 会走 skipped_no_change 分支，仅起"确认该条目仍在使用"的作用，可选）。
- `reclaim_polish` 桶：`en` 用 `details.cached_desc_en`（保持不变），`zh` 用 `details.current_description`，`name.en` 用 `details.cached_name_en`，`zh_suffix` 用从 `details.current_name` 提取的新后缀。

用临时文件传 patch 更稳（避免 shell 编码问题），比如 `Write` 到 `skill-frontmatter-zh/scripts/.patch.tmp.json`，然后：

```bash
python skill-frontmatter-zh/scripts/cache_writer.py \
    --cache skill-frontmatter-zh/translations.json \
    --patch skill-frontmatter-zh/scripts/.patch.tmp.json
```

完成后删除 `.patch.tmp.json`。cache_writer 的 stdout 报告留给步骤 6 汇报使用。

### 6. 汇报

```
扫描 N 个 skill
├─ 已中文化、跳过 X 个：[列表]
├─ 缓存命中、复用译文 H 个：[列表]
├─ 新翻译 Y 个：[列表]
├─ 回收用户润色到缓存 R 个：[列表]
└─ 格式异常需手动处理 Z 个：[列表及原因]
```

## 同步 submodule upstream 后重新中文化

当用户要求 "同步 skill 上游"、"更新 fork"、"拉取上游后再中文化"、"检查 skill 有没有新版本" 时执行此流程。场景：本仓库部分 skill 是 submodule（fork 自原作者），需要定期拉取原作者新 commit，拉取后可能需要重新中文化。

### 流程

1. **枚举 submodule**：
   ```bash
   git -C <主仓库> config --file .gitmodules --get-regexp 'path$' | awk '{print $2}'
   ```

2. **对每个 submodule 拉取 upstream 并看差异**：
   ```bash
   git -C <submodule> fetch upstream
   git -C <submodule> log --oneline HEAD..upstream/main
   ```
   无输出则 upstream 无新 commit，跳过该 submodule。

3. **有更新则合并到 fork**：
   ```bash
   git -C <submodule> rebase upstream/main
   git -C <submodule> push --force-with-lease origin main
   ```
   - rebase 冲突通常源自被中文化过的 name/description 被上游修改 → 保留中文版本，手动解决后 `git rebase --continue`。
   - 用 `--force-with-lease` 而非 `--force`：只在远端未变时生效，更安全。

4. **主仓库记录新 submodule pointer**：
   ```bash
   git -C <主仓库> add <submodule-path>
   # 随下次主仓库 commit 一并提交
   ```
   必须 commit，否则 submodule 新内容不会在别人 clone 主仓库时自动拉齐。

5. **判断是否需要重新中文化**（核心诉求）：
   - 若 rebase 成功保留了中文版本 → 无需改动；仍按[翻译缓存](#翻译缓存-translationsjson)规则检查用户润色是否需要回收。
   - 若上游覆盖了 frontmatter（name 重置为纯英文，或 description 重写为英文）→ 按[主工作流程](#工作流程)的步骤 3-7 处理。**优先查缓存**：若 `cached.description.en` 与上游新英文一致，直接复用缓存中文，无需重新翻译（这正是缓存机制最有价值的场景）。
   - 上游 frontmatter 新增了与中文化无关的字段 → 不干预（遵循"只改 name 和 description"硬性规则）。

### 汇报格式

```
同步 N 个 submodule
├─ 已是最新，跳过 X 个：[列表]
├─ 已同步，中文化无需变更 Y 个：[列表]
├─ 已同步，缓存命中直接复用译文 H 个：[列表]
├─ 已同步并重新中文化 Z 个：[列表 + 变更简述]
└─ rebase 冲突需手动介入 W 个：[列表]
```

## 硬性规则

- **只改 name 和 description** 两字段，license/metadata/allowed-tools/compatibility/github 等字段一字不动。
- **不改 SKILL.md 正文**，不改代码，不改目录结构。
- **唯一允许写入的非 SKILL.md 文件** 是 `skill-frontmatter-zh/translations.json`（翻译缓存）。
- **不 commit**，只修改文件，用户 review 后自行提交（SKILL.md 和 translations.json 建议同一次 commit）。
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
