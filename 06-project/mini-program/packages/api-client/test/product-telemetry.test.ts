import test from 'node:test';
import assert from 'node:assert/strict';
import {MiniProductTelemetry} from '../src/product-telemetry';
import {MiniIdentity,type IdentityDriver} from '../src/identity';
import catalog from '../../../apps/miniapp/src/config/telemetry-events.json';

async function fixture(t:{after(fn:()=>Promise<void>):void}) {
  const storage=new Map<string,string>(),requests:Parameters<IdentityDriver['request']>[0][]=[],held:Parameters<IdentityDriver['request']>[0][]=[];
  const timers=new Map<number,()=>void>();let consent=true,enabled=true,mode='ok',keys=0,aborts=0,pauseHook=()=>{};
  const identity=new MiniIdentity({enabled:true,guestEnabled:true,baseUrl:'https://platform.test',clientId:'fenleng-fridge-miniapp'},{
    getStorageSync:key=>storage.get(key),setStorageSync:(key,value)=>{storage.set(key,value);},removeStorageSync:key=>{storage.delete(key);},
    login:async()=>{throw Error('native login must not run');},request:input=>{
      requests.push(input);
      if(!input.url.endsWith('/telemetry/events')){input.success({statusCode:200,data:{accessToken:'synthetic-access',refreshToken:'synthetic-refresh'}});return;}
      if(mode==='hold'){held.push(input);return {abort:()=>{aborts++;}};}
      if(mode==='network'){input.fail({errMsg:'connection failed'});return;}
      const events=(input.data as {events:unknown[]}).events;
      input.success({statusCode:mode==='unauthorized'?401:200,data:mode==='unauthorized'?{code:'AUTHENTICATION_REQUIRED'}:{accepted:mode==='bad-ack'?0:events.length}});
    }});
  const config={enabled,consent:()=>consent,identity:()=>identity,ready:async()=>identity,catalog,
    context:()=>({platform:'mini-program' as const,appVersion:'0.1.0',buildNumber:'1',releaseChannel:'china' as const,locale:'ar'}),
    nextKey:async()=>`fridge-test-batch-${++keys}`,pause:async(ms:number)=>{if(ms===2000)await new Promise(()=>{});else pauseHook();},
    timers:{setTimeout:(fn:()=>void)=>{const key=timers.size+1;timers.set(key,fn);return key;},clearTimeout:(id:unknown)=>{timers.delete(id as number);}}};
  const telemetry=new MiniProductTelemetry(config);
  t.after(async()=>{telemetry.close();await identity.close();});
  return {telemetry,identity,requests,held,timers,config,setConsent:(value:boolean)=>{consent=value;},setMode:(value:string)=>{mode=value;},
    setPause:(fn:()=>void)=>{pauseHook=fn;},telemetryRequests:()=>requests.filter(input=>input.url.endsWith('/telemetry/events')),aborts:()=>aborts};
}
test('no consent means no collection SDK queue timer auth or HTTP; disabled transport remains offline',async t=>{
  const f=await fixture(t);f.setConsent(false);assert.equal(f.telemetry.record('fridge.home.viewed.v1'),false);await f.telemetry.flush();
  assert.equal(f.telemetry.pendingCount,0);assert.equal(f.timers.size,0);assert.equal(f.requests.length,0);
  const disabled=new MiniProductTelemetry({...f.config,enabled:false});
  f.setConsent(true);assert.equal(disabled.record('fridge.home.viewed.v1'),true);assert.equal(await disabled.flush(),0);assert.equal(f.requests.length,0);disabled.close();
});
test('strict product enums reject unknown and sensitive props and capture independent context snapshots',async t=>{
  const f=await fixture(t);
  assert.equal(f.telemetry.record('fridge.home.viewed.v1',{food:'private'}),false);
  assert.equal(f.telemetry.record('unknown.event'),false);assert.equal(f.telemetry.record('fridge.website.preview.opened.v1',{target:'app'}),false);
  assert.equal(f.telemetry.record('fridge.review.updated.v1',{state:'small',zone:'cold'}),false);
  assert.equal(f.telemetry.record('fridge.capture.started.v1',{source:'camera',constructor:'private'}),false);
  const props={state:'little',zone:'cold'};assert.equal(f.telemetry.record('fridge.review.updated.v1',props),true);props.zone='pantry';
  assert.equal(await f.telemetry.flush(),1);const events=(f.telemetryRequests()[0].data as {events:any[]}).events;
  assert.deepEqual(events[0].properties,{state:'little',zone:'cold'});
  assert.deepEqual(events[0].context,{platform:'mini-program',appVersion:'0.1.0',buildNumber:'1',releaseChannel:'china',locale:'ar'});
});
test('bounded retries preserve failed batch key and timestamp while new events wait for the next batch',async t=>{
  const f=await fixture(t);f.setMode('bad-ack');f.telemetry.record('fridge.home.viewed.v1');
  let added=false;f.setPause(()=>{if(!added){added=true;f.telemetry.record('fridge.reminder.opened.v1',{source:'home'});}});
  assert.equal(await f.telemetry.flush(),0);const first=f.telemetryRequests();assert.equal(first.length,3);
  for(const request of first){assert.deepEqual(request.data,first[0].data);assert.equal(request.header['Idempotency-Key'],first[0].header['Idempotency-Key']);}
  assert.equal(f.telemetry.pendingCount,2);f.setMode('ok');assert.equal(await f.telemetry.flush(),1);assert.equal(f.telemetry.pendingCount,1);
  assert.equal(await f.telemetry.flush(),1);assert.equal(f.telemetry.pendingCount,0);
});
test('withdrawing aborts the actual host request and discards late ACK without deleting new-generation events',async t=>{
  const f=await fixture(t);f.setMode('hold');f.telemetry.record('fridge.home.viewed.v1');
  const pending=f.telemetry.flush();
  while(!f.held.length)await new Promise(resolve=>setImmediate(resolve));
  f.setConsent(false);f.telemetry.withdraw();assert.equal(f.aborts(),1);assert.equal(f.telemetry.pendingCount,0);
  f.setConsent(true);f.setMode('ok');f.telemetry.record('fridge.reminder.opened.v1',{source:'notification'});
  f.held[0].success({statusCode:200,data:{accepted:1}});assert.equal(await pending,0);assert.equal(f.telemetry.pendingCount,1);
  assert.equal(await f.telemetry.flush(),1);assert.equal(f.telemetry.pendingCount,0);
});
test('401 clears old queue and invalidates identity rather than retrying under a new guest',async t=>{
  const f=await fixture(t);f.setMode('unauthorized');f.telemetry.record('fridge.home.viewed.v1');
  assert.equal(await f.telemetry.flush(),0);assert.equal(f.telemetryRequests().length,1);assert.equal(f.telemetry.pendingCount,0);
  assert.equal(f.identity.session.snapshot().status,'reauthentication-required');
});
test('queue100 batch50 and single-flight flush remain official SDK responsibilities',async t=>{
  const f=await fixture(t);for(let i=0;i<120;i++)f.telemetry.record('fridge.home.viewed.v1');assert.equal(f.telemetry.pendingCount,100);
  const one=f.telemetry.flush(),two=f.telemetry.flush();assert.equal(one,two);assert.equal(await one,50);assert.equal(f.telemetry.pendingCount,50);
  assert.equal(await f.telemetry.flush(),50);assert.equal(f.telemetryRequests().length,2);assert.equal(f.telemetry.pendingCount,0);
});
test('background flush cancels debounce and schedules no additional background timer',async t=>{
  const f=await fixture(t);f.telemetry.record('fridge.home.viewed.v1');assert.equal(f.timers.size,1);
  await f.telemetry.suspend();assert.equal(f.telemetry.pendingCount,0);assert.equal(f.timers.size,0);
  f.telemetry.record('fridge.home.viewed.v1');assert.equal(f.timers.size,0);f.telemetry.resume();assert.equal(f.timers.size,1);
});
test('withdrawal during token-storage await prevents the old batch from using a replacement session token',async t=>{
  const f=await fixture(t);await f.identity.ensureSession();
  const storage=f.identity.client.storage,read=storage.getItem.bind(storage);
  let entered!:()=>void,release!:()=>void;
  const started=new Promise<void>(resolve=>{entered=resolve;}),blocked=new Promise<void>(resolve=>{release=resolve;});
  storage.getItem=async key=>{if(key===f.identity.client.tokenKey){entered();await blocked;}return read(key);};
  f.telemetry.record('fridge.home.viewed.v1');const pending=f.telemetry.flush();await started;
  f.telemetry.withdraw();await storage.setItem(f.identity.client.tokenKey,'replacement-session-access');release();
  assert.equal(await pending,0);assert.equal(f.telemetryRequests().length,0);assert.equal(f.telemetry.pendingCount,0);
});
