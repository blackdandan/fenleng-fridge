"""Numeric settings baseline; prototype-only rows are outside the comparison."""
import collections,hashlib,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'02-engineering/evidence/android'
REF=ROOT/'01-product/references/figma-qa'
def normalized(name):
 raw=Image.open(OUT/(name+'.png')).convert('RGB')
 body=raw.crop((0,136,1080,136+round(855*1080/430))).resize((430,855),Image.Resampling.LANCZOS)
 frame=Image.new('RGB',(430,900),'#f8f8f3');frame.paste(body,(0,45));frame.save(OUT/(name+'-normalized.png'));return frame

def near(rgb,target,delta=2):return max(abs(a-b) for a,b in zip(rgb,target))<=delta
def bounds(im,rect,predicate,connected=False):
 points={(x,y) for y in range(rect[1],min(rect[3],im.height)) for x in range(rect[0],rect[2]) if predicate(im.getpixel((x,y)))}
 if connected:
  largest=[]
  while points:
   seed=points.pop();group=[seed];stack=[seed]
   while stack:
    x,y=stack.pop()
    for n in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
     if n in points:points.remove(n);stack.append(n);group.append(n)
   if len(group)>len(largest):largest=group
  points=largest
 return [min(x for x,y in points),min(y for x,y in points),max(x for x,y in points)+1,max(y for x,y in points)+1] if points else None

def pair(a,b,rect,predicate,connected=False):
 first=bounds(a,rect,predicate,connected);second=bounds(b,rect,predicate,connected)
 return {'referenceBounds':first,'renderBounds':second,'maxBoundaryDelta':max(abs(x-y) for x,y in zip(first,second)) if first and second else None}
reference=Image.open(REF/'06-figma.png').convert('RGB');render=normalized('settings430-top-20261113')
r={'scope':'Figma2:172 default-settings cohort only; demo/reset/time-simulation sections intentionally excluded from production. Additional real account/display rows and footer are tested separately.','colors':{},'geometry':{},'icons':{},'typography':{}}
for name,point in [('page',(10,500)),('card',(30,200)),('numberField',(300,190)),('timeField',(297,400)),('primary',(40,530))]:
 a=reference.getpixel(point);b=render.getpixel(point);r['colors'][name]={'point':point,'reference':'#%02x%02x%02x'%a,'render':'#%02x%02x%02x'%b,'maxChannelDelta':max(abs(x-y) for x,y in zip(a,b))}
for name,rect,color in [('defaultsCard',(20,145,410,453),(255,254,250)),('coldInput',(285,165,380,220),(245,247,239)),('frozenInput',(285,230,380,291),(245,247,239)),('pantryInput',(285,300,380,365),(245,247,239)),('timeInput',(280,375,399,435),(245,247,239)),('save',(20,485,410,568),(69,101,76))]:
 r['geometry'][name]=pair(reference,render,rect,lambda c:near(c,color),True)
for name,rect in [('cold',(40,178,63,208)),('frozen',(40,248,63,278)),('pantry',(40,318,63,349))]:
 r['icons'][name]=pair(reference,render,rect,lambda c:max(c)<210 and c[1]>c[0]+3 and c[1]>c[2]+8)
r['icons']['clock']=pair(reference,render,(355,390,382,416),lambda c:max(c)<170)
r['icons']['back']=pair(reference,render,(24,61,45,90),lambda c:max(c)<110)
for name,rect,threshold in [('title',(55,60,150,100),120),('section',(22,123,205,151),210),('cold',(62,177,125,208),130),('frozen',(62,247,125,278),130),('pantry',(62,317,125,348),130),('reminderLabel',(40,382,140,411),130),('reminderRule',(40,405,260,430),210),('defaultsHint',(24,445,405,500),210),('coldValue',(310,180,350,210),150),('frozenValue',(310,250,350,280),150),('pantryValue',(310,320,350,350),150),('timeValue',(300,390,347,419),150)]:
 r['typography'][name]={**pair(reference,render,rect,lambda c:max(c)<threshold),'threshold':threshold}
r['result']={'flatColorsExact':all(v['maxChannelDelta']==0 for v in r['colors'].values()),
 'defaultBlocksWithin1px':all(v['maxBoundaryDelta'] is not None and v['maxBoundaryDelta']<=1 for v in r['geometry'].values()),
 'staticIconsWithin1px':all(v['maxBoundaryDelta'] is not None and v['maxBoundaryDelta']<=1 for v in r['icons'].values()),
 'allTypographyMeasured':all(v['referenceBounds'] and v['renderBounds'] for v in r['typography'].values())}
r['normalization']={'native':[1080,2400],'density':402,'statusCrop':136,'referenceSystemRegion':45,'output':[430,900],'surfaces':'largest4-connected component, per-channel tolerance2'}
r['apkSha256']=hashlib.sha256((ROOT/'06-project/app/apps/fridge/build/app/outputs/flutter-apk/app-debug.apk').read_bytes()).hexdigest()
(OUT/'settings-fidelity-sampling.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf-8')
print(json.dumps(r,indent=2))
if not all(r['result'].values()):raise SystemExit(1)
