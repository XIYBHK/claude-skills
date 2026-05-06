#!/usr/bin/env python3
"""Shared helpers to enrich clipped notes with better tags and smoother summaries."""

from __future__ import annotations

import re
from collections import Counter
from html import unescape

CJK_RE = re.compile(r"[\u4e00-\u9fff]")
URL_LINE_RE = re.compile(r"^\s*>?\s*(原文链接|source|链接|公众号|发布时间|author|date|votes|duration_seconds)\s*[:：]", re.I)
HEADING_RE = re.compile(r"^#{1,6}\s+")
LIST_RE = re.compile(r"^\s*[-*+]\s+")
QUOTE_RE = re.compile(r"^\s*>")
PUNCT_RE = re.compile(r'''[\s\t\r\n,，。！？!?:：;；、“”"'‘’（）()\[\]{}<>《》/\\|@#%^&*_+=~`…-]+''')
ZH_PHRASE_RE = re.compile(r"[\u4e00-\u9fffA-Za-z0-9]{2,16}")
EN_TERM_RE = re.compile(r"\b[A-Za-z][A-Za-z0-9+._-]{1,20}\b")
STOPWORDS = {
    "我们", "你们", "他们", "一个", "一些", "这个", "那个", "可以", "已经", "就是", "如果", "因为", "所以", "以及", "还有", "没有",
    "不是", "自己", "进行", "通过", "需要", "什么", "这样", "那种", "现在", "时候", "问题", "这里", "一种", "作者", "文章", "内容",
    "项目", "工具", "系统", "用户", "工作", "支持", "使用", "能力", "方式", "提供", "实现", "运行", "开发", "编程", "工程",
    "主要", "有关", "相关", "以及", "一个", "一种", "我们可以", "大家", "其实", "然后", "其中", "并且", "同时", "比如", "这个项目", "为什么", "怎么", "如何",
    "这篇文章", "这篇内容", "视频", "笔记", "字幕整理", "原文链接", "发布时间", "公众号",
}
GENERIC_TAGS = {
    "文章", "回答", "视频", "摘抄", "微信公众号", "知乎", "B站", "网页", "原文", "摘要", "内容", "作者", "发布", "Code",
}
KEYWORD_ALIASES = {
    "ai": "AI",
    "openai": "OpenAI",
    "chatgpt": "ChatGPT",
    "claude": "Claude",
    "claudecode": "Claude Code",
    "claude code": "Claude Code",
    "codex": "Codex",
    "github": "GitHub",
    "gitlab": "GitLab",
    "linear": "Linear",
    "cursor": "Cursor",
    "agent": "Agent",
    "agents": "Agent",
    "workflow": "工作流",
    "ci": "CI",
    "pr": "PR",
    "api": "API",
    "sdk": "SDK",
    "rag": "RAG",
}
THEME_PATTERNS = [
    (re.compile(r"OpenAI|ChatGPT|GPT", re.I), "OpenAI"),
    (re.compile(r"Claude\s*Code|Claude", re.I), "Claude Code"),
    (re.compile(r"Codex", re.I), "Codex"),
    (re.compile(r"Agent|智能体|代理", re.I), "Agent"),
    (re.compile(r"工作流|workflow", re.I), "工作流"),
    (re.compile(r"自动化|automation", re.I), "自动化"),
    (re.compile(r"开源", re.I), "开源"),
    (re.compile(r"GitHub", re.I), "GitHub"),
    (re.compile(r"Linear", re.I), "Linear"),
    (re.compile(r"CI|持续集成", re.I), "CI"),
    (re.compile(r"PR|Pull Request", re.I), "PR"),
    (re.compile(r"提示词|prompt", re.I), "提示词"),
    (re.compile(r"总结|摘要|复盘", re.I), "总结"),
    (re.compile(r"性能|优化", re.I), "性能优化"),
    (re.compile(r"部署|发布", re.I), "部署"),
]
SOURCE_LEADS = {
    "wechat-article": "这篇文章主要在讲：{core}",
    "zhihu-answer": "这篇回答主要围绕：{core}",
    "zhihu-article": "这篇知乎文章主要讨论：{core}",
    "bilibili-video": "这个视频重点在讲：{core}",
    "web-article": "这篇内容主要围绕：{core}",
}
SOURCE_FOCUS = {
    "wechat-article": "文中重点提到：{point}",
    "zhihu-answer": "回答里比较核心的一点是：{point}",
    "zhihu-article": "文章里比较值得记的一点是：{point}",
    "bilibili-video": "视频里更值得记住的是：{point}",
    "web-article": "其中一个关键点是：{point}",
}
SOURCE_VALUE = {
    "wechat-article": "如果你关心{theme}，这篇内容有不错的参考价值。",
    "zhihu-answer": "如果你在看{theme}，这条回答可以当作一版思路参考。",
    "zhihu-article": "如果你想继续了解{theme}，这篇文章适合顺手留档。",
    "bilibili-video": "如果你正好在看{theme}，这段内容适合当速记版提纲。",
    "web-article": "如果你在关注{theme}，这篇内容值得顺手留一份。",
}


