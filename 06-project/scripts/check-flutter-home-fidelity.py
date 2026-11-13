"""Fixed-profile, source-linked Android/Figma home measurements (not a whole-App gate)."""
import argparse, hashlib, json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('--render',default='02-engineering/evidence/android/home-figma-430-proof-20261113.png')
parser.add_argument('--status-top',type=int,default=136)
args=parser.parse_args()
folder=ROOT/'02-engineering/evidence/android'
ref=Image.open(ROOT/'01-product/references/figma-qa/01-figma.png').convert('RGB')
im=Image.open(ROOT/args.render).convert('RGB')
page=im.crop((0,args.status_top,im.width,args.status_top+round(665*im.width/430))).resize((430,665),Image.Resampling.LANCZOS)
ren=Image.new('RGB',(430,710),'#f8f8f3');ren.paste(page,(0,45));ren.save(folder/'home430-proof-normalized.png')
roles={'page':(10,630),'cabinet':(29,350),'cold':(40,175),'frozen':(39,450),'pantry':(225,450),'surface':(330,66)}
report={'colors':{},'geometry':{},'icons':{},'typography':{}}
for role,point in roles.items():
 a=ref.getpixel(point);b=ren.getpixel(point)
 report['colors'][role]={'point':point,'reference':'#%02x%02x%02x'%a,'render':'#%02x%02x%02x'%b,'maxChannelDelta':max(abs(x-y) for x,y in zip(a,b))}
def bounds(image,rect,predicate):
 hits=[(x,y) for y in range(rect[1],rect[3]) for x in range(rect[0],rect[2]) if predicate(image.getpixel((x,y)))]
 return [min(x for x,y in hits),min(y for x,y in hits),max(x for x,y in hits)+1,max(y for x,y in hits)+1] if hits else None
def compare(rect,predicate):
 a=bounds(ref,rect,predicate);b=bounds(ren,rect,predicate)
 return {'referenceBounds':a,'renderBounds':b,'maxBoundaryDelta':max(abs(x-y) for x,y in zip(a,b)) if a and b else None}
# Segment within each source node's neighborhood. Dynamic photographs elsewhere
# can contain an identical RGB value and must not become part of a panel bbox.
regions={'cabinet':(20,120,410,605),'cold':(25,132,405,414),'frozen':(25,410,215,585),'pantry':(215,410,405,585)}
for role,color in [('cabinet','e5e9df'),('cold','eaf0e7'),('frozen','e9eef0'),('pantry','f1ede2')]:
 rgb=tuple(bytes.fromhex(color));report['geometry'][role]=compare(regions[role],lambda pixel:pixel==rgb)
for role,rect in [('bell',(314,64,348,100)),('settings',(370,64,400,100))]:
 result=compare(rect,lambda pixel:max(pixel)<110)
 result['referenceInkSize']=[result['referenceBounds'][i+2]-result['referenceBounds'][i] for i in range(2)]
 result['renderInkSize']=[result['renderBounds'][i+2]-result['renderBounds'][i] for i in range(2)]
 report['icons'][role]=result
report['typography']['title']=compare((20,60,180,103),lambda pixel:max(pixel)<110)
report['normalization']={'referenceSize':[430,710],'nativeSize':list(im.size),'nativeDensity':402,'nativeStatusCropPx':args.status_top,'referenceStatusExcludedPx':45,'nativeFont':'Android platform CJK','figmaFont':'Microsoft YaHei','nativeScreenshot':args.render}
report['scope']='Home only. Content normalization excludes native status bar and the fake Figma 10:00. Not proof for other routes/platforms.'
report['result']={'allSixColorPointsExact':all(v['maxChannelDelta']==0 for v in report['colors'].values()),'allFourPanelBoundsWithin1px':all(v['maxBoundaryDelta'] is not None and v['maxBoundaryDelta']<=1 for v in report['geometry'].values()),'iconInkSizesMatch':all(v['referenceInkSize']==v['renderInkSize'] for v in report['icons'].values())}
apk=ROOT/'06-project/app/apps/fridge/build/app/outputs/flutter-apk/app-debug.apk'
digest=hashlib.sha256()
with apk.open('rb') as stream:
 for chunk in iter(lambda:stream.read(1024*1024),b''): digest.update(chunk)
report['apkSha256']=digest.hexdigest()
(folder/'home430-fidelity-sampling.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':report['result'],'apkSha256':report['apkSha256']},indent=2))
if not all(report['result'].values()): raise SystemExit(1)
