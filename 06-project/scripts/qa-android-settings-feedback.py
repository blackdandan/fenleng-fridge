"""Reversible settings/preferences/draft QA on the owned AVD; never reports provider success."""
import json,re,subprocess,time,xml.etree.ElementTree as ET,hashlib,argparse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
ADB='D:/Documents/Android/Sdk/platform-tools/adb.exe';SERIAL='emulator-5580';PACKAGE='com.fenlengtech.fridge'
QA=ROOT/'.fenleng/figma-settings-fixtures';QA.mkdir(parents=True,exist_ok=True)
parser=argparse.ArgumentParser();parser.add_argument('--visual-only',action='store_true');VISUAL=parser.parse_args().visual_only
OUT=ROOT/'02-engineering/evidence/android';REPORT=OUT/('settings-feedback-visual-results.json' if VISUAL else 'settings-feedback-native-results.json');M=json.loads((ROOT/'06-project/contracts/locales/messages.json').read_text(encoding='utf-8'))
def adb(*args):return subprocess.run([ADB,'-s',SERIAL,*args],capture_output=True,check=True).stdout
def app(*args):return adb('shell','run-as',PACKAGE,*args)
def exists(target):return subprocess.run([ADB,'-s',SERIAL,'shell','run-as',PACKAGE,'ls',target],capture_output=True).returncode==0
def inventory():return json.loads(app('cat','files/fridge/inventory.json'))
def stage(local,target):
 temporary='/data/local/tmp/fridge-settings-'+local.name
 adb('push',str(local),temporary);app('cp',temporary,target);adb('shell','rm',temporary)
def dump():
 path='/sdcard/fridge-settings-qa.xml';adb('shell','rm','-f',path)
 reply=adb('shell','uiautomator','dump',path)
 if b'UI hierchary dumped' not in reply:raise RuntimeError('UI_NOT_READY')
 return adb('shell','cat',path).decode()
def ready(text):
 for _ in range(10):
  try:
   xml=dump()
   if text in xml:return xml
  except (subprocess.CalledProcessError,RuntimeError):pass
  time.sleep(.3)
 raise RuntimeError('SCREEN_NOT_READY:'+text)
