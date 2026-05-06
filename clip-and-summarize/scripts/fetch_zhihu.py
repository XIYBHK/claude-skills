#!/usr/bin/env python3
"""Fetch Zhihu answers/articles via API v4 and convert to Markdown.

Secrets are resolved via auth_resolver (~/.claude/config/clip-auth.json primary,
legacy <workspace>/tools/content-collectors/private/auth.json fallback, env vars last).

Image policy (对齐 Claudian Schema §4.0.1 动图优先):
- `data-actualsrc` > `data-original` > `src`
- Drop SVG placeholder `data:image/svg+xml,...` entries
"""

from __future__ import annotations

import argparse
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Tuple

# 保证同目录模块可被 import
SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import markdownify  # noqa: E402
import requests  # noqa: E402

from auth_resolver import resolve_secret  # noqa: E402
from note_enricher import enrich_markdown  # noqa: E402
from utf8_console import enable_utf8_stdio  # noqa: E402

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36",
    "Accept": "application/json",
    "Referer": "https://www.zhihu.com/",
}


def cookies() -> dict:
    xsrf = resolve_secret(("zhihu", "_xsrf"), "ZHIHU_XSRF")
    z_c0 = resolve_secret(("zhihu", "z_c0"), "ZHIHU_Z_C0")
    if not xsrf or not z_c0:
        raise SystemExit(
            "Missing Zhihu auth. Put _xsrf / z_c0 in ~/.claude/config/clip-auth.json "
            "under the `zhihu` key, or set ZHIHU_XSRF / ZHIHU_Z_C0 env vars."
        )
    return {"_xsrf": xsrf, "z_c0": z_c0}


def preprocess_images(html: str) -> str:
    """动图优先 + 过滤 SVG 占位（对齐 Claudian Schema §4.0.1）。

    知乎 HTML 里：
    - data-actualsrc 多为 _1440w.gif 动图真身
    - data-original 为原图
    - src 多半只是 _b.jpg 静态封面或 SVG 占位
    """
    def rewrite(match: re.Match) -> str:
        tag = match.group(0)
        actual = re.search(r'data-actualsrc="([^"]+)"', tag)
        original = re.search(r'data-original="([^"]+)"', tag)
        src = re.search(r'src="([^"]+)"', tag)

        # SVG 占位且没有动图/原图备份 → 整个 img 丢掉
        if src and src.group(1).startswith("data:image/svg+xml"):
            if not actual and not original:
                return ""

        winner = None
        for candidate in (actual, original, src):
            if candidate and not candidate.group(1).startswith("data:image/svg+xml"):
                winner = candidate.group(1)
                break
        if not winner:
            return ""

        alt_m = re.search(r'alt="([^"]*)"', tag)
        alt = alt_m.group(1) if alt_m else ""
        return f'<img src="{winner}" alt="{alt}">'

    return re.sub(r"<img[^>]*>", rewrite, html)


def parse_zhihu_url(url: str) -> Tuple[str | None, str | None]:
    for pattern, kind in [(r"/answer/(\d+)", "answer"), (r"/p/(\d+)", "article")]:
        m = re.search(pattern, url)
        if m:
            return kind, m.group(1)
    return None, None


def fetch_answer(answer_id: str) -> dict:
    url = f"https://www.zhihu.com/api/v4/answers/{answer_id}?include=content,excerpt,question.title,question.id,created_time,updated_time,author.name,voteup_count"
    r = requests.get(url, cookies=cookies(), headers=HEADERS, timeout=20)
    r.raise_for_status()
    return r.json()


def fetch_article(article_id: str) -> dict:
    url = f"https://www.zhihu.com/api/v4/articles/{article_id}?include=content,title,excerpt,author.name,created,updated,voteup_count"
    r = requests.get(url, cookies=cookies(), headers=HEADERS, timeout=20)
    r.raise_for_status()
    return r.json()


def html_to_md(html: str) -> str:
    md = markdownify.markdownify(html, heading_style="ATX")
    md = re.sub(r"<pre><code[^>]*>(.*?)</code></pre>", lambda m: "\n```\n" + re.sub(r"<[^>]+>", "", m.group(1)) + "\n```\n", md, flags=re.DOTALL)
    md = re.sub(r"<code[^>]*>(.*?)</code>", r"`\1`", md, flags=re.DOTALL)
    md = re.sub(r"<[^>]+>", "", md)
    md = re.sub(r"\n{3,}", "\n\n", md)
    return md.replace("\\_", "_").strip()


def build_markdown(url: str) -> tuple[str, str, str]:
    kind, obj_id = parse_zhihu_url(url)
    if not kind or not obj_id:
        raise SystemExit(f"Unsupported Zhihu URL: {url}")

    if kind == "answer":
        data = fetch_answer(obj_id)
        title = data.get("question", {}).get("title", "Unknown")
        author = data.get("author", {}).get("name", "Unknown")
        created = data.get("created_time", 0)
        source_url = f"https://www.zhihu.com/question/{data.get('question', {}).get('id', '')}/answer/{obj_id}"
        content_html = data.get("content", "")
    else:
        data = fetch_article(obj_id)
        title = data.get("title", "Unknown")
        author = data.get("author", {}).get("name", "Unknown")
        created = data.get("created", 0)
        source_url = f"https://zhuanlan.zhihu.com/p/{obj_id}"
        content_html = data.get("content", "")

    date_str = datetime.fromtimestamp(created).strftime("%Y-%m-%d") if created else None
    content_html = preprocess_images(content_html)
    md = html_to_md(content_html)
    raw = f"# {title}\n\n{md}\n"
    return title, source_url, enrich_markdown(
        raw,
        source_url=source_url,
        note_type=f"zhihu-{kind}",
        source_tag="知乎",
        type_tag="回答" if kind == "answer" else "文章",
        author=author,
        date=date_str,
    )


if __name__ == "__main__":
    enable_utf8_stdio()
    parser = argparse.ArgumentParser()
    parser.add_argument("url")
    parser.add_argument("--output", "-o")
    parser.add_argument(
        "--attachments-dir",
        help="预留：未来把知乎图片下载到此目录以本地化附件（当前未实现，参数被忽略）",
    )
    args = parser.parse_args()

    title, source_url, markdown = build_markdown(args.url)
    if args.output:
        out_path = Path(args.output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(markdown, encoding="utf-8")
        print(f"OK zhihu saved: {out_path}")
    else:
        print(markdown)