def strip_frontmatter(md: str) -> str:
    if md.startswith("---\n"):
        end = md.find("\n---\n", 4)
        if end != -1:
            return md[end + 5 :]
    return md


def extract_title(md: str, fallback: str = "未命名笔记") -> str:
    for line in md.splitlines():
        if line.startswith("# "):
            title = line[2:].strip()
            if title:
                return title
    return fallback


def normalize_text(md: str) -> str:
    text = strip_frontmatter(md)
    text = re.sub(r"!\[[^\]]*\]\([^)]*\)", " ", text)
    text = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", text)
    text = unescape(text)
    return text


def clean_line(line: str) -> str:
    line = line.strip()
    if URL_LINE_RE.match(line):
        return ""
    if line.startswith("---"):
        return ""
    line = HEADING_RE.sub("", line).strip()
    line = QUOTE_RE.sub("", line).strip()
    line = LIST_RE.sub("", line).strip()
    line = re.sub(r"\s+", " ", line)
    return line


def candidate_paragraphs(md: str) -> list[str]:
    text = normalize_text(md)
    paragraphs: list[str] = []
    current: list[str] = []
    for raw_line in text.splitlines():
        line = clean_line(raw_line)
        if not line:
            if current:
                paragraphs.append(" ".join(current).strip())
                current = []
            continue
        if len(line) < 8:
            continue
        current.append(line)
    if current:
        paragraphs.append(" ".join(current).strip())
    return paragraphs


def extract_headings(md: str) -> list[str]:
    items: list[str] = []
    for raw_line in strip_frontmatter(md).splitlines():
        if HEADING_RE.match(raw_line):
            line = HEADING_RE.sub("", raw_line).strip()
            if len(line) >= 2:
                items.append(line)
    return items


def trim_sentence(text: str, max_chars: int = 88) -> str:
    text = re.sub(r"\s+", " ", text).strip(" -—•")
    text = text.strip("#*_`>")
    if len(text) <= max_chars:
        return text
    cut = text[:max_chars]
    for sep in ("。", "；", "，", ". ", "; ", ", ", " "):
        idx = cut.rfind(sep)
        if idx >= max_chars // 2:
            cut = cut[:idx]
            break
    return cut.rstrip(" ,，；;。.!?！？") + "…"


