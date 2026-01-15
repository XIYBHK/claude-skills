---
name: skill-creator
description: 创建有效 skills 的指南。当用户想要创建新 skill（或更新现有 skill）以通过专业知识、工作流程或工具集成来扩展 Claude 的能力时，应使用此 skill。
license: Complete terms in LICENSE.txt
---

# Skill 创建器

此 skill 提供创建有效 skills 的指导。

## 关于 Skills

Skills 是模块化、独立的包，通过提供专业知识、工作流程和工具来扩展 Claude 的能力。可以将它们视为特定领域或任务的"入门指南"——它们将 Claude 从通用代理转变为配备了任何模型都无法完全拥有的程序性知识的专业代理。

### Skills 提供什么

1. 专业工作流程 - 特定领域的多步骤流程
2. 工具集成 - 处理特定文件格式或 API 的说明
3. 领域专业知识 - 公司特定知识、模式、业务逻辑
4. 捆绑资源 - 用于复杂和重复任务的脚本、参考资料和资产

### Skill 的结构

每个 skill 由一个必需的 SKILL.md 文件和可选的捆绑资源组成：

```
skill-name/
├── SKILL.md (必需)
│   ├── YAML frontmatter metadata (必需)
│   │   ├── name: (必需)
│   │   └── description: (必需)
│   └── Markdown instructions (必需)
└── Bundled Resources (可选)
    ├── scripts/          - 可执行代码（Python/Bash 等）
    ├── references/       - 需要时加载到上下文中的文档
    └── assets/           - 输出中使用的文件（模板、图标、字体等）
```

#### SKILL.md (必需)

**元数据质量：** YAML frontmatter 中的 `name` 和 `description` 决定了 Claude 何时使用该 skill。要具体说明 skill 的功能和使用时机。使用第三人称（例如"当...时应使用此 skill"而不是"当...时使用此 skill"）。

#### 捆绑资源 (可选)

##### Scripts (`scripts/`)

用于需要确定性可靠性或反复重写的任务的可执行代码（Python/Bash 等）。

- **何时包含**：当相同的代码被反复重写或需要确定性可靠性时
- **示例**：用于 PDF 旋转任务的 `scripts/rotate_pdf.py`
- **优势**：节省 token、确定性、可以在不加载到上下文的情况下执行
- **注意**：脚本可能仍需要被 Claude 读取以进行修补或环境特定的调整

##### References (`references/`)

需要时加载到上下文中以指导 Claude 的流程和思考的文档和参考资料。

- **何时包含**：用于 Claude 在工作时应参考的文档
- **示例**：用于财务模式的 `references/finance.md`、用于公司 NDA 模板的 `references/mnda.md`、用于公司政策的 `references/policies.md`、用于 API 规范的 `references/api_docs.md`
- **使用场景**：数据库模式、API 文档、领域知识、公司政策、详细工作流程指南
- **优势**：保持 SKILL.md 精简，仅在 Claude 确定需要时加载
- **最佳实践**：如果文件很大（>10k 字），在 SKILL.md 中包含 grep 搜索模式
- **避免重复**：信息应存在于 SKILL.md 或 references 文件中，而不是两者都有。除非信息对 skill 真正核心，否则优先使用 references 文件存储详细信息——这样可以保持 SKILL.md 精简，同时使信息可被发现而不占用上下文窗口。仅在 SKILL.md 中保留基本的程序性说明和工作流程指导；将详细的参考资料、模式和示例移至 references 文件。

##### Assets (`assets/`)

不打算加载到上下文中，而是在 Claude 生成的输出中使用的文件。

- **何时包含**：当 skill 需要在最终输出中使用的文件时
- **示例**：用于品牌资产的 `assets/logo.png`、用于 PowerPoint 模板的 `assets/slides.pptx`、用于 HTML/React 样板的 `assets/frontend-template/`、用于排版的 `assets/font.ttf`
- **使用场景**：模板、图像、图标、样板代码、字体、被复制或修改的示例文档
- **优势**：将输出资源与文档分离，使 Claude 能够在不将文件加载到上下文的情况下使用它们

### 渐进式披露设计原则

Skills 使用三级加载系统来有效管理上下文：

1. **元数据（name + description）** - 始终在上下文中（约 100 字）
2. **SKILL.md 主体** - 当 skill 触发时（<5k 字）
3. **捆绑资源** - 根据 Claude 需要（无限制*）

*无限制是因为脚本可以在不读入上下文窗口的情况下执行。

## Skill 创建流程

要创建 skill，请按顺序遵循"Skill 创建流程"，仅在有明确理由不适用时才跳过步骤。

### 步骤 1：通过具体示例理解 Skill

仅当 skill 的使用模式已经清楚理解时才跳过此步骤。即使在处理现有 skill 时，它仍然有价值。

要创建有效的 skill，需要清楚理解 skill 将如何使用的具体示例。这种理解可以来自直接的用户示例或通过用户反馈验证的生成示例。

例如，在构建 image-editor skill 时，相关问题包括：

- "image-editor skill 应该支持什么功能？编辑、旋转，还有其他吗？"
- "你能给出一些如何使用此 skill 的示例吗？"
- "我可以想象用户会要求诸如'从这张图片中去除红眼'或'旋转这张图片'之类的事情。你还能想象此 skill 被以其他方式使用吗？"
- "用户会说什么来触发此 skill？"

