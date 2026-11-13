"""Owned-AVD notification receipt/tap/merge/reboot QA; restore original records and preference/permission state."""
import argparse,copy,datetime,hashlib,json,re,subprocess,time,xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];ADB='D:/Documents/Android/Sdk/platform-tools/adb.exe';SERIAL='emulator-5580';PKG='com.fenlengtech.fridge'
QA=ROOT/'.fenleng/figma-notification-fixtures';QA.mkdir(parents=True,exist_ok=True);OUT=ROOT/'02-engineering/evidence/android'
M=json.loads((ROOT/'06-project/contracts/locales/messages.json').read_text(encoding='utf-8'))['zh-CN']
parser=argparse.ArgumentParser();parser.add_argument('--visual-only',action='store_true');VISUAL=parser.parse_args().visual_only
REPORT=OUT/('notifications-visual-results.json' if VISUAL else 'notifications-native-results.json')
def adb(*args):return subprocess.run([ADB,'-s',SERIAL,*args],capture_output=True,check=True).stdout
def app(*args):return adb('shell','run-as',PKG,*args)
def binary(path):return adb('exec-out','run-as',PKG,'cat',path)
def exists(path):return subprocess.run([ADB,'-s',SERIAL,'shell','run-as',PKG,'ls',path],capture_output=True).returncode==0
def inventory():return json.loads(app('cat','files/fridge/inventory.json'))
def prefs():
 root=ET.fromstring(app('cat','shared_prefs/local-reminders.xml'));result={}
 for n in root:
  result[n.get('name')]=[v.text for v in n] if n.tag=='set' else n.get('value')=='true' if n.tag=='boolean' else n.text if n.tag=='string' else int(n.get('value'))
 return result
def stage(file,target):
 temp='/data/local/tmp/fridge-notifications-'+file.name;adb('push',str(file),temp);app('cp',temp,target);adb('shell','rm',temp)
def dump():
 path='/sdcard/fridge-notification-qa.xml';adb('shell','rm','-f',path)
 if b'UI hierchary dumped' not in adb('shell','uiautomator','dump',path):raise RuntimeError('UI_NOT_READY')
 return adb('shell','cat',path).decode()
def ready(text):
 for _ in range(12):
  try:
   xml=dump()
   if text in xml:return xml
  except (subprocess.CalledProcessError,RuntimeError):pass
  time.sleep(.3)
 raise RuntimeError('SCREEN_NOT_READY:'+text)
