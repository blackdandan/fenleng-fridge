// Runs the actual pure .ets rules/coordinator in V8. This is NOT ArkTS/HAP compilation.
import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {readFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const require=createRequire(new URL('../../web/package.json',import.meta.url));
const {build}=require('esbuild');
const directory=fileURLToPath(new URL('../apps/fridge/ohos/entry/src/main/ets/reminders/',import.meta.url));
const bundle=await build({stdin:{contents:`export * from './ReminderPlan';export * from './ReminderCoordinator';`,resolveDir:directory,loader:'ts'},
  bundle:true,write:false,format:'esm',platform:'node',plugins:[{name:'ets',setup(builder){
    builder.onResolve({filter:/^\.\//},args=>({path:path.resolve(args.resolveDir,args.path+'.ets')}));
    builder.onLoad({filter:/\.ets$/},async args=>({contents:await readFile(args.path,'utf8'),loader:'ts',resolveDir:path.dirname(args.path)}));
  }}]});
const {ReminderState,ReminderCoordinator,makeBatches,validDay,cycleTime}=await import('data:text/javascript;base64,'+Buffer.from(bundle.outputFiles[0].text).toString('base64'));
const copy={title:'Check',body:'Check {count}',channel:'Reminders',locale:'en'};
const now=new Date(2030,0,1,8).getTime();
function cycle(key='a',hour=9,day='2030-01-01'){return {key,day,hour,minute:0,second:0,millisecond:0};}
function clone(value){return structuredClone(value);}
function fixture(){
  let state=new ReminderState();state.enabled=true;
  const f={writes:[],os:[],published:[],cancelled:[],cards:[],allowed:true,authorized:true,limit:30,failWrite:false,failPublish:false,next:1,
    load:()=>clone(state),save:s=>{state=clone(s);}};
  const storage={read:()=>clone(state),write:async s=>{if(f.failWrite)throw Error('WRITE');state=clone(s);f.writes.push(clone(s));}};
  const system={authorized:async()=>f.authorized,capacity:()=>f.limit,list:async()=>clone(f.os),
    publish:async batch=>{if(f.failPublish)throw Error('NATIVE');assert.ok(state.intent,'intent is durable before publish');
      const osId=f.next++;f.published.push(clone(batch));f.os.push({osId,batch:clone(batch)});if(f.afterPublish)await f.afterPublish();return osId;},
    cancel:async id=>{f.cancelled.push(id);f.os=f.os.filter(r=>r.osId!==id);},cancelCard:async day=>{f.cards.push(day);},
    updateCard:async batch=>{f.updated??=[];f.updated.push(clone(batch));}};
  f.coordinator=new ReminderCoordinator(storage,system,()=>f.allowed,(n,locale)=>new Intl.NumberFormat(locale).format(n));
  return f;
}
test('real calendar validation rejects normalization, missing values and duplicate cycles',()=>{
  assert.equal(validDay('2030-02-29'),false);assert.equal(validDay('2032-02-29'),true);
  for(const c of [{...cycle(),hour:24},{...cycle(),millisecond:1001},{...cycle(),key:''}])assert.throws(()=>cycleTime(c));
  assert.throws(()=>makeBatches([cycle(),cycle()],[],copy,now));
  assert.throws(()=>makeBatches([cycle()],[],{...copy,body:'missing'},now));
});
test('same day separate instants share card ID with cumulative counts, no early trigger',()=>{
  const first={...cycle('a'),millisecond:1};const batches=makeBatches([first,cycle('b',10)],[],copy,now);
  assert.equal(batches.length,2);assert.equal(batches[0].at,new Date(2030,0,1,9,0,1).getTime());
  assert.deepEqual(batches.map(b=>b.count),[1,2]);assert.equal(batches[0].notificationId,batches[1].notificationId);
});
test('overdue cycles coalesce per day; visited cycles count without being re-alerted',()=>{
  const cs=[cycle('a',6),cycle('b',7),cycle('c',9)];
  const batches=makeBatches(cs,['a'],copy,now);
  assert.equal(batches.length,2);assert.deepEqual(batches[0].keys,['b']);assert.equal(batches[0].count,2);
  assert.ok(batches[0].at>now);assert.equal(batches[1].count,3);
});
test('formatting is supplied by native locale formatter; click metadata is calendar only',()=>{
  const batches=makeBatches([cycle()],[],{...copy,locale:'ar'},now,(n,l)=>new Intl.NumberFormat(l).format(n));
  assert.equal(batches[0].content,'Check '+new Intl.NumberFormat('ar').format(1));assert.equal(batches[0].day,'2030-01-01');
});
test('consent fence and full validation precede every native mutation',async()=>{
  const f=fixture();f.allowed=false;await assert.rejects(f.coordinator.sync([cycle()],copy,now),/CONSENT/);
  f.allowed=true;await assert.rejects(f.coordinator.sync([cycle(),cycle()],copy,now),/INVALID/);
  assert.equal(f.published.length+f.cancelled.length+f.writes.length,0);
});
test('ordinary identical sync preserves exact native requests without duplicate publication',async()=>{
  const f=fixture();await f.coordinator.sync([cycle(),cycle('b',10)],copy,now);
  await f.coordinator.sync([cycle(),cycle('b',10)],copy,now+30000);
  assert.equal(f.published.length,2);assert.equal(f.cancelled.length,0);
});
test('OS-consumed old cycle is ledgered and undo does not republish it',async()=>{
  const f=fixture();await f.coordinator.sync([cycle()],copy,now);f.os=[];
  await f.coordinator.sync([],copy,now+7200000);
  assert.deepEqual(f.load().seen,['a']);await f.coordinator.sync([cycle()],copy,now+7200000);
  assert.equal(f.published.length,1);
});
test('removing a future cycle cancels it without marking it delivered; restore can schedule',async()=>{
  const f=fixture();await f.coordinator.sync([cycle()],copy,now);await f.coordinator.sync([],copy,now+1000);
  assert.deepEqual(f.load().seen,[]);assert.equal(f.cancelled.length,1);assert.deepEqual(f.cards,['2030-01-01']);
  await f.coordinator.sync([cycle()],copy,now+2000);assert.equal(f.published.length,2);
});
test('window capacity bounds native requests and flags deferred items',async()=>{
  const f=fixture();f.limit=1;await f.coordinator.sync([cycle(),cycle('b',10)],copy,now);
  assert.equal(f.published.length,1);assert.equal(f.load().limited,true);
  f.os=[];await f.coordinator.sync([cycle(),cycle('b',10)],copy,now+5400000);
  assert.equal(f.published.length,2);assert.equal(f.load().limited,false);
});
test('disabled OS cancels requests but retains app preference, requested flag and ledger',async()=>{
  const f=fixture();await f.coordinator.sync([cycle()],copy,now);f.authorized=false;
  await f.coordinator.sync([cycle()],copy,now+1000);assert.equal(f.os.length,0);
  assert.equal(f.load().enabled,true);assert.deepEqual(f.load().scheduled,[]);
  f.authorized=true;await f.coordinator.sync([cycle()],copy,now+2000);assert.equal(f.published.length,2);
});
test('durable intent write failure never publishes; native failure retains recovery intent',async()=>{
  const f=fixture();f.failWrite=true;await assert.rejects(f.coordinator.sync([cycle()],copy,now));assert.equal(f.published.length,0);
  f.failWrite=false;f.failPublish=true;await assert.rejects(f.coordinator.sync([cycle()],copy,now));assert.ok(f.load().intent);
  f.failPublish=false;await f.coordinator.sync([cycle()],copy,now+1000);assert.equal(f.published.length,1);
});
test('uncertain publication ACK is adopted instead of publishing twice',async()=>{
  const f=fixture();f.afterPublish=async()=>{f.failWrite=true;};await assert.rejects(f.coordinator.sync([cycle()],copy,now));
  assert.ok(f.load().intent);f.failWrite=false;f.afterPublish=null;
  await f.coordinator.sync([cycle()],copy,now+1000);assert.equal(f.published.length,1);assert.equal(f.load().intent,null);
});
test('withdrawal during native publish cancels late ACK; explicit revoke preserves ledger',async()=>{
  const f=fixture();f.afterPublish=async()=>{f.allowed=false;};await assert.rejects(f.coordinator.sync([cycle()],copy,now),/CONSENT/);
  assert.equal(f.os.length,0);await f.coordinator.clear();assert.equal(f.load().enabled,false);assert.equal(f.load().intent,null);
});
test('unconfirmed due intent is handed off once, not replayed after crash',async()=>{
  const f=fixture();const batch=makeBatches([cycle()],[],copy,now)[0];
  const s=f.load();s.intent=batch;s.cardDays=[batch.day];f.save(s);
  await f.coordinator.sync([cycle()],copy,now+7200000);assert.equal(f.published.length,0);assert.deepEqual(f.load().seen,['a']);
});
test('tap claim is durable and consumed once; invalid day does not overwrite',async()=>{
  const f=fixture();await f.coordinator.receive('2030-01-01');await assert.rejects(f.coordinator.receive('2030-02-29'));
  assert.equal(await f.coordinator.consume(),'2030-01-01');assert.equal(await f.coordinator.consume(),null);
  await f.coordinator.receive('2030-01-02');f.failWrite=true;await assert.rejects(f.coordinator.consume());
  f.failWrite=false;assert.equal(await f.coordinator.consume(),'2030-01-02');
});
test('partial handling updates only remaining due count; future cycles do not count early',async()=>{
  const f=fixture();const cs=[cycle('a',6),cycle('b',7),cycle('future',9)];
  await f.coordinator.sync(cs,copy,now);f.os=[];
  await f.coordinator.sync([cs[1],cs[2]],copy,now+10000);
  assert.equal(f.updated.at(-1).count,1);assert.equal(f.updated.at(-1).content,'Check 1');
});
test('disable still attempts native cancellation on local write failure and reports failure for retry',async()=>{
  const f=fixture();await f.coordinator.sync([cycle()],copy,now);f.failWrite=true;
  await assert.rejects(f.coordinator.clear(),/WRITE/);assert.equal(f.os.length,0);assert.ok(f.cards.length>0);
  f.failWrite=false;await f.coordinator.clear();assert.equal(f.load().enabled,false);
});
