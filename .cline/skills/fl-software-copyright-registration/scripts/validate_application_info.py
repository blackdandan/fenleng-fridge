#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Validate the Markdown application information summary."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


INLINE_FIELDS = {
    "软件名称": "software_name",
    "版本号": "version",
    "开发的硬件环境": "development_hardware_environment",
    "运行的硬件环境": "runtime_hardware_environment",
    "开发该软件的操作系统": "development_operating_system",
    "软件开发环境 / 开发工具": "development_tools",
    "该软件的运行平台 / 操作系统": "runtime_platform_operating_system",
    "软件运行支撑环境 / 支持软件": "runtime_supporting_software",
    "源程序量": "source_line_count",
    "开发目的": "development_purpose",
    "面向领域 / 行业": "target_domain_industry",
}

SECTION_FIELDS = {
    "软件的主要功能": "main_functions",
    "软件的技术特点": "technical_characteristics",
}

MAX_50_FIELDS = {
    "development_hardware_environment": "开发的硬件环境",
    "runtime_hardware_environment": "运行的硬件环境",
    "development_operating_system": "开发该软件的操作系统",
    "development_tools": "软件开发环境 / 开发工具",
    "runtime_platform_operating_system": "该软件的运行平台 / 操作系统",
    "runtime_supporting_software": "软件运行支撑环境 / 支持软件",
    "development_purpose": "开发目的",
    "target_domain_industry": "面向领域 / 行业",
}


def visible_length(value: str) -> int:
    """Count non-whitespace Unicode code points; punctuation counts."""
    return len(re.sub(r"\s+", "", value))


def is_placeholder(value: str) -> bool:
    return (
        not value.strip()
        or "{{" in value
        or "}}" in value
        or re.search(r"x{2,}", value, re.IGNORECASE) is not None
        or re.search(r"待(填写|确认|补充|提供)", value) is not None
    )


def parse_inline_fields(lines: list[str]) -> tuple[dict[str, str], list[str]]:
    values: dict[str, str] = {}
    errors: list[str] = []
    patterns = {
        label: re.compile(rf"^\s*-\s*{re.escape(label)}：\s*(.*?)\s*$")
        for label in INLINE_FIELDS
    }
    for line in lines:
        for label, pattern in patterns.items():
            match = pattern.match(line)
            if match:
                key = INLINE_FIELDS[label]
                if key in values:
                    errors.append(f"字段重复：{label}")
                value = match.group(1)
                if key == "source_line_count":
                    value = re.sub(r"\s*行\s*$", "", value)
                values[key] = value
                break
    return values, errors


def parse_sections(lines: list[str]) -> dict[str, str]:
    sections: dict[str, str] = {}
    current: str | None = None
    buffer: list[str] = []
    for line in lines:
        heading = re.match(r"^#{1,6}\s+(.+?)\s*$", line)
        if heading:
            if current is not None:
                sections[current] = "\n".join(buffer).strip()
            current = heading.group(1).strip()
            buffer = []
        elif current is not None:
            buffer.append(line)
    if current is not None:
        sections[current] = "\n".join(buffer).strip()
    return {SECTION_FIELDS[k]: sections.get(k, "") for k in SECTION_FIELDS}


def validate(path: Path) -> tuple[dict[str, object], list[str]]:
    text = path.read_text(encoding="utf-8-sig")
    lines = text.splitlines()
    values, errors = parse_inline_fields(lines)
    values.update(parse_sections(lines))

    for key, label in INLINE_FIELDS.items():
        field_key = label
        if field_key not in values:
            errors.append(f"缺少字段：{key}")
    for key, label in SECTION_FIELDS.items():
        if label not in values:
            errors.append(f"缺少章节：{key}")

    for key, label in MAX_50_FIELDS.items():
        value = str(values.get(key, ""))
        if is_placeholder(value):
            errors.append(f"字段未填写：{label}")
        elif visible_length(value) > 50:
            errors.append(f"字段超过 50 字：{label}（{visible_length(value)}）")

    software_name = str(values.get("software_name", ""))
    if is_placeholder(software_name):
        errors.append("字段未填写：软件名称")

    version = str(values.get("version", ""))
    if is_placeholder(version) or not re.fullmatch(r"V\d+(?:\.\d+)*", version):
        errors.append("版本号必须为类似 V1.0 的格式")

    source_line_count = str(values.get("source_line_count", ""))
    if not re.fullmatch(r"[1-9]\d*", source_line_count):
        errors.append("源程序量必须为正整数行数")

    main_functions = str(values.get("main_functions", ""))
    if is_placeholder(main_functions):
        errors.append("章节未填写：软件的主要功能")
    elif not 500 <= visible_length(main_functions) <= 1300:
        errors.append(
            f"软件的主要功能必须为 500–1300 字（当前 {visible_length(main_functions)}）"
        )

    technical = str(values.get("technical_characteristics", ""))
    if is_placeholder(technical):
        errors.append("章节未填写：软件的技术特点")
    elif visible_length(technical) > 100:
        errors.append(f"软件的技术特点超过 100 字（当前 {visible_length(technical)}）")

    report = {
        "input": str(path),
        "counts": {
            "main_functions": visible_length(main_functions),
            "technical_characteristics": visible_length(technical),
            "source_line_count": source_line_count,
            **{key: visible_length(str(values.get(key, ""))) for key in MAX_50_FIELDS},
        },
        "valid": not errors,
        "errors": errors,
    }
    return report, errors


def main() -> None:
    parser = argparse.ArgumentParser(description="校验软著申请填报信息摘要")
    parser.add_argument("--input", required=True, help="申请填报信息摘要 Markdown 文件")
    parser.add_argument("--report", help="可选 JSON 审计报告路径")
    args = parser.parse_args()
    path = Path(args.input).resolve()
    if not path.exists():
        raise SystemExit(f"找不到输入文件：{path}")
    report, errors = validate(path)
    if args.report:
        report_path = Path(args.report).resolve()
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if errors:
        for error in errors:
            print(f"✗ {error}")
        raise SystemExit(1)
    print(f"✓ 申请填报信息摘要校验通过：{path}")
    print(json.dumps(report["counts"], ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
