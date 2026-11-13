import test from 'node:test';
import assert from 'node:assert/strict';
import {createMiniReminderClient,cancelStoredMiniReminders} from '../src/reminders';
import type {MiniReminderDriver} from '../src/reminders';

test('installed official candidate shares auth keys but retains cancellation capability outside session cleanup',async()=>{
  const values=new Map<string,string>([['fridge.platform.v1:fl_session_token','test-access']]),requests:Parameters<MiniReminderDriver['request']>[0][]=[];
  let random=0,sealed=false;
  const driver:MiniReminderDriver={getStorageSync:key=>{if(sealed && key.startsWith('fridge.platform.v1:'))throw Error('sealed');return values.get(key);},
    setStorageSync:(key,value)=>{values.set(key,value);},removeStorageSync:key=>{values.delete(key);},
    randomBytes:async length=>new Uint8Array(length).fill(++random),request:input=>{
      requests.push(input);const body=input.data as Record<string,unknown>;
      input.success({statusCode:200,data:input.url.endsWith('/revoke')?{revoked:true}:input.url.endsWith('/config')?
        {configured:true,templateId:'template-one',requiresWechatSession:true,allowanceSource:'client-observation'}:
        {id:'b'.repeat(64),revision:body.revision,templateId:'template-one',revoked:false,observedAcceptances:0,
          timezone:body.timezone,language:body.language,days:body.days}});
    }};
  const config={enabled:true,baseUrl:'https://platform.test',clientId:'fenleng-fridge-miniapp'};
  const {sdk,plan}=createMiniReminderClient(config,driver);await plan.prepare();assert.equal(requests.length,0);
  assert.equal((await sdk.configuration()).configured,true);
  await plan.sync({timezone:'Asia/Shanghai',language:'zh_CN',days:[{day:'2026-11-13',fireAt:'2026-11-13T09:00:00Z',count:3}]});
  assert.equal(requests[1].header.Authorization,'Bearer test-access');assert.ok(values.has('fridge.reminders.v1:plan'));
  values.delete('fridge.platform.v1:fl_session_token');sealed=true;
  await createMiniReminderClient(config,driver).plan.revoke();assert.equal(requests[2].header.Authorization,undefined);
  assert.equal(JSON.parse(values.get('fridge.reminders.v1:plan')!).capability,null);
});
test('disabled reminder factory performs no storage crypto or network work',()=>{
  const forbidden=()=>{throw Error('must not be called');};
  assert.throws(()=>createMiniReminderClient({enabled:false,baseUrl:'https://platform.test',clientId:'fenleng-fridge-miniapp'},
    {getStorageSync:forbidden,setStorageSync:forbidden,removeStorageSync:forbidden,request:forbidden,randomBytes:forbidden}),/loginNotConfigured/);
});
test('cleanup before reconsent needs neither configured endpoint nor crypto when no capability exists',async()=>{
  const no=()=>{throw Error('must not run');};
  assert.deepEqual(await cancelStoredMiniReminders({baseUrl:''},{getStorageSync:()=>undefined,
    setStorageSync:no,removeStorageSync:no,request:no,randomBytes:no}),{revoked:true});
});
