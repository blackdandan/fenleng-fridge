"""Measure the detail/history cohort against the approved Figma PNGs."""
import collections,hashlib,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'02-engineering/evidence/android'
REF=ROOT/'01-product/references/figma-qa'
def bounds(im,rect,predicate):
 pts=[(x,y) for y in range(rect[1],min(rect[3],im.height)) for x in range(rect[0],min(rect[2],im.width)) if predicate(im.getpixel((x,y)))]
 return [min(x for x,y in pts),min(y for x,y in pts),max(x for x,y in pts)+1,max(y for x,y in pts)+1] if pts else None
def near(rgb,color,delta=2):return max(abs(a-b) for a,b in zip(rgb,color))<=delta
def pair(a,b,rect,predicate):
 x=bounds(a,rect,predicate);y=bounds(b,rect,predicate)
 return {'referenceBounds':x,'renderBounds':y,'maxBoundaryDelta':max(abs(v-w) for v,w in zip(x,y)) if x and y else None}
def surface_pair(a,b,rect,color):
 def component(im):
  points={(x,y) for y in range(rect[1],rect[3]) for x in range(rect[0],rect[2]) if near(im.getpixel((x,y)),color)}
  largest=[]
  while points:
   seed=points.pop();group=[seed];stack=[seed]
   while stack:
    x,y=stack.pop()
    for q in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
     if q in points:points.remove(q);group.append(q);stack.append(q)
   if len(group)>len(largest):largest=group
  return [min(x for x,y in largest),min(y for x,y in largest),max(x for x,y in largest)+1,max(y for x,y in largest)+1] if largest else None
 x=component(a);y=component(b)
 return {'referenceBounds':x,'renderBounds':y,'maxBoundaryDelta':max(abs(v-w) for v,w in zip(x,y)) if x and y else None,'method':'largest 4-connected near-RGB surface; excludes isolated glyph resampling overshoot'}
def resized(name):return Image.open(OUT/(name+'.png')).convert('RGB').resize((430,956),Image.Resampling.LANCZOS)
def dialog_aligned(name,reference):
 im=resized(name)
 box=bounds(im,(12,80,418,900),lambda c:near(c,(248,248,243),1))
 target=bounds(reference,(12,30,418,760),lambda c:near(c,(248,248,243),1))
 aligned=Image.new('RGB',reference.size,'#a4aea0');aligned.paste(im,(0,target[1]-box[1]))
 aligned.save(OUT/(name+'-fidelity.png'))
 return aligned,{'referencePaintBounds':target,'nativePaintBounds':box,'translationY':target[1]-box[1],
 'referenceSize':[target[2]-target[0],target[3]-target[1]],'nativeSize':[box[2]-box[0],box[3]-box[1]]}
ref=Image.open(REF/'05-figma.png').convert('RGB');bottom=Image.open(REF/'19-figma.png').convert('RGB')
top,dialog=dialog_aligned('detail430-top-20261113',ref)
low,bottom_dialog=dialog_aligned('detail430-bottom-20261113',bottom)
im=Image.open(OUT/'history430-20261113.png').convert('RGB')
body=im.crop((0,136,1080,136+round(855*1080/430))).resize((430,855),Image.Resampling.LANCZOS)
history=Image.new('RGB',(430,900),'#f8f8f3');history.paste(body,(0,45));history.save(OUT/'history430-20261113-fidelity.png')
rh=Image.open(REF/'08-figma.png').convert('RGB')
report={'scope':'Detail2:149 and42:95 local dialog coordinates; history2:227 Android430 top viewport. No claim of whole-screen pixel identity.','dialog':dialog,'bottomDialog':bottom_dialog,'colors':{},'detailGeometry':{},'historyGeometry':{},'typography':{},'icons':{}}
for role,a,b,point in [('dialog',ref,top,(80,320)),('field',ref,top,(65,373)),('close',ref,top,(370,99)),('handle',ref,top,(211,67)),('save',bottom,low,(60,630)),('historyPage',rh,history,(10,400)),('tabs',rh,history,(34,151)),('selectedTab',rh,history,(240,150)),('historyCard',rh,history,(100,244))]:
 x=a.getpixel(point);y=b.getpixel(point)
 report['colors'][role]={'point':point,'reference':'#%02x%02x%02x'%x,'render':'#%02x%02x%02x'%y,'maxChannelDelta':max(abs(v-w) for v,w in zip(x,y))}
