#!/usr/bin/env python3
"""Persist the Obsidian vault root path into the skill's local config.

Usage:
    python scripts/setup_vault.py --vault-root "E:/Obsidian/XIYBHK_Obsidian"

Also creates the InBox/ subdirectory if absent (clip-and-summarize 默认目标).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from config_store import set_vault_root, LOCAL_CONFIG_PATH  # noqa: E402
from utf8_console import enable_utf8_stdio  # noqa: E402


def main() -> None:
    enable_utf8_stdio()
    parser = argparse.ArgumentParser(description="Save Obsidian vault root for clip-and-summarize")
    parser.add_argument("--vault-root", required=True, help="Obsidian vault 的绝对路径")
    parser.add_argument(
        "--no-mkdir-inbox",
        action="store_true",
        help="不自动创建 InBox/ 子目录（默认会自动创建以便 clip 落盘）",
    )
    args = parser.parse_args()

    vault = set_vault_root(args.vault_root)

    if not args.no_mkdir_inbox:
        inbox = vault / "InBox"
        if not inbox.exists():
            inbox.mkdir(parents=True)
            print(f"创建 InBox 目录: {inbox}")

    print(f"已保存配置到 {LOCAL_CONFIG_PATH}")
    print(f"vault_root = {vault}")


if __name__ == "__main__":
    main()
