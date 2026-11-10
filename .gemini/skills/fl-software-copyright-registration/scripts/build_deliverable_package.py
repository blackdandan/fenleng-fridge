#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
中文说明：构建软著最终交付材料包。

本脚本只执行确定性文件转换、复制、命名和清单生成：
- 从 work 目录读取已确认的 Markdown/TXT/DOCX 文件。
- 将 Markdown/TXT 转换为 DOCX。
- 可选调用 LibreOffice/soffice 将 DOCX 转成 PDF。
- 将最终文件写入调用方指定的当前轮次 deliverables/vN 目录，并生成 最终交付材料清单.md。

使用 `--pdf-only` 时，DOCX 只写入 work/ 作为可编辑源，deliverables/vN 只输出 PDF/Markdown；默认通过 `render_docx_pdf.py` 嵌入中文 TTF 字体生成 PDF，补正说明、第三方/开源说明和自检报告默认不复制。

脚本不判断法律结论，不确认事实，不把 high_risk 材料改写为可提交状态。
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


DEFAULT_DOCUMENTS = {
    "application-info-summary": "申请填报信息摘要",
    "software-manual": "软件说明书",
    "core-function-description": "软件主要功能描述",
    "independent-development-statement": "独立开发及原创性声明",
    "third-party-disclosure": "第三方/开源代码情况说明",
    "correction-response": "补正说明",
}

INPUT_ALIASES = {
    "application-info-summary": ["申请填报信息摘要", "application-info-summary"],
    "software-manual": ["软件说明书", "software-manual"],
    "core-function-description": ["软件主要功能描述", "core-function-description"],
    "independent-development-statement": ["独立开发及原创性声明", "软件独立开发及原创性声明", "independent-development-statement"],
    "third-party-disclosure": ["第三方代码与开源组件说明", "第三方/开源代码情况说明", "third-party-disclosure"],
    "correction-response": ["correction-response", "补正说明"],
}


@dataclass
class Deliverable:
    name: str
    path: Path
    status: str
    note: str


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def add_markdown_line(doc, line: str) -> None:
    stripped = line.strip().lstrip("\ufeff")
    if not stripped:
        doc.add_paragraph("")
        return
    placeholder = parse_screenshot_placeholder(stripped)
    if placeholder:
        add_screenshot_placeholder(doc, placeholder[0], placeholder[1])
        return
    if stripped.startswith("#"):
        level = min(len(stripped) - len(stripped.lstrip("#")), 4)
        text = stripped[level:].strip()
        doc.add_heading(text, level=level)
        return
    if stripped.startswith("- "):
        doc.add_paragraph(stripped[2:].strip(), style="List Bullet")
        return
    if stripped.startswith("|") and stripped.endswith("|"):
        doc.add_paragraph(stripped)
        return
    doc.add_paragraph(line)


def parse_screenshot_placeholder(line: str) -> tuple[str, str] | None:
    if line.startswith("{{screenshot_placeholder:") and line.endswith("}}") and "|" in line:
        inner = line[len("{{screenshot_placeholder:") : -2]
        title, instruction = inner.split("|", 1)
        return title.strip(), instruction.strip()
    if line.startswith("截图：") and any(token in line for token in ["待补充", "待插入", "截图占位"]):
        return "截图待补充", line.removeprefix("截图：").strip()
    return None


def add_screenshot_placeholder(doc, title: str, instruction: str) -> None:
    table = doc.add_table(rows=2, cols=1)
    table.style = "Table Grid"
    title_cell = table.rows[0].cells[0]
    body_cell = table.rows[1].cells[0]
    title_para = title_cell.paragraphs[0]
    title_run = title_para.add_run(f"截图占位：{title}")
    title_run.bold = True
    body_para = body_cell.paragraphs[0]
    body_para.add_run(instruction)
    body_cell.add_paragraph("请用户在此处插入对应界面截图，插入后删除本占位说明。")