def candidates(text,xml,prefix=False):
 values=[]
 for node in ET.fromstring(xml).iter('node'):
  label=node.get('content-desc') or node.get('text') or ''
  if node.get('clickable')=='true' and (label.startswith(text) if prefix else label==text):
   x0,y0,x1,y1=map(int,re.findall(r'\d+',node.get('bounds')))
   if x1>x0 and y1>y0 and 0<=y0<2350:values.append((y0,(x0+x1)//2,(y0+y1)//2))
 return values
def click(text,xml=None,prefix=False):
 matches=candidates(text,xml or dump(),prefix)
 if not matches:raise RuntimeError('CLICK_TARGET_MISSING:'+text)
 _,x,y=min(matches);adb('shell','input','tap',str(x),str(y))
def reach(text,prefix=True):
 for _ in range(7):
  xml=dump()
  if candidates(text,xml,prefix):return xml
  adb('shell','input','swipe','540','1950','540','650','350')
 raise RuntimeError('TARGET_NOT_REACHABLE:'+text)
def hide_keyboard():
 state=adb('shell','dumpsys','input_method').decode()
 if re.search(r'(?:mIsInputViewShown|isInputViewShown)=true',state):adb('shell','input','keyevent','4')
def edit(node,value):
 x0,y0,x1,y1=map(int,re.findall(r'\d+',node.get('bounds')))
 adb('shell','input','tap',str((x0+x1)//2),str((y0+y1)//2));adb('shell','input','keyevent','123')
 for _ in range(5):adb('shell','input','keyevent','67')
 adb('shell','input','text',value)
def capture(name,xml):
 (OUT/(name+'.xml')).write_text(xml,encoding='utf-8');(OUT/(name+'.png')).write_bytes(adb('exec-out','screencap','-p'))
def start(lang='zh-CN'):
 adb('shell','am','start','-n',PACKAGE+'/.MainActivity');return ready(M[lang]['home'])
def settings(lang='zh-CN'):
 xml=ready(M[lang]['home']);click(M[lang]['settings'],xml);return ready(M[lang]['settingsDefaultsTitle'])
def preference(key):
 root=ET.fromstring(app('cat','shared_prefs/privacy-consent.xml').decode())
 return next((n.text for n in root if n.get('name')==key),None)

assert adb('emu','avd','name').decode().splitlines()[0].strip()=='fridge_api35'
assert 'Override density:' not in adb('shell','wm','density').decode()
installed=adb('shell','pm','path',PACKAGE).decode().strip().removeprefix('package:')
apk_hash=hashlib.sha256((ROOT/'06-project/app/apps/fridge/build/app/outputs/flutter-apk/app-debug.apk').read_bytes()).hexdigest()
assert adb('shell','sha256sum',installed).decode().split()[0]==apk_hash
targets=['files/fridge/inventory.json','files/fridge/inventory.backup.json','shared_prefs/privacy-consent.xml','shared_prefs/privacy-consent.xml.bak','files/fridge/feedback-draft.json']
originals={target:app('cat',target) if exists(target) else None for target in targets}
original=json.loads(originals['files/fridge/inventory.json']);assert len(original['foods'])==3
assert original['defaults']=={'cold':3,'frozen':14,'pantry':3} and original['reminderHour']==17 and original['reminderMinute']==30
for i,(target,value) in enumerate(originals.items()):
 if value is not None:(QA/f'original-{i}.bin').write_bytes(value)
result={'completed':False}
REPORT.write_text(json.dumps(result),encoding='utf-8')
def verify_visual():
 adb('shell','am','force-stop',PACKAGE);adb('shell','wm','density','402');start();xml=settings()
 capture('settings430-top-20261113',xml)
 xml=reach(M['zh-CN']['filingPending'],False);capture('settings430-footer-final-20261113',xml)
 click(M['zh-CN']['feedback'],reach(M['zh-CN']['feedback']),prefix=True)
 xml=ready(M['zh-CN']['feedbackSubject']);capture('feedback430-draft-final-20261113',xml)
 # Empty submission is local validation, with no platform call or synthetic receipt.
 click(M['zh-CN']['feedbackSubmit'],xml)
 xml=ready(M['zh-CN']['feedbackValidation']);capture('feedback430-empty-final-20261113',xml)
 result['emptyFeedbackValidationVisible']=True
 adb('shell','input','keyevent','4');ready(M['zh-CN']['settings'])
 xml=reach(M['zh-CN']['appearance']);click(M['zh-CN']['appearance'],xml,prefix=True)
 xml=ready(M['zh-CN']['dark']);click(M['zh-CN']['dark'],xml);ready(M['zh-CN']['settings'])
 capture('settings430-dark-final-20261113',reach(M['zh-CN']['appearance']))
 adb('shell','am','force-stop',PACKAGE);adb('shell','wm','density','540');start();xml=settings()
 capture('settings320-top-final-20261113',xml)
 capture('settings320-footer-final-20261113',reach(M['zh-CN']['filingPending'],False))
 result['settings430And320AndDarkCaptured']=True
 result['feedback430DraftAndValidationCaptured']=True

def verify_flow():
 adb('shell','am','force-stop',PACKAGE);adb('shell','wm','density','402');start();xml=settings()
 capture('settings430-top-20261113',xml)
 fields=[n for n in ET.fromstring(xml).iter('node') if n.get('class')=='android.widget.EditText']
 assert len(fields)==3;edit(fields[0],'7');hide_keyboard()
 xml=reach(M['zh-CN']['saveDefaults'],False);click(M['zh-CN']['saveDefaults'],xml)
 ready(M['zh-CN']['saved']);saved=inventory();assert saved['defaults']['cold']==7 and saved['foods']==original['foods']
 result['defaultsPersistedWithoutChangingExistingFoodRecords']=True
 print('QA defaults persisted',flush=True)
 xml=reach(M['zh-CN']['reminderTime']);click(M['zh-CN']['reminderTime'],xml,prefix=True)
 xml=ready('确定');fields=[n for n in ET.fromstring(xml).iter('node') if n.get('class')=='android.widget.EditText']
 assert len(fields)==2
 capture('settings430-time-picker-before-20261113',xml)
 edit(fields[0],'09');xml=ready('确定')
 fields=[n for n in ET.fromstring(xml).iter('node') if n.get('class')=='android.widget.EditText'];assert len(fields)==2
 edit(fields[1],'15')
 capture('settings430-time-picker-20261113',dump())
 xml=ready('确定');click('确定',xml);xml=reach(M['zh-CN']['saveDefaults'],False);click(M['zh-CN']['saveDefaults'],xml)
 ready(M['zh-CN']['saved']);saved=inventory();assert [saved['reminderHour'],saved['reminderMinute']]==[9,15] and saved['foods']==original['foods']
 result['reminderTimePersistedWithoutChangingCurrentCycles']=True
 print('QA reminder time persisted',flush=True)
 xml=reach(M['zh-CN']['appearance']);click(M['zh-CN']['appearance'],xml,prefix=True)
 xml=ready(M['zh-CN']['dark']);click(M['zh-CN']['dark'],xml)
 ready(M['zh-CN']['settingsDefaultsTitle']);assert preference('appearance')=='dark'
 capture('settings430-dark-20261113',reach(M['zh-CN']['appearance']))
 adb('shell','am','force-stop',PACKAGE);start();xml=settings();capture('settings430-dark-restarted-20261113',xml)
 assert preference('appearance')=='dark';result['nativeDarkPreferenceSurvivedRestart']=True
 xml=reach(M['zh-CN']['language']);click(M['zh-CN']['language'],xml,prefix=True)
 xml=ready(M['en']['_localeName']);click(M['en']['_localeName'],xml)
 ready(M['en']['settingsDefaultsTitle']);assert preference('locale')=='en'
 adb('shell','am','force-stop',PACKAGE);start('en');settings('en');assert preference('locale')=='en'
 result['nativeLanguagePreferenceSurvivedRestart']=True
 print('QA language preference survived restart',flush=True)
 xml=reach(M['en']['appearance']);click(M['en']['appearance'],xml,prefix=True)
 xml=ready(M['en']['light']);click(M['en']['light'],xml);ready(M['en']['settingsDefaultsTitle'])
 xml=reach(M['en']['filingPending'],False);capture('settings430-footer-20261113',xml)
 click(M['en']['feedback'],reach(M['en']['feedback']),prefix=True)
 xml=ready(M['en']['feedbackSubject']);capture('feedback430-draft-20261113',xml)
 fields=[n for n in ET.fromstring(xml).iter('node') if n.get('class')=='android.widget.EditText'];assert len(fields)==1
 edit(fields[0],'qa-feedback-retained');hide_keyboard()
 entry_xml=dump();entry_fields=[n for n in ET.fromstring(entry_xml).iter('node') if n.get('class')=='android.widget.EditText']
 assert len(entry_fields)==1
 entered=entry_fields[0].get('text');assert entered and entered!=M['en']['feedbackPlaceholder']
 xml=reach(M['en']['feedbackSubmit'],False);click(M['en']['feedbackSubmit'],xml)
 xml=ready(M['en']['feedbackUnavailable']);capture('feedback430-unconfigured-20261113',xml)
 draft=json.loads(app('cat','files/fridge/feedback-draft.json'));assert draft['text']==entered and draft['key'] and draft['receipt'] is None
 key=draft['key'];result['unconfiguredFeedbackRetainedDurableDraftWithoutReceipt']=True
 adb('shell','am','force-stop',PACKAGE);start('en');settings('en')
 click(M['en']['feedback'],reach(M['en']['feedback']),prefix=True);xml=ready(M['en']['feedbackSubject'])
 restored_fields=[n for n in ET.fromstring(xml).iter('node') if n.get('class')=='android.widget.EditText'];assert len(restored_fields)==1 and restored_fields[0].get('text')==entered
 assert json.loads(app('cat','files/fridge/feedback-draft.json'))['key']==key
 click(M['en']['feedbackSubmit'],reach(M['en']['feedbackSubmit'],False));ready(M['en']['feedbackUnavailable'])
 assert json.loads(app('cat','files/fridge/feedback-draft.json'))['key']==key
 result['feedbackDraftAndIdempotencyKeySurvivedRestartAndRetry']=True
 adb('shell','input','keyevent','4');ready(M['en']['settings'])
 xml=reach(M['en']['filingPending'],False);click(M['en']['filingPending'],xml)
 time.sleep(.4)
 activities=adb('shell','dumpsys','activity','activities').decode()
 result['filingQueryIntentObserved']='beian.miit.gov.cn' in activities
 adb('shell','am','force-stop',PACKAGE);adb('shell','wm','density','540');start('en');xml=settings('en')
 capture('settings320-top-20261113',xml);xml=reach(M['en']['filingPending'],False);capture('settings320-footer-20261113',xml)
 result['narrowSettingsFooterReachable']=True

try:
 if VISUAL:verify_visual()
 else:verify_flow()
 result['completed']=True
 print(json.dumps(result))
except Exception:
 try:capture('settings-feedback-failure-debug',dump())
 except Exception:pass
 raise
finally:
 adb('shell','wm','density','reset');adb('shell','am','force-stop',PACKAGE)
 for i,(target,value) in enumerate(originals.items()):
  assert target in targets
  if value is None:app('rm','-f',target)
  else:stage(QA/f'original-{i}.bin',target)
 start();restored=inventory();assert restored['foods']==original['foods'] and restored['defaults']==original['defaults'] and restored['nextNumber']==original['nextNumber']
 assert [restored['reminderHour'],restored['reminderMinute']]==[17,30]
 for target in targets[2:]:
  if originals[target] is None:assert not exists(target)
  elif target.startswith('shared_prefs/'):
   def entries(raw):return {n.get('name'):(n.tag,dict(n.attrib),n.text or '') for n in ET.fromstring(raw)}
   assert entries(app('cat',target))==entries(originals[target])
  else:assert app('cat',target)==originals[target]
 result['originalInventoryPreferencesDraftAndDensityRestored']=True
 result['apkSha256']=hashlib.sha256((ROOT/'06-project/app/apps/fridge/build/app/outputs/flutter-apk/app-debug.apk').read_bytes()).hexdigest()
 REPORT.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
 print('Restored original QA inventory/preferences/draft and density420')
