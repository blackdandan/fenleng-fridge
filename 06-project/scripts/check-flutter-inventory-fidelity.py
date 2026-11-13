"""Region/review blocks only; compare normalized native frames to approved nodes."""
import hashlib,json,re,xml.etree.ElementTree as ET
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'02-engineering/evidence/android'
def normalized(name):
 im=Image.open(OUT/(name+'.png')).convert('RGB')
 body=im.crop((0,136,1080,136+round(855*1080/430))).resize((430,855),Image.Resampling.LANCZOS)
 frame=Image.new('RGB',(430,900),'#f8f8f3');frame.paste(body,(0,45));frame.save(OUT/(name+'-normalized.png'));return frame
zone=normalized('zone430-aligned-20261113');review=normalized('review430-top-aligned-20261113')
rz=Image.open(ROOT/'01-product/references/figma-qa/02-figma.png').convert('RGB')
rr=Image.open(ROOT/'01-product/references/figma-qa/04-figma.png').convert('RGB')
report={'colors':{},'zoneGeometry':{},'reviewGeometry':{},'icons':{},'typography':{}}
def bounds(im,rect,predicate):
 points=[(x,y) for y in range(rect[1],rect[3]) for x in range(rect[0],rect[2]) if predicate(im.getpixel((x,y)))]
 return [min(x for x,y in points),min(y for x,y in points),max(x for x,y in points)+1,max(y for x,y in points)+1] if points else None
def pair(a,b,rect,predicate):
 first=bounds(a,rect,predicate);second=bounds(b,rect,predicate)
 return {'referenceBounds':first,'renderBounds':second,'maxBoundaryDelta':max(abs(x-y) for x,y in zip(first,second)) if first and second else None}
for role,a,b,point in [('page',rz,zone,(10,850)),('primaryAction',rz,zone,(30,171)),('secondaryAction',rz,zone,(230,171)),
 ('reviewSurface',rr,review,(30,220)),('fullChoice',rr,review,(60,285)),('halfChoice',rr,review,(140,285)),('smallChoice',rr,review,(225,285)),('goneChoice',rr,review,(315,285))]:
 x=a.getpixel(point);y=b.getpixel(point);report['colors'][role]={'point':point,'reference':'#%02x%02x%02x'%x,'render':'#%02x%02x%02x'%y,'maxChannelDelta':max(abs(v-w) for v,w in zip(x,y))}
report['zoneGeometry']['primaryPaintExactRgb']=pair(rz,zone,(20,145,215,202),lambda c:c==(69,101,76))
report['zoneGeometry']['secondaryPaintExactRgb']=pair(rz,zone,(215,145,410,202),lambda c:c==(255,254,250))
for index,(top,bottom) in enumerate([(169,338),(345,514),(520,689),(696,865)]):
 report['reviewGeometry']['card'+str(index+1)]=pair(rr,review,(20,top,410,bottom),lambda c:max(abs(x-y) for x,y in zip(c,(255,254,250)))<=2)
for name,a,b,rect,predicate in [
 ('zoneBack',rz,zone,(24,61,45,89),lambda c:max(c)<110),
 ('reviewBack',rr,review,(24,61,45,89),lambda c:max(c)<110),
 ('camera',rz,zone,(78,162,97,184),lambda c:min(c)>230),
]:
 info=pair(a,b,rect,predicate)
 info['referenceInkSize']=[info['referenceBounds'][i+2]-info['referenceBounds'][i] for i in range(2)]
 info['renderInkSize']=[info['renderBounds'][i+2]-info['renderBounds'][i] for i in range(2)]
 report['icons'][name]=info
for name,a,b,rect,threshold in [
 ('zoneTitle',rz,zone,(54,55,150,97),110),('reviewTitle',rr,review,(54,55,280,97),110),
 ('recordNumber',rz,zone,(65,345,104,367),180),('recordDate',rz,zone,(48,368,118,389),210),
 ('reviewMetadata',rr,review,(118,211,255,258),210),
]:report['typography'][name]={**pair(a,b,rect,lambda c:max(c)<threshold),'maxChannelThreshold':threshold}
# Logical action frames come from the native accessibility tree. Exact-RGB
# raster bboxes above are retained as observations: Lanczos resampling can
# introduce +/-1 channel ringing up to three pixels inside a sharp edge.
report['actionLayoutFrames']={}
expected={'食材入库':[24,149.6,209.2,195.6],'整理食材':[219.2,149.6,406,195.6]}
root=ET.parse(OUT/'zone430-aligned-20261113.xml')
for node in root.iter('node'):
 label=node.get('content-desc')
 if label in expected and node.get('clickable')=='true':
  x0,y0,x1,y1=map(int,re.findall(r'\d+',node.get('bounds')))
  frame=[x0*430/1080,(y0-136)*430/1080+45,x1*430/1080,(y1-136)*430/1080+45]
  report['actionLayoutFrames'][label]={'figmaFrame':expected[label],'nativeFrame':frame,'maxBoundaryDelta':max(abs(x-y) for x,y in zip(frame,expected[label]))}
report['edgeResamplingObservation']=[{'point':[116,y],'reference':rz.getpixel((116,y)),'render':zone.getpixel((116,y))} for y in range(148,155)]
report['result']={
 'allEightColorPointsExact':all(v['maxChannelDelta']==0 for v in report['colors'].values()),
 'actionBoundsWithin1px':len(report['actionLayoutFrames'])==2 and all(v['maxBoundaryDelta']<=1 for v in report['actionLayoutFrames'].values()),
 'firstFourCardBoundsWithin1px':all(v['maxBoundaryDelta'] is not None and v['maxBoundaryDelta']<=1 for v in report['reviewGeometry'].values()),
 'allThreeIconInkBoundsWithin1px':all(v['maxBoundaryDelta'] is not None and v['maxBoundaryDelta']<=1 for v in report['icons'].values()),
}
report['scope']='Nodes2:44/2:99, Android430 baseline top viewport. Native list-end and persistence/undo proof are recorded separately; platform-font bounds are observations.'
report['normalization']={'nativeSize':[1080,2400],'nativeDensity':402,'nativeStatusCropPx':136,'referenceSystemRegionPx':45,'outputSize':[430,900],'surfaceSegmentationMaxChannelDelta':2,'method':'Action layout: native semantic frames vs Figma geometry; panels: anti-alias-aware RGB segmentation; exact RGB paint bboxes retained separately'}
digest=hashlib.sha256()
with (ROOT/'06-project/app/apps/fridge/build/app/outputs/flutter-apk/app-debug.apk').open('rb') as source:
 for block in iter(lambda:source.read(1024*1024),b''):digest.update(block)
report['apkSha256']=digest.hexdigest()
(OUT/'inventory-ui-fidelity-sampling.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
if not all(report['result'].values()):raise SystemExit(1)
