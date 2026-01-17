# Claude Code Skills 最佳实践指南

> 本文档整理自 Anthropic 官方文档、社区实践及专家分享，旨在帮助开发者创建高效、可维护的 Claude Code Skills。

## 目录

1. [Skills 概述](#1-skills-概述)
2. [核心原则](#2-核心原则)
3. [文件结构与组织](#3-文件结构与组织)
4. [SKILL.md 编写规范](#4-skillmd-编写规范)
5. [渐进式披露模式](#5-渐进式披露模式)
6. [常用设计模式](#6-常用设计模式)
7. [工作流与反馈循环](#7-工作流与反馈循环)
8. [高级技巧](#8-高级技巧)
9. [常见反模式](#9-常见反模式)
10. [检查清单](#10-检查清单)

---

## 1. Skills 概述

### 什么是 Skills？

Skills 是包含指令、脚本和资源的文件夹，用于教会 Claude 执行特定任务。与传统工具不同，Skills 通过 **提示扩展** 和 **上下文修改** 来增强 Claude 的能力，而非直接执行代码。

### Skills vs 其他定制方式

| 机制 | 触发方式 | 上下文 | 适用场景 |
|------|----------|--------|----------|
| **CLAUDE.md** | 自动加载 | 主对话 | 项目级常驻指令 |
| **Slash Commands** | 用户输入 `/command` | 主对话 | 可重复的显式工作流 |
| **Skills** | Claude 自动匹配 | 主对话 | 自动发现的丰富能力 |
| **Subagents** | Claude 委托或显式调用 | 独立窗口 | 需要隔离上下文的复杂任务 |

### Skills 的工作原理

```
┌─────────────────────────────────────────────────────────────┐
│ 1. 启动时：加载所有 Skills 的元数据（name + description）    │
│ 2. 用户请求：Claude 根据 description 匹配相关 Skill         │
│ 3. 激活时：加载完整的 SKILL.md 内容到上下文                  │
│ 4. 执行时：按需读取 references/、scripts/、assets/ 资源     │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. 核心原则

### 2.1 简洁至上

上下文窗口是公共资源，你的 Skill 需要与系统提示、对话历史、其他 Skills 共享空间。

**默认假设**：Claude 已经非常智能，只添加它真正需要的信息。

```markdown
# ✅ 好的示例（约 50 tokens）
## 提取 PDF 文本

使用 pdfplumber 提取文本：
```python
import pdfplumber
with pdfplumber.open("file.pdf") as pdf:
    text = pdf.pages[0].extract_text()
```

# ❌ 差的示例（约 150 tokens）
## 提取 PDF 文本

PDF（可移植文档格式）是一种常见的文件格式，包含文本、图像和其他内容。
要从 PDF 中提取文本，您需要使用一个库。有很多可用于 PDF 处理的库，
但我们推荐 pdfplumber，因为它易于使用且能处理大多数情况...
```

### 2.2 适当的自由度

根据任务的脆弱性和可变性匹配指令的具体程度：

| 自由度 | 适用场景 | 示例 |
|--------|----------|------|
| **高** | 多种方法有效、依赖上下文 | 代码审查流程 |
| **中** | 存在首选模式、允许一定变化 | 带参数的脚本模板 |
| **低** | 操作脆弱、一致性关键 | 数据库迁移脚本 |

### 2.3 多模型测试

Skills 作为模型的扩展，效果取决于底层模型：

- **Claude Haiku**：是否提供了足够的指导？
- **Claude Sonnet**：指令是否清晰高效？
- **Claude Opus**：是否避免了过度解释？

---

## 3. 文件结构与组织

### 3.1 基本结构

```
my-skill/
├── SKILL.md              # 必需 - 核心指令文件
├── LICENSE.txt           # 可选 - 许可证
├── scripts/              # 可选 - 可执行脚本
│   ├── helper.py
│   └── validate.py
├── references/           # 可选 - 参考文档（加载到上下文）
│   ├── api-reference.md
│   └── patterns.md
└── assets/               # 可选 - 模板和二进制文件（仅引用路径）
    ├── template.html
    └── config.json
```

### 3.2 存放位置

| 位置 | 路径 | 适用范围 |
|------|------|----------|
| 企业级 | 托管设置中配置 | 组织内所有用户 |
| 个人级 | `~/.claude/skills/` | 你的所有项目 |
| 项目级 | `.claude/skills/` | 当前仓库的所有协作者 |
| 插件级 | 随插件捆绑 | 安装了该插件的用户 |

### 3.3 资源目录说明

| 目录 | 用途 | 加载方式 |
|------|------|----------|
| `scripts/` | 可执行代码（Python、Bash） | 通过 Bash 执行，不加载内容 |
| `references/` | 文档、模式、API 参考 | 按需读取到上下文 |
| `assets/` | 模板、配置、二进制文件 | 仅引用路径，不读取内容 |

---

## 4. SKILL.md 编写规范

### 4.1 文件结构

```markdown
---
# YAML Frontmatter（元数据）
name: skill-name
description: 简要描述功能和使用场景
allowed-tools: Read, Write, Bash
---

# Skill 标题

## 概述
[功能说明、使用时机、提供的能力]

## 前置条件
[所需工具、文件或上下文]

## 指令

### 步骤 1：[操作名称]
[祈使句式的指令]

### 步骤 2：[操作名称]
[祈使句式的指令]

## 输出格式
[结果的结构要求]

## 错误处理
[失败时的处理方式]

## 示例
[具体使用示例]
```

### 4.2 Frontmatter 字段说明

| 字段 | 必需 | 说明 |
|------|------|------|
| `name` | ✅ | 小写字母、数字、连字符，最多 64 字符 |
| `description` | ✅ | 功能和使用场景描述，最多 1024 字符 |
| `allowed-tools` | ❌ | 允许使用的工具列表 |
| `model` | ❌ | 指定使用的模型（如 `claude-opus-4-20250514`） |
| `context` | ❌ | 设为 `fork` 在子代理上下文中运行 |
| `user-invocable` | ❌ | 是否在斜杠命令菜单中显示（默认 true） |
| `hooks` | ❌ | 定义 Skill 生命周期钩子 |

### 4.3 命名规范

推荐使用 **动名词形式**（verb + -ing）：

```markdown
# ✅ 推荐
- processing-pdfs
- analyzing-spreadsheets
- managing-databases
- testing-code

# ❌ 避免
- helper
- utils
- tools
- anthropic-helper（包含保留词）
```

### 4.4 Description 编写要点

Description 是 Claude 决定是否使用 Skill 的关键信号：

```markdown
# ✅ 好的 description
description: 从 PDF 文件中提取文本和表格、填写表单、合并文档。
当处理 PDF 文件或用户提到 PDF、表单或文档提取时使用。

# ❌ 差的 description
description: 处理文档
description: 处理数据
```

**要点**：
- 使用第三人称（"处理 Excel 文件"而非"我可以帮你处理"）
- 包含触发关键词
- 说明功能和使用场景

---

## 5. 渐进式披露模式

### 5.1 核心理念

只展示足够的信息帮助 Claude 决定下一步，随需要逐步揭示更多细节：

```
1. Frontmatter：最小化（name, description）
2. SKILL.md：全面但聚焦的核心指令
3. references/：按需加载的详细文档
4. scripts/：执行时才运行，不占用上下文
```

### 5.2 模式一：高级指南 + 引用

> **说明**：以下是 SKILL.md 内部的编写示例，展示如何在 Skill 中引用同目录下的其他文档文件。

假设你的 Skill 目录结构如下：

```
pdf-processing/
├── SKILL.md          # 主指令文件
├── FORMS.md          # 表单填写详细指南
├── REFERENCE.md      # API 参考文档
└── EXAMPLES.md       # 使用示例集合
```

那么在 `SKILL.md` 中可以这样引用：

```markdown
# PDF 处理

## 快速开始

使用 pdfplumber 提取文本：

    import pdfplumber
    with pdfplumber.open("file.pdf") as pdf:
        text = pdf.pages[0].extract_text()

## 高级功能

**表单填写**：见 [FORMS.md](FORMS.md)
**API 参考**：见 [REFERENCE.md](REFERENCE.md)
**使用示例**：见 [EXAMPLES.md](EXAMPLES.md)
```

Claude 会根据需要读取这些引用文件，而不是一开始就全部加载到上下文中。

### 5.3 模式二：领域分离

对于多领域 Skill，按领域组织以避免加载无关上下文：

```
bigquery-skill/
├── SKILL.md
└── reference/
    ├── finance.md    # 收入、账单指标
    ├── sales.md      # 机会、管道数据
    ├── product.md    # API 使用、功能
    └── marketing.md  # 营销活动、归因
```

### 5.4 避免深层嵌套

保持引用在一级深度，避免文件间的链式引用：

```
# ❌ 差的示例：层级过深
SKILL.md 引用 → advanced.md 引用 → details.md → 实际信息
（Claude 可能只能部分读取深层文件）

# ✅ 好的示例：一级深度
SKILL.md 中直接引用所有文档：
- advanced.md
- reference.md
- examples.md
（所有引用文件都在同一层级，Claude 可以完整读取）
```

---

## 6. 常用设计模式

### 6.1 脚本自动化模式

适用于需要多步骤或确定性逻辑的复杂操作：

```markdown
## 使用方法

运行分析脚本：
```bash
python {baseDir}/scripts/analyzer.py --path "$USER_PATH" --output report.json
```

解析生成的 `report.json` 并呈现发现。

---
allowed-tools: "Bash(python {baseDir}/scripts/*:*), Read, Write"
```

### 6.2 读取-处理-写入模式

适用于文件转换和数据处理：

```markdown
## 处理工作流

1. 使用 Read 工具读取输入文件
2. 按照格式规范解析内容
3. 按照规格转换数据
4. 使用 Write 工具写入输出
5. 报告完成情况和摘要
```

### 6.3 搜索-分析-报告模式

适用于代码库分析和模式检测：

```markdown
## 分析流程

1. 使用 Grep 搜索相关代码模式
2. 读取每个匹配的文件
3. 分析漏洞或问题
4. 生成结构化报告
```

### 6.4 模板生成模式

```markdown
## 报告结构

**始终**使用以下模板结构：

```markdown
# [分析标题]

## 执行摘要
[关键发现的一段概述]

## 主要发现
- 发现 1 及支持数据
- 发现 2 及支持数据

## 建议
1. 具体可操作的建议
2. 具体可操作的建议
```
```

### 6.5 示例模式

提供输入/输出对帮助 Claude 理解预期风格：

```markdown
## 提交信息格式

按照以下示例生成提交信息：

**示例 1：**
输入：添加了使用 JWT 令牌的用户认证
输出：
```
feat(auth): 实现基于 JWT 的认证

添加登录端点和令牌验证中间件
```

**示例 2：**
输入：修复了报告中日期显示不正确的 bug
输出：
```
fix(reports): 修正时区转换中的日期格式

在报告生成中统一使用 UTC 时间戳
```
```

---

## 7. 工作流与反馈循环

### 7.1 多步骤工作流

对于复杂操作，分解为清晰的顺序步骤，并提供检查清单：

```markdown
## PDF 表单填写工作流

复制此检查清单并跟踪进度：

```
任务进度：
- [ ] 步骤 1：分析表单（运行 analyze_form.py）
- [ ] 步骤 2：创建字段映射（编辑 fields.json）
- [ ] 步骤 3：验证映射（运行 validate_fields.py）
- [ ] 步骤 4：填写表单（运行 fill_form.py）
- [ ] 步骤 5：验证输出（运行 verify_output.py）
```

**步骤 1：分析表单**
运行：`python scripts/analyze_form.py input.pdf`
这会提取表单字段和位置，保存到 `fields.json`。

**步骤 2：创建字段映射**
编辑 `fields.json` 为每个字段添加值。

...
```

### 7.2 反馈循环

实现验证-修复-重复的循环以提高输出质量：

```markdown
## 文档编辑流程

1. 对 `word/document.xml` 进行编辑
2. **立即验证**：`python ooxml/scripts/validate.py unpacked_dir/`
3. 如果验证失败：
   - 仔细查看错误信息
   - 修复 XML 中的问题
   - 再次运行验证
4. **只有验证通过后才继续**
5. 重建：`python ooxml/scripts/pack.py unpacked_dir/ output.docx`
6. 测试输出文档
```

---

## 8. 高级技巧

### 8.1 可执行脚本最佳实践

**解决问题，而非推卸责任**：

```python
# ✅ 好的示例：显式处理错误
def process_file(path):
    """处理文件，如果不存在则创建。"""
    try:
        with open(path) as f:
            return f.read()
    except FileNotFoundError:
        print(f"文件 {path} 未找到，创建默认文件")
        with open(path, 'w') as f:
            f.write('')
        return ''

# ❌ 差的示例：推卸给 Claude
def process_file(path):
    return open(path).read()  # 失败了让 Claude 解决
```

### 8.2 可验证的中间输出

对于复杂任务，创建可验证的计划文件：

```markdown
## 批量修改工作流

1. 分析 → 创建 `changes.json` 计划文件
2. 验证计划 → 运行 `validate_changes.py`
3. 执行更改 → 应用计划中的修改
4. 验证结果 → 确认所有更改正确应用

这样可以在执行前捕获错误，提供客观验证。
```

### 8.3 MCP 工具引用

使用完全限定的工具名称：

```markdown
# ✅ 正确：包含服务器前缀
使用 BigQuery:bigquery_schema 工具检索表模式。
使用 GitHub:create_issue 工具创建 Issue。

# ❌ 错误：可能找不到工具
使用 bigquery_schema 工具检索表模式。
```

### 8.4 字符串替换变量

Skills 支持动态值替换：

| 变量 | 说明 |
|------|------|
| `$ARGUMENTS` | 调用时传递的所有参数 |
| `${CLAUDE_SESSION_ID}` | 当前会话 ID |

```markdown
---
name: session-logger
description: 记录当前会话的活动
---

将以下内容记录到 logs/${CLAUDE_SESSION_ID}.log：

$ARGUMENTS
```

---

## 9. 常见反模式

### 9.1 避免 Windows 风格路径

```markdown
# ✅ 正确：使用正斜杠
scripts/helper.py
reference/guide.md

# ❌ 错误：Windows 风格
scripts\helper.py
reference\guide.md
```

### 9.2 避免提供过多选项

```markdown
# ❌ 差的示例：太多选择让人困惑
"你可以使用 pypdf、pdfplumber、PyMuPDF、pdf2image..."

# ✅ 好的示例：提供默认选项和备选
"使用 pdfplumber 提取文本：
```python
import pdfplumber
```

对于需要 OCR 的扫描 PDF，改用 pdf2image 配合 pytesseract。"
```

### 9.3 避免时效性信息

```markdown
# ❌ 差的示例：会过时
如果在 2025 年 8 月之前，使用旧 API。
2025 年 8 月之后，使用新 API。

# ✅ 好的示例：使用"旧模式"部分
## 当前方法
使用 v2 API 端点：`api.example.com/v2/messages`

## 旧模式
<details>
<summary>Legacy v1 API（2025-08 弃用）</summary>
v1 API 使用：`api.example.com/v1/messages`
此端点不再支持。
</details>
```

### 9.4 避免假设工具已安装

```markdown
# ❌ 差的示例：假设已安装
"使用 pdf 库处理文件。"

# ✅ 好的示例：明确依赖
"安装所需包：`pip install pypdf`

然后使用：
```python
from pypdf import PdfReader
reader = PdfReader("file.pdf")
```"
```

---

## 10. 检查清单

### 核心质量

- [ ] Description 具体且包含关键触发词
- [ ] Description 包含功能说明和使用场景
- [ ] SKILL.md 正文少于 500 行
- [ ] 额外详情放在独立文件中
- [ ] 无时效性信息（或放在"旧模式"部分）
- [ ] 全文术语一致
- [ ] 示例具体，非抽象
- [ ] 文件引用保持一级深度
- [ ] 适当使用渐进式披露
- [ ] 工作流步骤清晰

### 代码和脚本

- [ ] 脚本解决问题而非推卸给 Claude
- [ ] 错误处理明确且有帮助
- [ ] 无"魔法常量"（所有值都有说明）
- [ ] 所需包列在指令中且已验证可用
- [ ] 脚本有清晰的文档
- [ ] 无 Windows 风格路径
- [ ] 关键操作有验证/确认步骤
- [ ] 质量关键任务有反馈循环

### 测试

- [ ] 至少创建 3 个评估场景
- [ ] 在 Haiku、Sonnet、Opus 上测试过
- [ ] 用真实使用场景测试过
- [ ] 已纳入团队反馈（如适用）

---