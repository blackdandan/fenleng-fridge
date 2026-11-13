"""Finalize the review package without inventing registration facts or signatures."""
from pathlib import Path
import importlib.util
import json
import hashlib
from collections import Counter
import re
from docx import Document
from docx.shared import Pt

ROOT=Path(__file__).resolve().parents[4]
WORK=Path(__file__).resolve().parent
FINAL=WORK.parent/'deliverables/v1'
SKILL=ROOT/'.agents/skills/fl-software-copyright-registration/scripts'

def main():
    guide='''# 用户执行步骤

本包为“冰箱库存管理 V0.1.0”软著人工复核材料。当前名称沿用产品描述，不表示已确定登记名称；没有代你完成官方申报或签章。

## 1. 先确认事实
确认最终登记名称、著作权人及统一社会信用代码、实际开发方式及权属。主体资料参考现有运营者“杭州临安芬棱软件设计工作室（个体工商户）”，最终以证明材料为准。实际开发完成日期、首次发表状态及日期由你核实；2026年11月13日只是本材料编制日，不能自动当作完成或发表日期。

## 2. 复核源码和第三方边界
源代码PDF来自本仓库Android客户端完整业务文件，60页、每页57行，共3420个排版行。work/source-selection.json记录真实路径、逐文件哈希和源码提交0940eb1；没有混入Shared Platform、SDK或第三方库源码。源码总量按自有客户端Dart有效行统计，与排版行数不同。

机械单行重复检测为34.76%，自动标记high_risk，主要重复是try、override、通知调用与Flutter布局语句。已重新选择业务模块并复核来源；连续10行和20行语义片段没有重复。该复核不保证外部查重或原创性成立。请结合work/source-review.json、identifier-audit.json、人工复核说明和真实开发/权属资料决定是否进一步调整；高风险未确认前不要直接提交。

## 3. 核对说明书与签章
软件说明书使用真实Android验收截图和测试食材数据。小程序真实预览、iOS和鸿蒙验收由你另行处理，不把这些端写成已发行。确认说明书与申报版本一致；如更名或修改范围，同步全部文档页眉和摘要。声明PDF尚未签署，请核实内容后签字盖章，并准备主体证明及可能需要的权属合同。

## 4. 在官方系统填写并提交
按申请填报信息摘要.md逐项录入；根据系统当前要求上传源程序、说明书、主体证明和已签章材料。主要功能描述是辅助材料。使用中国版权保护中心正式网站进入登记系统，提交前重新核对其当期要求，保留受理回执。申请受理和登记成功不能由本材料包替代。

规则核验参考：国家版权局《计算机软件著作权登记办法》第九至十一条，程序和文档原则上前后各连续30页，不足60页提交全部；程序每页不少于50行，文档每页不少于30行（特定情况例外）。当前源程序使用60页×57行，说明书含界面图片。

权威来源：https://www.ncac.gov.cn/xxfb/flfg/bmgz/202410/t20241015_869486.html
官方办理入口：https://www.ccopyright.com.cn/
本次核验日期：2026年11月13日。
'''
    (FINAL/'用户执行步骤.md').write_text(guide,encoding='utf8')
    (WORK/'用户执行步骤.md').write_text(guide,encoding='utf8')
    doc=Document();doc.core_properties.author='杭州临安芬棱软件设计工作室（个体工商户）'
    for line in guide.splitlines():
        if line.startswith('#'):doc.add_heading(line.lstrip('# '),min(len(line)-len(line.lstrip('#')),3))
        elif line.strip():doc.add_paragraph(line)
    doc.styles['Normal'].font.size=Pt(10.5);doc.save(WORK/'用户执行步骤.docx')
    rows=['# 最终交付材料清单','',
      '状态：材料生成和排版检查完成，供Owner人工复核；不是已经可直接提交或已经登记。待办由Owner后续处理。','',
      '| 文件 | 用途与状态 |','| --- | --- |',
      '| 源代码.pdf | 60页真实客户端源码；机械重复率风险须复核 |',
      '| 软件说明书.pdf | Android真实界面与操作说明；9页 |',
      '| 软件主要功能描述.pdf | 功能说明辅助材料；1页 |',
      '| 独立开发及原创性声明.pdf | 1页；权利人核实后签字盖章 |',
      '| 申请填报信息摘要.md | 已完成字段长度校验，供官方系统录入 |',
      '| 用户执行步骤.md / .pdf | 事实确认、风险复核、签章和申报步骤 |','',
      '可编辑Word、源码筛选、开源边界、自动与人工审查报告保留在../../work；本目录只放最终PDF/Markdown。',
      '登记名称、权属、完成日期、首次发表、主体证明和签章尚待Owner确认；不得用材料编制日代替法律事实。','',
      '源码自动单行重复34.76%，high_risk保留；10/20行代码片段无重复且来源完整。人工复核未关闭前不要直接提交。']
    (FINAL/'最终交付材料清单.md').write_text('\n'.join(rows)+'\n',encoding='utf8')
    lines=(WORK/'源程序鉴别材料.txt').read_text(encoding='utf8').splitlines()
    sem=[x.strip() for x in lines if len(x.strip())>5 and not re.fullmatch(r'[{}()\[\],;\s]+',x.strip())]
    blocks={n:sum(v>1 for v in Counter(tuple(sem[i:i+n])for i in range(len(sem)-n+1)).values())for n in [5,10,20]}
    report={'status':'owner-review-required','sourceSelection':'complete real Android business files, hash-traceable',
      'automaticLineDuplicatePercent':34.76,'automaticVerdict':'high_risk','repeatedSemanticWindows':blocks,
      'originalityGuarantee':False,'ownerDeferred':'Explicit 2026-11-13 instruction assigns remaining confirmations and manual review to Owner; does not block material generation or delivery completion.'}
    (WORK/'manual-review.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    (WORK/'规则与事实复核.md').write_text('''# 规则与事实复核
2026-11-13核验国家版权局官方登记办法：https://www.ncac.gov.cn/xxfb/flfg/bmgz/202410/t20241015_869486.html 。本包准备技术材料，不作法律结论。
软件登记名称仍待Owner确认；版本来源pubspec为0.1.0，实际Android ARM64分包versionCode2001，登记版本写V0.1.0。编制日不代替实际完成日或首发日。运营主体来自MVP法律草案，Owner需与主体证明核对。无伪造签名、盖章、身份证明或开发合同。
已两次改选业务代码，所有文件完整且按真实哈希追溯。机械重复高风险来自常见单行结构；另查连续语义代码片段，10/20行无重复。不得把本地检查当作外部查重或权属保证。Owner已明确其余待办自行处理，风险作为后续人工复核留存，不宣称源码已通过正式原创性审查。
''',encoding='utf8')

if __name__=='__main__':main()
