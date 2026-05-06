#!/usr/bin/env python3
"""Read/write the skill's local config under <skill>/config/local.json.

Config schema:
    {
      "vault_root": "E:/Obsidian/XIYBHK_Obsidian"
    }

The file is git-ignored so each machine keeps its own values.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPT_DIR.parent
CONFIG_DIR = SKILL_DIR / "config"
LOCAL_CONFIG_PATH = CONFIG_DIR / "local.json"


def load_local_config() -> dict[str, Any]:
    if not LOCAL_CONFIG_PATH.exists():
        return {}
    try:
        return json.loads(LOCAL_CONFIG_PATH.read_text(encoding="utf-8"))
    except Exception as exc:
        raise SystemExit(f"Failed to read {LOCAL_CONFIG_PATH}: {exc}")


def save_local_config(data: dict[str, Any]) -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    LOCAL_CONFIG_PATH.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def get_vault_root() -> Path | None:
    """Return the configured Obsidian vault root, or None if absent/invalid."""
    data = load_local_config()
    val = data.get("vault_root")
    if not val:
        return None
    path = Path(val).expanduser()
    if not path.exists():
        return None
    return path


def set_vault_root(path: str | Path) -> Path:
    """Persist vault_root after validating the directory exists."""
    vault = Path(path).expanduser()
    if not vault.exists():
        raise SystemExit(f"Vault 目录不存在: {vault}")
    if not vault.is_dir():
        raise SystemExit(f"Vault 路径不是目录: {vault}")

    data = load_local_config()
    data["vault_root"] = str(vault).replace("\\", "/")
    save_local_config(data)
    return vault
