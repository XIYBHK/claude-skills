#!/usr/bin/env python3
"""Preflight dependency checks for clip-and-summarize."""

from __future__ import annotations

import argparse
import importlib.util
import re
import shutil
import sys
from pathlib import Path

from utf8_console import enable_utf8_stdio

SCRIPT_DIR = Path(__file__).resolve().parent
WORKSPACE_DIR = SCRIPT_DIR.parent.parent.parent
PRIVATE_AUTH_PATH = WORKSPACE_DIR / "tools" / "content-collectors" / "private" / "auth.json"


def detect_source(url: str) -> str:
    if "zhihu.com" in url or "zhuanlan.zhihu.com" in url:
        return "zhihu"
    if "bilibili.com/video/" in url or re.search(r"\bBV[0-9A-Za-z]+\b", url):
        return "bilibili"
    if "mp.weixin.qq.com" in url:
        return "wechat"
    if url.startswith("http://") or url.startswith("https://"):
        return "generic"
    raise SystemExit(f"Unsupported source: {url}")


def has_module(name: str) -> bool:
    return importlib.util.find_spec(name) is not None


def has_command(name: str) -> bool:
    return shutil.which(name) is not None


def fail(lines: list[str]) -> None:
    raise SystemExit("\n".join(lines))


def check_common() -> None:
    missing = []
    if not has_module("markdownify"):
        missing.append("- Missing Python package: markdownify")
    if missing:
        fail(missing + ["Install with: python -m pip install markdownify"])


def check_zhihu() -> None:
    check_common()
    if not has_module("requests"):
        fail([
            "- Missing Python package: requests",
            "Install with: python -m pip install requests",
        ])
    if not PRIVATE_AUTH_PATH.exists():
        fail([
            f"- Missing private auth file: {PRIVATE_AUTH_PATH}",
            "Create it or set ZHIHU_XSRF / ZHIHU_Z_C0 as environment variables.",
        ])


def check_bilibili() -> None:
    check_common()
    missing = []
    if not has_module("bilibili_api"):
        missing.append("- Missing Python package: bilibili-api-python")
    if not has_module("aiohttp"):
        missing.append("- Missing Python package: aiohttp")
    if missing:
        fail(missing + ["Install with: python -m pip install bilibili-api-python aiohttp"])
    if not PRIVATE_AUTH_PATH.exists():
        fail([
            f"- Missing private auth file: {PRIVATE_AUTH_PATH}",
            "Create it or set BILIBILI_SESSDATA as an environment variable.",
        ])


def check_wechat() -> None:
    check_common()
    if not has_module("wechat_article_to_markdown"):
        fail([
            "- Missing Python package: wechat-article-to-markdown",
            "Install with: python -m pip install wechat-article-to-markdown",
        ])
    if not has_module("camoufox"):
        fail([
            "- Missing Python package: camoufox",
            "Install with: python -m pip install \"camoufox[geoip]\"",
        ])


def check_generic() -> None:
    check_common()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    args = parser.parse_args()

    source = detect_source(args.url)
    if source == "zhihu":
        check_zhihu()
    elif source == "bilibili":
        check_bilibili()
    elif source == "wechat":
        check_wechat()
    elif source == "generic":
        check_generic()
    print(f"preflight ok: {source}")


if __name__ == "__main__":
    main()
