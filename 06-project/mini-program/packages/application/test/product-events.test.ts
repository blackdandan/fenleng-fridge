import test from 'node:test';
import assert from 'node:assert/strict';
import {emptyInventory,type InventoryState} from '@fridge/domain';
import {FeedbackSession,FridgeController,InventoryRepository,MiniReminderSession,type ProductEventSink} from '../src/index';
import type {PreferencesPort,MediaPort} from '@fridge/platform-contracts';

test('real controller emits committed record/review/entry events with enums and no photo path or identifier',async()=>{
  const now=new Date('2026-11-13T10:00:00Z');let state:InventoryState=emptyInventory(),fail=false;
  const events:{event:string;properties:Readonly<Record<string,string>>}[]=[];
  const prefs:PreferencesPort={async readPrivacy(){return {policyVersion:'V0.4',acceptedAt:now.toISOString()};},async writePrivacy(){},
    async readDisplay(){return {locale:null,theme:'system'};},async writeDisplay(){}};
  const media:MediaPort={attachCamera(){},async takePhoto(){return 'private-camera-photo.jpg';},async chooseAlbum(){return ['private-album-photo.jpg'];},
    async persist(){return 'private-managed-photo.jpg';},async removeManaged(){}};
  const controller=new FridgeController(new InventoryRepository({async load(){return state;},async save(next){if(fail)throw Error('private filesystem error');state=next;}},()=>now),prefs,media,()=>now);
  controller.setEventSink((event,properties)=>{events.push({event,properties});});
  try {
    controller.recordEvent('fridge.home.viewed.v1');assert.equal(events.length,0);await controller.initialize();
    controller.recordEvent('fridge.home.viewed.v1');controller.openCamera('cold');fail=true;await controller.capture();
    assert.deepEqual(events.map(item=>item.event),['fridge.home.viewed.v1','fridge.capture.started.v1','fridge.inventory.added.v1']);
    assert.deepEqual(events[2].properties,{source:'camera',zone:'cold',result:'save_failed'});assert.equal(state.nextNumber,1);
    fail=false;await controller.retryCapture();assert.equal(state.nextNumber,2);
    assert.deepEqual(events.at(-1)?.properties,{source:'camera',zone:'cold',result:'success'});
    await controller.finishCapture();await controller.organize('001','small');
    assert.deepEqual(events.at(-1)?.properties,{state:'little',zone:'cold'});
    controller.navigate({name:'reminders'});assert.deepEqual(events.at(-1)?.properties,{source:'home'});
    const payload=JSON.stringify(events);assert.ok(!payload.includes('photo.jpg'));assert.ok(!payload.includes('001'));assert.ok(!payload.includes('filesystem'));
  }finally {controller.close();}
});
test('feedback success requires durable ACK and storage failure reports no false success or message text',async()=>{
  const events:Readonly<Record<string,string>>[]=[];let fail=true,consent=true;
  const session=new FeedbackSession({async load(){return {text:'private feedback body',key:null,receipt:null};},async save(value){if(fail && value.receipt)throw Error('disk');}},
    {async submit(){return 'receipt-one';}},()=>consent,()=> 'feedback-intent-one',(_name,properties)=>{events.push(properties);});
  await session.start();await session.submit();assert.deepEqual(events,[{result:'storage_failed'}]);
  fail=false;await session.submit();assert.deepEqual(events,[{result:'storage_failed'},{result:'success'}]);
  consent=false;await session.submit();assert.equal(events.length,2);assert.ok(!JSON.stringify(events).includes('private'));
  await session.close();
});
test('subscription native result is recorded once even if observation delivery is retried later',async()=>{
  const events:{name:string;properties:Readonly<Record<string,string>>}[]=[];
  const sink:ProductEventSink=(name,properties)=>{events.push({name,properties});};
  const gateway={async configuration(){return {configured:true,templateId:'template-one'};},async sync(){},async retryObservations(){return {observedAcceptances:1};},
    async observe(){throw Error('network');},async requestPermission(){return 'accept' as const;},async revoke(){}};
  const session=new MiniReminderSession({consent:()=>true,events:sink,async accountReady(){return true;},
    calendar:()=>({timezone:'UTC',language:'en_US',days:[]}),async readEnabled(){return true;},async writeEnabled(){},create:()=>gateway,async cancelStored(){}});
  await session.enable();await session.requestPermission();assert.equal(session.snapshot().errorKey,'miniSyncFailed');
  await session.refresh();assert.deepEqual(events,[{name:'fridge.permission.resolved.v1',properties:{permission:'notifications',result:'granted'}}]);session.close();
});
