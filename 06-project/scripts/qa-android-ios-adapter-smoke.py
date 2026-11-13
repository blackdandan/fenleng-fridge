"""Own-AVD compatibility smoke; verify unchanged inventory/photos/permission."""
import hashlib,json,re,subprocess,time,xml.etree.ElementTree as ET
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
adb('install','-r',str(apk));adb('shell','am','force-stop',PKG)
adb('shell','am','start','-n',PKG+'/.MainActivity')
messages=json.loads((ROOT/'06-project/contracts/locales/messages.json').read_text(encoding='utf-8'))['zh-CN']
for _ in range(12):
 try:
  adb('shell','uiautomator','dump','/sdcard/fridge-ios-adapter-smoke.xml')
  xml=adb('shell','cat','/sdcard/fridge-ios-adapter-smoke.xml').decode()
  if messages['home'] in xml:break
 except subprocess.CalledProcessError:pass
 time.sleep(.3)
else:raise RuntimeError('HOME_NOT_READY')
assert 'permission_allow_button' not in xml
installed=adb('shell','pm','path',PKG).decode().strip().removeprefix('package:')
assert adb('shell','sha256sum',installed).decode().split()[0]==sha
assert data()==before and photos(data())==images and flags()==prior and permission()==grant
(OUT/'ios-adapter-android-smoke-20261113.xml').write_text(xml,encoding='utf-8')
(OUT/'ios-adapter-android-smoke-20261113.png').write_bytes(adb('exec-out','screencap','-p'))
report={'completed':True,'apkSha256':sha,'scope':'Own API35 AVD cold-home compatibility smoke after shared iOS capacity status addition; not a repeated full notification delivery run',
 'installedHashMatches':True,'homeWithoutPermissionPrompt':True,'originalInventoryPhotoBytesNotificationFlagsAndOSPermissionUnchanged':True}
(OUT/'ios-adapter-android-smoke.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
