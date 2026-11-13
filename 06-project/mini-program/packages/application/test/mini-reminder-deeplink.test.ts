import test from 'node:test';
import assert from 'node:assert/strict';
import {addFood,emptyInventory,type InventoryState} from '@fridge/domain';
import {FridgeController,InventoryRepository} from '../src/index';
import type {PreferencesPort,MediaPort} from '@fridge/platform-contracts';

function fixture(accepted=true,gone=false) {
  const now=new Date('2026-11-13T18:00:00Z');
  const food=addFood(emptyInventory(),'001','private/one.jpg','cold',new Date('2026-11-10T12:00:00Z'));
  let stored:InventoryState={...food,foods:{'001':{...food.foods['001'],dueAt:'2026-11-13T09:00:00Z',remaining:gone?'gone':'full'}}};
  let privacy=accepted?{policyVersion:'V0.4',acceptedAt:now.toISOString()}:null,loads=0;
  const prefs:PreferencesPort={async readPrivacy(){return privacy;},async writePrivacy(value){privacy=value;},
    async readDisplay(){return {locale:null,theme:'system'};},async writeDisplay(){},async beginWithdrawal(){},async finishWithdrawal(){}};
  const media:MediaPort={attachCamera(){},async chooseAlbum(){return [];},async takePhoto(){return '';},async persist(path){return path;},async removeManaged(){}};
  const repo=new InventoryRepository({async load(){loads++;return stored;},async save(value){stored=value;}},()=>now);
  const controller=new FridgeController(repo,prefs,media,()=>now);controller.setPrivacyCleanup(async()=>{});
  return {controller,loads:()=>loads};
}
test('cold message link waits for consent and loads the current due cycle before opening review',async()=>{
  const f=fixture(false);try {
    await f.controller.requestReminderDay('2026-11-13');await f.controller.initialize();assert.equal(f.loads(),0);
    await f.controller.accept();assert.deepEqual(f.controller.snapshot().route,{name:'review',day:'2026-11-13'});
    assert.deepEqual(f.controller.reviewFoods().map(food=>food.id),['001']);
  }finally {f.controller.close();}
});
test('stale message with no remaining work opens reminder history instead of a false completed checklist',async()=>{
  const f=fixture(true,true);try {await f.controller.initialize();await f.controller.requestReminderDay('2026-11-13');
    assert.deepEqual(f.controller.snapshot().route,{name:'reminders'});
  }finally {f.controller.close();}
});
test('malformed and future links are ignored and duplicate load or show events add no duplicate back entry',async()=>{
  const f=fixture();try {
    await f.controller.initialize();await f.controller.requestReminderDay('2026-02-30');await f.controller.requestReminderDay('2099-01-01');
    assert.deepEqual(f.controller.snapshot().route,{name:'home'});
    await Promise.all([f.controller.requestReminderDay('2026-11-13'),f.controller.requestReminderDay('2026-11-13')]);
    f.controller.back();assert.deepEqual(f.controller.snapshot().route,{name:'home'});
  }finally {f.controller.close();}
});
