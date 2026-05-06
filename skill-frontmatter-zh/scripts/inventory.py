#!/usr/bin/env python3
"""
skill-frontmatter-zh 盘点脚本

扫描 skills 目录下所有 */SKILL.md 的 YAML frontmatter，读取 translations.json 缓存，
输出分类清单到 stdout（JSON），供 Claude 决策。

桶：
    need_translate     纯英文 + 缓存未命中（无 key 或 en 已变）→ 需要 LLM 翻译
    cache_hit          纯英文 + 缓存 en 命中                → 直接复用 cached.zh
    skip_cjk_no_cache  SKILL.md 已含 CJK + 缓存无 key       → 跳过不处理
    reclaim_polish     SKILL.md 已含 CJK + 缓存有 key 且当前 zh ≠ cached.zh → 回收用户润色
    format_anomaly     frontmatter 缺 name/description 或解析失败

用法:
    python inventory.py --skills-dir ~/.claude/skills [--cache <path>]

不依赖 PyYAML，手动解析 frontmatter 的 name/description 两字段（含单行、双引号、
块标量 |/> 以及缩进折叠形式），避免 PyYAML 对 description 里 ": " 的误判。
"""

import argparse
import json
import re
import sys
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')
except AttributeError:
    pass

CJK_RE = re.compile(r'[一-鿿぀-ゟ゠-ヿ가-힯]')


def contains_cjk(s: str) -> bool:
    return bool(CJK_RE.search(s or ""))


def _strip_quotes(s: str) -> str:
    s = s.strip()
    if len(s) >= 2 and ((s[0] == '"' and s[-1] == '"') or (s[0] == "'" and s[-1] == "'")):
        return s[1:-1]
    return s


def extract_field(block_lines, key: str):
    """
    从 frontmatter 行数组里提取 `key` 字段的完整字符串值。支持:
      key: value                      # 单行（可选引号）
      key: "value with : colon"       # 带引号
      key: |                          # 块标量（保留换行）
        line1
        line2
      key: >                          # 折叠式（空行变换行）
        line1
        line2
      key:                            # 空值 + 缩进后续行（折叠）
        line1
        line2
    返回 None 表示没找到该 key。
    """
    key_re = re.compile(rf'^{re.escape(key)}\s*:\s*(.*)$')
    for i, line in enumerate(block_lines):
        m = key_re.match(line)
        if not m:
            continue
        first = m.group(1).rstrip()

        # 块标量或空值（下一段需要缩进）
        if first in ('|', '|-', '|+', '>', '>-', '>+') or first == '':
            body = []
            base_indent = None
            for nl in block_lines[i + 1:]:
                stripped = nl.strip()
                if stripped == '':
                    body.append('')
                    continue
                cur_indent = len(nl) - len(nl.lstrip(' '))
                if cur_indent == 0:
                    break
                if base_indent is None:
                    base_indent = cur_indent
                body.append(nl[base_indent:] if nl.startswith(' ' * base_indent) else nl.lstrip(' '))
            # 去掉尾部空行
            while body and body[-1] == '':
                body.pop()

            if first.startswith('|'):
                return '\n'.join(body)
            # 折叠（> 或空值）
            out = []
            run = []
            for ln in body:
                if ln == '':
                    if run:
                        out.append(' '.join(run))
                        run = []
                    out.append('')
                else:
                    run.append(ln)
            if run:
                out.append(' '.join(run))
            # 合并相邻空行为单个换行
            return '\n'.join(out).strip()

        # 单行（去掉两端引号，内部 ": " 保持不动）
        return _strip_quotes(first)
    return None


def parse_frontmatter(skill_md: Path):
    """返回 (name, description)，找不到返回 (None, None)。"""
    try:
        text = skill_md.read_text(encoding='utf-8')
    except (OSError, UnicodeDecodeError):
        return None, None
    if not text.startswith('---'):
        return None, None
    m = re.match(r'---\r?\n(.*?)\r?\n---\r?\n', text, re.DOTALL)
    if not m:
        return None, None
    block_lines = m.group(1).split('\n')
    name = extract_field(block_lines, 'name')
    desc = extract_field(block_lines, 'description')
    return name, desc


