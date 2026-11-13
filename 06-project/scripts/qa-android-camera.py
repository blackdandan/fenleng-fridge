"""Owned-AVD camera/retention/permission QA with reversible local fixtures."""
import argparse,hashlib,json,re,subprocess,time,xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
ADB='D:/Documents/Android/Sdk/platform-tools/adb.exe';SERIAL='emulator-5580';PACKAGE='com.fenlengtech.fridge'
parser=argparse.ArgumentParser();parser.add_argument('--visual-only',action='store_true');VISUAL=parser.parse_args().visual_only
OUT=ROOT/'02-engineering/evidence/android';QA=ROOT/'.fenleng/figma-camera-fixtures';QA.mkdir(parents=True,exist_ok=True)
M=json.loads((ROOT/'06-project/contracts/locales/messages.json').read_text(encoding='utf-8'))['zh-CN']
REPORT=OUT/('camera-visual-results.json' if VISUAL else 'camera-native-results.json')
def adb(*args):return subprocess.run([ADB,'-s',SERIAL,*args],capture_output=True,check=True).stdout
def app(*args):return adb('shell','run-as',PACKAGE,*args)
def inventory():return json.loads(app('cat','files/fridge/inventory.json'))
def exists(path):return subprocess.run([ADB,'-s',SERIAL,'shell','run-as',PACKAGE,'ls',path],capture_output=True).returncode==0
def stage(local,target):
 temp='/data/local/tmp/fridge-camera-'+local.name
 adb('push',str(local),temp);app('cp',temp,target);adb('shell','rm',temp)
def dump():
 path='/sdcard/fridge-camera-qa.xml';adb('shell','rm','-f',path)
 response=adb('shell','uiautomator','dump',path)
 if b'UI hierchary dumped' not in response:raise RuntimeError('UI_NOT_READY')
 return adb('shell','cat',path).decode()
def ready(text):
 for _ in range(12):
  try:
   xml=dump()
   if text in xml:return xml
  except (subprocess.CalledProcessError,RuntimeError):pass
  time.sleep(.3)
 raise RuntimeError('SCREEN_NOT_READY:'+text)
