"""Rebuild Owner-review copyright materials from this repository's real App sources."""
from pathlib import Path
import hashlib
import importlib.util
import json
import subprocess
import textwrap
from collections import Counter
from docx import Document
from docx.shared import Pt, Inches
from docx.oxml.ns import qn

ROOT=Path(__file__).resolve().parents[4]
WORK=Path(__file__).resolve().parent
SKILL=ROOT/'.agents/skills/fl-software-copyright-registration/scripts'
NAME='冰箱库存管理'
VERSION='V0.1.0'
SUBJECT='杭州临安芬棱软件设计工作室（个体工商户）'

def load(name):
    spec=importlib.util.spec_from_file_location(name,SKILL/(name+'.py'))
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module

def source_material():
    extractor=load('extract_source_material')
    core=ROOT/'06-project/app/packages/core/lib/src'
    app=ROOT/'06-project/app/apps/fridge/lib'
    feature=ROOT/'06-project/app/packages/features/feature_inventory/lib/src'
    required=[core/x for x in ['inventory_rules.dart','inventory_state.dart','inventory_repository.dart','file_inventory_storage.dart']]
    required += [app/'application'/x for x in ['inventory_actions.dart','capture_flow.dart','photo_lifecycle.dart','notification_session.dart','review_items.dart','camera_coordinator.dart']]
    optional=sorted(feature.glob('*.dart')) + [p for folder in [app/'application',app/'infrastructure',app/'presentation'] for p in sorted(folder.glob('*.dart')) if p not in required and not any(word in p.name for word in ['identity','firebase','bootstrap','online_sessions','platform_','account_page','app_routes','deletion_storage'])]
    def lines(file):
        return [x for raw in file.read_text(encoding='utf8').splitlines() if (x:=extractor.clean_line(raw,False))]
    def size(file):
        return sum(len(textwrap.wrap(x,width=95,replace_whitespace=False,drop_whitespace=False) or ['']) for x in lines(file))
    target=3420-sum(size(x) for x in required)
    reviewer=load('review_source_material')
    frequencies=Counter(reviewer.semantic_lines([line for file in required+optional for line in lines(file)]))
    def cost(file):
        semantic=reviewer.semantic_lines(lines(file))
        return -sum(1/frequencies[line] for line in semantic)
    choices={0:(0,[])}
    for file in optional:
        n=size(file)
        file_cost=cost(file)
        for total,(score,selected) in list(choices.items()):
            new=total+n;candidate=score+file_cost
            if new<=target and (new not in choices or candidate<choices[new][0]):choices[new]=(candidate,selected+[file])
    if target not in choices:raise SystemExit(f'No complete-file selection fits 3420 rendered lines; available {sorted(choices)[-5:]} target {target}')
    selected=required+choices[target][1]
    output=[];manifest=[]
    for file in selected:
        # Run the installed extractor for each selected complete file; preserve real source order.
        extracted=extractor.collect_lines([file],False,None)
        output.extend(extracted[1:])
        manifest.append(dict(path=file.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(file.read_bytes()).hexdigest(),effectiveLines=len(extracted)-1,renderedLines=size(file)))
    extractor.write_docx(output,WORK/'源程序鉴别材料.docx',NAME,VERSION)
    extractor.write_text(output,WORK/'源程序鉴别材料.txt')
    all_files=[p for folder in [ROOT/'06-project/app/apps/fridge/lib',ROOT/'06-project/app/packages'] for p in folder.rglob('*.dart') if 'test' not in p.parts and 'generated' not in p.parts]
    volume=sum(len(lines(p)) for p in all_files)
    (WORK/'source-selection.json').write_text(json.dumps(dict(software=NAME,version=VERSION,sourceCommit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),materialEffectiveLines=len(output),materialRenderedLines=3420,applicationEffectiveLines=volume,selected=manifest,excluded=[dict(path=p.relative_to(ROOT).as_posix(),reason='本次仅选Android App完整业务模块；其余UI、鉴权、实体/配置或未选业务文件不进入鉴别材料') for p in all_files if p not in selected],thirdParty='不包含Flutter、官方SDK、第三方插件、小程序、官网或Shared Platform源码；未改名、混淆或补写材料代码。'),ensure_ascii=False,indent=2)+'\n')
    return volume