def write_docx_from_text(input_path: Path, output_path: Path, title: str, header_text: str) -> None:
    try:
        from docx import Document
        from docx.shared import Pt
        from docx.oxml.ns import qn
    except ImportError as exc:
        raise SystemExit("缺少 python-docx，无法生成 DOCX。") from exc

    output_path.parent.mkdir(parents=True, exist_ok=True)
    doc = Document()
    style = doc.styles["Normal"]
    style.font.name = "Songti SC"
    style.font.size = Pt(10.5)
    style.element.get_or_add_rPr().get_or_add_rFonts().set(qn("w:eastAsia"), "Songti SC")

    if header_text:
        for section in doc.sections:
            paragraph = section.header.paragraphs[0] if section.header.paragraphs else section.header.add_paragraph()
            paragraph.text = header_text
            for run in paragraph.runs:
                run.font.name = "Heiti SC"
                run._element.get_or_add_rPr().get_or_add_rFonts().set(qn("w:eastAsia"), "Heiti SC")

    if title:
        doc.add_heading(title, level=1)
    content_lines = read_text(input_path).splitlines()
    # The Markdown guide already carries its own H1. Do not duplicate it when
    # the helper is asked to add the document title for a standalone source.
    if content_lines and title and content_lines[0].strip().lstrip("# ") == title:
        content_lines = content_lines[1:]
    for line in content_lines:
        add_markdown_line(doc, line)
    doc.save(output_path)