def dedupe_texts(items: list[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for item in items:
        key = re.sub(r"\W+", "", item).lower()
        if not key or key in seen:
            continue
        seen.add(key)
        out.append(item)
    return out


def normalize_tag(token: str) -> str:
    raw = token.strip().strip("-—•")
    low = raw.lower()
    if low in KEYWORD_ALIASES:
        return KEYWORD_ALIASES[low]
    if raw.upper() in {"AI", "API", "SDK", "RAG", "CI", "PR"}:
        return raw.upper()
    if raw.lower() == "github":
        return "GitHub"
    if raw.lower() == "openai":
        return "OpenAI"
    if raw.lower() == "codex":
        return "Codex"
    if raw.lower() == "agent":
        return "Agent"
    return raw


def is_good_tag(token: str, title: str = "") -> bool:
    token = token.strip()
    if len(token) < 2 or len(token) > 16:
        return False
    if token in STOPWORDS or token in GENERIC_TAGS:
        return False
    if token.isdigit():
        return False
    if re.search(r"为什么|怎么|如何|会不会|能不能|值不值", token):
        return False
    if re.fullmatch(r"[\u4e00-\u9fff]+", token) and len(token) > 6:
        return False
    if re.fullmatch(r"[\u4e00-\u9fff]+", token) and re.search(r"会|能|要|讲|说|做|用|看", token) and len(token) >= 5:
        return False
    if re.fullmatch(r"[A-Za-z]", token):
        return False
    if title and token == title:
        return False
    return bool(CJK_RE.search(token) or re.search(r"[A-Za-z]", token))


def score_tag_candidates(title: str, headings: list[str], paragraphs: list[str]) -> Counter[str]:
    counts: Counter[str] = Counter()
    corpora = [(title, 6), (" ".join(headings[:8]), 4), (" ".join(paragraphs[:6]), 1)]
    for text, weight in corpora:
        if not text:
            continue
        for pat, tag in THEME_PATTERNS:
            if pat.search(text):
                counts[tag] += weight + 2
        for token in ZH_PHRASE_RE.findall(text):
            token = normalize_tag(token)
            if is_good_tag(token, title):
                counts[token] += weight
        for token in EN_TERM_RE.findall(text):
            token = normalize_tag(token)
            if is_good_tag(token, title):
                counts[token] += max(weight - 1, 1)
    return counts


def infer_tags(md: str, source_tag: str, type_tag: str | None = None, max_extra: int = 5) -> list[str]:
    title = extract_title(md, "")
    headings = extract_headings(md)
    paragraphs = candidate_paragraphs(md)
    counts = score_tag_candidates(title, headings, paragraphs)

    tags = [source_tag, "摘抄"]
    if type_tag:
        tags.append(type_tag)

    lower_existing = {t.lower() for t in tags}
    for token, _ in counts.most_common(40):
        norm = normalize_tag(token)
        if norm.lower() in lower_existing:
            continue
        if not is_good_tag(norm, title):
            continue
        tags.append(norm)
        lower_existing.add(norm.lower())
        if len(tags) >= 2 + (1 if type_tag else 0) + max_extra:
            break
    return tags


def collect_summary_points(md: str, title: str) -> list[str]:
    headings = [h for h in extract_headings(md) if h != title]
    paragraphs = candidate_paragraphs(md)
    points: list[str] = []
    for item in paragraphs:
        trimmed = trim_sentence(item, max_chars=92)
        if len(trimmed) < 18:
            continue
        if title and (trimmed == title or trimmed.startswith(title)):
            continue
        points.append(trimmed)
    for heading in headings[:6]:
        clean = trim_sentence(heading, max_chars=28)
        if len(clean) >= 4:
            points.append(clean)
    return dedupe_texts(points)


def humanize_summary(md: str, note_type: str) -> list[str]:
    title = extract_title(md, "未命名内容")
    tags = infer_tags(md, source_tag="内容", type_tag=None, max_extra=3)
    points = collect_summary_points(md, title)
    theme = next((t for t in tags if t not in {"内容", "摘抄", "文章", "回答", "视频"}), title)

    if not points:
        return [f"这篇内容主要围绕《{title}》展开。"]

    core = points[0]
    summary: list[str] = []
    lead_tpl = SOURCE_LEADS.get(note_type, "这篇内容主要在讲：{core}")
    if re.match(r"^(这篇(文章|回答|内容)|这个视频)主要", core):
        summary.append(trim_sentence(core, max_chars=96))
    else:
        summary.append(trim_sentence(lead_tpl.format(core=core), max_chars=96))

    if len(points) >= 2:
        focus_tpl = SOURCE_FOCUS.get(note_type, "其中一个关键点是：{point}")
        summary.append(trim_sentence(focus_tpl.format(point=points[1]), max_chars=96))

    if len(points) >= 3:
        third = points[2]
        if len(third) <= 18 and CJK_RE.search(third):
            summary.append(f"它也顺手覆盖了「{third}」这类话题。")
        else:
            value_tpl = SOURCE_VALUE.get(note_type, "如果你在关注{theme}，这篇内容值得顺手留一份。")
            summary.append(trim_sentence(value_tpl.format(theme=theme), max_chars=88))
    else:
        value_tpl = SOURCE_VALUE.get(note_type, "如果你在关注{theme}，这篇内容值得顺手留一份。")
        summary.append(trim_sentence(value_tpl.format(theme=theme), max_chars=88))

    return dedupe_texts(summary)[:3]


def build_header(*, source_url: str, note_type: str, title: str, tags: list[str], summary: list[str], author: str | None = None, date: str | None = None) -> str:
    lines = ["---", f"source: {source_url}", f"type: {note_type}"]
    if author:
        lines.append(f"author: {author}")
    if date:
        lines.append(f"date: {date}")
    lines.append("tags:")
    for tag in tags:
        lines.append(f"  - {tag}")
    lines.extend(["---", "", f"# {title}", "", "## 摘要", ""])
    lines.extend(f"- {item}" for item in summary)
    lines.extend(["", "## 原文", ""])
    return "\n".join(lines)


def enrich_markdown(md: str, *, source_url: str, note_type: str, source_tag: str, type_tag: str | None = None, author: str | None = None, date: str | None = None) -> str:
    title = extract_title(md)
    summary = humanize_summary(md, note_type=note_type)
    tags = infer_tags(md, source_tag=source_tag, type_tag=type_tag)
    body = strip_frontmatter(md)
    body_lines = body.splitlines()
    if body_lines and body_lines[0].startswith("# "):
        body = "\n".join(body_lines[1:]).lstrip()
    header = build_header(source_url=source_url, note_type=note_type, title=title, tags=tags, summary=summary, author=author, date=date)
    return header + body.lstrip()
