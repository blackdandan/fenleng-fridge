#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
中文说明：从真实项目源码中提取软著源程序鉴别材料。

本脚本只执行确定性提取、清洗和 DOCX 生成，不负责判断哪些源码具有原创性。
源码选择策略应先由 Agent 或用户通过 include/exclude 参数明确给出。
"""

from __future__ import annotations

import argparse
import os
import re
from pathlib import Path
from typing import Iterable


DEFAULT_EXTENSIONS = {
    ".java", ".kt", ".kts", ".js", ".jsx", ".ts", ".tsx", ".py", ".go",
    ".rs", ".cs", ".cpp", ".c", ".h", ".hpp", ".swift", ".dart", ".php"
}

DEFAULT_EXCLUDE_PARTS = {
    ".git", "node_modules", "dist", "build", "out", "target", ".gradle",
    ".idea", ".vscode", "test", "tests", "__tests__", "generated",
    "vendor", "third_party", "third-party"
}


def should_skip(path: Path, exclude_parts: set[str]) -> bool:
    lowered = {part.lower() for part in path.parts}
    return bool(lowered & exclude_parts)


def clean_line(line: str, keep_imports: bool) -> str:
    stripped = line.rstrip()
    if not stripped.strip():
        return ""
    if stripped.lstrip().startswith("//"):
        return ""
    if stripped.lstrip().startswith("#") and not stripped.lstrip().startswith("#!"):
        return ""
    if not keep_imports and re.match(r"^\s*(import|package|using|namespace)\b", stripped):
        return ""
    return stripped


def iter_source_files(roots: Iterable[Path], extensions: set[str], exclude_parts: set[str]) -> Iterable[Path]:
    for root in roots:
        if root.is_file() and root.suffix.lower() in extensions:
            yield root
            continue
        if not root.exists():
            continue
        for current, dirs, files in os.walk(root):
            current_path = Path(current)
            dirs[:] = [d for d in dirs if not should_skip(current_path / d, exclude_parts)]
            for name in files:
                path = current_path / name
                if path.suffix.lower() in extensions and not should_skip(path, exclude_parts):
                    yield path


def collect_lines(files: Iterable[Path], keep_imports: bool, max_lines: int | None) -> list[str]:
    lines: list[str] = []
    for path in files:
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        file_lines: list[str] = []
        for raw in text.splitlines():
            cleaned = clean_line(raw, keep_imports)
            if cleaned:
                file_lines.append(cleaned)
        if file_lines:
            lines.append(f"// Source file: {path}")
            lines.extend(file_lines)
        if max_lines and len(lines) >= max_lines:
            return lines[:max_lines]
    return lines


def write_text(lines: list[str], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_docx(lines: list[str], output: Path, software_name: str, version: str) -> None:
    try:
        from docx import Document
        from docx.shared import Pt
        from docx.oxml.ns import qn
    except ImportError as exc:
        raise SystemExit("缺少 python-docx，请先安装后再生成 DOCX。") from exc

    output.parent.mkdir(parents=True, exist_ok=True)
    doc = Document()
    style = doc.styles["Normal"]
    style.font.name = "Courier New"
    style.font.size = Pt(9)
    style.element.get_or_add_rPr().get_or_add_rFonts().set(qn("w:eastAsia"), "宋体")

    header_text = f"{software_name} {version}".strip()
    for section in doc.sections:
        header = section.header
        para = header.paragraphs[0] if header.paragraphs else header.add_paragraph()
        para.text = header_text

    for idx, line in enumerate(lines):
        para = doc.paragraphs[0] if idx == 0 and doc.paragraphs else doc.add_paragraph()
        para.text = line
        para.paragraph_format.space_before = Pt(0)
        para.paragraph_format.space_after = Pt(0)

    doc.save(output)


def main() -> None:
    parser = argparse.ArgumentParser(description="提取软著源程序鉴别材料")
    parser.add_argument("--source-root", action="append", required=True, help="源码根目录，可重复传入")
    parser.add_argument("--output", required=True, help="输出文件，支持 .txt/.md/.docx")
    parser.add_argument("--software-name", default="", help="软件名称，用于 DOCX 页眉")
    parser.add_argument("--version", default="", help="版本号，用于 DOCX 页眉")
    parser.add_argument("--extension", action="append", help="允许的源码扩展名，例如 .kt，可重复传入")
    parser.add_argument("--exclude-part", action="append", help="排除的路径片段，可重复传入")
    parser.add_argument("--keep-imports", action="store_true", help="已废弃：软著源代码材料禁止保留 import/package/using 等声明")
    parser.add_argument("--max-lines", type=int, default=None, help="最多输出行数")
    args = parser.parse_args()

    roots = [Path(p).resolve() for p in args.source_root]
    extensions = set(args.extension or DEFAULT_EXTENSIONS)
    exclude_parts = {p.lower() for p in (args.exclude_part or [])} | DEFAULT_EXCLUDE_PARTS
    output = Path(args.output).resolve()

    files = list(iter_source_files(roots, extensions, exclude_parts))
    if args.keep_imports:
        raise SystemExit("源代码材料禁止保留 import/package/using/namespace 声明；请不要使用 --keep-imports。")
    lines = collect_lines(files, False, args.max_lines)
    if any(re.search(r"\bimport\b", line, re.IGNORECASE) for line in lines):
        raise SystemExit("源代码材料提取结果仍包含 import 字样，已拒绝生成材料。")
    if any(not line.strip() for line in lines):
        raise SystemExit("源代码材料提取结果包含空白行，已拒绝生成 DOCX。")

    if output.suffix.lower() == ".docx":
        write_docx(lines, output, args.software_name, args.version)
    else:
        write_text(lines, output)

    print(f"source_files={len(files)}")
    print(f"output_lines={len(lines)}")
    print(f"output={output}")


if __name__ == "__main__":
    main()
