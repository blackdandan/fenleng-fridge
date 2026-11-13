"""Camera chrome only: a real sensor image deliberately replaces demo bread."""
import collections,hashlib,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'02-engineering/evidence/android'
ref=Image.open(ROOT/'01-product/references/figma-qa/03-figma.png').convert('RGB')
def normalized(name):
 raw=Image.open(OUT/(name+'.png')).convert('RGB')
 frame=Image.new('RGB',(430,923),'#263c2c')
 frame.paste(raw.crop((0,136,1080,136+round(878*1080/430))).resize((430,878),Image.Resampling.LANCZOS),(0,45))
 frame.save(OUT/(name+'-normalized.png'));return frame
ren=normalized('camera430-top-20261113');bottom=normalized('camera430-bottom-20261113')
def near(c,target,delta=2):return max(abs(a-b) for a,b in zip(c,target))<=delta
def bounds(im,rect,predicate,connected=False):
 pts={(x,y) for y in range(rect[1],min(rect[3],im.height)) for x in range(rect[0],rect[2]) if predicate(im.getpixel((x,y)))}
 if connected:
  largest=[]
  while pts:
   seed=pts.pop();group=[seed];stack=[seed]
   while stack:
    x,y=stack.pop()
    for q in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
     if q in pts:pts.remove(q);group.append(q);stack.append(q)
   if len(group)>len(largest):largest=group
  pts=largest
 assert pts
 return [min(x for x,y in pts),min(y for x,y in pts),max(x for x,y in pts)+1,max(y for x,y in pts)+1]
def pair(a,b,area,predicate,connected=False):
 x=bounds(a,area,predicate,connected);y=bounds(b,area,predicate,connected)
 return {'referenceBounds':x,'renderBounds':y,'maxBoundaryDelta':max(abs(i-j) for i,j in zip(x,y))}
report={'scope':'Figma2:81 camera chrome; real emulator sensor replaces demo photo. Real local-only label replaces demo badge, so badge width is not compared. Native system bars excluded; footer height compared in local coordinates because viewport heights differ.',
 'colors':{},'geometry':{},'icons':{},'typography':{},'coverage':{}}
for role,point in [('page',(10,400)),('selector',(30,173)),('shutter',(215,645))]:
 a=ref.getpixel(point);b=ren.getpixel(point)
 report['colors'][role]={'point':point,'reference':'#%02x%02x%02x'%a,'render':'#%02x%02x%02x'%b,'maxChannelDelta':max(abs(x-y) for x,y in zip(a,b))}
report['geometry']['selector']=pair(ref,ren,(20,145,410,201),lambda c:near(c,(53,74,59)),True)
report['geometry']['previewFrame']=pair(ref,ren,(20,203,410,605),lambda c:max(abs(a-b) for a,b in zip(c,(38,60,44)))>25,True)
report['geometry']['shutterFill']=pair(ref,ren,(175,605,255,690),lambda c:near(c,(249,250,243)),True)
report['geometry']['shutterBorder']=pair(ref,ren,(175,605,255,690),lambda c:near(c,(188,200,179)))
for name,area,ink in [('back',(24,58,47,86),(249,250,243)),('selector',(380,162,402,184),(238,238,238)),('album',(50,624,74,653),(199,209,189))]:
 # Thin white strokes can overshoot238 when Lanczos-resampled; segment their
 # contrast rather than excluding those valid bright stroke pixels.
 predicate=(lambda c:min(c)>150) if name in ['back','selector'] else (lambda c:near(c,ink,6))
 report['icons'][name]=pair(ref,ren,area,predicate)
