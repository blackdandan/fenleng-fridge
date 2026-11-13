"""Reversible region/review QA on the agent-owned Android AVD only."""
import copy, datetime, hashlib, json, re, subprocess, time, xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
ADB='D:/Documents/Android/Sdk/platform-tools/adb.exe'
SERIAL='emulator-5580';PACKAGE='com.fenlengtech.fridge'
ASSETS=ROOT/'.fenleng/figma-home-fixtures';QA=ROOT/'.fenleng/figma-inventory-fixtures'
OUT=ROOT/'02-engineering/evidence/android';QA.mkdir(parents=True,exist_ok=True)
def adb(*args):return subprocess.run([ADB,'-s',SERIAL,*args],capture_output=True,check=True).stdout
def app(*args):return adb('shell','run-as',PACKAGE,*args)
def inventory():return json.loads(app('cat','files/fridge/inventory.json'))
def stage(local,target):
 temporary='/data/local/tmp/fridge-inventory-'+local.name
 adb('push',str(local),temporary);app('cp',temporary,target);adb('shell','rm',temporary)
def dump():
 path='/sdcard/fridge-inventory-qa.xml';adb('shell','rm','-f',path)
 response=adb('shell','uiautomator','dump',path)
 if b'UI hierchary dumped' not in response:raise RuntimeError('UI_NOT_READY')
 return adb('shell','cat',path).decode()
def ready(text):
 for _ in range(10):
  try:
   xml=dump()
   if text in xml:return xml
  except (subprocess.CalledProcessError,RuntimeError):pass
  time.sleep(.3)
 raise RuntimeError('SCREEN_NOT_READY')
def click(text,xml=None,prefix=False):
 nodes=ET.fromstring(xml or dump()).iter('node');candidates=[]
 for node in nodes:
  label=node.get('content-desc') or node.get('text') or ''
  if node.get('clickable')=='true' and (label.startswith(text) if prefix else label==text):
   x0,y0,x1,y1=map(int,re.findall(r'\d+',node.get('bounds')));candidates.append((y0,(x0+x1)//2,(y0+y1)//2))
 if not candidates:raise RuntimeError('CLICK_TARGET_MISSING:'+text)
 _,x,y=min(candidates);adb('shell','input','tap',str(x),str(y))
def capture(name,xml):
 (OUT/(name+'.xml')).write_text(xml,encoding='utf-8')
 (OUT/(name+'.png')).write_bytes(adb('exec-out','screencap','-p'))
def start():
 adb('shell','am','start','-n',PACKAGE+'/.MainActivity');return ready('我的冰箱')
assert adb('emu','avd','name').decode().splitlines()[0].strip()=='fridge_api35'
assert 'Override density:' not in adb('shell','wm','density').decode()
originals={name:app('cat','files/fridge/'+name) for name in ['inventory.json','inventory.backup.json']}
original=json.loads(originals['inventory.json']);assert len(original['foods'])==3
for name,data in originals.items():(QA/('original-'+name)).write_bytes(data)
fixtures=[];result={}
try:
 adb('shell','am','force-stop',PACKAGE);adb('shell','wm','density','402')
 now=datetime.datetime.now().replace(microsecond=0);due=now+datetime.timedelta(days=30)
 state=copy.deepcopy(original);state.update(foods=[],reminders=[],nextNumber=15,lastOrganizedAt=now.isoformat())
 for number in range(1,15):
  record=copy.deepcopy(original['foods'][0]);identifier=f'{number:03}'
  image=identifier if number in [1,2,3,4,5,9,10,12,13] else {6:'001',7:'002',8:'003',11:'009',14:'012'}[number]
  target='files/fridge/photos/qa-inventory-'+identifier+'.png';fixtures.append(target);stage(ASSETS/(image+'.png'),target)
  zone='cold' if number<=8 else 'frozen' if number<=11 else 'pantry'
  record.update(id=identifier,photoPath='/data/user/0/'+PACKAGE+'/'+target,zone=zone,remaining='full',cycle=1,
   intervalDays=state['defaults'][zone],addedAt=datetime.datetime(2026,11,11-(number-1)%4).isoformat(),
   confirmedAt=datetime.datetime(2026,11,[12,11,10,12,11,10,12,11][(number-1)%8],10).isoformat(),dueAt=due.isoformat())
  state['foods'].append(record)
 fixture=QA/'fixture-inventory.json';fixture.write_text(json.dumps(state),encoding='utf-8')
 stage(fixture,'files/fridge/inventory.json');stage(fixture,'files/fridge/inventory.backup.json')
 xml=start();click('冷藏',xml,prefix=True)
 xml=ready('冷藏区');assert '#008' in xml;capture('zone430-aligned-20261113',xml)
 result['zoneLastRecordVisible']=True
 click('整理食材',xml);xml=ready('整理冷藏食材');capture('review430-top-aligned-20261113',xml)
 for _ in range(2):adb('shell','input','swipe','540','2000','540','450','350')
 xml=ready('#008');capture('review430-bottom-aligned-20261113',xml);result['reviewLastRecordVisible']=True
 adb('shell','input','keyevent','4');xml=ready('冷藏区');click('整理食材',xml);xml=ready('整理冷藏食材')
 before=inventory();click('没了',xml)
 for _ in range(30):
  consumed=inventory()
  if consumed['foods'][0]['remaining']=='gone':break
  time.sleep(.05)
 assert consumed['foods'][0]['remaining']=='gone'
 assert consumed['foods'][1:]==before['foods'][1:]
 result['archivePersistedBeforeSuccess']=True;result['unselectedRecordsUnchanged']=True
 xml=ready('撤销');click('撤销',xml)
 for _ in range(30):
  undone=inventory()
  if undone['foods']==before['foods']:break
  time.sleep(.05)
 assert undone['foods']==before['foods'] and undone['nextNumber']==before['nextNumber']
 result['nativeUndoRestoredExactFoodCycles']=True
 capture('review430-after-undo-aligned-20261113',ready('整理冷藏食材'))
 print(json.dumps(result))
finally:
 adb('shell','wm','density','reset');adb('shell','am','force-stop',PACKAGE)
 for name in originals:stage(QA/('original-'+name),'files/fridge/'+name)
 for target in fixtures:
  assert re.fullmatch(r'files/fridge/photos/qa-inventory-\d{3}\.png',target);app('rm',target)
 start();restored=inventory()
 assert restored['foods']==original['foods'] and restored['nextNumber']==original['nextNumber']
 result['originalThreeRecordsAndDensityRestored']=True
 digest=hashlib.sha256()
 with (ROOT/'06-project/app/apps/fridge/build/app/outputs/flutter-apk/app-debug.apk').open('rb') as source:
  for chunk in iter(lambda:source.read(1024*1024),b''):digest.update(chunk)
 result['apkSha256']=digest.hexdigest()
 (OUT/'inventory-ui-native-results.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
 print('Restored original QA inventory and density420')
