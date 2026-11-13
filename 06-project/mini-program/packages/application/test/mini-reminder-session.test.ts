import test from 'node:test';
import assert from 'node:assert/strict';
import {MiniReminderSession,type MiniReminderSessionPorts,type MiniPermissionResult} from '../src/mini-reminder-session';
import type {MiniReminderCalendar} from '@fridge/domain';
function fixture() {
  const calls:string[]=[],f={consent:true,account:true,enabled:false,configured:true,cancelFail:false,count:3,calls};
  const gateway={async configuration(){calls.push('config');return {configured:f.configured,templateId:f.configured?'template-one':null};},
    async sync(calendar:MiniReminderCalendar){calls.push(`sync:${calendar.days[0]?.count}`);},async retryObservations(){calls.push('retry');return {observedAcceptances:0};},
    async observe(_template:string,result:MiniPermissionResult){calls.push(`observe:${result}`);return {observedAcceptances:result==='accept'?1:0};},
    requestPermission(_template:string):Promise<MiniPermissionResult>{calls.push('native');return Promise.resolve('accept');},
    async revoke(){calls.push('revoke');if(f.cancelFail)throw Error('network');}};
  const ports:MiniReminderSessionPorts={consent:()=>f.consent,async accountReady(){calls.push('account');return f.account;},
    calendar:()=>({timezone:'UTC',language:'en_US',days:[{day:'2026-11-13',fireAt:'2026-11-13T17:30:00Z',count:f.count}]}),
    async readEnabled(){calls.push('read');return f.enabled;},async writeEnabled(value){calls.push(`save:${value}`);f.enabled=value;},
    create(){calls.push('create');return gateway;},async cancelStored(){calls.push('cancel-stored');if(f.cancelFail)throw Error('network');}};
  return Object.assign(f,{gateway,ports,session:new MiniReminderSession(ports)});
}
test('no consent performs no online preparation and guest configuration never implicitly logs in',async()=>{
  const f=fixture();f.consent=false;await f.session.refresh();await f.session.enable();assert.equal(f.calls.length,0);
  f.consent=true;f.account=false;await f.session.enable();assert.equal(f.session.snapshot().phase,'needs-login');
  assert.equal(f.calls.includes('config'),false);assert.equal(f.calls.includes('native'),false);
});
test('configuration and plan are prepared before a direct native click and recorded only after native result',async()=>{
  const f=fixture();await f.session.enable();assert.equal(f.session.snapshot().phase,'ready');assert.ok(f.calls.indexOf('sync:3')>f.calls.indexOf('config'));
  f.calls.length=0;const pending=f.session.requestPermission();assert.deepEqual(f.calls,['native']);await pending;
  assert.deepEqual(f.calls,['native','observe:accept']);assert.equal(f.session.snapshot().messageKey,'miniGranted');
});
test('unconfigured state never presents a fake native dialog',async()=>{
  const f=fixture();f.configured=false;await f.session.enable();assert.equal(f.session.snapshot().phase,'unconfigured');
  await f.session.requestPermission();assert.equal(f.calls.includes('native'),false);assert.equal(f.calls.some(c=>c.startsWith('sync:')),false);
});
test('cancellation failure retains a retryable state and also blocks false privacy completion',async()=>{
  const f=fixture();await f.session.enable();f.cancelFail=true;f.consent=false;
  await assert.rejects(f.session.cancel(),/miniCancelFailed/);assert.equal(f.enabled,false);assert.equal(f.session.snapshot().errorKey,'miniCancelFailed');
  const count=f.calls.length;f.consent=true;await f.session.enable();await f.session.refresh();assert.equal(f.calls.length,count);
  f.cancelFail=false;await f.session.cancel();assert.equal(f.session.snapshot().phase,'off');assert.ok(f.calls.includes('cancel-stored'));
});
test('late permission result after consent loss or account cancellation never records an observation',async()=>{
  const f=fixture();await f.session.enable();let result!:(value:MiniPermissionResult)=>void;
  f.gateway.requestPermission=()=>new Promise(resolve=>{result=resolve;});
  const native=f.session.requestPermission();f.consent=false;f.session.freeze();await f.session.cancel();result('accept');await native;
  assert.equal(f.calls.includes('observe:accept'),false);assert.equal(f.session.snapshot().phase,'off');
});
test('racing enable preference commit is ordered before the final cancellation preference',async()=>{
  const f=fixture();let release!:()=>void,entered!:()=>void;
  const started=new Promise<void>(resolve=>{entered=resolve;});
  f.ports.writeEnabled=async value=>{if(value){entered();await new Promise<void>(resolve=>{release=resolve;});}f.enabled=value;};
  const enabling=f.session.enable();await started;const cancelling=f.session.cancel();release();await Promise.all([enabling,cancelling]);
  assert.equal(f.enabled,false);assert.equal(f.session.snapshot().phase,'off');assert.equal(f.calls.includes('config'),false);
});
test('cold start with disabled preference cancels orphan capability before declaring off',async()=>{
  const f=fixture();f.cancelFail=true;await f.session.refresh();assert.equal(f.session.snapshot().errorKey,'miniCancelFailed');
  f.cancelFail=false;await f.session.cancel();assert.equal(f.session.snapshot().phase,'off');assert.deepEqual(f.calls.slice(0,2),['read','cancel-stored']);
});
test('native acceptance followed by failed observation sync offers outbox retry without another native dialog',async()=>{
  const f=fixture();await f.session.enable();f.gateway.observe=async()=>{throw Error('offline');};
  await f.session.requestPermission();assert.equal(f.session.snapshot().errorKey,'miniSyncFailed');
  await f.session.refresh();assert.equal(f.calls.filter(call=>call==='native').length,1);assert.equal(f.session.snapshot().phase,'ready');
});
test('stock changed during preparation is coalesced and uses the latest calendar without requesting permission',async()=>{
  const f=fixture();let entered!:()=>void,release!:()=>void;
  const started=new Promise<void>(resolve=>{entered=resolve;}),blocked=new Promise<void>(resolve=>{release=resolve;});
  const original=f.gateway.configuration;let first=true;
  f.gateway.configuration=async()=>{if(first){first=false;entered();await blocked;}return original();};
  const enabling=f.session.enable();await started;f.count=8;const refresh=f.session.refresh();release();await Promise.all([enabling,refresh]);
  assert.ok(f.calls.includes('sync:8'));assert.equal(f.calls.includes('sync:3'),false);assert.equal(f.calls.includes('native'),false);
});
