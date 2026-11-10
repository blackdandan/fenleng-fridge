#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Render a copyright-registration Word source to a readable PDF.

LibreOffice in some macOS headless environments cannot embed the available
CJK fonts. This renderer reads the editable DOCX in ``work/`` and embeds the
requested CJK TrueType font for headers and Chinese source-code characters.
ASCII source text uses Courier New (or the built-in Courier fallback), while
Chinese characters use the embedded CJK font at the same 9 pt size. Source
code page numbers are drawn as plain numerals at the top center of each page.
"""

from __future__ import annotations

import argparse
import re
import textwrap
from io import BytesIO
from pathlib import Path
from xml.sax.saxutils import escape

from docx import Document
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.cidfonts import UnicodeCIDFont
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Image, KeepTogether, Paragraph, SimpleDocTemplate, Spacer


FONT_NAME = "STSong-Light"
CODE_FONT = "Courier New"
CODE_FALLBACK_FONT = "Courier"
PAGE_WIDTH, PAGE_HEIGHT = A4
SOURCE_PAGE_COUNT = 60


def find_courier_new() -> Path | None:
    """Find a portable Courier New TTF when running on macOS/Windows hosts."""
    candidates = [
        Path("/System/Library/Fonts/Supplemental/Courier New.ttf"),
        Path("/Library/Fonts/Courier New.ttf"),
        Path("C:/Windows/Fonts/cour.ttf"),
    ]
    return next((path for path in candidates if path.exists()), None)


def register_fonts(font_path: Path | None) -> None:
    global CODE_FONT
    if font_path:
        pdfmetrics.registerFont(TTFont(FONT_NAME, str(font_path)))
    else:
        pdfmetrics.registerFont(UnicodeCIDFont(FONT_NAME))
    courier_new = find_courier_new()
    if courier_new:
        pdfmetrics.registerFont(TTFont(CODE_FONT, str(courier_new)))
    else:
        # ReportLab always ships the Type 1 Courier metric as a safe fallback.
        CODE_FONT = CODE_FALLBACK_FONT


def header_footer(canvas, document, header_text: str) -> None:
    canvas.saveState()
    canvas.setFont(FONT_NAME, 9)
    canvas.drawString(document.leftMargin, PAGE_HEIGHT - 15 * mm, header_text)
    canvas.setFont(FONT_NAME, 8)
    canvas.drawRightString(PAGE_WIDTH - document.rightMargin, 12 * mm, f"第 {document.page} 页")
    canvas.restoreState()


def image_for_paragraph(document: Document, paragraph, full_page: bool = False) -> list[Image]:
    rel_ids = re.findall(r'r:embed="([^"]+)"', paragraph._p.xml)
    images: list[Image] = []
    for rel_id in rel_ids:
        related = document.part.related_parts.get(rel_id)
        if related is None or not hasattr(related, "blob"):
            continue
        image = Image(BytesIO(related.blob))
        if full_page:
            max_width, max_height = 175 * mm, 240 * mm
        else:
            max_width, max_height = 165 * mm, 90 * mm
        scale = min(max_width / image.imageWidth, max_height / image.imageHeight, 1.0)
        image.drawWidth = image.imageWidth * scale
        image.drawHeight = image.imageHeight * scale
        image.hAlign = "CENTER"
        images.append(image)
    return images


def paragraph_style(name: str, size: float, leading: float, alignment=TA_LEFT, space_after: float = 4) -> ParagraphStyle:
    return ParagraphStyle(
        name,
        fontName=FONT_NAME,
        fontSize=size,
        leading=leading,
        alignment=alignment,
        spaceAfter=space_after,
        wordWrap="CJK",
    )


def render_standard_docx(docx_path: Path, output_path: Path, header_text: str) -> None:
    document = Document(str(docx_path))
    styles = {
        "body": paragraph_style("body", 10.5, 17),
        "heading1": paragraph_style("heading1", 16, 23, space_after=8),
        "heading2": paragraph_style("heading2", 13, 20, space_after=6),
        "heading3": paragraph_style("heading3", 11.5, 18, space_after=5),
        "caption": paragraph_style("caption", 9, 14, TA_CENTER, 5),
    }
    story = []
    for paragraph in document.paragraphs:
        text = paragraph.text.strip()
        images = image_for_paragraph(document, paragraph, full_page="签章页" in docx_path.name)
        if text:
            style = styles["body"]
            if paragraph.style.name.startswith("Heading 1"):
                style = styles["heading1"]
            elif paragraph.style.name.startswith("Heading 2"):
                style = styles["heading2"]
            elif paragraph.style.name.startswith("Heading 3"):
                style = styles["heading3"]
            elif text.startswith(("图", "表")):
                style = styles["caption"]
            # Preserve basic line breaks and avoid interpreting source text as XML.
            safe = escape(text).replace("\n", "<br/>")
            block = [Paragraph(safe, style)]
            if images:
                block.extend([Spacer(1, 2 * mm), *images, Spacer(1, 2 * mm)])
            story.append(KeepTogether(block) if images else block[0])
        elif images:
            story.extend([Spacer(1, 2 * mm), *images, Spacer(1, 2 * mm)])

    output_path.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(output_path),
        pagesize=A4,
        rightMargin=18 * mm,
        leftMargin=18 * mm,
        topMargin=24 * mm,
        bottomMargin=18 * mm,
        title=docx_path.stem,
    )
    doc.build(
        story,
        onFirstPage=lambda c, d: header_footer(c, d, header_text),
        onLaterPages=lambda c, d: header_footer(c, d, header_text),
    )


def render_source_docx(docx_path: Path, output_path: Path, header_text: str) -> None:
    """Render source paragraphs with the unified 60-page code layout.

    The source standard is A4, Courier New 9 pt (with the embedded CJK font as
    a per-character fallback), fixed 12.24 pt line height, 95-character
    wrapping and 57 rendered lines per page. The current source material must
    therefore produce exactly 60 pages; a different count fails.
    """
    document = Document(str(docx_path))
    lines = [paragraph.text for paragraph in document.paragraphs]
    import_lines = [line for line in lines if re.search(r"\bimport\b", line, re.IGNORECASE)]
    if import_lines:
        raise SystemExit(f"源代码材料仍包含 import 字样（{len(import_lines)} 行）；请先清理 Word 源文件。")
    blank_lines = [line for line in lines if not line.strip()]
    if blank_lines:
        raise SystemExit(f"源代码材料仍包含空白行（{len(blank_lines)} 行）；请补入真实源码行后再生成 PDF。")
    max_chars = 95
    lines_per_page = 57
    chunks: list[str] = []
    for line in lines:
        chunks.extend(textwrap.wrap(line, width=max_chars, replace_whitespace=False, drop_whitespace=False) or [""])
    page_count = (len(chunks) + lines_per_page - 1) // lines_per_page
    if page_count != SOURCE_PAGE_COUNT:
        raise SystemExit(f"源代码材料按统一排版应为 {SOURCE_PAGE_COUNT} 页，当前计算为 {page_count} 页。")

    canvas = __import__("reportlab.pdfgen.canvas", fromlist=["canvas"]).Canvas(str(output_path), pagesize=A4)
    canvas.setTitle(docx_path.stem)
    left, right = 14 * mm, 14 * mm
    top = PAGE_HEIGHT - 22 * mm
    font_size, line_height = 9.0, 12.24
    page_number = 1

    def start_page(number: int) -> None:
        canvas.setFont(FONT_NAME, 9)
        canvas.drawString(left, PAGE_HEIGHT - 12 * mm, header_text)
        canvas.setFont(FONT_NAME, 8)
        # 源代码页码固定在页面顶部居中；不得放到右下角。
        canvas.drawCentredString(PAGE_WIDTH / 2, PAGE_HEIGHT - 12 * mm, str(number))
        canvas.setFont(CODE_FONT, font_size)

    def draw_code_line(text: str, x: float, y: float) -> None:
        """Draw ASCII with Courier New and non-ASCII with the CJK fallback."""
        runs: list[tuple[str, str]] = []
        for char in text.rstrip():
            font = FONT_NAME if ord(char) > 127 else CODE_FONT
            if runs and runs[-1][0] == font:
                runs[-1] = (font, runs[-1][1] + char)
            else:
                runs.append((font, char))
        cursor = x
        for font, value in runs:
            canvas.setFont(font, font_size)
            canvas.drawString(cursor, y, value)
            cursor += pdfmetrics.stringWidth(value, font, font_size)

    for index, chunk in enumerate(chunks):
        slot = index % lines_per_page
        if slot == 0:
            if index:
                canvas.showPage()
                page_number += 1
            start_page(page_number)
        y = top - slot * line_height
        draw_code_line(chunk, left, y)
    canvas.save()


def main() -> None:
    parser = argparse.ArgumentParser(description="将 work 中的 Word 源文件渲染为可读 PDF")
    parser.add_argument("--docx", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--header-text", required=True)
    parser.add_argument("--font-path", type=Path, help="可嵌入中文字体的 TTF；未提供时使用 STSong CID 字体")
    args = parser.parse_args()
    register_fonts(args.font_path)
    if "源程序鉴别材料" in args.docx.name:
        render_source_docx(args.docx, args.output, args.header_text)
    else:
        render_standard_docx(args.docx, args.output, args.header_text)


if __name__ == "__main__":
    main()
