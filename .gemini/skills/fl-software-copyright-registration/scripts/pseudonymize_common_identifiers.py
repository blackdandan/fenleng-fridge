#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
中文说明：对软著源程序材料执行经 Owner 明确授权的、可追溯的标识符保密化处理。

这不是查重工具，也不是原创性证明。脚本只替换选定的内部通用标识符，替换名应为
与柠檬扫描业务有关但不采用行业通用词的业务化名称；跳过注释、字符串、页眉和软件名称；
替换名与原名等长，以保持固定换行和页数。默认是预览，
必须显式提供 --apply 才会写出材料；映射只应保存在 work/，不得放入交付目录。
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Iterable


# 仅包含可由申请人确认的内部架构/实现命名。框架公开 API（如 Widget、Theme、
# BuildContext、State、Route 等）不在默认集合，避免改变外部 API 表达。
TARGET_REPLACEMENTS = {
    "bean": "Lemn",
    "domain": "Citrax",
    "manager": "LemonIO",
    "service": "LemonFx",
    "repository": "LemonVault",
    "controller": "CitrBinder",
    "entity": "CitraX",
    "dto": "Lix",
    "vo": "LX",
    "pojo": "Lumo",
    "usecase": "CitrRun",
    "use_case": "LemonAct",
    "notifier": "CitrPing",
    "viewmodel": "LemonPane",
    "config": "CitrIO",
    "util": "Citr",
    "helper": "LemAid",
    "factory": "LemMold",
    "builder": "LemCast",
    "adapter": "LemJoin",
    "dao": "Dex",
    "handler": "LemHook",
    "client": "CitrUX",
    "request": "CitrAsk",
    "response": "CitrEcho",
    "result": "CitrOp",
    "base": "LemX",
    "impl": "LemI",
    "common": "LemonX",
}

IDENTIFIER_RE = re.compile(r"\b[A-Za-z_][A-Za-z0-9_]*\b")


def read_text_lines(path: Path) -> list[str]:
    return path.read_text(encoding="utf-8", errors="ignore").splitlines()


def iter_identifiers(lines: Iterable[str]) -> Iterable[str]:
    for line in lines:
        for identifier in IDENTIFIER_RE.findall(line):
            yield identifier


def style_replacement(original: str, replacement: str) -> str:
    if original.isupper():
        return replacement.upper()
    if original.islower():
        return replacement.lower()
    if original[:1].isupper():
        return replacement[:1].upper() + replacement[1:]
    return replacement[:1].lower() + replacement[1:]


def choose_mapping(lines: list[str]) -> dict[str, str]:
    existing = {identifier.lower() for identifier in iter_identifiers(lines)}
    mapping: dict[str, str] = {}
    for source, target in TARGET_REPLACEMENTS.items():
        if source not in existing:
            continue
        if len(source) != len(target):
            raise ValueError(f"保密替换名必须等长：{source} -> {target}")
        if target in existing or target in mapping.values():
            raise ValueError(f"保密替换名与现有标识符冲突：{source} -> {target}")
        mapping[source] = target
    return mapping


def replace_code_line(line: str, mapping: dict[str, str], in_block_comment: bool) -> tuple[str, bool, int]:
    result: list[str] = []
    index = 0
    replaced = 0
    while index < len(line):
        if in_block_comment:
            end = line.find("*/", index)
            if end < 0:
                return "".join(result) + line[index:], True, replaced
            result.append(line[index:end + 2])
            index = end + 2
            in_block_comment = False
            continue
        if line.startswith("/*", index):
            end = line.find("*/", index + 2)
            if end < 0:
                return "".join(result) + line[index:], True, replaced
            result.append(line[index:end + 2])
            index = end + 2
            continue
        if line.startswith("//", index) or line.startswith("#", index):
            result.append(line[index:])
            break
        if line[index] in {"'", '"', "`"}:
            quote = line[index]
            start = index
            index += 1
            while index < len(line):
                if line[index] == "\\":
                    index += 2
                elif line[index] == quote:
                    index += 1
                    break
                else:
                    index += 1
            result.append(line[start:index])
            continue
        match = IDENTIFIER_RE.match(line, index)
        if not match:
            result.append(line[index])
            index += 1
            continue
        original = match.group(0)
        target = mapping.get(original.lower())
        if target is None:
            result.append(original)
        else:
            result.append(style_replacement(original, target))
            replaced += 1
        index = match.end()
    return "".join(result), in_block_comment, replaced


