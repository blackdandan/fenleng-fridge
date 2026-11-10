#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
中文说明：审计提取后的源程序材料中的高频/通用标识符。

本脚本是只读审计器，绝不改写标识符、源码或文档。Bean、Domain、Service
等词汇在软件工程中很常见，出现本身不能证明抄袭，也不能通过改名制造原创性；
报告只用于定位需要人工确认的通用代码、模板代码和源码选材风险。
"""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path


# 常见架构层、实现层、UI 层和泛化业务词。匹配时会拆分 CamelCase、snake_case。
COMMON_COMPONENTS = {
    "bean", "domain", "manager", "service", "repository", "controller",
    "model", "entity", "dto", "vo", "pojo", "usecase", "provider",
    "notifier", "state", "viewmodel", "config", "configuration", "util",
    "utility", "helper", "factory", "builder", "adapter", "client",
    "request", "response", "result", "data", "common", "base", "impl",
    "api", "dao", "handler", "context", "widget", "screen", "page",
    "view", "component", "route", "router", "theme", "event", "action",
    "store", "user", "account", "item", "list", "info", "value", "key",
    "type", "name", "id", "crud", "default",
}

IDENTIFIER_RE = re.compile(r"\b[A-Za-z_][A-Za-z0-9_]*\b")
CAMEL_PART_RE = re.compile(r"[A-Z]+(?=[A-Z][a-z]|[0-9]|$)|[A-Z]?[a-z]+|[A-Z]+|[0-9]+")
FORBIDDEN_DECLARATION_RE = re.compile(r"^\s*(import|package|using|namespace)\b", re.IGNORECASE)


def read_lines(path: Path) -> list[str]:
    if path.suffix.lower() == ".docx":
        try:
            from docx import Document
        except ImportError as exc:
            raise SystemExit("缺少 python-docx，无法读取 DOCX。") from exc
        return [paragraph.text for paragraph in Document(path).paragraphs]
    return path.read_text(encoding="utf-8", errors="ignore").splitlines()


def strip_comments_and_strings(line: str, in_block_comment: bool) -> tuple[str, bool]:
    """删除注释和字符串，避免路径、说明文字或示例字符串污染标识符统计。"""
    result: list[str] = []
    index = 0
    while index < len(line):
        if in_block_comment:
            end = line.find("*/", index)
            if end < 0:
                return "".join(result), True
            index = end + 2
            in_block_comment = False
            continue
        if line.startswith("/*", index):
            in_block_comment = True
            index += 2
            continue
        if line.startswith("//", index) or line.startswith("#", index):
            break
        if line[index] in {"'", '"', "`"}:
            quote = line[index]
            index += 1
            while index < len(line):
                if line[index] == "\\":
                    index += 2
                elif line[index] == quote:
                    index += 1
                    break
                else:
                    index += 1
            result.append(" ")
            continue
        result.append(line[index])
        index += 1
    return "".join(result), in_block_comment


def identifier_components(identifier: str) -> list[str]:
    parts: list[str] = []
    for segment in identifier.split("_"):
        parts.extend(match.group(0).lower() for match in CAMEL_PART_RE.finditer(segment))
    return parts or [identifier.lower()]


def build_report(path: Path) -> dict:
    lines = read_lines(path)
    blank_lines = [index for index, line in enumerate(lines, start=1) if not line.strip()]
    forbidden = [
        {"line": index, "text": line.strip()}
        for index, line in enumerate(lines, start=1)
        if FORBIDDEN_DECLARATION_RE.match(line) or re.search(r"\bimport\b", line, re.IGNORECASE)
    ]

    identifiers: list[str] = []
    components: list[str] = []
    in_block_comment = False
    for line in lines:
        cleaned, in_block_comment = strip_comments_and_strings(line, in_block_comment)
        for identifier in IDENTIFIER_RE.findall(cleaned):
            identifiers.append(identifier)
            components.extend(identifier_components(identifier))

    exact_counts = Counter(identifier.lower() for identifier in identifiers)
    common_counts = Counter(component for component in components if component in COMMON_COMPONENTS)
    common_occurrences = sum(common_counts.values())
    identifier_count = len(components)
    common_ratio = (common_occurrences / identifier_count * 100) if identifier_count else 0

    if common_ratio >= 25:
        common_risk = "high_frequency_identifier_risk"
    elif common_ratio >= 15:
        common_risk = "needs_manual_review"
    else:
        common_risk = "low_signal"

    return {
        "file": str(path),
        "read_only": True,
        "line_count": len(lines),
        "blank_line_count": len(blank_lines),
        "blank_line_numbers": blank_lines[:50],
        "forbidden_declaration_count": len(forbidden),
        "forbidden_declarations": forbidden[:50],
        "identifier_component_count": identifier_count,
        "common_identifier_occurrences": common_occurrences,
        "common_identifier_ratio": round(common_ratio, 2),
        "common_identifier_risk": common_risk,
        "top_common_identifiers": [
            {"identifier": name, "count": count}
            for name, count in common_counts.most_common(30)
        ],
        "top_identifiers": [
            {"identifier": name, "count": count}
            for name, count in exact_counts.most_common(30)
        ],
        "recommendation": (
            "仅将结果用于源码选材和人工复核；不要通过批量改名、随机字符串或补写代码来降低指标。"
            "常见标识符不是抄袭结论，外部登记机构的数据库比对不由本地脚本保证。"
        ),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="只读审计源程序材料中的通用标识符")
    parser.add_argument("file", help="待审计文件，支持文本或 DOCX")
    parser.add_argument("--output", help="JSON 报告输出路径")
    args = parser.parse_args()

    report = build_report(Path(args.file).resolve())
    text = json.dumps(report, ensure_ascii=False, indent=2)
    if args.output:
        output = Path(args.output).resolve()
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(text + "\n", encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
