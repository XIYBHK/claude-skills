#!/usr/bin/env python3
"""Unified router for clip-and-summarize sources.

- Detects source from URL (zhihu / bilibili / wechat / generic)
- Delegates to the corresponding fetcher script
- Saves the output into an Obsidian vault (default: <vault>/InBox/) or a plain
  Markdown path, with filename derived from frontmatter `title` when not given.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

# 确保同目录脚本（utf8_console、save_note 等）可 import，无论从哪个 CWD 运行
SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from utf8_console import enable_utf8_stdio  # noqa: E402
from config_store import get_vault_root, LOCAL_CONFIG_PATH  # noqa: E402

# Windows 不允许的文件名字符（Obsidian 跨平台也建议避开）
ILLEGAL_NAME_CHARS = r'\/:*?"<>|'


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


def run(cmd: list[str]) -> str:
    env = dict(os.environ)
    env.setdefault("PYTHONUTF8", "1")
    env.setdefault("PYTHONIOENCODING", "utf-8")
    result = subprocess.run(
        cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", env=env
    )
    if result.returncode != 0:
        raise SystemExit(result.stderr or result.stdout or f"Command failed: {' '.join(cmd)}")
    return result.stdout


def resolve_vault_root(cli_value: str | None) -> Path | None:
    """解析 vault 根目录：CLI 参数 > <skill>/config/local.json 的 vault_root > None。

    不再支持环境变量。首次使用时需要让用户提供路径并通过 setup_vault.py 持久化。
    """
    if cli_value:
        path = Path(cli_value).expanduser()
        if not path.exists():
            raise SystemExit(f"Vault root does not exist: {path}")
        return path
    return get_vault_root()  # None if not configured yet


def read_title_from_note(md_path: Path) -> str | None:
    """解析笔记标题：优先 frontmatter.title，否则用正文第一个 H1。

    考虑到各 fetcher（如 fetch_wechat）生成的 frontmatter 不一定含 title
    而把标题放在正文 `# ...` 里，这里加一层 H1 fallback。
    """
    if not md_path.exists():
        return None
    text = md_path.read_text(encoding="utf-8")

    body = text
    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end > 0:
            fm = text[4:end]
            for line in fm.splitlines():
                m = re.match(r'^title:\s*(.+?)\s*$', line)
                if m:
                    val = m.group(1).strip()
                    if (val.startswith('"') and val.endswith('"')) or (val.startswith("'") and val.endswith("'")):
                        val = val[1:-1]
                    if val:
                        return val
            body = text[end + 5:]

    m = re.search(r'^#\s+(.+?)\s*$', body, flags=re.MULTILINE)
    if m:
        return m.group(1).strip()
    return None


def sanitize_filename(name: str) -> str:
    """去掉 Windows/Obsidian 非法字符并合并多余空格。"""
    cleaned = name
    for ch in ILLEGAL_NAME_CHARS:
        cleaned = cleaned.replace(ch, " ")
    cleaned = " ".join(cleaned.split())
    return cleaned.strip() or "未命名"


def resolve_output_path(
    args: argparse.Namespace, temp_path: Path, vault_root: Path | None
) -> Path:
    """决定最终落盘的 md 文件路径。"""
    # target=markdown：完全由 --output 指定
    if args.target == "markdown":
        if not args.output:
            raise SystemExit("target=markdown 时必须指定 --output")
        return Path(args.output).expanduser()

    # target=obsidian：需要 vault_root
    if vault_root is None:
        raise SystemExit(
            f"未配置 Obsidian vault 路径。请先运行:\n"
            f"  python scripts/setup_vault.py --vault-root <绝对路径>\n"
            f"或临时指定 --vault-root <绝对路径>\n"
            f"配置文件位置: {LOCAL_CONFIG_PATH}"
        )

    folder = args.folder or "InBox"
    if args.output:
        # 用户显式指定了文件名
        filename = args.output
        if not filename.lower().endswith(".md"):
            filename = f"{filename}.md"
    else:
        # 从 frontmatter.title 或正文 H1 推断中文文件名
        title = read_title_from_note(temp_path)
        if not title:
            raise SystemExit(
                "未从抓取结果中获取到标题（frontmatter.title 和正文 H1 都没有），"
                "请用 --output <中文标题> 显式指定文件名"
            )
        filename = f"{sanitize_filename(title)}.md"

    return vault_root / folder / filename


def main() -> None:
    enable_utf8_stdio()

    parser = argparse.ArgumentParser(description="Route a URL to the right fetcher and save the note.")
    parser.add_argument("--url", required=True, help="知乎/B站/微信公众号/通用网页 URL")
    parser.add_argument(
        "--target",
        choices=["markdown", "obsidian"],
        default="obsidian",
        help="默认 obsidian：保存进 vault；markdown：保存为普通 md 文件（需配合 --output）",
    )
    parser.add_argument(
        "--vault-root",
        help="Obsidian vault 根目录；未指定时读 <skill>/config/local.json 的 vault_root",
    )
    parser.add_argument(
        "--folder",
        default="InBox",
        help="vault 内的子目录，默认 InBox/（对齐 Claudian Schema）",
    )
    parser.add_argument(
        "--output",
        help="文件名（target=obsidian）或完整路径（target=markdown）；"
        "未指定时从 frontmatter title 自动生成中文文件名",
    )
    parser.add_argument(
        "--temp",
        default=str(SCRIPT_DIR / "_tmp_note.md"),
        help="中间态 md 文件路径（fetcher 输出→此文件→save_note 搬到最终位置）",
    )
    args = parser.parse_args()

    vault_root = resolve_vault_root(args.vault_root)

    source = detect_source(args.url)
    # 预检
    run([sys.executable, str(SCRIPT_DIR / "preflight_check.py"), "--url", args.url])

    temp_path = Path(args.temp)
    temp_path.parent.mkdir(parents=True, exist_ok=True)

    # 通用附件策略：给每个 fetcher 准备临时附件目录，fetcher 按需往里放文件，
    # 最终由 save_note 重写引用 + copy 到 <笔记名>/。未实现本地附件下载的 fetcher
    # 会忽略这个参数（目录保持空），save_note 侧会跳过 rewrite。
    tmp_attachments = SCRIPT_DIR / "_tmp_attachments"
    if tmp_attachments.exists():
        shutil.rmtree(tmp_attachments, ignore_errors=True)
    tmp_attachments.mkdir(parents=True, exist_ok=True)

    # 分发到具体 fetcher
    fetcher_map = {
        "zhihu": "fetch_zhihu.py",
        "bilibili": "fetch_bilibili.py",
        "wechat": "fetch_wechat.py",
        "generic": "fetch_generic.py",
    }
    fetcher = SCRIPT_DIR / fetcher_map[source]
    fetcher_cmd = [
        sys.executable, str(fetcher), args.url,
        "--output", str(temp_path),
        "--attachments-dir", str(tmp_attachments),
    ]
    run(fetcher_cmd)

    # 决定最终路径并调 save_note
    dest = resolve_output_path(args, temp_path, vault_root)
    save_cmd = [
        sys.executable,
        str(SCRIPT_DIR / "save_note.py"),
        str(temp_path),
        "--target",
        args.target,
    ]
    if args.target == "obsidian":
        save_cmd += [
            "--obsidian-root",
            str(vault_root),
            "--folder",
            args.folder or "InBox",
            "--output",
            dest.name,
        ]
    else:
        save_cmd += ["--output", str(dest)]

    # 有实际附件才传 --attachments-dir，避免空目录触发无谓 rewrite
    if any(tmp_attachments.iterdir()):
        save_cmd += ["--attachments-dir", str(tmp_attachments)]

    out = run(save_cmd).strip()
    print(f"OK clip saved: {out or dest}")

    # 清理临时文件
    try:
        temp_path.unlink(missing_ok=True)
    except OSError:
        pass
    shutil.rmtree(tmp_attachments, ignore_errors=True)


if __name__ == "__main__":
    main()
