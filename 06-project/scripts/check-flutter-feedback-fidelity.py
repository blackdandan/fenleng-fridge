"""Compare production feedback components with the approved prototype's draft.

The 34.4px demo badge/control section is intentionally absent in production.
Native Noto CJK rasterization is recorded separately from geometry/color gates.
"""
import collections,hashlib,json
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'02-engineering/evidence/android'
ref=Image.open(ROOT/'01-product/references/figma-qa/12-figma.png').convert('RGB')
raw=Image.open(OUT/'feedback430-draft-final-20261113.png').convert('RGB')
ren=Image.new('RGB',(430,900),'#f8f8f3')
ren.paste(raw.crop((0,136,1080,136+round(855*1080/430))).resize((430,855),Image.Resampling.LANCZOS),(0,45))
ren.save(OUT/'feedback430-draft-final-normalized.png')

def near(c,target):return max(abs(a-b) for a,b in zip(c,target))<=2
def bounds(im,rect,predicate,connected=False):
 pts={(x,y) for y in range(rect[1],rect[3]) for x in range(rect[0],rect[2]) if predicate(im.getpixel((x,y)))}
 if connected:
  largest=[]
  while pts:
   seed=pts.pop();group=[seed];stack=[seed]
   while stack:
    x,y=stack.pop()
    for point in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
     if point in pts:pts.remove(point);stack.append(point);group.append(point)
   if len(group)>len(largest):largest=group
  pts=largest
 assert pts
 return [min(x for x,y in pts),min(y for x,y in pts),max(x for x,y in pts)+1,max(y for x,y in pts)+1]
def dimensions(b):return [b[2]-b[0],b[3]-b[1]]
result={'scope':'Draft components from Figma2:289; no whole-page equality or native accepted-receipt claim. Production omits the34.4px demo badge, demo controls and fake receipt; uses the shared original SVG back button.',
 'normalization':{'density':402,'statusCrop':136,'referenceSystemRegion':45,'demoBadgeRemoved':34.4},'geometry':{},'colors':{},'typography':{}}
for name,area,predicate in [
 ('textarea',(20,150,410,420),lambda c:near(c,(255,254,250))),
 ('submit',(20,420,410,530),lambda c:c[1]>c[0]+10 and c[1]>c[2]+10 and max(c)<200)]:
 a=bounds(ref,area,predicate,True);b=bounds(ren,area,predicate,True)
 expected=[a[0],a[1]-34.4,a[2],a[3]-34.4]
 result['geometry'][name]={'referenceBounds':a,'renderBounds':b,'referenceSize':dimensions(a),'renderSize':dimensions(b),
  'maxSizeDelta':max(abs(x-y) for x,y in zip(dimensions(a),dimensions(b))),
  'maxBoundaryDeltaAfterDemoRemoval':round(max(abs(x-y) for x,y in zip(expected,b)),3)}
for name,a,b in [('page',(10,550),(10,550)),('textarea',(30,250),(30,250)),('primary',(50,480),(50,445))]:
 ca=ref.getpixel(a);cb=ren.getpixel(b)
 result['colors'][name]={'reference':'#%02x%02x%02x'%ca,'render':'#%02x%02x%02x'%cb,'maxChannelDelta':max(abs(x-y) for x,y in zip(ca,cb))}
for name,ra,rb,threshold in [
 ('title',(60,65,130,100),(60,65,130,100),130),
 ('label',(24,160,160,195),(24,125,160,160),130),
 ('placeholder',(35,218,365,245),(35,183,365,212),180),
 ('privacy',(24,420,405,445),(24,385,405,412),210),
 ('submit',(175,475,255,503),(175,438,255,466),None)]:
 pred=(lambda c:min(c)>230) if threshold is None else (lambda c:max(c)<threshold)
 a=bounds(ref,ra,pred);b=bounds(ren,rb,pred)
 result['typography'][name]={'referenceInkBounds':a,'renderInkBounds':b,'referenceInkSize':dimensions(a),'renderInkSize':dimensions(b),
  'note':'Microsoft YaHei reference vs native Noto CJK; measured, not asserted pixel-identical'}
result['checks']={'threeFlatColorsExact':all(v['maxChannelDelta']==0 for v in result['colors'].values()),
 'componentSizesWithin2px':all(v['maxSizeDelta']<=2 for v in result['geometry'].values()),
 'componentPositionWithin2pxAfterDemoRemoval':all(v['maxBoundaryDeltaAfterDemoRemoval']<=2 for v in result['geometry'].values()),
 'allFiveTypographyGroupsMeasured':len(result['typography'])==5}
result['apkSha256']=hashlib.sha256((ROOT/'06-project/app/apps/fridge/build/app/outputs/flutter-apk/app-debug.apk').read_bytes()).hexdigest()
(OUT/'feedback-fidelity-sampling.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result,indent=2))
if not all(result['checks'].values()):raise SystemExit(1)
