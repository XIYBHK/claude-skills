#!/usr/bin/env python3
"""Save generated markdown to workspace or Obsidian vault.

Attachment layout follows Claudian Schema + Attachment Management plugin:
  <vault>/<folder>/<笔记名>.md
  <vault>/<folder>/<笔记名>/<原始图片文件>

笔记内图片引用重写为 `<笔记名>/<原始文件名>`；Attachment Management 插件
在 Obsidian 打开笔记时会接管重命名（→ `IMG-YYYYMMDDHHmmssSSS.<ext>`），
因此脚本保留原始文件名，不提前模拟插件命名。
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

# 确保同目录模块可被 import，无论 CWD 在哪
SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from utf8_console import enable_utf8_stdio  # noqa: E402


def rewrite_attachment_paths(content: str, dest: Path, attachments_dir: Path) -> str:
    """把附件复制到 <笔记名>/ 子目录，并把 md 内的图片引用改成 Obsidian wikilink。

    为什么用 wikilink（`![[file.png]]`）而不是 markdown link（`![](path)`）：
    - Obsidian 对 wikilink 做全 vault 解析，只需文件名即可定位附件
    - Attachment Management 插件只跟踪 wikilink，rename 附件时自动同步引用
    - 与用户现有 vault 笔记风格保持一致（参考 sources/ 下的原始资料）

    附件物理仍放到 <笔记名>/ 子目录，方便归档和移动时整体搬运。
    """
    note_stem = dest.stem
    target_dir = dest.parent / note_stem
    target_dir.mkdir(parents=True, exist_ok=True)

    for item in sorted(attachments_dir.iterdir()):
        if not item.is_file():
            continue
        shutil.copy2(item, target_dir / item.name)

        # 把所有形如 ![alt](attachments/file) 或 ![alt](images/file "title") 的
        # markdown image link 替换为 Obsidian wikilink ![[file]]
        filename_re = re.escape(item.name)
        md_link_pattern = re.compile(
            r'!\[[^\]]*\]\((?:attachments|images)/'
            + filename_re
            + r'(?:\s+"[^"]*")?\)'
        )
        content = md_link_pattern.sub(f'![[{item.name}]]', content)

    return content


def save_markdown(
    content: str,
    target: str,
    output: str | None = None,
    obsidian_root: str | None = None,
    folder: str | None = None,
    attachments_dir: str | None = None,
) -> Path:
    if target == "markdown":
        if not output:
            raise SystemExit("--output is required when target=markdown")
        dest = Path(output).expanduser()
    elif target == "obsidian":
        if not obsidian_root or not folder or not output:
            raise SystemExit("obsidian target requires --obsidian-root, --folder, and --output")
        dest = Path(obsidian_root).expanduser() / folder / output
    else:
        raise SystemExit(f"Unsupported target: {target}")

    dest.parent.mkdir(parents=True, exist_ok=True)

    if attachments_dir:
        src = Path(attachments_dir)
        if src.exists() and src.is_dir():
            content = rewrite_attachment_paths(content, dest, src)

    dest.write_text(content, encoding="utf-8")
    return dest


def main() -> None:
    enable_utf8_stdio()
    parser = argparse.ArgumentParser()
    parser.add_argument("input_file", help="待保存的 markdown 文件路径")
    parser.add_argument("--target", choices=["markdown", "obsidian"], required=True)
    parser.add_argument("--output")
    parser.add_argument("--obsidian-root")
    parser.add_argument("--folder")
    parser.add_argument("--attachments-dir")
    args = parser.parse_args()

    content = Path(args.input_file).read_text(encoding="utf-8")
    dest = save_markdown(
        content,
        args.target,
        args.output,
        args.obsidian_root,
        args.folder,
        args.attachments_dir,
    )
    print(dest)


if __name__ == "__main__":
    main()