FUNCTIONS='''本软件面向家庭和个人用户，围绕冰箱内食材的拍照记录、分区存放、日常检查和处置追踪提供操作界面。用户首次进入时阅读用户协议与隐私政策，经同意后使用首页；未同意时不进入库存功能。首页按冷藏和冷冻区域展示食材照片、数量与状态，支持切换区域、查看库存、进入记录详情，空库存时提供明确的入库入口。
食材入库以完整页面承载相机预览和拍摄操作。Android首次请求相机权限前先展示用途说明，再触发系统权限请求。用户可拍摄照片，也可从相册选择图片；图片保存在本机，入库前可以补充食材名称、数量、所属区域和相关日期。编辑确认后，库存状态与本地记录一致更新，取消编辑时不产生伪造的入库记录。
用户可以在详情页修改记录、调整数量、改变分区或删除食材。软件针对已过期、即将到期和需要复查的食材生成检查内容，并提供用掉、丢弃、保留及撤销等处理路径；处理结果回写库存与历史记录，避免通知页面和实际库存长期不一致。历史界面按时间呈现实际操作，缺少记录时显示空状态。
提醒功能根据用户选择的检查计划与时间安排本地通知，申请通知权限时给出对应解释，并在权限关闭、授权拒绝或系统通知不可用时展示可理解的状态。进入检查页面后可逐项处理食材，处理结果可影响后续提醒。设置页面提供主题、语言、提醒、协议与隐私政策入口，同时承载反馈和账号相关操作。反馈内容可作为草稿保存，在配置真实平台服务并建立会话后提交，网络失败时保留用户内容并允许重试。
软件不强制用户注册账号密码。配置平台能力后，可建立游客会话并按渠道提供微信等身份接入；账号删除及隐私撤回有独立处理路径。关键产品事件使用枚举属性和官方SDK队列发送，避免把食材照片与自由文本作为分析属性。当前鉴别材料覆盖Android客户端业务实现，官网仅作为介绍与开发预览下载入口，小程序、iOS和鸿蒙的后续配置及人工验收不作为本版本已完成发行的证明。'''