def nodes(xml,text=None,resource=None,clickable=True,prefix=False):
 matches=[]
 for n in ET.fromstring(xml).iter('node'):
  label=n.get('content-desc') or n.get('text') or ''
  valid=(n.get('resource-id')==resource) if resource else (label.startswith(text) if prefix else label==text)
  if valid and (not clickable or n.get('clickable')=='true'):
   x0,y0,x1,y1=map(int,re.findall(r'\d+',n.get('bounds')))
   if x1>x0 and y1>y0 and 0<=y0<2350:matches.append((y0,(x0+x1)//2,(y0+y1)//2))
 return matches
def click(text=None,xml=None,resource=None,clickable=True,prefix=False):
 values=nodes(xml or dump(),text,resource,clickable,prefix)
 if not values:raise RuntimeError('CLICK_TARGET_MISSING:'+str(text or resource))
 _,x,y=min(values);adb('shell','input','tap',str(x),str(y))
def reach(text):
 for _ in range(8):
  xml=dump()
  if nodes(xml,text,prefix=True):return xml
  adb('shell','input','swipe','540','1900','540','600','350')
 raise RuntimeError('TARGET_NOT_REACHABLE:'+text)
def capture(name,xml):
 (OUT/(name+'.xml')).write_text(xml,encoding='utf-8');(OUT/(name+'.png')).write_bytes(adb('exec-out','screencap','-p'))
def start():
 adb('shell','am','start','-n',PKG+'/.MainActivity');return ready(M['home'])
def settings():
 xml=ready(M['home']);click(M['settings'],xml);ready(M['settingsDefaultsTitle']);click(M['notificationSettings'],reach(M['notificationSettings']),prefix=True)
 return ready(M['notificationEnable'])
def stop():adb('shell','am','force-stop',PKG)
def new_fixture(state):
 stop();file=QA/'fixture.json';file.write_text(json.dumps(state),encoding='utf-8');stage(file,'files/fridge/inventory.json');stage(file,'files/fridge/inventory.backup.json');start()
def permission():
 lines=adb('shell','dumpsys','package',PKG).decode().splitlines()
 return next(line.strip() for line in lines if 'android.permission.POST_NOTIFICATIONS: granted=' in line)
def wait_device():
 for _ in range(180):
  try:
   if adb('shell','getprop','sys.boot_completed').decode().strip()=='1':return
  except subprocess.CalledProcessError:pass
  time.sleep(1)
 raise RuntimeError('OWN_AVD_BOOT_NOT_READY')
def visual_fixture(original):
 now=datetime.datetime.strptime(adb('shell','date','+%Y-%m-%dT%H:%M:%S').decode().strip(),'%Y-%m-%dT%H:%M:%S')
 state=copy.deepcopy(original);state.update(foods=[],reminders=[],nextNumber=12)
 for n in range(1,12):
  food=copy.deepcopy(original['foods'][0]);food.update(id=f'{n:03}',remaining='full',cycle=1,dueAt=(now-datetime.timedelta(minutes=5)).isoformat(timespec='milliseconds'));state['foods'].append(food)
 new_fixture(state);xml=ready(M['home']);click(M['notifications'],xml);xml=ready(M['notificationTitle']);capture('notifications430-pending-20261113',xml)
 state=inventory();state['foods'][0].update(remaining='half',cycle=2,dueAt=(now+datetime.timedelta(days=3)).isoformat(timespec='milliseconds'))
 new_fixture(state);click(M['notifications'],ready(M['home']));capture('notifications430-partial-20261113',ready(M['partiallyHandled']))
 for food in state['foods']:food.update(remaining='gone',cycle=food['cycle']+1)
 new_fixture(state);click(M['notifications'],ready(M['home']));capture('notifications430-handled-20261113',ready(M['notificationHandled']))
 state.update(foods=[],reminders=[],nextNumber=12);new_fixture(state);click(M['notifications'],ready(M['home']));capture('notifications430-empty-20261113',ready(M['notificationEmpty']))
 stop();adb('shell','wm','density','540');new_fixture(original);settings();capture('notification-settings320-20261113',ready(M['notificationEnable']))
 return True

assert adb('emu','avd','name').decode().splitlines()[0].strip()=='fridge_api35'
assert 'Override density:' not in adb('shell','wm','density').decode()
apk=ROOT/'06-project/app/apps/fridge/build/app/outputs/flutter-apk/app-debug.apk';APK=hashlib.sha256(apk.read_bytes()).hexdigest()
installed=adb('shell','pm','path',PKG).decode().strip().removeprefix('package:');assert adb('shell','sha256sum',installed).decode().split()[0]==APK
start()
for _ in range(30):
 if exists('shared_prefs/local-reminders.xml') and 'cycles' in prefs():break
 time.sleep(.2)
original=inventory();assert len(original['foods'])==3 and original['nextNumber']==4
original_permission=permission();original_enabled=prefs().get('enabled',False);original_requested=prefs().get('requested',False)
assert not original_enabled
original_photos={food['photoPath']:binary(food['photoPath']) for food in original['foods']}
for n,(path,data) in enumerate(original_photos.items()):
 assert path.startswith('/data/user/0/'+PKG+'/files/fridge/photos/')
 (QA/f'original-photo-{n}.bin').write_bytes(data)
targets=['files/fridge/inventory.json','files/fridge/inventory.backup.json','shared_prefs/local-reminders.xml','shared_prefs/local-reminders.xml.bak']
originals={p:binary(p) if exists(p) else None for p in targets}
for n,(target,value) in enumerate(originals.items()):
 if value is not None:(QA/f'original-{n}.bin').write_bytes(value)
result={'completed':False};REPORT.write_text(json.dumps(result),encoding='utf-8')
try:
 stop();adb('shell','wm','density','402')
 if not VISUAL:
  assert not prefs().get('enabled',False) and not prefs().get('requested',False)
  assert 'granted=false' in original_permission
  result['noNotificationPermissionRequestOnHome']=True
  now=datetime.datetime.strptime(adb('shell','date','+%Y-%m-%dT%H:%M:%S').decode().strip(),'%Y-%m-%dT%H:%M:%S');due=now+datetime.timedelta(seconds=180)
  state=copy.deepcopy(original);state['reminders']=[]
  for food in state['foods']:food.update(remaining='full',dueAt=(due if food['id'] in ['001','002'] else now+datetime.timedelta(days=3)).isoformat(timespec='milliseconds'))
  new_fixture(state);xml=settings();capture('notification-settings430-off-20261113',xml)
  click(M['notificationEnable'],xml);xml=ready(M['notificationPermissionTitle']);capture('notification-explanation430-20261113',xml)
  click(M['notificationLater'],xml);ready(M['notificationEnable']);assert not prefs().get('requested',False) and 'granted=false' in permission()
  result['explanationCancelDidNotRequestOSPermission']=True
  click(M['notificationEnable']);xml=ready(M['notificationPermissionTitle']);click(M['continueRequest'],xml)
  xml=ready('permission_allow_button');capture('notification-system-permission430-20261113',xml)
  click(resource='com.android.permissioncontroller:id/permission_allow_button',xml=xml)
  xml=ready(M['notificationDisable']);capture('notification-settings430-on-20261113',xml)
  assert prefs()['enabled'] and prefs()['requested'] and 'granted=true' in permission()
  assert not prefs().get('sentCycles',[]),'QA setup missed future deadline'
  assert 'CHECK_DUE' in adb('shell','dumpsys','alarm').decode()
  result['explicitSystemPermissionAndOneFutureAlarm']=True
  adb('shell','input','keyevent','3');time.sleep(1)
  owned_pid=adb('shell','pidof',PKG).decode().strip();assert owned_pid.isdigit()
  # Kill this UID's process, without force-stopping the package (which cancels alarms).
  app('kill','-9',owned_pid)
  for _ in range(20):
   if not subprocess.run([ADB,'-s',SERIAL,'shell','pidof',PKG],capture_output=True).stdout.strip():break
   time.sleep(.2)
  assert not subprocess.run([ADB,'-s',SERIAL,'shell','pidof',PKG],capture_output=True).stdout.strip()
  result['applicationProcessExitedBeforeAlarm']=True
  print('Waiting for real inexact alarm after '+due.isoformat(timespec='seconds'),flush=True)
  wait_started=time.monotonic()
  while time.monotonic()-wait_started<360:
   if len(prefs().get('sentCycles',[]))==2:break
   time.sleep(2)
  assert len(prefs().get('sentCycles',[]))==2 and prefs()['lastOrigin']=='com.fenlengtech.fridge.CHECK_DUE'
  adb('shell','cmd','statusbar','expand-notifications');xml=ready(M['notificationTitle']);capture('system-notification-drawer430-20261113',xml)
  result['realBackgroundAlarmPostedOneMergedSystemNotification']=True
  click(M['notificationTitle'],xml,clickable=False);xml=ready('#001');assert '#002' in xml
  capture('notification-tap-review430-20261113',xml);result['coldNotificationTapOpenedPendingDayRecords']=True
  click(M['gone'],xml);ready('#002');after=inventory();assert next(f for f in after['foods'] if f['id']=='001')['remaining']=='gone'
  adb('shell','input','keyevent','4');click(M['notifications'],ready(M['home']));xml=ready(M['partiallyHandled'])
  assert M['pendingCount'].format(count=1) in xml and M['notificationBody'].format(count=2) in xml;capture('notification-business-partial430-20261113',xml)
  click(M['notificationOpen'],xml);xml=ready('#002');click(M['gone'],xml);ready(M['allHandled'])
  click(M['back']);xml=ready(M['notificationHandled']);capture('notification-business-handled430-20261113',xml)
  assert M['pendingCount'].format(count=0) in xml and M['notificationBody'].format(count=2) in xml
  assert len(prefs()['sentCycles'])==2;result['partialAndCompleteKeepOriginalCountAndDoNotRepeatCycles']=True
  adb('shell','input','keyevent','3');adb('reboot');wait_device()
  for _ in range(60):
   if prefs().get('lastReconcileOrigin')=='android.intent.action.BOOT_COMPLETED':break
   time.sleep(1)
  assert prefs().get('lastReconcileOrigin')=='android.intent.action.BOOT_COMPLETED'
  assert 'CHECK_DUE' in adb('shell','dumpsys','alarm').decode() and len(prefs()['sentCycles'])==2
  result['deviceRebootRebuiltFutureAlarmWithoutRepeatingDeliveredCycles']=True
  print('Real alarm/tap/partial/complete/reboot verified',flush=True)
  start();click(M['settings'],ready(M['home']));ready(M['settingsDefaultsTitle']);click(M['notificationSettings'],reach(M['notificationSettings']),prefix=True)
  xml=ready(M['notificationDisable']);click(M['notificationDisable'],xml);ready(M['notificationEnable']);assert not prefs()['enabled']
  result['explicitDisableCancelledSchedules']=True
 result['pendingPartialHandledEmptyAnd320Captured']=visual_fixture(original)
 result['completed']=True;print(json.dumps(result),flush=True)
except Exception:
 try:capture('notification-failure-debug',dump())
 except Exception:pass
 raise
finally:
 wait_device();stop();adb('shell','wm','density','reset')
 for n,(target,value) in enumerate(originals.items()):
  if value is None:app('rm','-f',target)
  else:stage(QA/f'original-{n}.bin',target)
 for n,(path,data) in enumerate(original_photos.items()):stage(QA/f'original-photo-{n}.bin',path)
 if 'granted=true' in original_permission:adb('shell','pm','grant',PKG,'android.permission.POST_NOTIFICATIONS')
 else:adb('shell','pm','revoke',PKG,'android.permission.POST_NOTIFICATIONS')
 for flag,token in [('user-set','USER_SET'),('user-fixed','USER_FIXED')]:
  adb('shell','pm','set-permission-flags' if token in original_permission else 'clear-permission-flags',PKG,'android.permission.POST_NOTIFICATIONS',flag)
 start();restored=inventory();assert restored['foods']==original['foods'] and restored['nextNumber']==4
 assert prefs().get('enabled',False)==original_enabled and prefs().get('requested',False)==original_requested
 assert all(binary(path)==data for path,data in original_photos.items())
 result['originalInventoryNotificationPreferencePermissionAndDensityRestored']=True;result['apkSha256']=APK
 REPORT.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print('Restored original3 records, notification preference/permission and density420',flush=True)
