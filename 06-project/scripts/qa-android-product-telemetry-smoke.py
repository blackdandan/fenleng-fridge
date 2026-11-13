"""Own-AVD compatibility smoke; verify unchanged inventory/photos/permission."""
import hashlib,io,json,re,subprocess,time,zipfile,xml.etree.ElementTree as ET
from PIL import Image
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];ADB='D:/Documents/Android/Sdk/platform-tools/adb.exe'
PKG='com.fenlengtech.fridge';SERIAL='emulator-5580';OUT=ROOT/'02-engineering/evidence/android'
def adb(*args):return subprocess.run([ADB,'-s',SERIAL,*args],capture_output=True,check=True).stdout
def read(path):return adb('exec-out','run-as',PKG,'cat',path)
def data():return json.loads(read('files/fridge/inventory.json'))
def photos(state):return {f['photoPath']:hashlib.sha256(read(f['photoPath'])).hexdigest() for f in state['foods']}
def flags():
 xml=ET.fromstring(read('shared_prefs/local-reminders.xml'))
 return {n.get('name'):n.get('value') for n in xml if n.get('name') in ['enabled','requested']}
def permission():
 text=adb('shell','dumpsys','package',PKG).decode()
 return re.search(r'android.permission.POST_NOTIFICATIONS: granted=(true|false)',text).group(1)
assert adb('emu','avd','name').decode().splitlines()[0].strip()=='fridge_api35'
before=data();assert len(before['foods'])==3 and before['nextNumber']==4
images=photos(before);prior=flags();grant=permission()
assert prior.get('enabled','false')=='false' and 'Override density:' not in adb('shell','wm','density').decode()
apk=ROOT/'06-project/app/apps/fridge/build/app/outputs/flutter-apk/app-debug.apk'
sha=hashlib.sha256(apk.read_bytes()).hexdigest()
with zipfile.ZipFile(apk) as archive:
 catalog=archive.read('assets/flutter_assets/assets/telemetry-events.json')
 kernel=archive.read('assets/flutter_assets/kernel_blob.bin')
 for marker in [b'product_telemetry.dart',b'_HomeTelemetryObserver',b'response_body.dart',b'onlineConsent']:
  assert marker in kernel
assert catalog==(ROOT/'01-product/mvp/telemetry-events.json').read_bytes()
assert json.loads(catalog)['consentSource']=='unified-privacy-v0.4'
adb('install','-r',str(apk));adb('shell','am','force-stop',PKG)
adb('shell','am','start','-n',PKG+'/.MainActivity')
messages=json.loads((ROOT/'06-project/contracts/locales/messages.json').read_text(encoding='utf-8'))['zh-CN']
for _ in range(12):
 try:
  adb('shell','uiautomator','dump','/sdcard/fridge-product-telemetry-smoke.xml')
  xml=adb('shell','cat','/sdcard/fridge-product-telemetry-smoke.xml').decode()
  screen=adb('exec-out','screencap','-p')
  image=Image.open(io.BytesIO(screen)).convert('RGB');width,height=image.size
  painted=(image.getpixel((width//2,int(height*.33))) in {(234,240,231),(41,59,45)} and
   image.getpixel((width//4,int(height*.55))) in {(233,238,240),(41,55,60)})
  if messages['home'] in xml and painted:break
 except subprocess.CalledProcessError:pass
 time.sleep(.3)
else:raise RuntimeError('HOME_NOT_READY')
assert 'permission_allow_button' not in xml
installed=adb('shell','pm','path',PKG).decode().strip().removeprefix('package:')
assert adb('shell','sha256sum',installed).decode().split()[0]==sha
assert data()==before and photos(data())==images and flags()==prior and permission()==grant
capture=f'product-telemetry-smoke-{sha[:12]}-20261113'
(OUT/f'{capture}.xml').write_text(xml,encoding='utf-8')
(OUT/f'{capture}.png').write_bytes(screen)
report={'completed':True,'apkSha256':sha,'scope':'Own API35 AVD cold-home compatibility smoke after Flutter guest/session/product telemetry integration; not a repeated full notification delivery run',
 'screenshot':f'{capture}.png','uiTree':f'{capture}.xml','paintedCabinetVisible':True,'apkCatalogV04MatchesSource':True,'compiledTelemetryAndTimeoutMarkers':True,'installedHashMatches':True,'homeWithoutPermissionPrompt':True,'originalInventoryPhotoBytesNotificationFlagsAndOSPermissionUnchanged':True}
(OUT/'product-telemetry-smoke.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
