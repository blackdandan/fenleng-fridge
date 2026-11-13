"""Syntax/project wiring checks only. This is not a Swift compiler or iOS runtime."""
import hashlib,json,re
from importlib.metadata import version
from pathlib import Path
from tree_sitter import Language,Parser
import tree_sitter_swift
ROOT=Path(__file__).resolve().parents[2]
IOS=ROOT/'06-project/app/apps/fridge/ios'
parser=Parser(Language(tree_sitter_swift.language()))
names=['AppDelegate.swift','ReminderPlan.swift','ReminderStore.swift','ReminderScheduler.swift','ReminderBridge.swift']
paths=[IOS/'Runner'/name for name in names]+[IOS/'RunnerTests/RunnerTests.swift']
results=[]
for path in paths:
 data=path.read_bytes();tree=parser.parse(data);errors=[]
 def visit(node):
  if node.type=='ERROR' or node.is_missing:errors.append({'type':node.type,'start':list(node.start_point),'end':list(node.end_point)})
  for child in node.children:visit(child)
 visit(tree.root_node)
 results.append({'path':str(path.relative_to(ROOT)).replace('\\','/'),'lines':len(data.splitlines()),'sha256':hashlib.sha256(data).hexdigest(),'syntaxErrors':errors})
project=(IOS/'Runner.xcodeproj/project.pbxproj').read_text()
objects=re.findall(r'^\s*([A-F0-9]{24}) /\*.*?\*/ =',project,re.M)
assert len(objects)==len(set(objects)),'Duplicate Xcode object identifiers'
for name in names:
 assert project.count('/* '+name+' in Sources */')==2,(name,'build reference or source phase missing')
 assert project.count('path = '+name+';')==1,(name,'file reference missing')
 assert project.count('/* '+name+' */')==3,(name,'Runner group reference missing')
assert all(r['lines']<=300 for r in results)
report={'scope':'Tree-sitter syntax and Xcode source membership only; not typechecking, linking, XCTest or device evidence',
 'tools':{'tree-sitter':version('tree-sitter'),'tree-sitter-swift':version('tree-sitter-swift')},
 'sources':results,'sourceMembership':'pass','nativeTestsDefined':len(re.findall(r'func test\w+\(',paths[-1].read_text())),
 'xcodeBuild':'not-run-Windows-no-Xcode','xctest':'not-run-Windows-no-Xcode','device':'not-run',
 'syntax':'pass' if all(not r['syntaxErrors'] for r in results) else 'fail'}
out=ROOT/'02-engineering/evidence/ios';out.mkdir(parents=True,exist_ok=True)
(out/'notification-source-results.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
assert report['syntax']=='pass'