for name,area,color in [('title',(55,52,190,94),(249,250,243)),('localTag',(24,116,220,142),(207,219,194)),('selector',(38,160,180,186),(238,238,238)),('guideCaption',(135,537,295,566),(255,253,244)),('albumLabel',(24,652,103,675),(199,209,189)),('count',(325,628,405,669),(174,190,159)),('hint',(25,718,405,770),(174,190,159))]:
 report['typography'][name]={**pair(ref,ren,area,lambda c:near(c,color,12)), 'note':'Native Noto CJK vs reference YaHei/Noto; text differs intentionally in local-only badge and saved count.'}
for name,color,area in [('tagBorder',(108,125,98),(24,116,220,143)),('captionInk',(174,190,159),(25,718,405,770))]:
 def closest(im):
  return min((im.getpixel((x,y)) for y in range(area[1],area[3]) for x in range(area[0],area[2])), key=lambda c:max(abs(a-b) for a,b in zip(c,color)))
 a=closest(ref);b=closest(ren)
 report['colors'][name]={'referenceNearest':'#%02x%02x%02x'%a,'renderNearest':'#%02x%02x%02x'%b,'maxChannelDelta':max(abs(x-y) for x,y in zip(a,b))}
footer=pair(ref,bottom,(20,820,410,915),lambda c:near(c,(53,74,59)),True)
footer['referenceSize']=[footer['referenceBounds'][2]-footer['referenceBounds'][0],footer['referenceBounds'][3]-footer['referenceBounds'][1]]
footer['renderSize']=[footer['renderBounds'][2]-footer['renderBounds'][0],footer['renderBounds'][3]-footer['renderBounds'][1]]
footer['maxSizeDelta']=max(abs(a-b) for a,b in zip(footer['referenceSize'],footer['renderSize']))
report['footer']=footer
report['coverage']={'background':'flat color','header':'back SVG and title ink','localOnlyTag':'top/height from source-aligned Widget geometry; semantic content changed','selector':'surface, SVG, label','preview':'frame bounds; live texture is dynamic','guide':'Widget inset17/inner frame346.4 at430, caption ink; translucent border compositing depends on live pixels','controls':'shutter fill/border, original album SVG and label/count','hint':'two-line ink bounds and color','finish':'local surface size; native430/320 reachability'}
explanation=Image.open(OUT/'camera430-permission-explanation-20261113.png').convert('RGB')
dialog=bounds(explanation,(0,136,1080,1500),lambda c:near(c,(255,254,250)))
scale=1080/430
report['permissionExplanation']={'nativeDialogBounds':dialog,
 'leftMarginLogical':round(dialog[0]/scale,2),'rightMarginLogical':round((1080-dialog[2])/scale,2),
 'topMarginAfterStatusBarLogical':round((dialog[1]-136)/scale,2),
 'evidenceApkSha256':json.loads((OUT/'camera-native-results.json').read_text())['apkSha256'],
 'scope':'Android rationale margin requirement only; not full2:373 visual parity'}
report['checks']={'threeFlatColorsExact':all(report['colors'][role]['maxChannelDelta']==0 for role in ['page','selector','shutter']),
 'twoRasterInkColorsMeasured':all(role in report['colors'] for role in ['tagBorder','captionInk']),
 'fourSurfacesWithin2px':all(v['maxBoundaryDelta']<=2 for v in report['geometry'].values()),
 'threeSvgInkBoundsWithin2px':all(v['maxBoundaryDelta']<=2 for v in report['icons'].values()),
 'footerSizeWithin2px':footer['maxSizeDelta']<=2,'sevenTypographyGroupsMeasured':len(report['typography'])==7}
report['checks']['permissionExplanationHas16pxTopAndSideMargins']=all(15.5<=report['permissionExplanation'][key]<=17 for key in ['leftMarginLogical','rightMarginLogical','topMarginAfterStatusBarLogical'])
report['apkSha256']=hashlib.sha256((ROOT/'06-project/app/apps/fridge/build/app/outputs/flutter-apk/app-debug.apk').read_bytes()).hexdigest()
(OUT/'camera-fidelity-sampling.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
if not all(report['checks'].values()):raise SystemExit(1)
