"""Render the editable manual with its page breaks and readable full-height screenshots."""
from pathlib import Path
import importlib.util
from io import BytesIO
from xml.sax.saxutils import escape
import re
from docx import Document
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Image, PageBreak, Spacer

ROOT=Path(__file__).resolve().parents[4]
WORK=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('renderer',ROOT/'.agents/skills/fl-software-copyright-registration/scripts/render_docx_pdf.py')
renderer=importlib.util.module_from_spec(spec);spec.loader.exec_module(renderer)
renderer.register_fonts(Path('C:/Windows/Fonts/simhei.ttf'))
document=Document(WORK/'software-manual.docx')
story=[]
for paragraph in document.paragraphs:
    if re.search(r'<w:br[^>]*w:type="page"',paragraph._p.xml):
        story.append(PageBreak());continue
    text=paragraph.text.strip()
    if text:
        heading=paragraph.style.name.startswith('Heading') or paragraph.style.name=='Title'
        style=renderer.paragraph_style('heading' if heading else 'body',14 if heading else 10.5,21 if heading else 16,space_after=5)
        style.keepWithNext=heading
        story.append(Paragraph(escape(text).replace('\n','<br/>'),style))
    for rel in re.findall(r'r:embed="([^"]+)"',paragraph._p.xml):
        image=Image(BytesIO(document.part.related_parts[rel].blob))
        # The cover image is deliberately shorter; subsequent UI pages use 170 mm.
        max_height=123*mm if not any(isinstance(x,PageBreak) for x in story) else 170*mm
        scale=min(165*mm/image.imageWidth,max_height/image.imageHeight)
        image.drawWidth=image.imageWidth*scale;image.drawHeight=image.imageHeight*scale
        image.hAlign='CENTER';story.extend([Spacer(1,2*mm),image,Spacer(1,2*mm)])
pdf=WORK.parent/'deliverables/v1/软件说明书.pdf'
doc=SimpleDocTemplate(str(pdf),pagesize=A4,leftMargin=18*mm,rightMargin=18*mm,topMargin=23*mm,bottomMargin=18*mm,title='冰箱库存管理 V0.1.0 软件说明书')
doc.build(story,onFirstPage=lambda c,d:renderer.header_footer(c,d,'冰箱库存管理 V0.1.0'),onLaterPages=lambda c,d:renderer.header_footer(c,d,'冰箱库存管理 V0.1.0'))
