"""Exercise only the owned AVD; preserve original preferences in memory."""
import base64,hashlib,json,re,subprocess,time,xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
ADB='D:/Documents/Android/Sdk/platform-tools/adb.exe';SERIAL='emulator-5580';PKG='com.fenlengtech.fridge'
OUT=ROOT/'02-engineering/evidence/android'
M=json.loads((ROOT/'06-project/contracts/locales/messages.json').read_text(encoding='utf-8'))['zh-CN']
def adb(*args,input=None):
 return subprocess.run([ADB,'-s',SERIAL,*args],input=input,capture_output=True,check=True,timeout=30).stdout
def read(path):return adb('exec-out','run-as',PKG,'cat',path)
def exists(path):return subprocess.run([ADB,'-s',SERIAL,'shell','run-as',PKG,'test','-f',path],capture_output=True).returncode==0
def dump():
 adb('shell','rm','-f','/sdcard/fridge-privacy-withdrawal.xml')
 response=adb('shell','uiautomator','dump','/sdcard/fridge-privacy-withdrawal.xml')
 if b'UI hierchary dumped' not in response:raise RuntimeError('UI_NOT_READY')
 return adb('exec-out','cat','/sdcard/fridge-privacy-withdrawal.xml').decode()
def ready(text):
 for _ in range(15):
  try:
   xml=dump()
   if text in xml:return xml
  except (RuntimeError,subprocess.CalledProcessError,subprocess.TimeoutExpired):pass
  time.sleep(.2)
 raise RuntimeError('SCREEN_NOT_READY:'+text)
def candidates(text,xml):
 result=[]
 for node in ET.fromstring(xml).iter('node'):
  label=node.get('content-desc') or node.get('text') or ''
  if label==text:
   x0,y0,x1,y1=map(int,re.findall(r'\d+',node.get('bounds')))
   if x1>x0 and y1>y0 and y0<2300:result.append(((x0+x1)//2,(y0+y1)//2))
 return result
def click(text,xml=None):
 items=candidates(text,xml or dump())
 if not items:raise RuntimeError('CLICK_TARGET_MISSING:'+text)
 x,y=items[-1];time.sleep(.5);adb('shell','input','tap',str(x),str(y));time.sleep(.8)
def reach(text):
 for _ in range(15):
  try:xml=dump()
  except (RuntimeError,subprocess.CalledProcessError,subprocess.TimeoutExpired):continue
  if candidates(text,xml):return xml
  adb('shell','input','swipe','540','1960','540','650','250')
 raise RuntimeError('TARGET_NOT_REACHABLE:'+text)
def restart():
 adb('shell','am','force-stop',PKG);adb('shell','am','start','-n',PKG+'/.MainActivity')
def consent():
 return {n.get('name'):n.text or n.get('value') for n in ET.fromstring(read('shared_prefs/privacy-consent.xml'))}
def capture(name,xml):
 base=f'privacy-withdrawal-{sha[:12]}-{name}'
 (OUT/(base+'.xml')).write_text(xml,encoding='utf-8')
 (OUT/(base+'.png')).write_bytes(adb('exec-out','screencap','-p'))
 return base+'.png'
assert adb('emu','avd','name').decode().splitlines()[0].strip()=='fridge_api35'
stock=read('files/fridge/inventory.json');state=json.loads(stock)
assert len(state['foods'])==3 and state['nextNumber']==4
photos={f['photoPath']:hashlib.sha256(read(f['photoPath'])).hexdigest() for f in state['foods']}
paths=['shared_prefs/privacy-consent.xml','shared_prefs/local-reminders.xml']
originals={p:read(p) for p in paths}
assert consent().get('policyVersion')=='V0.4'
apk=ROOT/'06-project/app/apps/fridge/build/app/outputs/flutter-apk/app-debug.apk'
sha=hashlib.sha256(apk.read_bytes()).hexdigest()
adb('install','-r',str(apk))
captures={}
try:
 restart();ready(M['home']);time.sleep(.5)
 click(M['settings']);ready(M['settingsDefaultsTitle'])
 click(M['privacy'],reach(M['privacy']))
 xml=reach(M['privacyWithdrawLink'])
 assert 'android.webkit.WebView' in xml
 captures['reader']=capture('reader',xml)
 print('Native reader and footer ready',flush=True)
 click(M['privacyWithdrawLink'],xml)
 xml=ready(M['privacyWithdrawConfirm']);captures['confirmation']=capture('confirmation',xml)
 click(M['cancel'],xml);ready(M['privacy'])
 assert consent().get('policyVersion')=='V0.4'
 print('Cancellation preserved consent',flush=True)
 restart();ready(M['home']);time.sleep(.5)
 click(M['settings']);ready(M['settingsDefaultsTitle'])
 click(M['privacy'],reach(M['privacy']))
 click(M['privacyWithdrawLink'],reach(M['privacyWithdrawLink']))
 click(M['privacyWithdrawConfirm'],ready(M['privacyWithdrawConfirm']))
 xml=ready(M['agree']);captures['returnedGate']=capture('gate',xml)
 print('Confirmed withdrawal returned to gate',flush=True)
 revoked=consent()
 assert 'policyVersion' not in revoked and 'acceptedAt' not in revoked and revoked.get('withdrawalPending')!='true'
 if exists('files/fridge/platform-session.json'):
  assert json.loads(read('files/fridge/platform-session.json'))=={}
 assert read('files/fridge/inventory.json')==stock
 assert {p:hashlib.sha256(read(p)).hexdigest() for p in photos}==photos
 alarms=adb('shell','dumpsys','alarm').decode()
 assert not re.search(r'(?m)^\s*(?:RTC_WAKEUP|ELAPSED_WAKEUP) #\d+:.*com\.fenlengtech\.fridge',alarms)
 restart();xml=ready(M['agree']);captures['restartGate']=capture('restart-gate',xml)
 click(M['agree'],xml);ready(M['home']);time.sleep(.5)
 assert consent().get('policyVersion')=='V0.4'
 assert read('files/fridge/inventory.json')==stock
 assert {p:hashlib.sha256(read(p)).hexdigest() for p in photos}==photos
 report={'completed':True,'apkSha256':sha,'scope':'Own API35 AVD; real offline native WebView and Flutter confirmation; identity/network flags disabled; no real Provider login or simulated IO failure claimed',
  'cancelKeepsConsent':True,'confirmReturnsToGate':True,'restartRequiresConsent':True,'reconsentRestoresLocalStock':True,
  'inventoryAndPhotoBytesPreserved':True,'activeSessionAbsentOrEmpty':True,'ownedWakeupAlarmAbsent':True,'captures':captures}
finally:
 adb('shell','am','force-stop',PKG)
 for path,value in originals.items():
  encoded=base64.b64encode(value).decode()
  adb('shell',"run-as "+PKG+" sh -c 'printf %s "+encoded+" | base64 -d > "+path+"'")
  assert read(path)==value
 restart()
report['originalPreferenceBytesRestored']=True
(OUT/'privacy-withdrawal-results.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