def write_docs(volume):
    summary=f'''# 软件著作权申请填报信息摘要

## 基本信息
- 软件名称：{NAME}
- 版本号：{VERSION}

## 环境信息
- 开发的硬件环境：x86_64架构Windows开发计算机
- 运行的硬件环境：具备摄像头和本地存储的Android手机
- 开发该软件的操作系统：Windows 11
- 软件开发环境 / 开发工具：Flutter、Dart、Android SDK、JDK17、Gradle
- 该软件的运行平台 / 操作系统：Android 7.0及以上
- 软件运行支撑环境 / 支持软件：Android系统、Flutter运行时；联网功能使用Shared Platform

## 软件说明
- 源程序量：{volume} 行
- 开发目的：通过拍照记录、检查和处置追踪帮助个人管理冰箱食材。
- 面向领域 / 行业：家庭生活与个人食材库存管理

### 软件的主要功能
{FUNCTIONS}

### 软件的技术特点
采用Flutter分层客户端、本地持久化与照片生命周期管理；检查计划驱动库存处置和通知更新；平台会话与反馈通过官方SDK接入，事件以UUID去重。
'''
    (WORK/'application-info-summary.md').write_text(summary,encoding='utf8')
    (WORK/'core-function-description.md').write_text(f'# 软件主要功能描述\n\n软件：{NAME} {VERSION}\n\n'+FUNCTIONS,encoding='utf8')
    (WORK/'independent-development-statement.md').write_text(f'''# 独立开发及原创性声明

软件名称：{NAME}

版本：{VERSION}

声明主体：{SUBJECT}

本页供权利人核实后签署。声明在签署前不代表已经完成权属、开发方式或原创性事实确认。

本人／本单位在核实真实开发记录、合同及第三方许可后声明：申请登记部分系依法享有著作权的软件表达；提交的源程序与说明文档来自本项目真实实现；未使用无关代码、重复填充或虚构功能形成申请材料。对开源框架、第三方插件及外部Shared Platform服务，仅在合法许可和实际权利范围内使用，不将其独立源码或权利作为本软件原创内容申报。

本材料按当前Android客户端实现制作。iOS、鸿蒙及小程序后续配置与验收不构成本声明的已发行证明。若实际存在委托、合作、职务开发或权利转让，应按真实事实修改本声明并提交相应权属证明。

声明主体签字／盖章：________________

授权签署人：________________

签署日期：______年____月____日
''',encoding='utf8')
    (WORK/'third-party-disclosure.md').write_text('''# 第三方与开源情况（过程复核）
Flutter/Dart、camera、image_picker、firebase_auth、google_sign_in、权限插件及Fenleng官方SDK均是依赖，不作为本申请原创代码。Shared Platform是既有外部服务，不包含在鉴别材料。依赖精确版本与许可应对照06-project/app/pubspec.lock及各依赖LICENSE复核；本地原创性检查不代表外部查重通过。没有添加伪代码、标识符保密化或复制其他项目代码。
''',encoding='utf8')
    doc=Document();doc.core_properties.author=SUBJECT;doc.core_properties.title=f'{NAME} {VERSION} 软件说明书'
    style=doc.styles['Normal'];style.font.name='SimHei';style.font.size=Pt(10.5);style.element.get_or_add_rPr().get_or_add_rFonts().set(qn('w:eastAsia'),'黑体')
    doc.add_heading('软件说明书',0);doc.add_paragraph(f'{NAME} {VERSION}\nAndroid客户端\n编制日期：2026年11月13日')
    doc.add_heading('一、软件概述与运行条件',1)
    doc.add_paragraph('本软件为个人及家庭提供冰箱食材照片记录、分区库存、到期检查、处置历史和提醒设置。当前材料使用既有Android验收截图和真实源码，展示内容为测试食材数据。截图来自开发预览，不证明已完成应用市场发行或所有端真机验收。')
    doc.add_paragraph('Android 7.0及以上，具有摄像头、本地存储和通知能力。安装与设备架构相匹配的APK；当前开发预览包需允许对应来源安装。相机和通知可拒绝授权，软件应展示对应状态；联网反馈与游客会话需要平台运行配置。照片只保存在本机，删除应用或清理数据可能导致本地记录丢失。')
    doc.add_picture(str(ROOT/'02-engineering/evidence/android/home-figma-430-proof-20261113.png'),height=Inches(4.8))
    doc.add_paragraph('图：软件首页示例')
    sections=[
      ('二、首次进入与协议确认','consent-v04.png','首次进入阅读用户协议与隐私政策；同意后进入首页。拒绝时停留在入口。设置内可再次阅读政策，撤回同意后重新进入协议步骤。'),
      ('三、首页与冷藏冷冻分区','home-figma-430-proof-20261113.png','通过顶部区域切换查看冷藏与冷冻食材，照片卡片承载食材信息。点击食材进入详情，点击入库进入拍摄页面。无库存时显示引导入口，不虚构食材。'),
      ('四、相机权限与拍照入库','camera430-permission-explanation-20261113.png','点击拍照且未授权时，Android先显示相机用途解释，再请求系统权限。相机使用完整页面，支持拍照与相册入口。照片不会自动上传；权限拒绝时可使用可用的替代路径或前往系统设置。'),
      ('五、记录详情与编辑','detail430-top-20261113-fidelity-final.png','在详情查看照片和记录字段，编辑名称、数量、区域与日期并保存。删除前确认；取消编辑不提交新内容。图片与库存记录的持久化由应用统一处理。'),
      ('六、库存检查与撤销','review430-top-aligned-20261113.png','检查页面展示待处理食材。对条目选择用掉、丢弃或保留，结果更新库存和历史；支持撤销可恢复的操作。检查后的状态用于后续提醒判断。'),
      ('七、通知中心与处理结果','notifications430-pending-20261113.png','通知展示待检查内容，点击进入对应检查页面。已处理与待处理状态区分展示，处理后不继续显示为未完成。系统通知权限或计划不可用时，按实际状态显示说明。'),
      ('八、历史记录','history430-20261113-fidelity-final.png','历史记录反映实际发生的入库和处置。用户可按界面查看条目与时间，空记录使用空状态。历史与当前库存相互关联，撤销后应更新对应记录。'),
      ('九、设置与隐私入口','settings430-footer-final-20261113.png','设置提供语言、主题、提醒及账号相关选项。页面底部可打开用户协议、隐私政策和反馈，备案信息位于页脚。反馈支持草稿和失败重试；服务未配置时明确显示不可用，不报告虚假成功。'),
    ]
    images=[]
    for title,filename,text in sections:
        doc.add_page_break();doc.add_heading(title,1);doc.add_paragraph(text)
        file=ROOT/'02-engineering/evidence/android'/filename
        if not file.is_file():raise SystemExit(f'Missing real screenshot: {file}')
        doc.add_picture(str(file),height=Inches(6.25));doc.add_paragraph('图：'+title.split('、',1)[1])
        images.append(dict(path=file.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(file.read_bytes()).hexdigest()))
    doc.save(WORK/'software-manual.docx')
    (WORK/'screenshot-provenance.json').write_text(json.dumps(images,ensure_ascii=False,indent=2)+'\n')

if __name__=='__main__':
    write_docs(source_material())