for name,rect,color in [('addedField',(35,355,395,415),(255,254,250)),('zoneField',(35,435,215,500),(255,254,250)),('intervalField',(215,435,395,500),(255,254,250)),('nextField',(35,520,395,585),(255,254,250)),('closeCircle',(340,80,395,140),(236,239,230)),('handle',(190,60,240,75),(214,221,204))]:
 report['detailGeometry'][name]=surface_pair(ref,top,rect,color)
report['detailGeometry']['saveBottom']=pair(bottom,low,(35,590,395,675),lambda c:near(c,(69,101,76)))
report['detailGeometry']['photoGreenInk']=pair(ref,top,(150,150,280,280),lambda c:c[1]>c[0]*1.2 and c[1]>c[2]*1.1 and max(c)<220)
for name,rect,color in [('tabs',(20,120,410,180),(236,239,230)),('selectedTab',(200,125,410,180),(255,254,250)),('recordCard',(20,230,410,325),(255,254,250))]:
 report['historyGeometry'][name]=pair(rh,history,rect,lambda c:near(c,color))
for name,a,b,rect,threshold in [('detailTitle',ref,top,(36,90,130,135),120),('photoLink',ref,top,(170,282,260,307),210),('addedLabel',ref,top,(36,330,130,356),210),('addedValue',ref,top,(45,370,220,402),160),('zoneLabel',ref,top,(36,416,150,442),210),('intervalLabel',ref,top,(217,416,370,442),210),('nextLabel',ref,top,(36,498,170,526),210),('editorHint',ref,top,(36,581,395,626),210),('lastOrganized',ref,top,(36,627,200,650),210),('deleteAction',bottom,low,(155,677,285,708),210),('historyTitle',rh,history,(54,60,160,100),120),('historyHint',rh,history,(25,196,405,222),210),('historyMetadata',rh,history,(103,257,260,301),210),('restoreAction',rh,history,(350,260,400,300),170)]:
 report['typography'][name]={**pair(a,b,rect,lambda c:max(c)<threshold),'maxChannelThreshold':threshold}
for name,rect in [('calendarAdded',(358,370,385,398)),('calendarNext',(358,538,385,563)),('dropdown',(180,460,208,477))]:
 report['icons'][name]=pair(ref,top,rect,lambda c:max(c)<190)
report['result']={'flatColorsExact':all(v['maxChannelDelta']==0 for v in report['colors'].values()),
 'detailFieldsWithin1px':all(v['maxBoundaryDelta'] is not None and v['maxBoundaryDelta']<=1 for k,v in report['detailGeometry'].items() if k in ['addedField','zoneField','intervalField','nextField']),
 'historyBlocksWithin1px':all(v['maxBoundaryDelta'] is not None and v['maxBoundaryDelta']<=1 for v in report['historyGeometry'].values()),
 'saveBottomWithin1px':report['detailGeometry']['saveBottom']['maxBoundaryDelta']<=1,
 'allStaticIconBoundsWithin1px':all(v['maxBoundaryDelta'] is not None and v['maxBoundaryDelta']<=1 for v in report['icons'].values()),
 'allVisibleTypographyMeasured':all(v['renderBounds'] and v['referenceBounds'] for v in report['typography'].values())}
report['notes']=['Detail controls have at least44px touch height versus43px source fields. Field deltas are reported explicitly, not hidden as exact fidelity.','Dialog is centered in the native safe viewport; local dialog alignment removes only the viewport-height difference.','Native font glyphs can differ from Microsoft YaHei; typography values are observations, not a pixel-identity gate.']
report['apkSha256']=hashlib.sha256((ROOT/'06-project/app/apps/fridge/build/app/outputs/flutter-apk/app-debug.apk').read_bytes()).hexdigest()
(OUT/'detail-history-fidelity-sampling.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
if not all(report['result'].values()):raise SystemExit(1)