def norm(s) -> str:
    return s.strip() if isinstance(s, str) else ''


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--skills-dir', required=True,
                    help='skills 根目录，如 ~/.claude/skills')
    ap.add_argument('--cache', default=None,
                    help='translations.json 路径，默认 <skills-dir>/skill-frontmatter-zh/translations.json')
    args = ap.parse_args()

    skills_dir = Path(args.skills_dir).expanduser().resolve()
    if not skills_dir.is_dir():
        sys.stderr.write(f"skills 目录不存在: {skills_dir}\n")
        sys.exit(1)

    cache_path = (Path(args.cache).expanduser().resolve() if args.cache
                  else skills_dir / 'skill-frontmatter-zh' / 'translations.json')

    cache = {}
    if cache_path.exists():
        try:
            cache = json.loads(cache_path.read_text(encoding='utf-8'))
        except json.JSONDecodeError as e:
            sys.stderr.write(f"缓存文件 JSON 解析失败 {cache_path}: {e}\n")
            sys.exit(3)
        if not isinstance(cache, dict):
            sys.stderr.write(f"缓存文件根必须是 JSON object: {cache_path}\n")
            sys.exit(3)

    buckets = {
        'need_translate': [],
        'cache_hit': [],
        'skip_cjk_no_cache': [],
        'reclaim_polish': [],
        'format_anomaly': [],
    }
    details = {}

    for skill_md in sorted(skills_dir.glob('*/SKILL.md')):
        skill_key = skill_md.parent.name
        if skill_key.startswith('.'):
            continue

        name, description = parse_frontmatter(skill_md)
        name = norm(name)
        description = norm(description)

        if not name or not description:
            buckets['format_anomaly'].append(skill_key)
            details[skill_key] = {'reason': 'frontmatter 缺 name 或 description'}
            continue

        is_cjk = contains_cjk(name) or contains_cjk(description)
        cached = cache.get(skill_key) if isinstance(cache.get(skill_key), dict) else None
        cached_desc_en = ''
        cached_desc_zh = ''
        cached_name_en = ''
        cached_name_zh_suffix = ''
        if cached:
            d = cached.get('description') or {}
            n = cached.get('name') or {}
            cached_desc_en = norm(d.get('en'))
            cached_desc_zh = norm(d.get('zh'))
            cached_name_en = norm(n.get('en'))
            cached_name_zh_suffix = norm(n.get('zh_suffix'))

        if is_cjk:
            if cached and cached_desc_en:
                if cached_desc_zh != description:
                    buckets['reclaim_polish'].append(skill_key)
                    details[skill_key] = {
                        'cached_name_en': cached_name_en,
                        'cached_name_zh_suffix': cached_name_zh_suffix,
                        'cached_desc_en': cached_desc_en,
                        'cached_desc_zh': cached_desc_zh,
                        'current_name': name,
                        'current_description': description,
                    }
            else:
                buckets['skip_cjk_no_cache'].append(skill_key)
                details[skill_key] = {
                    'reason': 'SKILL.md 已中文化但缓存无记录，不做补种子',
                }
        else:
            if cached and cached_desc_en == description:
                buckets['cache_hit'].append(skill_key)
                details[skill_key] = {
                    'cached_zh_suffix': cached_name_zh_suffix,
                    'cached_zh': cached_desc_zh,
                    'current_name': name,
                }
            else:
                buckets['need_translate'].append(skill_key)
                details[skill_key] = {
                    'name': name,
                    'description': description,
                    'reason': 'no_cache' if not cached else 'en_changed',
                    'prev_cached_desc_en': cached_desc_en if cached else '',
                }

    output = {
        'skills_dir': str(skills_dir),
        'cache_path': str(cache_path),
        'summary': {k: len(v) for k, v in buckets.items()},
        'buckets': buckets,
        'details': details,
    }
    json.dump(output, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write('\n')


if __name__ == '__main__':
    main()