def click(text,xml=None,prefix=False):
 found=[]
 for n in ET.fromstring(xml or dump()).iter('node'):
  label=n.get('content-desc') or n.get('text') or ''
  if n.get('clickable')=='true' and (label.startswith(text) if prefix else label==text):
   x0,y0,x1,y1=map(int,re.findall(r'\d+',n.get('bounds')))
   if x1>x0 and y1>y0 and 0<=y0<2350:found.append((y0,(x0+x1)//2,(y0+y1)//2))
 if not found:raise RuntimeError('CLICK_TARGET_MISSING:'+text)
 _,x,y=min(found);adb('shell','input','tap',str(x),str(y))
def capture(name,xml):
 (OUT/(name+'.xml')).write_text(xml,encoding='utf-8');(OUT/(name+'.png')).write_bytes(adb('exec-out','screencap','-p'))
def start():
 adb('shell','am','start','-n',PACKAGE+'/.MainActivity');return ready(M['home'])
def camera():
 xml=ready(M['home']);click(M['cold'],xml,prefix=True)
 xml=ready(M['coldZone']);click(M['add'],xml)
 return ready(M['cameraSingleCaption'])
def photos():return set(app('ls','files/fridge/photos').decode().splitlines())
def finish():
 adb('shell','input','swipe','540','1920','540','650','350')
 xml=ready(M['done']);capture('camera430-bottom-20261113',xml);click(M['done'],xml)
 ready(M['coldZone'])

assert adb('emu','avd','name').decode().splitlines()[0].strip()=='fridge_api35'
assert 'Override density:' not in adb('shell','wm','density').decode()
assert 'android.permission.CAMERA: granted=true' in adb('shell','dumpsys','package',PACKAGE).decode()
apk=ROOT/'06-project/app/apps/fridge/build/app/outputs/flutter-apk/app-debug.apk';apk_hash=hashlib.sha256(apk.read_bytes()).hexdigest()
installed=adb('shell','pm','path',PACKAGE).decode().strip().removeprefix('package:')
assert adb('shell','sha256sum',installed).decode().split()[0]==apk_hash
originals={n:app('cat','files/fridge/'+n) for n in ['inventory.json','inventory.backup.json']}
original=json.loads(originals['inventory.json']);assert len(original['foods'])==3 and original['nextNumber']==4
for name,data in originals.items():(QA/('original-'+name)).write_bytes(data)
before_photos=photos();fixtures=[];result={'completed':False}
REPORT.write_text(json.dumps(result),encoding='utf-8')
try:
 adb('shell','am','force-stop',PACKAGE);adb('shell','wm','density','402')
 if not VISUAL:
  source='files/fridge/photos/'+next(iter(before_photos))
  for name in ['123456789-aabbcc.image','123456790-aabbcc.pending','qa-camera-keep.txt']:
   target='files/fridge/photos/'+name;assert not exists(target);app('cp',source,target);fixtures.append(target)
 xml=start()
 if not VISUAL:
  assert not exists(fixtures[0]) and not exists(fixtures[1]) and exists(fixtures[2])
  assert all(exists('files/fridge/photos/'+n) for n in before_photos)
  result['startupCollectedOnlyUnreferencedManagedPhotos']=True
 xml=camera();capture('camera430-top-20261113',xml)
 if not VISUAL:
  click(M['captureNow'],xml);ready(M['recordCountShort'].format(count=1))
  saved=inventory();assert len(saved['foods'])==4
  first=next(f for f in saved['foods'] if f['id']=='004');assert first['zone']=='cold'
  xml=ready(M['cameraSingleCaption']);click(M['putInto'].format(zone=M['coldZone']),xml)
  xml=ready(M['putInto'].format(zone=M['frozenZone']));click(M['putInto'].format(zone=M['frozenZone']),xml)
  xml=ready(M['cameraSingleCaption']);click(M['captureNow'],xml);ready(M['recordCountShort'].format(count=2))
  saved=inventory();second=next(f for f in saved['foods'] if f['id']=='005');assert second['zone']=='frozen'
  assert next(f for f in saved['foods'] if f['id']=='004')==first
  assert [f for f in saved['foods'] if f['id'] in ['001','002','003']]==original['foods']
  for food in [first,second]:assert int(app('stat','-c','%s',food['photoPath']))>0
  result['twoRealCapturesPersistedWithSequentialNumbersAndIndependentZones']=True
  capture('camera430-two-captures-20261113',dump())
 finish()
 adb('shell','am','force-stop',PACKAGE);start()
 if not VISUAL:
  reloaded=inventory();assert reloaded['foods']==saved['foods'] and reloaded['nextNumber']==6
  result['capturedPhotosAndInventorySurvivedRestart']=True
 adb('shell','am','force-stop',PACKAGE);adb('shell','wm','density','540');start();xml=camera()
 capture('camera320-top-20261113',xml)
 adb('shell','input','swipe','540','1920','540','650','350');capture('camera320-bottom-20261113',ready(M['done']))
 result['camera430And320Captured']=True
 if not VISUAL:
  adb('shell','am','force-stop',PACKAGE);adb('shell','wm','density','402');adb('shell','pm','revoke',PACKAGE,'android.permission.CAMERA')
  xml=start();click(M['cold'],xml,prefix=True);xml=ready(M['coldZone']);click(M['add'],xml)
  xml=ready(M['permissionTitle']);capture('camera430-permission-explanation-20261113',xml)
  assert 'com.android.permissioncontroller' not in xml
  click(M['notNow'],xml);xml=ready(M['cameraUnavailable']);capture('camera430-denied-20261113',xml)
  assert M['album'] in xml and M['openSettings'] in xml
  result['explanationPrecededSystemPermissionAndDeclineKeptAlbum']=True
 result['completed']=True
 print(json.dumps(result),flush=True)
except Exception:
 try:capture('camera-failure-debug',dump())
 except Exception:pass
 raise
finally:
 adb('shell','am','force-stop',PACKAGE);adb('shell','wm','density','reset');adb('shell','pm','grant',PACKAGE,'android.permission.CAMERA')
 for name in originals:stage(QA/('original-'+name),'files/fridge/'+name)
 for name in photos()-before_photos:app('rm','-f','files/fridge/photos/'+name)
 for target in fixtures:
  if exists(target):app('rm','-f',target)
 start();restored=inventory();assert restored['foods']==original['foods'] and restored['nextNumber']==4
 assert all(exists('files/fridge/photos/'+n) for n in before_photos)
 assert 'Override density:' not in adb('shell','wm','density').decode()
 result['originalInventoryPhotosPermissionAndDensityRestored']=True;result['apkSha256']=apk_hash
 REPORT.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
 print('Restored original3 records/photos, CAMERA permission and density420',flush=True)
