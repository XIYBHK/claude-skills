#!/usr/bin/env python3
"""Wrap the installed wechat-article-to-markdown tool and normalize outputs.

This wrapper:
1. Calls the installed tool through a UTF-8-safe child process
2. Finds the newest generated markdown under the package output dir
3. Rewrites image links from images/ to attachments/
4. Copies images into a caller-provided attachments dir when requested
5. Adds real header tags + extractive summary for Obsidian-friendly notes
"""

from __future__ import annotations

import argparse
import importlib.util
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

from note_enricher import enrich_markdown
from utf8_console import enable_utf8_stdio


def resolve_package_output_dir() -> Path:
    spec = importlib.util.find_spec("wechat_article_to_markdown")
    if spec is None or not spec.origin:
        raise SystemExit("wechat_article_to_markdown is not installed")
    return Path(spec.origin).resolve().parent / "output"


def find_latest_markdown(output_dir: Path) -> Path:
    candidates = list(output_dir.glob("*/*.md"))
    if not candidates:
        raise SystemExit(f"No markdown output found under {output_dir}")
    return max(candidates, key=lambda p: p.stat().st_mtime)


def run_tool(url: str) -> None:
    cmd = [sys.executable, "-X", "utf8", "-m", "wechat_article_to_markdown", url]
    env = dict(os.environ)
    env["PYTHONUTF8"] = "1"
    env["PYTHONIOENCODING"] = "utf-8"
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        env=env,
    )
    if result.returncode != 0:
        raise SystemExit(result.stderr or result.stdout or "wechat-article-to-markdown failed")


def extract_meta(content: str) -> tuple[str | None, str | None]:
    author = None
    date = None
    for line in content.splitlines():
        if line.startswith("> 公众号:"):
            author = line.split(":", 1)[1].strip()
        elif line.startswith("> 发布时间:"):
            date = line.split(":", 1)[1].strip()
    return author, date


def localize_image_links(content: str, images_dir: Path) -> str:
    image_files = sorted(p for p in images_dir.glob("img_*.*") if p.is_file())
    pattern = re.compile(r'!\[([^\]]*)\]\((https://mmbiz\.qpic\.cn/[^)\s]+)(?:\s+"([^"]*)")?\)')

    def repl(match: re.Match[str]) -> str:
        idx = repl.idx
        if idx >= len(image_files):
            return match.group(0)
        alt, title = match.group(1), match.group(3)
        local = f"attachments/{image_files[idx].name}"
        repl.idx += 1
        return f'![{alt}]({local}' + (f' "{title}"' if title else '') + ')'

    repl.idx = 0
    return pattern.sub(repl, content)


def rewrite_markdown(md_path: Path, source_url: str) -> str:
    content = md_path.read_text(encoding="utf-8")
    images_dir = md_path.parent / "images"
    content = localize_image_links(content, images_dir)
    content = re.sub(r"\(images/", "(attachments/", content)
    content = content.replace("\\_", "_")
    author, date = extract_meta(content)
    return enrich_markdown(
        content,
        source_url=source_url,
        note_type="wechat-article",
        source_tag="微信公众号",
        type_tag="文章",
        author=author,
        date=date,
    )


def copy_attachments(src_dir: Path, dest_dir: Path | None) -> None:
    if dest_dir is None or not src_dir.exists():
        return
    dest_dir.mkdir(parents=True, exist_ok=True)
    for item in src_dir.iterdir():
        if item.is_file():
            shutil.copy2(item, dest_dir / item.name)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("url")
    parser.add_argument("--output", "-o", required=True)
    parser.add_argument("--attachments-dir")
    args = parser.parse_args()

    output_dir = resolve_package_output_dir()
    run_tool(args.url)
    latest_md = find_latest_markdown(output_dir)

    content = rewrite_markdown(latest_md, args.url)
    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(content, encoding="utf-8")

    article_dir = latest_md.parent
    images_dir = article_dir / "images"
    copy_attachments(images_dir, Path(args.attachments_dir) if args.attachments_dir else None)
    print(out_path)


if __name__ == "__main__":
    enable_utf8_stdio()
    main()
