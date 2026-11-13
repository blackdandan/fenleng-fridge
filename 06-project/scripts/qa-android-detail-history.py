"""Detail/history reversible QA, restricted to the owned fridge_api35 AVD."""
import argparse,copy,datetime,hashlib,json,re,subprocess,time,xml.etree.ElementTree as ET
parser=argparse.ArgumentParser();parser.add_argument("--visual-only",action="store_true");args=parser.parse_args()
class VisualComplete(Exception):pass
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
ADB='D:/Documents/Android/Sdk/platform-tools/adb.exe'
SERIAL='emulator-5580';PACKAGE='com.fenlengtech.fridge'
ASSETS=ROOT/'.fenleng/figma-home-fixtures';QA=ROOT/'.fenleng/figma-detail-fixtures'
OUT=ROOT/'02-engineering/evidence/android';QA.mkdir(parents=True,exist_ok=True)

def adb(*args):return subprocess.run([ADB,'-s',SERIAL,*args],capture_output=True,check=True).stdout
def app(*args):return adb('shell','run-as',PACKAGE,*args)
def inventory():return json.loads(app('cat','files/fridge/inventory.json'))
def stage(local,target):
 temporary='/data/local/tmp/fridge-detail-'+local.name
 adb('push',str(local),temporary);app('cp',temporary,target);adb('shell','rm',temporary)
def dump():
 path='/sdcard/fridge-detail-qa.xml';adb('shell','rm','-f',path)
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
 raise RuntimeError('SCREEN_NOT_READY:'+text)
