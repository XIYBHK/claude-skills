#!/usr/bin/env python3
"""
skill-frontmatter-zh 缓存写回脚本

接收 patch JSON，更新 translations.json。patch 可从文件或 stdin 读入。

patch 结构:
{
    "<skill_key>": {
        "name": {"en": "...", "zh_suffix": "..."},
        "description": {"en": "...", "zh": "..."}
    },
    ...
}

脚本自动:
- 填入 updated_at = 今天
- 内容实际变化才写入并刷新 updated_at（避免空 commit）
- 输出文件按 key 字母序排序，2 空格缩进，UTF-8 无 BOM，末尾换行

用法:
    python cache_writer.py --cache <translations.json> --patch <patch.json>
    python cache_writer.py --cache <translations.json> --patch -     # stdin
    python cache_writer.py --cache <translations.json> --remove <skill_key>  # 可多次
"""

import argparse
import json
import sys
from datetime import date
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')
    sys.stdin.reconfigure(encoding='utf-8')
except AttributeError:
    pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--cache', required=True, help='translations.json 路径')
    ap.add_argument('--patch', default=None,
                    help='patch JSON 文件路径，- 表示 stdin；不传则不应用 patch')
    ap.add_argument('--remove', action='append', default=[],
                    help='要从缓存中移除的 skill_key，可多次指定')
    args = ap.parse_args()

    cache_path = Path(args.cache).expanduser().resolve()
    if cache_path.exists():
        try:
            cache = json.loads(cache_path.read_text(encoding='utf-8'))
        except json.JSONDecodeError as e:
            sys.stderr.write(f"缓存文件 JSON 解析失败 {cache_path}: {e}\n")
            sys.exit(3)
        if not isinstance(cache, dict):
            sys.stderr.write(f"缓存文件根必须是 JSON object: {cache_path}\n")
            sys.exit(3)
    else:
        cache = {}

    patch = {}
    if args.patch:
        if args.patch == '-':
            patch_text = sys.stdin.read()
        else:
            patch_text = Path(args.patch).expanduser().resolve().read_text(encoding='utf-8')
        if patch_text.strip():
            try:
                patch = json.loads(patch_text)
            except json.JSONDecodeError as e:
                sys.stderr.write(f"patch JSON 解析失败: {e}\n")
                sys.exit(3)
        if not isinstance(patch, dict):
            sys.stderr.write("patch 根必须是 JSON object\n")
            sys.exit(3)

    today = date.today().isoformat()
    changed = []
    skipped_no_change = []
    errors = []

    for skill_key, entry in patch.items():
        if not isinstance(entry, dict):
            errors.append({'key': skill_key, 'reason': 'entry 不是 object'})
            continue
        name = entry.get('name') or {}
        desc = entry.get('description') or {}
        name_en = (name.get('en') or '').strip() if isinstance(name.get('en'), str) else ''
        name_zh_suffix = (name.get('zh_suffix') or '').strip() if isinstance(name.get('zh_suffix'), str) else ''
        desc_en = name_en_missing = False
        desc_en_val = desc.get('en') if isinstance(desc.get('en'), str) else ''
        desc_zh_val = desc.get('zh') if isinstance(desc.get('zh'), str) else ''

        missing = []
        if not name_en: missing.append('name.en')
        if not name_zh_suffix: missing.append('name.zh_suffix')
        if not desc_en_val.strip(): missing.append('description.en')
        if not desc_zh_val.strip(): missing.append('description.zh')
        if missing:
            errors.append({'key': skill_key, 'reason': f'缺字段: {",".join(missing)}'})
            continue

        old = cache.get(skill_key) if isinstance(cache.get(skill_key), dict) else {}
        new = {
            'name': {'en': name_en, 'zh_suffix': name_zh_suffix},
            'description': {'en': desc_en_val, 'zh': desc_zh_val},
            'updated_at': today,
        }
        old_core = {k: v for k, v in old.items() if k != 'updated_at'}
        new_core = {k: v for k, v in new.items() if k != 'updated_at'}
        if old_core == new_core:
            skipped_no_change.append(skill_key)
            continue
        cache[skill_key] = new
        changed.append(skill_key)

    removed = []
    for key in args.remove:
        if key in cache:
            del cache[key]
            removed.append(key)

    sorted_cache = {k: cache[k] for k in sorted(cache.keys())}

    cache_path.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(sorted_cache, ensure_ascii=False, indent=2) + '\n'
    cache_path.write_text(text, encoding='utf-8')

    report = {
        'cache_path': str(cache_path),
        'total_entries': len(sorted_cache),
        'changed': changed,
        'skipped_no_change': skipped_no_change,
        'removed': removed,
        'errors': errors,
    }
    json.dump(report, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write('\n')
    if errors:
        sys.exit(4)


if __name__ == '__main__':
    main()
