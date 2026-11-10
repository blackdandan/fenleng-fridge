#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
中文说明：审计软著源程序鉴别材料，输出重复率、调试残留、结构完整性和页面饱满度风险。
"""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path


SUSPICIOUS_KEYWORDS = {
    "temp": "临时变量或临时目录痕迹",
    "test": "测试残留",
    "todo": "未完成事项",
    "placeholder": "占位内容",
    "dummy": "虚拟实现",
    "mock": "模拟数据",
    "debug": "调试信息",
    "example": "示例代码"
}


def read_lines(path: Path) -> list[str]:
    if path.suffix.lower() == ".docx":
        try:
            from docx import Document
        except ImportError as exc:
            raise SystemExit("缺少 python-docx，无法读取 DOCX。") from exc
        doc = Document(path)
        return [p.text for p in doc.paragraphs]
    return path.read_text(encoding="utf-8", errors="ignore").splitlines()


def semantic_lines(lines: list[str]) -> list[str]:
    result: list[str] = []
    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue
        if re.match(r"^[{}()\[\],;.*+\-/\\=\s]+$", stripped):
            continue
        if stripped.startswith("//") or stripped.startswith("/*") or stripped.startswith("*"):
            continue
        result.append(stripped)
    return result


def keyword_issues(lines: list[str]) -> list[str]:
    issues: list[str] = []
    for idx, line in enumerate(lines, start=1):
        lowered = line.lower()
        for keyword, desc in SUSPICIOUS_KEYWORDS.items():
            if re.search(r"\b" + re.escape(keyword) + r"\b", lowered):
                if keyword == "temp" and any(exempt in lowered for exempt in ["template", "timestamp", "attempt", "tempdir"]):
                    continue
                issues.append(f"第 {idx} 行包含 {keyword}: {desc}")
    return issues


def integrity_score(non_empty: list[str]) -> tuple[int, list[str]]:
    score = 100
    issues: list[str] = []
    if not non_empty:
        return 0, ["材料为空"]
    last = non_empty[-1].strip()
    if last.endswith((",", "=", "+", "-", "*", "/", "&&", "||")):
        score -= 20
        issues.append("末行疑似未自然结束")
    opens = sum(line.count("{") for line in non_empty)
    closes = sum(line.count("}") for line in non_empty)
    diff = abs(opens - closes)
    if diff > 3:
        score -= 30
        issues.append(f"大括号数量明显不匹配：开 {opens}，闭 {closes}")
    elif diff > 0:
        issues.append(f"大括号轻微不匹配：开 {opens}，闭 {closes}")
    return max(score, 0), issues


def build_report(path: Path, assumed_pages: int) -> dict:
    lines = read_lines(path)
    non_empty = [line.strip() for line in lines if line.strip()]
    sem = semantic_lines(lines)
    counts = Counter(sem)
    duplicates = [(line, count) for line, count in counts.items() if count > 1]
    duplicate_occurrences = sum(count for _, count in duplicates)
    duplicate_ratio = (duplicate_occurrences / len(sem) * 100) if sem else 0
    top_duplicates = sorted(duplicates, key=lambda item: item[1], reverse=True)[:15]
    score, integrity_issues = integrity_score(non_empty)
    avg_lines = len(non_empty) / assumed_pages if assumed_pages else len(non_empty)
    page_fill_score = 100
    page_issues: list[str] = []
    if avg_lines < 35:
        page_fill_score = 50
        page_issues.append(f"平均每页 {avg_lines:.1f} 行，页面可能明显空白")
    elif avg_lines < 40:
        page_fill_score = 80
        page_issues.append(f"平均每页 {avg_lines:.1f} 行，建议提高页面饱满度")
    keyword_findings = keyword_issues(lines)
    issues = integrity_issues + page_issues + keyword_findings
    verdict = "pass"
    if duplicate_ratio >= 30 or score < 80 or page_fill_score < 70:
        verdict = "high_risk"
    elif duplicate_ratio >= 15 or issues:
        verdict = "needs_fix"
    return {
        "file": str(path),
        "duplicate_method": "同一份材料内的规范化语义行精确频次；不连接外部登记机构或第三方代码数据库",
        "external_duplicate_check": False,
        "line_count": len(lines),
        "non_empty_line_count": len(non_empty),
        "duplicate_ratio": round(duplicate_ratio, 2),
        "top_duplicate_lines": [{"line": line, "count": count} for line, count in top_duplicates],
        "integrity_score": score,
        "page_fill_score": page_fill_score,
        "issues": issues,
        "verdict": verdict,
        "guarantee": "本报告只能发现材料内部重复和格式风险，不能保证外部查重或原创性结论。"
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="审计软著源程序鉴别材料")
    parser.add_argument("file", help="待审计文件，支持文本或 DOCX")
    parser.add_argument("--assumed-pages", type=int, default=60, help="估算页数，默认 60")
    parser.add_argument("--output", help="JSON 报告输出路径")
    args = parser.parse_args()

    report = build_report(Path(args.file).resolve(), args.assumed_pages)
    text = json.dumps(report, ensure_ascii=False, indent=2)
    if args.output:
        Path(args.output).write_text(text + "\n", encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