def click(text,xml=None,prefix=False):
 candidates=[]
 for node in ET.fromstring(xml or dump()).iter('node'):
  label=node.get('content-desc') or node.get('text') or ''
  if node.get('clickable')=='true' and (label.startswith(text) if prefix else label==text):
   x0,y0,x1,y1=map(int,re.findall(r'\d+',node.get('bounds')))
   candidates.append((y0,(x0+x1)//2,(y0+y1)//2))
 if not candidates:raise RuntimeError('CLICK_TARGET_MISSING:'+text)
 _,x,y=min(candidates);adb('shell','input','tap',str(x),str(y))
def capture(name,xml):
 (OUT/(name+'.xml')).write_text(xml,encoding='utf-8')
 (OUT/(name+'.png')).write_bytes(adb('exec-out','screencap','-p'))
def start():
 adb('shell','am','start','-n',PACKAGE+'/.MainActivity');return ready('我的冰箱')
def wait_food(identifier,predicate):
 for _ in range(30):
  state=inventory();food=next((f for f in state['foods'] if f['id']==identifier),None)
  if predicate(food):return state
  time.sleep(.1)
 raise RuntimeError('PERSISTENCE_NOT_CONFIRMED:'+identifier)
def bottom():
 adb('shell','input','swipe','540','1850','540','450','400')
 return ready('误拍了，删除记录')

assert adb('emu','avd','name').decode().splitlines()[0].strip()=='fridge_api35'
assert 'Override density:' not in adb('shell','wm','density').decode()
originals={name:app('cat','files/fridge/'+name) for name in ['inventory.json','inventory.backup.json']}
original=json.loads(originals['inventory.json']);assert len(original['foods'])==3
for name,data in originals.items():(QA/('original-'+name)).write_bytes(data)
fixtures=[];result={}
try:
 adb('shell','am','force-stop',PACKAGE);adb('shell','wm','density','402')
 now=datetime.datetime.now().replace(microsecond=0)
 state=copy.deepcopy(original);state.update(foods=[],reminders=[],nextNumber=15,lastOrganizedAt=now.isoformat(timespec='milliseconds'))
 for number in range(1,15):
  record=copy.deepcopy(original['foods'][0]);identifier=f'{number:03}'
  image=identifier if number in [1,2,3,4,5,9,10,12,13] else {6:'001',7:'002',8:'003',11:'009',14:'012'}[number]
  target='files/fridge/photos/qa-detail-'+identifier+'.image';fixtures.append(target);stage(ASSETS/(image+'.png'),target)
  zone='cold' if number<=8 else 'frozen' if number<=11 else 'pantry'
  record.update(id=identifier,photoPath='/data/user/0/'+PACKAGE+'/'+target,zone=zone,
   remaining='gone' if number==2 else 'full',cycle=1,intervalDays=state['defaults'][zone],
   addedAt=datetime.datetime(2026,11,11-(number-1)%4,10).isoformat(timespec='milliseconds'),
   confirmedAt=datetime.datetime(2026,11,12,10).isoformat(timespec='milliseconds'),dueAt=datetime.datetime(2026,11,14,17,30).isoformat(timespec='milliseconds'))
  state['foods'].append(record)
 fixture=QA/'fixture-inventory.json';fixture.write_text(json.dumps(state),encoding='utf-8')
 stage(fixture,'files/fridge/inventory.json');stage(fixture,'files/fridge/inventory.backup.json')
 xml=start();click('冷藏',xml,prefix=True)
 xml=ready('冷藏区');click('#001',xml,prefix=True)
 xml=ready('替换照片');capture('detail430-top-20261113',xml)
 xml=bottom();capture('detail430-bottom-20261113',xml)
 if args.visual_only:
  adb('shell','input','keyevent','4');adb('shell','input','keyevent','4');xml=ready('我的冰箱');click('设置',xml)
  xml=ready('历史记录');click('历史记录',xml);xml=ready('已移出');capture('history430-20261113',xml)
  adb('shell','am','force-stop',PACKAGE);adb('shell','wm','density','540')
  xml=start();click('冷藏',xml,prefix=True);xml=ready('冷藏区');click('#003',xml,prefix=True)
  xml=ready('替换照片');capture('detail320-top-20261113',xml)
  for _ in range(2):adb('shell','input','swipe','540','1800','540','500','350')
  xml=ready('误拍了，删除记录');capture('detail320-bottom-20261113',xml)
  result['detailTopBottomHistoryAnd320Captured']=True
  raise VisualComplete()
 click('冷藏',xml);xml=ready('冷冻');click('冷冻',xml)
 xml=ready('检查间隔')
 fields=[n for n in ET.fromstring(xml).iter('node') if n.get('class')=='android.widget.EditText']
 assert len(fields)==1
 x0,y0,x1,y1=map(int,re.findall(r'\d+',fields[0].get('bounds')))
 adb('shell','input','tap',str((x0+x1)//2),str((y0+y1)//2));adb('shell','input','keyevent','123')
 adb('shell','input','keyevent','67');adb('shell','input','text','7');adb('shell','input','keyevent','4')
 xml=bottom();capture('detail430-edited-20261113',xml);click('保存修改',xml)
 ready('冷藏区');saved=wait_food('001',lambda f:f['zone']=='frozen' and f['intervalDays']==7)
 before={f['id']:f for f in state['foods']};after={f['id']:f for f in saved['foods']}
 assert all(before['001'][key]==after['001'][key] for key in ['dueAt','addedAt','cycle','confirmedAt'])
 assert all(before[k]==after[k] for k in before if k!='001')
 result['editPersistedWithoutChangingCurrentReminderOrOtherRecords']=True
 adb('shell','input','keyevent','4');xml=ready('我的冰箱');click('设置',xml)
 xml=ready('历史记录');click('历史记录',xml);xml=ready('已移出')
 capture('history430-20261113',xml);click('恢复',xml)
 xml=ready('还没有历史记录');capture('history430-empty-20261113',xml)
 restored=wait_food('002',lambda f:f['remaining']=='full' and f['cycle']==2)
 restored_food=next(f for f in restored['foods'] if f['id']=='002')
 assert datetime.datetime.fromisoformat(restored_food['dueAt'])>now
 assert next(f for f in restored['foods'] if f['id']=='001')==after['001']
 result['restorePersistedNewCycleAndLeftEditedRecordUnchanged']=True
 click('在库',xml,prefix=True);xml=ready('#001');click('#001',xml,prefix=True)
 ready('替换照片');xml=bottom();click('误拍了，删除记录',xml)
 xml=ready('确定永久删除');capture('detail430-delete-confirm-20261113',xml);click('取消',xml)
 xml=ready('误拍了，删除记录');assert any(f['id']=='001' for f in inventory()['foods'])
 result['deleteCancelPreservedRecord']=True
 click('误拍了，删除记录',xml);xml=ready('确定永久删除');click('永久删除',xml)
 ready('食材记录');deleted=wait_food('001',lambda f:f is None)
 assert [f for f in restored['foods'] if f['id']!='001']==deleted['foods']
 assert not any(f['id']=='001' for f in json.loads(app('cat','files/fridge/inventory.backup.json'))['foods'])
 photo_check=subprocess.run([ADB,'-s',SERIAL,'shell','run-as',PACKAGE,'ls','files/fridge/photos/qa-detail-001.image'],capture_output=True)
 assert photo_check.returncode!=0 and b'No such file' in photo_check.stdout+photo_check.stderr
 result['permanentDeleteRemovedOnlySelectedRecordBackupAndPhoto']=True
 adb('shell','am','force-stop',PACKAGE);adb('shell','wm','density','540')
 xml=start();click('冷藏',xml,prefix=True);xml=ready('冷藏区');click('#003',xml,prefix=True)
 xml=ready('替换照片');capture('detail320-top-20261113',xml)
 for _ in range(2):adb('shell','input','swipe','540','1800','540','500','350')
 xml=ready('误拍了，删除记录');capture('detail320-bottom-20261113',xml)
 result['narrowDetailDeleteAccessible']=True
 print(json.dumps(result))
except VisualComplete:
 pass
finally:
 adb('shell','wm','density','reset');adb('shell','am','force-stop',PACKAGE)
 for name in originals:stage(QA/('original-'+name),'files/fridge/'+name)
 for target in fixtures:
  assert re.fullmatch(r'files/fridge/photos/qa-detail-\d{3}\.image',target);app('rm','-f',target)
 start();restored_original=inventory()
 assert restored_original['foods']==original['foods'] and restored_original['nextNumber']==original['nextNumber']
 result['originalThreeRecordsAndDensityRestored']=True
 result['apkSha256']=hashlib.sha256((ROOT/'06-project/app/apps/fridge/build/app/outputs/flutter-apk/app-debug.apk').read_bytes()).hexdigest()
 (OUT/('detail-history-visual-results.json' if args.visual_only else 'detail-history-native-results.json')).write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
 print('Restored original QA inventory and density420')