def convert_docx_to_pdf(docx_path: Path, output_dir: Path, soffice: str) -> Path | None:
    exe = shutil.which(soffice) or shutil.which("soffice") or shutil.which("libreoffice")
    if not exe:
        return None
    subprocess.run(
        [exe, "--headless", "--convert-to", "pdf", "--outdir", str(output_dir), str(docx_path)],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    pdf_path = output_dir / f"{docx_path.stem}.pdf"
    return pdf_path if pdf_path.exists() else None


def verify_embedded_cjk_font(pdf_path: Path) -> None:
    """Fail closed when a generated PDF has no embedded TrueType font."""
    try:
        try:
            from pypdf import PdfReader
        except ImportError:
            from PyPDF2 import PdfReader
        reader = PdfReader(str(pdf_path))
        for page in reader.pages:
            fonts = page.get("/Resources", {}).get("/Font")
            if not fonts:
                continue
            for reference in fonts.values():
                font = reference.get_object()
                descriptor = font.get("/FontDescriptor")
                if descriptor and descriptor.get_object().get("/FontFile2"):
                    return
        raise SystemExit(f"PDF 未检测到嵌入式中文 TrueType 字体：{pdf_path}")
    except ModuleNotFoundError as exc:
        raise SystemExit("缺少 pypdf/PyPDF2，无法验证 PDF 中文字体资源；请使用工作区依赖运行构建。") from exc


def verify_pdf_page_count(pdf_path: Path, expected: int) -> None:
    try:
        try:
            from pypdf import PdfReader
        except ImportError:
            from PyPDF2 import PdfReader
        actual = len(PdfReader(str(pdf_path)).pages)
    except ModuleNotFoundError as exc:
        raise SystemExit("缺少 pypdf/PyPDF2，无法验证 PDF 页数；请使用工作区依赖运行构建。") from exc
    if actual != expected:
        raise SystemExit(f"PDF 页数不符合统一规范：要求 {expected} 页，实际 {actual} 页：{pdf_path}")


def find_input(work_dir: Path, stem: str) -> Path | None:
    for candidate in INPUT_ALIASES.get(stem, [stem]):
        for suffix in [".docx", ".md", ".txt"]:
            path = work_dir / f"{candidate}{suffix}"
            if path.exists():
                return path
    # Current work files may include the software name/version in their stem.
    for candidate in INPUT_ALIASES.get(stem, [stem]):
        matches = sorted(
            path
            for suffix in [".docx", ".md", ".txt"]
            for path in work_dir.glob(f"{candidate}-*{suffix}")
        )
        if matches:
            return matches[0]
    return None


def find_source_material(work_dir: Path, version: str) -> Path | None:
    exact_stems = ["source-material", "源程序鉴别材料"]
    if version:
        exact_stems.extend([f"source-material-{version}", f"源程序鉴别材料-{version}"])
    for stem in exact_stems:
        found = find_input(work_dir, stem)
        if found:
            return found
    candidates: list[Path] = []
    for suffix in [".docx", ".md", ".txt"]:
        candidates.extend(sorted(work_dir.glob(f"source-material*{suffix}")))
        candidates.extend(sorted(work_dir.glob(f"源程序鉴别材料*{suffix}")))
    return candidates[0] if candidates else None


def collect_screenshot_placeholders(path: Path) -> list[tuple[str, str]]:
    if path.suffix.lower() not in {".md", ".txt"}:
        return []
    placeholders: list[tuple[str, str]] = []
    for line in read_text(path).splitlines():
        parsed = parse_screenshot_placeholder(line.strip().lstrip("\ufeff"))
        if parsed:
            placeholders.append(parsed)
    return placeholders


def validate_application_info_summary(input_path: Path, work_dir: Path) -> None:
    """Fail closed before copying the Markdown application summary."""
    if input_path.suffix.lower() != ".md":
        raise SystemExit("申请填报信息摘要必须使用 Markdown 源文件，不得使用 DOCX/PDF。")
    validator = Path(__file__).with_name("validate_application_info.py")
    report = work_dir / "申请填报信息摘要审计报告.json"
    subprocess.run(
        [sys.executable, str(validator), "--input", str(input_path), "--report", str(report)],
        check=True,
    )


def copy_or_convert_document(
    input_path: Path,
    output_stem: str,
    title: str,
    deliverables_dir: Path,
    header_text: str,
    make_pdf: bool,
    soffice: str,
) -> list[Deliverable]:
    results: list[Deliverable] = []
    docx_output = deliverables_dir / f"{output_stem}.docx"

    if input_path.suffix.lower() == ".docx":
        docx_output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(input_path, docx_output)
    else:
        write_docx_from_text(input_path, docx_output, title, header_text)

    results.append(Deliverable(title, docx_output, "needs_review", "提交前人工复核"))
    if make_pdf:
        pdf_path = convert_docx_to_pdf(docx_output, deliverables_dir, soffice)
        if pdf_path:
            results.append(Deliverable(title, pdf_path, "needs_review", "由 DOCX 转换生成"))
    return results


def convert_work_source_to_pdf(
    input_path: Path,
    output_stem: str,
    title: str,
    work_dir: Path,
    deliverables_dir: Path,
    header_text: str,
    soffice: str,
    pdf_renderer: str,
    font_path: str,
) -> list[Deliverable]:
    """Convert an editable Word source in work/ into a PDF-only deliverable."""
    if input_path.suffix.lower() == ".docx":
        source_docx = input_path
    else:
        source_docx = work_dir / f"{input_path.stem}.docx"
        write_docx_from_text(input_path, source_docx, title, header_text)
    pdf_path = deliverables_dir / f"{output_stem}.pdf"
    if pdf_renderer == "reportlab":
        if not font_path:
            raise SystemExit("--pdf-only 必须提供可嵌入中文字体：请传入 --font-path NotoSansCJKsc-VF.ttf。")
        renderer = Path(__file__).with_name("render_docx_pdf.py")
        subprocess.run(
            [
                sys.executable,
                str(renderer),
                "--docx",
                str(source_docx),
                "--output",
                str(pdf_path),
                "--header-text",
                header_text,
                "--font-path",
                font_path,
            ],
            check=True,
        )
        generated_pdf = pdf_path
        verify_embedded_cjk_font(generated_pdf)
        if output_stem == "源代码":
            verify_pdf_page_count(generated_pdf, 60)
    else:
        generated_pdf = convert_docx_to_pdf(source_docx, deliverables_dir, soffice)
    if not generated_pdf:
        raise SystemExit(f"无法生成 PDF：{source_docx}")
    if generated_pdf != pdf_path:
        generated_pdf.replace(pdf_path)
    return [Deliverable(title, pdf_path, "needs_review", "由 work/ 中的可编辑 Word 源文件转换生成")]


def copy_directory_if_exists(source: Path, target: Path) -> list[Deliverable]:
    if not source.exists() or not source.is_dir():
        return []
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(source, target)
    return [Deliverable(source.name, target, "needs_review", "目录附件，提交前按官方入口要求上传")]


def write_manifest(
    path: Path,
    deliverables: list[Deliverable],
    work_dir: Path,
    screenshot_placeholders: list[tuple[str, str]],
) -> None:
    lines = [
        "# 软件著作权最终交付材料清单",
        "",
        f"- 过程文件目录：{work_dir}",
        f"- 最终交付目录：{path.parent}",
        "",
        "## 文件清单",
        "",
        "| 材料 | 文件 | 状态 | 说明 |",
        "| :--- | :--- | :--- | :--- |",
    ]
    for item in deliverables:
        lines.append(f"| {item.name} | {item.path.name} | {item.status} | {item.note} |")
    lines.extend(
        [
            "",
            "## 提醒",
            "",
            "- 本清单不替代官方系统填报。",
            "- 签字、盖章、主体证明和上传格式仍需人工复核。",
            "- 若自检报告标记 high_risk，源程序鉴别材料不得直接提交。",
        ]
    )
    if screenshot_placeholders:
        lines.extend(
            [
                "",
                "## 截图补充项",
                "",
                "软件说明书 Word 中已预留以下截图位置，用户应在对应占位处插入截图后再提交。",
                "",
                "| Word 文档位置 | 需要补充的截图 |",
                "| :--- | :--- |",
            ]
        )
        for title, instruction in screenshot_placeholders:
            lines.append(f"| 截图占位：{title} | {instruction} |")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_user_action_guide(
    path: Path,
    software_name: str,
    version: str,
    deliverables_dir: Path,
    deliverables: list[Deliverable],
    screenshot_placeholders: list[tuple[str, str]],
) -> None:
    version_name = deliverables_dir.name if re.fullmatch(r"v\d+", deliverables_dir.name, re.IGNORECASE) else "vN"
    delivery_prefix = f"deliverables/{version_name}"
    lines = [
        "# 软件著作权申请用户执行步骤",
        "",
        "## 1. 确认软件基本信息",
        "",
        "| 事项 | 当前值 | 用户动作 |",
        "| :--- | :--- | :--- |",
        f"| 软件全称 | {software_name or '待用户确认'} | 确认是否作为最终申请名称 |",
        "| 软件简称 | 待用户确认 | 确认是否填写；无简称则留空 |",
        f"| 版本号 | {version or '待用户确认'} | 确认版本格式是否与软件实际发布一致 |",
        "| 申请主体 | 待用户确认 | 确认主体名称与证照、公章一致 |",
        "| 开发完成日期 | 待用户确认 | 填写真实完成日期 |",
        "| 首次发表状态/日期 | 待用户确认 | 按真实情况填写 |",
        "| 开发方式 | 待用户确认 | 确认独立、委托、合作、改编或受让等情况 |",
        "",
        "## 2. 填写申请填报信息摘要",
        "",
        f"在 `work/申请填报信息摘要.md` 中按模板填写，运行 `python scripts/validate_application_info.py --input work/申请填报信息摘要.md --report work/申请填报信息摘要审计报告.json`；校验通过后才使用 `{delivery_prefix}/申请填报信息摘要.md`。",
        "开发硬件环境、运行硬件环境、开发操作系统、开发环境/工具、运行平台/操作系统、运行支撑环境/支持软件、开发目的和面向领域/行业均不超过 50 字；源程序量为正整数；主要功能为 500–1300 字；技术特点不超过 100 字。",
        "",
        "## 3. 准备图标或应用标识",
        "",
        "若官方系统、地方入口或材料模板要求上传软件图标，请按该入口的最新规格准备。无法确认最新规格时，不得把历史经验当作最终规则。",
        "",
        "| 文件 | 建议规格 | 用途 |",
        "| :--- | :--- | :--- |",
        "| 应用图标原图 | 1024 x 1024 像素，PNG，透明或纯色背景 | 用于生成各尺寸图标 |",
        "| 常用上传图标 | 512 x 512 像素，PNG/JPG | 用于入口要求较小尺寸时提交 |",
        "| 软件启动页或主界面标识 | PNG/JPG，清晰可辨 | 用于说明书截图或辅助说明 |",
        "",
        "## 4. 补充软件说明书截图",
        "",
        "在 `work/` 中打开软件说明书 Word 源文件，在文档中的“截图占位”位置插入对应截图。插入截图后删除占位说明文字，再重新生成当前轮次 PDF。",
        "",
    ]
    if screenshot_placeholders:
        lines.extend(["| Word 文档位置 | 需要补充的截图 |", "| :--- | :--- |"])
        for title, instruction in screenshot_placeholders:
            lines.append(f"| 截图占位：{title} | {instruction} |")
    else:
        lines.append("- 当前未检测到截图占位；仍需人工复核说明书截图是否完整、真实、清晰。")
    lines.extend(
        [
            "",
            "截图要求：",
            "",
            "- 截图应来自真实运行的软件。",
            "- 截图内容应覆盖说明书中的核心操作步骤和功能结果。",
            "- 截图中的软件名称、版本、界面文字不应与申请信息冲突。",
            "- 不要使用与申请软件无关的演示图、设计稿或竞品截图。",
            "",
            "## 5. 复核和签章声明材料",
            "",
            "| 文件 | 用户动作 |",
            "| :--- | :--- |",
            f"| `work/` 中的独立开发及原创性声明 Word | 核对开发事实，确认无误后按要求手写、签字或盖章；提交 `{delivery_prefix}/独立开发及原创性声明.pdf` |",
            f"| `deliverables/{version_name}/签章页.pdf` | 按通知要求手抄划线内容并完成签章后提交 |",
            "| `work/` 中的补正说明、第三方/开源说明 | 仅作过程记录；除非官方入口明确要求，不放入当前交付目录 |",
            "",
            "## 6. 复核源程序鉴别材料",
            "",
            "打开 `work/` 中的源程序鉴别材料 Word，检查页眉、源码范围和页面完整性；确认后使用当前轮次的 `源代码.pdf`。",
            "",
            "- 是否来自真实项目源码。",
            "- 源代码 PDF 必须恰好 60 页（渲染后 3420 行真实源码）；统一为 A4、英文/数字 Courier New 9 磅、中文字符同字号嵌入式中文回退字体、固定行高 12.24 磅、每页 57 行、95 字符换行，页码为页面最上方居中的纯数字；源代码中不得出现 import 语句或空白行。",
            "- 是否优先选取一个端的核心业务代码。",
            "- 是否避开无关后台、测试代码、第三方依赖、重复填充和调试残留。",
            "- 若 `work/` 中自检报告标记 high_risk，不要直接提交，先重新选择源码范围或人工确认风险。",
            "",
            "## 7. 准备官方系统填报和上传",
            "",
            "| 事项 | 参考材料 |",
            "| :--- | :--- |",
            f"| 软件名称、简称、版本号 | `{delivery_prefix}/申请填报信息摘要.md` |",
            "| 申请主体信息 | 主体证照、公章信息、官方系统账户 |",
            f"| 开发完成日期、发表状态 | `{delivery_prefix}/申请填报信息摘要.md` 和用户确认事实 |",
            f"| 软件说明书上传 | `{delivery_prefix}/软件说明书.pdf` |",
            f"| 源程序鉴别材料上传 | `{delivery_prefix}/源代码.pdf`（提交前按官方要求复核） |",
            f"| 主要功能描述上传 | `{delivery_prefix}/软件主要功能描述.pdf` |",
            f"| 独立开发声明上传 | `{delivery_prefix}/独立开发及原创性声明.pdf` |",
            f"| 签章页上传 | `{delivery_prefix}/签章页.pdf`（完成手抄和签章后） |",
            "",
            "## 8. 最终提交前检查",
            "",
            "- 软件名称、简称、版本号在所有文件中一致。",
            "- 说明书截图已补齐，且截图来自真实软件。",
            "- 源程序材料自检没有未处理的 high_risk。",
            "- 需要签字或盖章的文件已完成签章。",
            "- 主体证明、委托/合作/受让等证明材料已按真实情况准备。",
            "- 官方系统要求的图标、截图、格式、页数和签章要求已按最新入口复核。",
            "",
            "## 9. 本次最终材料",
            "",
            f"以 `{delivery_prefix}/最终交付材料清单.md` 为准，提交前只使用 `{delivery_prefix}/` 中的最终文件。`work/` 目录中的 Word、补正说明、第三方/开源说明和自检报告不作为本轮交付件。下一轮补正必须新建递增的 vN 目录。",
        ]
    )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="构建软著最终交付材料包")
    parser.add_argument("--work-dir", required=True, help="过程文件目录")
    parser.add_argument("--deliverables-dir", required=True, help="最终交付目录")
    parser.add_argument("--software-name", default="", help="软件名称，用于页眉")
    parser.add_argument("--version", default="", help="版本号，用于页眉和源程序文件名")
    parser.add_argument("--to-pdf", action="store_true", help="尝试调用 LibreOffice/soffice 生成 PDF")
    parser.add_argument("--pdf-only", action="store_true", help="只在 deliverables/vN 输出 PDF/Markdown；Word 源文件保留在 work/")
    parser.add_argument("--pdf-renderer", choices=["reportlab", "soffice"], default="reportlab", help="PDF-only 模式的渲染器；reportlab 使用嵌入式中文字体")
    parser.add_argument("--font-path", default="", help="reportlab 渲染器使用的可嵌入中文 TTF 字体路径")
    parser.add_argument("--include-process-docs", action="store_true", help="显式包含补正说明和第三方/开源说明；默认仅保留在 work/")
    parser.add_argument("--include-self-check", action="store_true", help="显式复制自检报告；默认仅保留在 work/")
    parser.add_argument("--header-text", default="", help="页眉完整文本；传入后优先于软件名称和版本号拼接")
    parser.add_argument("--soffice", default="soffice", help="LibreOffice/soffice 可执行文件名或路径")
    args = parser.parse_args()

    work_dir = Path(args.work_dir).resolve()
    deliverables_dir = Path(args.deliverables_dir).resolve()
    if not re.fullmatch(r"v\d+", deliverables_dir.name, re.IGNORECASE):
        raise SystemExit("--deliverables-dir 必须指向 deliverables/vN/ 当前轮次目录，不能直接写入 deliverables 根目录。")
    deliverables_dir.mkdir(parents=True, exist_ok=True)
    header_text = args.header_text.strip() or " ".join(part for part in [args.software_name, args.version] if part).strip()

    deliverables: list[Deliverable] = []
    screenshot_placeholders: list[tuple[str, str]] = []
    for stem, title in DEFAULT_DOCUMENTS.items():
        source = find_input(work_dir, stem)
        if not source:
            continue
        if stem == "application-info-summary":
            validate_application_info_summary(source, work_dir)
        if args.pdf_only and stem in {"correction-response", "third-party-disclosure"} and not args.include_process_docs:
            continue
        if stem == "software-manual":
            screenshot_placeholders.extend(collect_screenshot_placeholders(source))
        if args.pdf_only and stem == "application-info-summary":
            if source.suffix.lower() != ".md":
                raise SystemExit("--pdf-only 模式要求申请填报信息摘要使用 Markdown 源文件。")
            target = deliverables_dir / "申请填报信息摘要.md"
            shutil.copy2(source, target)
            deliverables.append(Deliverable(title, target, "needs_review", "Markdown 填报参考，不生成 DOCX/PDF"))
        elif args.pdf_only:
            deliverables.extend(
                convert_work_source_to_pdf(
                    source,
                    DEFAULT_DOCUMENTS[stem],
                    title,
                    work_dir,
                    deliverables_dir,
                    header_text,
                    args.soffice,
                    args.pdf_renderer,
                    args.font_path,
                )
            )
        else:
            deliverables.extend(
                copy_or_convert_document(
                    source,
                    DEFAULT_DOCUMENTS[stem],
                    title,
                    deliverables_dir,
                    header_text,
                    args.to_pdf,
                    args.soffice,
                )
            )

    source = find_source_material(work_dir, args.version)
    if source:
        if args.pdf_only:
            deliverables.extend(
                convert_work_source_to_pdf(
                    source,
                    "源代码",
                    "源程序鉴别材料",
                    work_dir,
                    deliverables_dir,
                    header_text,
                    args.soffice,
                    args.pdf_renderer,
                    args.font_path,
                )
            )
        else:
            output_stem = f"source-material-{args.version}" if args.version else "source-material"
            deliverables.extend(
                copy_or_convert_document(
                    source,
                    output_stem,
                    "源程序鉴别材料",
                    deliverables_dir,
                    header_text,
                    args.to_pdf,
                    args.soffice,
                )
            )

    if not args.pdf_only:
        for directory_name in ["screenshots", "applicant-proof"]:
            deliverables.extend(copy_directory_if_exists(work_dir / directory_name, deliverables_dir / directory_name))

    self_check = work_dir / "submission-self-check.md"
    if self_check.exists() and (not args.pdf_only or args.include_self_check):
        target = deliverables_dir / "submission-self-check.md"
        shutil.copy2(self_check, target)
        deliverables.append(Deliverable("提交前自检报告", target, "needs_review", "如含 high_risk 必须先处理"))

    guide_md_path = deliverables_dir / "用户执行步骤.md"
    write_user_action_guide(guide_md_path, args.software_name, args.version, deliverables_dir, deliverables, screenshot_placeholders)
    deliverables.append(Deliverable("用户执行步骤文档", guide_md_path, "needs_review", "按步骤完成确认、补图、签章和提交"))
    if args.pdf_only:
        guide_docx_path = work_dir / "用户执行步骤-工作源.docx"
        write_docx_from_text(guide_md_path, guide_docx_path, "软件著作权申请用户执行步骤", header_text)
        guide_pdf_path = deliverables_dir / "用户执行步骤.pdf"
        if args.pdf_renderer == "reportlab":
            if not args.font_path:
                raise SystemExit("--pdf-only 必须提供可嵌入中文字体：请传入 --font-path NotoSansCJKsc-VF.ttf。")
            renderer = Path(__file__).with_name("render_docx_pdf.py")
            subprocess.run(
                [
                    sys.executable,
                    str(renderer),
                    "--docx",
                    str(guide_docx_path),
                    "--output",
                    str(guide_pdf_path),
                    "--header-text",
                    header_text,
                    "--font-path",
                    args.font_path,
                ],
                check=True,
            )
            generated_guide_pdf = guide_pdf_path
            verify_embedded_cjk_font(generated_guide_pdf)
        else:
            generated_guide_pdf = convert_docx_to_pdf(guide_docx_path, deliverables_dir, args.soffice)
            if generated_guide_pdf and generated_guide_pdf != guide_pdf_path:
                generated_guide_pdf.replace(guide_pdf_path)
        if generated_guide_pdf:
            deliverables.append(Deliverable("用户执行步骤文档", guide_pdf_path, "needs_review", "由 work/ 中的可编辑 Word 源文件转换生成"))
    else:
        guide_docx_path = deliverables_dir / "用户执行步骤.docx"
        write_docx_from_text(guide_md_path, guide_docx_path, "软件著作权申请用户执行步骤", header_text)
        deliverables.append(Deliverable("用户执行步骤文档", guide_docx_path, "needs_review", "按步骤完成确认、补图、签章和提交"))
    manifest_path = deliverables_dir / "最终交付材料清单.md"
    write_manifest(manifest_path, deliverables, work_dir, screenshot_placeholders)
    print(f"deliverables={len(deliverables)}")
    print(f"manifest={manifest_path}")


if __name__ == "__main__":
    main()
