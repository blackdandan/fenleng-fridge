import test from 'node:test';
import assert from 'node:assert/strict';
import {createMiniReminderClient,cancelStoredMiniReminders,type MiniReminderDriver} from '../src/reminders';
import {FridgeController,InventoryRepository,MiniReminderSession} from '../../application/src/index';
import {addFood,emptyInventory,miniReminderCalendar,type InventoryState} from '@fridge/domain';
import type {PreferencesPort,MediaPort} from '@fridge/platform-contracts';

test('actual SDK cancellation gates privacy completion and resumes before inventory or auth access on restart',async()=>{
  const now=new Date('2026-11-13T18:00:00Z'),config={enabled:true,baseUrl:'https://platform.test',clientId:'fenleng-fridge-miniapp'};
  const storage=new Map<string,string>([['fridge.platform.v1:fl_session_token','synthetic-access']]);
  let random=0,sealed=false,cancelFails=true,enabled=false,pending=false,loads=0;
  let privacy:{policyVersion:string;acceptedAt:string}|null={policyVersion:'V0.4',acceptedAt:now.toISOString()};
  const requests:{path:string;body:Record<string,unknown>;authorization:string|undefined}[]=[];
  let stock=addFood(emptyInventory(),'001','private/photo.jpg','cold',new Date('2026-11-10T12:00:00Z'));
  const original=JSON.stringify(stock);
  const driver:MiniReminderDriver={getStorageSync:key=>{
    if(sealed && key.startsWith('fridge.platform.v1:'))throw Error('auth storage must not be accessed');return storage.get(key);
  },setStorageSync:(key,value)=>{storage.set(key,value);},removeStorageSync:key=>{storage.delete(key);},
    randomBytes:async length=>new Uint8Array(length).fill(++random),request:input=>{
      const body=input.data as Record<string,unknown>;requests.push({path:input.url,body,authorization:input.header.Authorization});
      if(input.url.endsWith('/revoke')) {
        if(cancelFails){input.fail({errMsg:'offline'});return;}
        input.success({statusCode:200,data:{revoked:true}});return;
      }
      input.success({statusCode:200,data:input.url.endsWith('/config')?
        {configured:true,templateId:'template-one',requiresWechatSession:true,allowanceSource:'client-observation'}:
        {id:'b'.repeat(64),revision:body.revision,templateId:'template-one',revoked:false,observedAcceptances:0,
          timezone:body.timezone,language:body.language,days:body.days}});
    }};
  const prefs:PreferencesPort={async readPrivacy(){return privacy;},async writePrivacy(value){privacy=value;},
    async readDisplay(){return {locale:'ar',theme:'dark'};},async writeDisplay(){},
    async readWithdrawalPending(){return pending;},async beginWithdrawal(){pending=true;},async finishWithdrawal(){pending=false;}};
  const media:MediaPort={attachCamera(){},async chooseAlbum(){return [];},async takePhoto(){return '';},async persist(path){return path;},async removeManaged(){throw Error('photo must stay');}};
  const create=()=>{
    const repo=new InventoryRepository({async load(){loads++;return stock;},async save(value:InventoryState){stock=value;}},()=>now);
    const controller=new FridgeController(repo,prefs,media,()=>now);
    const reminders=new MiniReminderSession({consent:()=>controller.snapshot().stage==='ready',async accountReady(){return true;},
      calendar:()=>miniReminderCalendar(stock,now,Intl.DateTimeFormat().resolvedOptions().timeZone,'ar'),
      async readEnabled(){return enabled;},async writeEnabled(value){enabled=value;},
      create:()=>{const {sdk,plan}=createMiniReminderClient(config,driver);return {configuration:()=>sdk.configuration(),
        sync:calendar=>plan.sync(calendar),retryObservations:()=>plan.retryObservations(),observe:(template,result)=>plan.observe(template,result),
        requestPermission:async()=> 'accept',revoke:()=>plan.revoke()};},
      cancelStored:()=>cancelStoredMiniReminders(config,driver)});
    controller.setPrivacyCleanup(()=>reminders.cancel());
    return {controller,reminders,close(){controller.close();reminders.close();}};
  };
  let app=create();await app.controller.initialize();await app.reminders.enable();assert.equal(app.reminders.snapshot().phase,'ready');
  const token=JSON.parse(storage.get('fridge.reminders.v1:plan')!).capability;
  sealed=true;await app.controller.withdraw();assert.equal(app.controller.snapshot().stage,'withdrawal-error');assert.equal(pending,true);
  assert.equal(JSON.parse(storage.get('fridge.reminders.v1:plan')!).capability,token);assert.equal(enabled,false);app.close();
  cancelFails=false;const reads=loads;app=create();
  try {
    await app.controller.initialize();assert.equal(app.controller.snapshot().stage,'consent');assert.equal(loads,reads);assert.equal(pending,false);
    assert.equal(JSON.parse(storage.get('fridge.reminders.v1:plan')!).capability,null);
    const cancellations=requests.filter(request=>request.path.endsWith('/revoke'));assert.equal(cancellations.length,2);
    for(const request of cancellations){assert.equal(request.body.cancellationToken,token);assert.equal(request.authorization,undefined);}
    assert.equal(JSON.stringify({...stock,reminders:[]}),original);assert.equal(app.controller.snapshot().theme,'dark');
  }finally {app.close();}
});
