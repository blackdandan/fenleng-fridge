"""Reversible QA state, restricted to the agent-owned isolated emulator."""
import argparse, copy, datetime, json, re, subprocess, time
parser=argparse.ArgumentParser()
parser.add_argument("--empty-only",action="store_true")
options=parser.parse_args()
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
ADB='D:/Documents/Android/Sdk/platform-tools/adb.exe'
SERIAL='emulator-5580'
PACKAGE='com.fenlengtech.fridge'
QA=ROOT/'.fenleng/figma-home-fixtures'
OUT=ROOT/'02-engineering/evidence/android'
def adb(*args):
 return subprocess.run([ADB,'-s',SERIAL,*args],capture_output=True,check=True).stdout
def app(*args): return adb('shell','run-as',PACKAGE,*args)
def stage(local,target):
 temporary='/data/local/tmp/fridge-qa-'+local.name
 adb('push',str(local),temporary)
 app('cp',temporary,target)
 adb('shell','rm',temporary)
def launch():
 import io
 adb('shell','am','start','-n',PACKAGE+'/.MainActivity')
 for _ in range(12):
  time.sleep(.5)
  try:
   adb('shell','rm','-f','/sdcard/fridge-home-fixture.xml')
   output=adb('shell','uiautomator','dump','/sdcard/fridge-home-fixture.xml')
   if b'UI hierchary dumped' not in output: continue
   xml=adb('shell','cat','/sdcard/fridge-home-fixture.xml').decode()
   if '我的冰箱' not in xml: continue
   time.sleep(.7)
   png=adb('exec-out','screencap','-p')
   im=Image.open(io.BytesIO(png)).convert('RGB')
   if sum(count for count,color in im.getcolors(im.width*im.height) if color==(234,240,231))<20000: continue
   return xml
  except subprocess.CalledProcessError: pass
 raise RuntimeError('HOME_NOT_READY')
assert SERIAL=='emulator-5580'
assert adb('emu','avd','name').decode().splitlines()[0].strip()=='fridge_api35', 'Not the isolated QA AVD'
if not options.empty_only: assert (QA/'001.png').exists()
density_text=adb('shell','wm','density').decode()
assert 'Override density:' not in density_text, 'Unexpected override; leave display unchanged'
originals={name:app('cat','files/fridge/'+name) for name in ['inventory.json','inventory.backup.json']}
for name,data in originals.items(): (QA/('original-'+name)).write_bytes(data)
original=json.loads(originals['inventory.json'])
assert len(original['foods'])==3, 'Unexpected QA state; leave it unchanged'
fixtures=[]
try:
 adb('shell','am','force-stop',PACKAGE)
 now=datetime.datetime.now().replace(microsecond=0)
 state=copy.deepcopy(original);state.update(foods=[],reminders=[],nextNumber=15,lastOrganizedAt=now.isoformat())
 for number in ([] if options.empty_only else range(1,15)):
  record=copy.deepcopy(original['foods'][0]);identifier=f'{number:03}'
  image=identifier if number in [1,2,3,4,5,9,10,12,13] else {6:'001',7:'002',8:'003',11:'009',14:'012'}[number]
  target='files/fridge/photos/qa-figma-'+identifier+'.png'
  fixtures.append(target);stage(QA/(image+'.png'),target)
  record.update(id=identifier,photoPath='/data/user/0/'+PACKAGE+'/'+target,
    zone='cold' if number<=8 else 'frozen' if number<=11 else 'pantry',remaining='full',cycle=0,
    addedAt=(now-datetime.timedelta(days=1)).isoformat(),confirmedAt=None,dueAt=(now+datetime.timedelta(days=10)).isoformat())
  state['foods'].append(record)
 if options.empty_only: state.update(nextNumber=1,lastOrganizedAt=None)
 path=QA/'fixture-inventory.json';path.write_text(json.dumps(state),encoding='utf-8')
 stage(path,'files/fridge/inventory.json');stage(path,'files/fridge/inventory.backup.json')
 for profile,density in ([('empty-430',402)] if options.empty_only else [('430',402),('320',540),('800',216)]):
  adb('shell','wm','density',str(density))
  xml=launch()
  if options.empty_only: assert '#001' not in xml
  (OUT/('home-figma-'+profile+'-proof-20261113.xml')).write_text(xml,encoding='utf-8')
  (OUT/('home-figma-'+profile+'-proof-20261113.png')).write_bytes(adb('exec-out','screencap','-p'))
 print('Captured native empty state' if options.empty_only else 'Captured reference-count native home: cold 8, frozen 3, pantry 3')
finally:
 adb('shell','wm','density','reset')
 adb('shell','am','force-stop',PACKAGE)
 for name in originals: stage(QA/('original-'+name),'files/fridge/'+name)
 for target in fixtures:
  assert re.fullmatch(r'files/fridge/photos/qa-figma-\d{3}\.png',target)
  app('rm',target)
 launch()
 restored=json.loads(app('cat','files/fridge/inventory.json'))
 assert restored['foods']==original['foods'] and restored['nextNumber']==original['nextNumber']
 print('Restored original 3 QA records and nextNumber; removed only QA fixture copies')
