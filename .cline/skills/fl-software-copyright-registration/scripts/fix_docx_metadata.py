#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
中文说明：修复软著材料 DOCX 中的软件名称、版本号、页眉文本和页码设置；源代码可将纯数字 PAGE 字段放在页眉顶部居中，并清除 import 语句。
"""

from __future__ import annotations

import argparse
import re
import shutil
from pathlib import Path


def replace_text_in_docx(
    path: Path,
    output: Path,
    replacements: list[tuple[str, str]],
    header_text: str | None,
    page_number_top_center: bool = False,
    remove_import_lines: bool = False,
) -> None:
    try:
        from docx import Document
        from docx.oxml import OxmlElement
        from docx.oxml.ns import qn
        from docx.enum.text import WD_ALIGN_PARAGRAPH
        from lxml import etree
    except ImportError as exc:
        raise SystemExit("缺少 python-docx 或 lxml，无法修复 DOCX。") from exc

    output.parent.mkdir(parents=True, exist_ok=True)
    if path.resolve() != output.resolve():
        shutil.copy2(path, output)

    doc = Document(output)

    def replace_in_paragraph(paragraph) -> None:
        full_text = paragraph.text
        if not full_text:
            return
        new_text = full_text
        for old, new in replacements:
            new_text = new_text.replace(old, new)
        if new_text != full_text and paragraph.runs:
            paragraph.runs[0].text = new_text
            for run in paragraph.runs[1:]:
                run.text = ""

    def remove_import_statement(paragraph) -> None:
        """Blank import statements while preserving source line/page slots."""
        if remove_import_lines and paragraph.text and re.match(r"^\s*import\b", paragraph.text, re.IGNORECASE):
            paragraph.text = ""

    def set_header_font(paragraph) -> None:
        for run in paragraph.runs:
            run.font.name = "Heiti SC"
            run._element.get_or_add_rPr().get_or_add_rFonts().set(qn("w:eastAsia"), "Heiti SC")

    def set_top_center_page_header(paragraph, text: str) -> None:
        """Keep the software name at left and place a PAGE field at top center."""
        paragraph.text = text
        paragraph.alignment = WD_ALIGN_PARAGRAPH.LEFT
        ppr = paragraph._p.get_or_add_pPr()
        tabs = ppr.find(qn("w:tabs"))
        if tabs is None:
            tabs = OxmlElement("w:tabs")
            ppr.append(tabs)
        for child in list(tabs):
            tabs.remove(child)
        center_tab = OxmlElement("w:tab")
        center_tab.set(qn("w:val"), "center")
        center_tab.set(qn("w:pos"), "4536")
        tabs.append(center_tab)

        tab_run = paragraph.add_run()
        tab_run._r.append(OxmlElement("w:tab"))
        begin_run = paragraph.add_run()
        begin = OxmlElement("w:fldChar")
        begin.set(qn("w:fldCharType"), "begin")
        instr = OxmlElement("w:instrText")
        instr.set(qn("xml:space"), "preserve")
        instr.text = " PAGE "
        separate = OxmlElement("w:fldChar")
        separate.set(qn("w:fldCharType"), "separate")
        placeholder = OxmlElement("w:t")
        placeholder.text = "1"
        end = OxmlElement("w:fldChar")
        end.set(qn("w:fldCharType"), "end")
        begin_run._r.extend([begin, instr, separate, placeholder, end])
        set_header_font(paragraph)

    for paragraph in doc.paragraphs:
        replace_in_paragraph(paragraph)
        remove_import_statement(paragraph)
    for table in doc.tables:
        for row in table.rows:
            for cell in row.cells:
                for paragraph in cell.paragraphs:
                    replace_in_paragraph(paragraph)
                    remove_import_statement(paragraph)

    for section in doc.sections:
        if header_text:
            header = section.header
            paragraph = header.paragraphs[0] if header.paragraphs else header.add_paragraph()
            if page_number_top_center:
                set_top_center_page_header(paragraph, header_text)
            else:
                paragraph.text = header_text
                set_header_font(paragraph)
        for header in [section.header, section.first_page_header, section.even_page_header]:
            for paragraph in header.paragraphs:
                replace_in_paragraph(paragraph)
                set_header_font(paragraph)
        sectPr = section._sectPr
        pg_num = sectPr.find(qn("w:pgNumType"))
        if pg_num is None:
            pg_num = etree.SubElement(sectPr, qn("w:pgNumType"))
        pg_num.set(qn("w:fmt"), "decimal")

    doc.save(output)


def main() -> None:
    parser = argparse.ArgumentParser(description="修复软著 DOCX 元数据")
    parser.add_argument("file", help="输入 DOCX")
    parser.add_argument("--output", required=True, help="输出 DOCX")
    parser.add_argument("--replace", action="append", default=[], help="替换规则，格式 old=new，可重复传入")
    parser.add_argument("--software-name", default="", help="软件名称")
    parser.add_argument("--version", default="", help="版本号")
    parser.add_argument("--header-text", default="", help="页眉完整文本；传入后优先于软件名称和版本号拼接")
    parser.add_argument("--page-number-top-center", action="store_true", help="在页眉顶部居中插入纯数字 PAGE 页码字段")
    parser.add_argument("--remove-import-lines", action="store_true", help="清除源代码中的 import 语句；生成前必须补入真实源码行，不得保留空行")
    args = parser.parse_args()

    replacements: list[tuple[str, str]] = []
    for item in args.replace:
        if "=" not in item:
            raise SystemExit(f"无效替换规则: {item}")
        old, new = item.split("=", 1)
        replacements.append((old, new))

    header_text = args.header_text.strip() or " ".join(part for part in [args.software_name, args.version] if part).strip() or None
    replace_text_in_docx(
        Path(args.file).resolve(),
        Path(args.output).resolve(),
        replacements,
        header_text,
        args.page_number_top_center,
        args.remove_import_lines,
    )
    print(f"output={Path(args.output).resolve()}")


if __name__ == "__main__":
    main()
