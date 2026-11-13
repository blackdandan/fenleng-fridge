"""Measure Figma reminder blocks; disclose production-only state/date differences."""
import hashlib,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'02-engineering/evidence/android'
ref=Image.open(ROOT/'01-product/references/figma-qa/07-figma.png').convert('RGB')
raw=Image.open(OUT/'notifications430-pending-20261113.png').convert('RGB')
ren=Image.new('RGB',(430,900),'#f8f9f3')
ren.paste(raw.crop((0,136,1080,136+round(855*1080/430))).resize((430,855),Image.Resampling.LANCZOS),(0,45))
ren.save(OUT/'notifications430-pending-normalized.png')
def near(c,t,d=2):return max(abs(a-b) for a,b in zip(c,t))<=d
def bounds(im,rect,predicate,connected=False):
 pts={(x,y) for y in range(rect[1],rect[3]) for x in range(rect[0],rect[2]) if predicate(im.getpixel((x,y)))}
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
 assert pts,rect
 return [min(x for x,y in pts),min(y for x,y in pts),max(x for x,y in pts)+1,max(y for x,y in pts)+1]
cardA=bounds(ref,(20,205,411,380),lambda c:near(c,(255,254,250)),True)
cardB=bounds(ren,(20,170,411,420),lambda c:near(c,(255,254,250)),True)
report={'scope':'Figma2:216. Native system bars excluded. Removed demo badge34.4px; live day has no invented delivery time. Production adds pending/status row and minimum44px action. Fonts Noto CJK vs reference YaHei; no whole-screen pixel parity claim.',
 'colors':{},'card':{'referenceBounds':cardA,'renderBounds':cardB,
 'topDeltaAfterDemoBadgeRemoval':round(abs(cardB[1]-(cardA[1]-34.4)),2),
 'widthDelta':abs(cardA[2]-cardA[0]-(cardB[2]-cardB[0])),
 'heightDifference':cardB[3]-cardB[1]-(cardA[3]-cardA[1])},'typography':{},'coverage':{}}
for role,point in [('page',(10,400)),('card',(300,230))]:
 a=ref.getpixel(point);b=ren.getpixel(point)
 report['colors'][role]={'reference':'#%02x%02x%02x'%a,'render':'#%02x%02x%02x'%b,'maxChannelDelta':max(abs(x-y) for x,y in zip(a,b))}
for role,color,areaA,areaB in [
 ('date',(157,166,143),(40,231,110,250),(40,196,110,217)),
 ('title',(23,40,29),(40,260,230,284),(40,225,230,253)),
 ('body',(135,144,132),(40,293,385,317),(40,259,385,288)),
 ('action',(69,101,76),(40,326,200,347),(40,323,210,355))]:
 # Tiny date glyphs are entirely antialiased after native downsampling.
 # Segment contrast against the surface; report nearest ink separately.
 ink=lambda c: min(c)<235 and max(c)-min(c)>5
 a=bounds(ref,areaA,ink);b=bounds(ren,areaB,ink)
 report['typography'][role]={'referenceBounds':a,'renderBounds':b,
 'relativeCardTopDelta':(b[1]-cardB[1])-(a[1]-cardA[1]),
 'inkHeightDelta':(b[3]-b[1])-(a[3]-a[1])}
 def closest(im,area):
  return min((im.getpixel((x,y)) for y in range(area[1],area[3]) for x in range(area[0],area[2])),key=lambda c:max(abs(a-b) for a,b in zip(c,color)))
 aa=closest(ref,areaA);bb=closest(ren,areaB)
 report['colors'][role]={'referenceNearest':'#%02x%02x%02x'%aa,'renderNearest':'#%02x%02x%02x'%bb,'maxChannelDelta':max(abs(x-y) for x,y in zip(aa,bb))}
report['backSvg']={'referenceBounds':bounds(ref,(24,65,46,95),lambda c:max(c)-min(c)>5 and min(c)<145),
 'renderBounds':bounds(ren,(24,65,46,95),lambda c:max(c)-min(c)>5 and min(c)<145)}
report['backSvg']['maxBoundaryDelta']=max(abs(a-b) for a,b in zip(report['backSvg']['referenceBounds'],report['backSvg']['renderBounds']))
report['coverage']={'background':'flat page and card colors','header':'original back SVG bounds; production title differs',
 'caption':'same translated copy,12px line1.8; demo badge removed',
 'card':'surface bounds/radius14/border.8 source tokens; no nested container',
 'date':'10px ink and relative position; actual day only',
 'title':'14px medium ink and relative position','body':'12px original count11 and ink',
 'pendingAndStatus':'production-only row; partial/handled/empty native screenshots and widget matrix',
 'action':'primary ink; complete localized label; monochrome north_east substitutes text glyph; minimum44px touch target'}
report['checks']={'twoFlatColorsExact':all(report['colors'][r]['maxChannelDelta']==0 for r in ['page','card']),
 'cardWidthAndAdjustedTopWithin2px':report['card']['widthDelta']<=2 and report['card']['topDeltaAfterDemoBadgeRemoval']<=2,
 'backSvgWithin2px':report['backSvg']['maxBoundaryDelta']<=2,
 'dateTitleBodyRelativeTopWithin3px':all(abs(report['typography'][r]['relativeCardTopDelta'])<=3 for r in ['date','title','body']),
 'fourRasterTextColorsMeasured':all(r in report['colors'] for r in ['date','title','body','action'])}
report['apkSha256']=hashlib.sha256((ROOT/'06-project/app/apps/fridge/build/app/outputs/flutter-apk/app-debug.apk').read_bytes()).hexdigest()
visual=json.loads((OUT/'notifications-visual-results.json').read_text())
assert visual['completed'] and visual['apkSha256']==report['apkSha256']
explanation=Image.open(OUT/'notification-explanation430-20261113.png').convert('RGB')
dialog=bounds(explanation,(0,136,1080,1500),lambda c:near(c,(255,254,250)))
report['permissionExplanation']={'bounds':dialog,'leftLogical':round(dialog[0]*430/1080,2),
 'rightLogical':round((1080-dialog[2])*430/1080,2),'topLogical':round((dialog[1]-136)*430/1080,2),
 'apkSha256':json.loads((OUT/'notifications-native-results.json').read_text())['apkSha256']}
report['checks']['explanation16pxMargins']=all(15.5<=report['permissionExplanation'][k]<=17 for k in ['leftLogical','rightLogical','topLogical'])
(OUT/'reminders-fidelity-sampling.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
if not all(report['checks'].values()):raise SystemExit(1)
