import test from 'node:test';
import assert from 'node:assert/strict';
import {addFood,emptyInventory,type InventoryState} from '@fridge/domain';
import {FridgeController,InventoryRepository} from '../src/index';
import type {PreferencesPort,PrivacyRecord,MediaPort} from '@fridge/platform-contracts';
function fixture() {
  const now=new Date('2026-11-13T12:00:00Z');
  let consent:PrivacyRecord|null={policyVersion:'V0.4',acceptedAt:now.toISOString()};
  let pending=false,failBegin=false,failCleanup=false,loads=0,cleanups=0;
  const data=addFood(emptyInventory(),'001','private/photo.jpg','cold',now);
  const storage={state:data,async load(){loads++;return this.state;},async save(value:InventoryState){this.state=value;}};
  const prefs:PreferencesPort={async readPrivacy(){return consent;},async writePrivacy(value){consent=value;},
    async readDisplay(){return {locale:'ar',theme:'dark'};},async writeDisplay(){},
    async readWithdrawalPending(){return pending;},async beginWithdrawal(){if(failBegin)throw new Error('QUOTA');pending=true;},async finishWithdrawal(){pending=false;}};
  const media:MediaPort={attachCamera(){},async chooseAlbum(){return [];},async takePhoto(){return '';},async persist(path){return path;},async removeManaged(){throw new Error('SAVED_PHOTO_MUST_STAY');}};
  const create=()=>{
    const controller=new FridgeController(new InventoryRepository(storage,()=>now),prefs,media,()=>now);
    controller.setPrivacyCleanup(async()=>{cleanups++;if(failCleanup)throw new Error('CLEANUP_FAILED');});
    return controller;
  };
  return {create,storage,prefs,pending:()=>pending,consent:()=>consent,loads:()=>loads,cleanups:()=>cleanups,
    failCleanup:(value:boolean)=>{failCleanup=value;},failBegin:(value:boolean)=>{failBegin=value;}};
}
test('withdraw is single flight, blocks online state immediately, preserves stock/display and allows reconsent',async()=>{
  const f=fixture(),c=f.create();try {
    await c.initialize();const before=JSON.stringify(f.storage.state);
    c.navigate({name:'legal',document:'privacy'});c.requestPrivacyWithdrawal();assert.equal(c.snapshot().privacyWithdrawalRequested,true);
    c.cancelPrivacyWithdrawal();assert.equal(f.cleanups(),0);assert.notEqual(f.consent(),null);
    const one=c.withdraw(),two=c.withdraw();assert.equal(one,two);assert.equal(c.snapshot().stage,'withdrawing');
    await one;assert.equal(c.snapshot().stage,'consent');assert.equal(f.consent(),null);assert.equal(f.pending(),false);
    assert.equal(JSON.stringify(f.storage.state),before);assert.equal(c.snapshot().locale,'ar');assert.equal(c.snapshot().theme,'dark');
    await c.accept();assert.equal(c.snapshot().stage,'ready');assert.equal(JSON.stringify(f.storage.state),before);assert.equal(f.cleanups(),1);
  } finally {c.close();}
});
test('durable pending cleanup is recovered before inventory read; failed cleanup has no acceptance bypass',async()=>{
  const f=fixture();f.failCleanup(true);let c=f.create();await c.initialize();await c.withdraw();
  assert.equal(c.snapshot().stage,'withdrawal-error');assert.equal(f.pending(),true);c.close();
  const loads=f.loads();c=f.create();try {
    await c.initialize();assert.equal(c.snapshot().stage,'withdrawal-error');assert.equal(f.loads(),loads);
    await c.accept();assert.equal(c.snapshot().stage,'withdrawal-error');
    f.failCleanup(false);await c.withdraw();assert.equal(c.snapshot().stage,'consent');assert.equal(f.pending(),false);
    assert.equal(f.loads(),loads);
  } finally {c.close();}
});
test('failed initial marker write stops this process and is retryable without changing stock',async()=>{
  const f=fixture(),c=f.create();try {
    await c.initialize();f.failBegin(true);await c.withdraw();assert.equal(c.snapshot().stage,'withdrawal-error');
    assert.equal(f.pending(),false);assert.notEqual(f.consent(),null);assert.equal(f.cleanups(),0);
    f.failBegin(false);await c.withdraw();assert.equal(c.snapshot().stage,'consent');
  } finally {c.close();}
});
test('preconsent and terms reading cannot request withdrawal',async()=>{
  const f=fixture();await f.prefs.writePrivacy(null);const c=f.create();try {
    await c.initialize();c.navigate({name:'legal',document:'privacy'});c.requestPrivacyWithdrawal();assert.equal(c.snapshot().privacyWithdrawalRequested,false);
    await c.accept();c.navigate({name:'legal',document:'terms'});c.requestPrivacyWithdrawal();assert.equal(c.snapshot().privacyWithdrawalRequested,false);
  } finally {c.close();}
});