def transform_lines(lines: list[str], mapping: dict[str, str]) -> tuple[list[str], int]:
    transformed: list[str] = []
    in_block_comment = False
    replaced = 0
    for line in lines:
        output, in_block_comment, count = replace_code_line(line, mapping, in_block_comment)
        transformed.append(output)
        replaced += count
    return transformed, replaced


def transform_docx(input_path: Path, output_path: Path, mapping: dict[str, str]) -> int:
    try:
        from docx import Document
    except ImportError as exc:
        raise SystemExit("缺少 python-docx，无法读取 DOCX。") from exc
    document = Document(input_path)
    replaced = 0
    for paragraph in document.paragraphs:
        transformed, count = transform_lines([paragraph.text], mapping)
        if count:
            paragraph.text = transformed[0]
            replaced += count
    for table in document.tables:
        for row in table.rows:
            for cell in row.cells:
                for paragraph in cell.paragraphs:
                    transformed, count = transform_lines([paragraph.text], mapping)
                    if count:
                        paragraph.text = transformed[0]
                        replaced += count
    output_path.parent.mkdir(parents=True, exist_ok=True)
    document.save(output_path)
    return replaced


def main() -> None:
    parser = argparse.ArgumentParser(description="对选定内部标识符执行可追溯保密化处理")
    parser.add_argument("input", help="源程序材料 TXT 或 DOCX")
    parser.add_argument("--output", required=True, help="输出 TXT/DOCX，不得与 input 相同")
    parser.add_argument("--mapping-output", required=True, help="work/ 中的映射 JSON")
    parser.add_argument("--apply", action="store_true", help="明确授权后才实际写出保密化材料")
    args = parser.parse_args()

    input_path = Path(args.input).resolve()
    output_path = Path(args.output).resolve()
    mapping_path = Path(args.mapping_output).resolve()
    if input_path == output_path:
        raise SystemExit("为保留原始材料，input 与 output 不得相同。")
    if not input_path.exists():
        raise SystemExit(f"输入文件不存在：{input_path}")

    if input_path.suffix.lower() == ".docx":
        try:
            from docx import Document
        except ImportError as exc:
            raise SystemExit("缺少 python-docx，无法读取 DOCX。") from exc
        lines = [paragraph.text for paragraph in Document(input_path).paragraphs]
    else:
        lines = read_text_lines(input_path)
    mapping = choose_mapping(lines)
    preview_lines, preview_count = transform_lines(lines, mapping)
    report = {
        "purpose": "owner_authorized_confidentiality_pseudonymization",
        "read_only_preview": not args.apply,
        "input": str(input_path),
        "output": str(output_path),
        "mapping_output": str(mapping_path),
        "mapping": mapping,
        "mapping_count": len(mapping),
        "replacement_occurrences": preview_count,
        "same_length_mapping": all(len(source) == len(target) for source, target in mapping.items()),
        "scope": "exact internal identifiers only; comments, strings, headers, software name and public framework APIs are skipped",
        "warning": "This protects naming information only; it is not an external duplicate-check guarantee or a substitute for excluding secrets and third-party code.",
    }
    mapping_path.parent.mkdir(parents=True, exist_ok=True)
    mapping_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if not args.apply:
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return

    if input_path.suffix.lower() == ".docx":
        actual_count = transform_docx(input_path, output_path, mapping)
    else:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text("\n".join(preview_lines) + "\n", encoding="utf-8")
        actual_count = preview_count
    if actual_count != preview_count:
        raise SystemExit("实际替换次数与预览不一致，已拒绝交付。")
    report["read_only_preview"] = False
    report["applied_replacement_occurrences"] = actual_count
    mapping_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
