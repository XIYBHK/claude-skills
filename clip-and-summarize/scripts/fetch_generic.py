#!/usr/bin/env python3
"""Fetch generic web pages via Jina Reader and normalize into lean markdown."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

from note_enricher import enrich_markdown
from utf8_console import enable_utf8_stdio


def fetch_via_jina(url: str, max_chars: int = 20000) -> tuple[str, str]:
    cmd = [
        "curl.exe",
        "-sSL",
        f"https://r.jina.ai/{url}",
        "-H",
        f"X-Max-Chars: {max_chars}",
        "-H",
        "X-With-Format: json",
        "-H",
        "X-No-Track: true",
        "-H",
        "X-Locale: zh-CN",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if result.returncode != 0:
        raise SystemExit(result.stderr or result.stdout or "Jina Reader fetch failed")

    raw = result.stdout.strip()
    try:
        data = json.loads(raw)
        title = (data.get("title") or "网页内容").strip()
        content = (data.get("content") or "").strip()
        return title, content
    except json.JSONDecodeError:
        title = "网页内容"
        return title, raw


def build_markdown(url: str) -> str:
    title, content = fetch_via_jina(url)
    raw = f"# {title}\n\n{content}\n"
    return enrich_markdown(
        raw,
        source_url=url,
        note_type="web-article",
        source_tag="网页",
        type_tag="文章",
    )


if __name__ == "__main__":
    enable_utf8_stdio()
    parser = argparse.ArgumentParser()
    parser.add_argument("url")
    parser.add_argument("--output", "-o")
    parser.add_argument(
        "--attachments-dir",
        help="预留：未来把通用网页图片下载到此目录以本地化（当前未实现，参数被忽略）",
    )
    args = parser.parse_args()

    markdown = build_markdown(args.url)
    if args.output:
        out_path = Path(args.output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(markdown, encoding="utf-8")
        print(f"OK generic saved: {out_path}")
    else:
        print(markdown)