为避免让用户不知所措，避免在单条消息中提出太多问题。从最重要的问题开始，根据需要跟进以获得更好的效果。

当对 skill 应支持的功能有清晰的认识时，结束此步骤。

### 步骤 2：规划可重用的 Skill 内容

要将具体示例转化为有效的 skill，通过以下方式分析每个示例：

1. 考虑如何从头开始执行示例
2. 确定在重复执行这些工作流程时哪些脚本、参考资料和资产会有帮助

示例：在构建 `pdf-editor` skill 以处理"帮我旋转这个 PDF"之类的查询时，分析显示：

1. 旋转 PDF 每次都需要重写相同的代码
2. 在 skill 中存储 `scripts/rotate_pdf.py` 脚本会很有帮助

示例：在设计 `frontend-webapp-builder` skill 以处理"给我构建一个待办事项应用"或"给我构建一个跟踪我步数的仪表板"之类的查询时，分析显示：

1. 编写前端 webapp 每次都需要相同的样板 HTML/React
2. 在 skill 中存储包含样板 HTML/React 项目文件的 `assets/hello-world/` 模板会很有帮助

示例：在构建 `big-query` skill 以处理"今天有多少用户登录？"之类的查询时，分析显示：

1. 查询 BigQuery 每次都需要重新发现表模式和关系
2. 在 skill 中存储记录表模式的 `references/schema.md` 文件会很有帮助

要确定 skill 的内容，分析每个具体示例以创建要包含的可重用资源列表：脚本、参考资料和资产。

### 步骤 3：初始化 Skill

此时，是时候实际创建 skill 了。

仅当正在开发的 skill 已经存在且需要迭代或打包时才跳过此步骤。在这种情况下，继续下一步。

从头开始创建新 skill 时，始终运行 `init_skill.py` 脚本。该脚本方便地生成一个新的模板 skill 目录，自动包含 skill 所需的一切，使 skill 创建过程更加高效和可靠。

用法：

```bash
scripts/init_skill.py <skill-name> --path <output-directory>
```

该脚本：

- 在指定路径创建 skill 目录
- 生成带有正确 frontmatter 和 TODO 占位符的 SKILL.md 模板
- 创建示例资源目录：`scripts/`、`references/` 和 `assets/`
- 在每个目录中添加可以自定义或删除的示例文件

初始化后，根据需要自定义或删除生成的 SKILL.md 和示例文件。

### 步骤 4：编辑 Skill

在编辑（新生成或现有的）skill 时，请记住该 skill 是为另一个 Claude 实例使用而创建的。专注于包含对 Claude 有益且不明显的信息。考虑哪些程序性知识、领域特定细节或可重用资产会帮助另一个 Claude 实例更有效地执行这些任务。

#### 从可重用的 Skill 内容开始

要开始实现，从上面确定的可重用资源开始：`scripts/`、`references/` 和 `assets/` 文件。请注意，此步骤可能需要用户输入。例如，在实现 `brand-guidelines` skill 时，用户可能需要提供要存储在 `assets/` 中的品牌资产或模板，或要存储在 `references/` 中的文档。

此外，删除 skill 不需要的任何示例文件和目录。初始化脚本在 `scripts/`、`references/` 和 `assets/` 中创建示例文件以演示结构，但大多数 skills 不需要所有这些文件。

#### 更新 SKILL.md

**写作风格：** 使用**祈使句/不定式形式**（动词优先的说明）编写整个 skill，而不是第二人称。使用客观的说明性语言（例如，"要完成 X，执行 Y"而不是"你应该执行 X"或"如果你需要执行 X"）。这保持了 AI 使用的一致性和清晰度。

要完成 SKILL.md，回答以下问题：

1. skill 的目的是什么，用几句话说明？
2. 何时应使用该 skill？
3. 在实践中，Claude 应该如何使用该 skill？应引用上面开发的所有可重用 skill 内容，以便 Claude 知道如何使用它们。

### 步骤 5：打包 Skill

一旦 skill 准备就绪，应将其打包成可分发的 zip 文件并与用户共享。打包过程会自动首先验证 skill 以确保其满足所有要求：

```bash
scripts/package_skill.py <path/to/skill-folder>
```

可选的输出目录规范：

```bash
scripts/package_skill.py <path/to/skill-folder> ./dist
```

打包脚本将：

1. **验证** skill，自动检查：
   - YAML frontmatter 格式和必需字段
   - Skill 命名约定和目录结构
   - 描述的完整性和质量
   - 文件组织和资源引用

2. **打包** skill（如果验证通过），创建以 skill 命名的 zip 文件（例如，`my-skill.zip`），其中包含所有文件并保持正确的目录结构以供分发。

如果验证失败，脚本将报告错误并退出而不创建包。修复任何验证错误并再次运行打包命令。

### 步骤 6：迭代

测试 skill 后，用户可能会要求改进。这通常发生在使用 skill 后不久，对 skill 的表现有新鲜的上下文。

**迭代工作流程：**
1. 在实际任务中使用 skill
2. 注意困难或低效之处
3. 确定应如何更新 SKILL.md 或捆绑资源
4. 实施更改并再次测试
