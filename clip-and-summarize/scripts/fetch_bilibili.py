#!/usr/bin/env python3
"""Fetch Bilibili video metadata and subtitle-first note content.

Secrets are resolved in this order:
1. tools/content-collectors/private/auth.json
2. environment variables
"""

from __future__ import annotations

import argparse
import asyncio
from datetime import datetime
from pathlib import Path

from bilibili_api import Credential, video

from auth_resolver import resolve_secret
from note_enricher import enrich_markdown
from utf8_console import enable_utf8_stdio


def credential() -> Credential:
    sessdata = resolve_secret(("bilibili", "sessdata"), "BILIBILI_SESSDATA")
    if not sessdata:
        raise SystemExit("Missing Bilibili auth. Put it in tools/content-collectors/private/auth.json or set BILIBILI_SESSDATA.")
    return Credential(sessdata=sessdata)


async def build_note(bvid: str) -> str:
    v = video.Video(bvid=bvid, credential=credential())
    info = await v.get_info()
    title = info.get("title", bvid)
    owner = (info.get("owner") or {}).get("name", "Unknown")
    duration = info.get("duration", 0)
    pubdate = info.get("pubdate", 0)
    source_url = f"https://www.bilibili.com/video/{bvid}"

    cid = await v.get_cid(page_index=0)
    player = await v.get_player_info(cid=cid)
    subtitles = ((player.get("subtitle") or {}).get("subtitles") or [])

    subtitle_text = ""
    if subtitles:
        sub_url = subtitles[0].get("subtitle_url")
        if sub_url:
            import aiohttp
            async with aiohttp.ClientSession() as session:
                async with session.get(f"https:{sub_url}") as resp:
                    sub_data = await resp.json()
            body = sub_data.get("body", [])
            subtitle_text = "\n".join(item.get("content", "") for item in body)

    date_str = datetime.fromtimestamp(pubdate).strftime("%Y-%m-%d") if pubdate else None
    transcript_block = f"## 字幕整理\n\n{subtitle_text}\n" if subtitle_text else "## 字幕整理\n\n- 该视频未获取到字幕，可先保存元信息笔记。\n"
    raw = f"# {title}\n\n{transcript_block}"
    markdown = enrich_markdown(
        raw,
        source_url=source_url,
        note_type="bilibili-video",
        source_tag="B站",
        type_tag="视频",
        author=owner,
        date=date_str,
    )
    if duration:
        markdown = markdown.replace("---\n\n# ", f"duration_seconds: {duration}\n---\n\n# ", 1)
    return markdown


if __name__ == "__main__":
    enable_utf8_stdio()
    parser = argparse.ArgumentParser()
    parser.add_argument("bvid")
    parser.add_argument("--output", "-o")
    parser.add_argument(
        "--attachments-dir",
        help="预留：未来把 B 站封面/字幕素材下载到此目录（当前未实现，参数被忽略）",
    )
    args = parser.parse_args()

    markdown = asyncio.run(build_note(args.bvid))
    if args.output:
        out_path = Path(args.output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(markdown, encoding="utf-8")
        print(f"OK bilibili saved: {out_path}")
    else:
        print(markdown)
