#!/usr/bin/env python3
"""Resolve private auth config for content collectors.

Lookup priority:
1. ~/.claude/config/clip-auth.json  (推荐，通用位置)
2. <workspace>/tools/content-collectors/private/auth.json  (OpenClaw 时代遗留位置)
3. environment variables

Keys expected in the JSON:
    {
      "zhihu":    { "_xsrf": "...", "z_c0": "..." },
      "bilibili": { "SESSDATA": "..." }
    }
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPT_DIR.parent

# 主位置：skill 工作目录下的 config/clip-auth.json（已在 .gitignore 保护，跨机器不泄露）
PRIMARY_AUTH_PATH = SKILL_DIR / "config" / "clip-auth.json"

# Legacy 1：先前版本曾建议 ~/.claude/config/clip-auth.json，保留兼容
LEGACY_HOME_AUTH_PATH = Path.home() / ".claude" / "config" / "clip-auth.json"

# Legacy 2：OpenClaw 时代路径 <workspace>/tools/content-collectors/private/auth.json
LEGACY_OPENCLAW_AUTH_PATH = (
    SCRIPT_DIR.parent.parent.parent / "tools" / "content-collectors" / "private" / "auth.json"
)

AUTH_CANDIDATES = [PRIMARY_AUTH_PATH, LEGACY_HOME_AUTH_PATH, LEGACY_OPENCLAW_AUTH_PATH]


def load_private_auth() -> dict[str, Any]:
    """Read the first existing auth file among AUTH_CANDIDATES.

    Returns empty dict when none exists so callers can fall back to env vars.
    """
    for path in AUTH_CANDIDATES:
        if path.exists():
            try:
                return json.loads(path.read_text(encoding="utf-8"))
            except Exception as exc:
                raise SystemExit(f"Failed to read private auth config: {path} ({exc})")
    return {}


def get_nested(mapping: dict[str, Any], *keys: str) -> str | None:
    current: Any = mapping
    for key in keys:
        if not isinstance(current, dict):
            return None
        current = current.get(key)
    return current if isinstance(current, str) and current else None


def resolve_secret(private_keys: tuple[str, ...], env_key: str) -> str | None:
    """Resolve a secret from auth file (by nested key path) or environment variable."""
    data = load_private_auth()
    local_value = get_nested(data, *private_keys)
    if local_value:
        return local_value
    env_value = os.environ.get(env_key)
    return env_value or None


def auth_source_hint() -> str:
    """Human-readable hint showing which auth file is effective (for error messages)."""
    for path in AUTH_CANDIDATES:
        if path.exists():
            return str(path)
    return f"(none; fallback to env vars; put JSON at {PRIMARY_AUTH_PATH})"
