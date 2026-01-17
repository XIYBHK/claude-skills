#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Skill Best Practices Checker - 检查 skill 是否遵循最佳实践

Usage:
    python scripts/check_best_practices.py <path/to/skill-folder>
    python scripts/check_best_practices.py <path/to/skill-folder> --interactive

Example:
    python skill-creator/scripts/check_best_practices.py my-skill/
    python skill-creator/scripts/check_best_practices.py my-skill/ --interactive
"""

import sys
import io
import re
from pathlib import Path
from typing import List, Tuple, Dict

# 配置 UTF-8 输出（修复 Windows 编码问题）
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')


class CheckResult:
    """检查结果类"""
    def __init__(self):
        self.passed = []
        self.warnings = []
        self.errors = []

    def add_pass(self, message: str):
        self.passed.append(message)

    def add_warning(self, message: str):
        self.warnings.append(message)

    def add_error(self, message: str):
        self.errors.append(message)

    def has_issues(self) -> bool:
        return len(self.errors) > 0 or len(self.warnings) > 0


def check_description_quality(frontmatter: str, result: CheckResult):
    """检查 description 的质量"""
    desc_match = re.search(r'description:\s*(.+?)(?:\n[a-z-]+:|$)', frontmatter, re.DOTALL)
    if not desc_match:
        result.add_error("Description 字段缺失")
        return

    description = desc_match.group(1).strip()

    # 检查长度
    if len(description) < 50:
        result.add_warning(f"Description 过短（{len(description)} 字符），建议至少 50 字符以提供足够的上下文")
    elif len(description) > 1024:
        result.add_error(f"Description 过长（{len(description)} 字符），必须少于 1024 字符")
    else:
        result.add_pass(f"Description 长度适中（{len(description)} 字符）")

    # 检查是否包含触发关键词的建议
    if "当" in description or "使用" in description or "时使用" in description:
        result.add_pass("Description 包含使用场景说明")
    else:
        result.add_warning("Description 建议包含使用场景（如：'当...时使用此 skill'）")

    # 检查是否过于模糊
    vague_words = ["处理数据", "帮助", "工具", "辅助"]
    if any(word in description for word in vague_words):
        result.add_warning("Description 可能过于模糊，建议使用更具体的描述")


def check_skill_md_length(skill_md_path: Path, result: CheckResult):
    """检查 SKILL.md 的行数"""
    try:
        content = skill_md_path.read_text(encoding='utf-8')
        lines = content.split('\n')
        line_count = len(lines)

        if line_count > 500:
            result.add_warning(f"SKILL.md 有 {line_count} 行（建议 < 500 行）。考虑将详细内容移至 references/ 目录")
        else:
            result.add_pass(f"SKILL.md 长度合适（{line_count} 行）")
    except Exception as e:
        result.add_error(f"无法读取 SKILL.md: {e}")


def check_windows_paths(skill_path: Path, result: CheckResult):
    """检查是否使用了 Windows 风格的路径"""
    issues_found = []

    # 检查 SKILL.md
    skill_md = skill_path / "SKILL.md"
    if skill_md.exists():
        content = skill_md.read_text(encoding='utf-8')
        # 查找 Windows 风格路径（反斜杠）
        # 排除代码块中的转义字符
        lines = content.split('\n')
        for i, line in enumerate(lines, 1):
            # 跳过代码块
            if line.strip().startswith('```') or line.strip().startswith('    '):
                continue
            # 查找路径中的反斜杠
            if re.search(r'[a-zA-Z]:\\|scripts\\|references\\|assets\\', line):
                issues_found.append(f"SKILL.md:{i}")

    if issues_found:
        result.add_warning(f"发现 Windows 风格路径（反斜杠）：{', '.join(issues_found[:3])}" +
                          ("..." if len(issues_found) > 3 else ""))
    else:
        result.add_pass("未发现 Windows 风格路径")


def check_temporal_language(skill_md_path: Path, result: CheckResult):
    """检查时效性语言"""
    try:
        content = skill_md_path.read_text(encoding='utf-8')
        temporal_patterns = [
            (r'\b202[3-9]\b', '具体年份'),
            (r'目前|当前|最近|现在', '时间性词汇'),
            (r'即将|未来|不久', '未来时态'),
        ]

        issues = []
        for pattern, label in temporal_patterns:
            matches = re.finditer(pattern, content)
            for match in matches:
                # 计算行号
                line_num = content[:match.start()].count('\n') + 1
                issues.append(f"{label} (第 {line_num} 行)")

        if issues:
            result.add_warning(f"发现时效性信息：{', '.join(issues[:3])}" +
                             ("..." if len(issues) > 3 else ""))
        else:
            result.add_pass("未发现时效性语言")
    except Exception as e:
        result.add_error(f"检查时效性语言时出错: {e}")


def check_consistency(skill_md_path: Path, result: CheckResult):
    """检查术语一致性（简单版本）"""
    try:
        content = skill_md_path.read_text(encoding='utf-8')

        # 检查常见不一致的术语
        issues = []

        # skill vs Skill vs SKILL
        skill_lower = len(re.findall(r'\bskill\b', content))
        skill_upper = len(re.findall(r'\bSkill\b', content))
        if skill_lower > 0 and skill_upper > 0:
            issues.append(f"'skill' 与 'Skill' 混用")

        if issues:
            result.add_warning(f"术语一致性问题：{', '.join(issues)}")
        else:
            result.add_pass("术语使用一致")
    except Exception as e:
        result.add_error(f"检查术语一致性时出错: {e}")


def run_automated_checks(skill_path: Path) -> CheckResult:
    """运行所有自动检查"""
    result = CheckResult()
    skill_md = skill_path / "SKILL.md"

    print("🔍 运行自动检查...\n")

    # 检查 SKILL.md 是否存在
    if not skill_md.exists():
        result.add_error("SKILL.md 文件不存在")
        return result

    # 读取 frontmatter
    try:
        content = skill_md.read_text(encoding='utf-8')
        match = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
        if match:
            frontmatter = match.group(1)
        else:
            result.add_error("无法解析 YAML frontmatter")
            return result
    except Exception as e:
        result.add_error(f"读取 SKILL.md 失败: {e}")
        return result

    # 执行各项检查
    check_description_quality(frontmatter, result)
    check_skill_md_length(skill_md, result)
    check_windows_paths(skill_path, result)
    check_temporal_language(skill_md, result)
    check_consistency(skill_md, result)

    return result


def run_interactive_checklist() -> Dict[str, bool]:
    """运行交互式检查清单"""
    print("\n" + "="*60)
    print("📋 交互式最佳实践检查清单")
    print("="*60)
    print("请回答以下问题（输入 y/n）：\n")

    checklists = {
        "核心质量": [
            "Description 包含了触发关键词",
            "额外详情已放在独立文件中（而非全部在 SKILL.md）",
            "示例具体而非抽象",
            "文件引用保持一级深度（避免链式引用）",
            "适当使用了渐进式披露",
            "工作流步骤清晰明确",
        ],
        "代码和脚本": [
            "脚本能解决问题而非推卸给 Claude",
            "错误处理明确且有帮助",
            "无魔法常量（所有值都有说明）",
            "所需包已列在指令中",
            "关键操作有验证/确认步骤",
        ],
        "测试": [
            "已创建至少 3 个评估场景",
            "在不同模型上测试过（Haiku/Sonnet/Opus）",
            "用真实使用场景测试过",
        ],
    }

    results = {}
    for category, items in checklists.items():
        print(f"\n【{category}】")
        for i, item in enumerate(items, 1):
            while True:
                answer = input(f"  {i}. {item}? (y/n): ").strip().lower()
                if answer in ['y', 'n']:
                    results[f"{category}:{item}"] = (answer == 'y')
                    break
                print("     请输入 y 或 n")

    return results


def print_report(result: CheckResult, interactive_results: Dict[str, bool] = None):
    """打印检查报告"""
    print("\n" + "="*60)
    print("📊 检查报告")
    print("="*60)

    # 自动检查结果
    print(f"\n✅ 通过项 ({len(result.passed)}):")
    for item in result.passed:
        print(f"   • {item}")

    if result.warnings:
        print(f"\n⚠️  警告项 ({len(result.warnings)}):")
        for item in result.warnings:
            print(f"   • {item}")

    if result.errors:
        print(f"\n❌ 错误项 ({len(result.errors)}):")
        for item in result.errors:
            print(f"   • {item}")

    # 交互式检查结果
    if interactive_results:
        failed_items = [k.split(':', 1)[1] for k, v in interactive_results.items() if not v]
        if failed_items:
            print(f"\n📝 需要改进的项 ({len(failed_items)}):")
            for item in failed_items:
                print(f"   • {item}")

    # 总结
    print("\n" + "="*60)
    if not result.has_issues() and (not interactive_results or all(interactive_results.values())):
        print("🎉 恭喜！Skill 符合所有最佳实践！")
    elif result.errors:
        print("⛔ 发现严重问题，强烈建议在打包前修复所有错误项。")
    else:
        print("✨ 基本检查通过，建议解决警告项以提升质量。")
    print("="*60)


def main():
    """主函数"""
    if len(sys.argv) < 2:
        print("使用方法: python scripts/check_best_practices.py <path/to/skill-folder> [--interactive]")
        print("\n示例:")
        print("  python skill-creator/scripts/check_best_practices.py my-skill/")
        print("  python skill-creator/scripts/check_best_practices.py my-skill/ --interactive")
        sys.exit(1)

    skill_path = Path(sys.argv[1]).resolve()
    interactive = "--interactive" in sys.argv

    # 验证 skill 路径
    if not skill_path.exists():
        print(f"❌ 错误: Skill 目录不存在: {skill_path}")
        sys.exit(1)

    if not skill_path.is_dir():
        print(f"❌ 错误: 路径不是目录: {skill_path}")
        sys.exit(1)

    print(f"🔎 检查 Skill: {skill_path.name}")
    print()

    # 运行自动检查
    result = run_automated_checks(skill_path)

    # 运行交互式检查（如果指定）
    interactive_results = None
    if interactive:
        interactive_results = run_interactive_checklist()

    # 打印报告
    print_report(result, interactive_results)

    # 返回退出码
    if result.errors:
        sys.exit(1)
    else:
        sys.exit(0)


if __name__ == "__main__":
    main()
