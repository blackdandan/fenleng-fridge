// Executes actual .ets bridge/storage/system sources against explicit native API fakes.
// Type erasure by esbuild is not an ArkTS compiler or a device permission test.
import test from 'node:test';import assert from 'node:assert/strict';
import {createRequire} from 'node:module';import {readFile} from 'node:fs/promises';
import path from 'node:path';import {fileURLToPath} from 'node:url';
const require=createRequire(new URL('../../web/package.json',import.meta.url));const {build}=require('esbuild');
const directory=fileURLToPath(new URL('../apps/fridge/ohos/entry/src/main/ets/reminders/',import.meta.url));
const output=await build({stdin:{contents:`export {default as ReminderBridge} from './ReminderBridge';export * from './ReminderNative';`,resolveDir:directory,loader:'ts'},
 bundle:true,write:false,format:'esm',platform:'node',plugins:[{name:'native-fakes',setup(b){
  b.onResolve({filter:/^@ohos/},a=>({path:a.path,namespace:'native'}));
  b.onLoad({filter:/.*/,namespace:'native'},a=>{
   if(a.path==='@ohos.data.preferences')return {contents:`export default {getPreferencesSync(){globalThis.harmonyNative.openCount++;return globalThis.harmonyNative.preferences;}}`,loader:'js'};
   if(a.path==='@ohos.reminderAgentManager')return {contents:`export default globalThis.harmonyNative.agent;`,loader:'js'};
   if(a.path==='@ohos.notificationManager')return {contents:`export default globalThis.harmonyNative.notifications;`,loader:'js'};
   if(a.path==='@ohos.intl')return {contents:`export default {NumberFormat:Intl.NumberFormat};`,loader:'js'};
   if(a.path==='@ohos.deviceInfo')return {contents:`export default {sdkApiVersion:26};`,loader:'js'};
   if(a.path==='@ohos.app.ability.wantAgent')return {contents:`export default {OperationType:{START_ABILITY:1},WantAgentFlags:{UPDATE_PRESENT_FLAG:1},getWantAgent:async value=>value};`,loader:'js'};
   if(a.path.endsWith('/MethodChannel'))return {contents:`export default class Channel {constructor(_,name){this.name=name;globalThis.harmonyNative.channels.push(this);}setMethodCallHandler(handler){this.handler=handler;}invokeMethod(name,args){globalThis.harmonyNative.hints.push({name,args});}}`,loader:'js'};
   throw Error('Unexpected runtime native import: '+a.path);
  });
  b.onResolve({filter:/^\.\//},a=>({path:path.resolve(a.resolveDir,a.path+'.ets')}));
  b.onLoad({filter:/\.ets$/},async a=>({contents:await readFile(a.path,'utf8'),loader:'ts',resolveDir:path.dirname(a.path)}));
 }}]});
const runtime={openCount:0,channels:[],hints:[],values:new Map(),valid:[],requests:[],cancelled:[],cards:[],enabled:true,requestCount:0,settingsCount:0,failFlush:false,next:1};
runtime.preferences={getSync:(k,f)=>runtime.values.get(k)??f,putSync:(k,v)=>runtime.values.set(k,v),flush:async()=>{if(runtime.failFlush)throw Error('disk');}};
runtime.agent={ReminderType:{REMINDER_TYPE_CALENDAR:1},getAllValidReminders:async()=>runtime.valid,
 publishReminder:async reminderReq=>{const reminderId=runtime.next++;runtime.requests.push(reminderReq);runtime.valid.push({reminderId,reminderReq});return reminderId;},
 cancelReminder:async id=>{runtime.cancelled.push(id);runtime.valid=runtime.valid.filter(r=>r.reminderId!==id);}};
runtime.notifications={SlotType:{SERVICE_INFORMATION:2},ContentType:{NOTIFICATION_CONTENT_BASIC_TEXT:0},
 getActiveNotifications:async()=>runtime.active||[],publish:async req=>{runtime.cardUpdates??=[];runtime.cardUpdates.push(req);},isNotificationEnabled:async()=>runtime.enabled,
 requestEnableNotification:async()=>{runtime.requestCount++;},openNotificationSettings:async()=>{runtime.settingsCount++;},cancel:async id=>{runtime.cards.push(id);}};
globalThis.harmonyNative=runtime;
const {ReminderBridge,NativeReminderStorage,NativeReminderSystem}=await import('data:text/javascript;base64,'+Buffer.from(output.outputFiles[0].text).toString('base64'));
const context={abilityInfo:{bundleName:'com.fenlengtech.fridge'}};
const engine={getDartExecutor:()=>({getBinaryMessenger:()=>({})})};
function reset(){runtime.values.clear();runtime.channels=[];runtime.hints=[];runtime.valid=[];runtime.requests=[];runtime.cancelled=[];runtime.cards=[];runtime.active=[];runtime.cardUpdates=[];runtime.failFlush=false;runtime.enabled=true;runtime.openCount=0;runtime.requestCount=0;}
function invoke(bridge,method,args={}){return new Promise((resolve,reject)=>bridge.onMethodCall({method,argument:k=>args[k]},
 {success:resolve,error:code=>reject(Error(code)),notImplemented:()=>reject(Error('NOT_IMPLEMENTED'))}));}
function cycle(){const date=new Date(Date.now()+3600000),pad=n=>String(n).padStart(2,'0');return new Map(Object.entries({key:'private-cycle',
 day:`${date.getFullYear()}-${pad(date.getMonth()+1)}-${pad(date.getDate())}`,hour:date.getHours(),minute:date.getMinutes(),second:date.getSeconds(),millisecond:0}));}
function copy(){return new Map(Object.entries({title:'Check',body:'Check {count}',channel:'Reminders',locale:'en'}));}
test('constructor and early tap do not access preferences, permissions, plugins or channel before authorize',async()=>{
 reset();const bridge=new ReminderBridge(context,engine);bridge.receive('fridge://reminders/2030-01-01');
 assert.equal(runtime.openCount,0);assert.equal(runtime.channels.length,0);assert.equal(runtime.requestCount,0);
 await bridge.authorize();assert.equal(runtime.openCount,1);assert.equal(await invoke(bridge,'consumeTap'),'2030-01-01');
 assert.equal(await invoke(bridge,'consumeTap'),null);assert.equal(runtime.hints.length,1);
});
test('actual bridge decodes Flutter codec maps and publishes calendar with day-only click URI',async()=>{
 reset();const bridge=new ReminderBridge(context,engine);await bridge.authorize();
 await invoke(bridge,'request');await invoke(bridge,'enable',{enabled:true});await invoke(bridge,'sync',{cycles:[cycle()],copy:copy()});
 assert.equal(runtime.requestCount,1);assert.equal(runtime.requests.length,1);
 const req=runtime.requests[0];assert.equal(req.wantAgent.pkgName,'com.fenlengtech.fridge');
 assert.match(req.wantAgent.uri,/^fridge:\/\/reminders\/\d{4}-\d{2}-\d{2}$/);
 assert.equal(JSON.stringify(req).includes('private-cycle'),false);assert.equal(req.notificationId,Number(req.wantAgent.uri.slice(-10).replaceAll('-','')));
 await invoke(bridge,'sync',{cycles:[cycle()],copy:copy()});assert.equal(runtime.requests.length,1);
});
test('native status reflects actual denial separately from requested and enabled',async()=>{
 reset();runtime.enabled=false;const bridge=new ReminderBridge(context,engine);await bridge.authorize();
 const status=await invoke(bridge,'request');assert.equal(status.get('authorized'),false);assert.equal(status.get('requested'),true);
 await assert.rejects(invoke(bridge,'enable',{enabled:true}));assert.equal(runtime.requests.length,0);
});
test('native storage preserves corrupt ledger and rolls back in-memory write on flush failure',async()=>{
 reset();const storage=new NativeReminderStorage(context);runtime.values.set('state','broken');
 assert.throws(()=>storage.read(),/STORE_INVALID/);assert.equal(runtime.values.get('state'),'broken');
 runtime.values.delete('state');const state=storage.read();runtime.failFlush=true;state.enabled=true;
 await assert.rejects(storage.write(state),/WRITE_FAILED/);assert.equal(runtime.values.get('state'),'');
});
test('native list scopes cancellation to this feature and recovers intent after publish-before-ACK crash',async()=>{
 reset();const bridge=new ReminderBridge(context,engine);await bridge.authorize();await invoke(bridge,'enable',{enabled:true});
 await invoke(bridge,'sync',{cycles:[cycle()],copy:copy()});
 const saved=JSON.parse(runtime.values.get('state'));saved.intent=saved.scheduled[0].batch;saved.scheduled=[];runtime.values.set('state',JSON.stringify(saved));
 runtime.valid.push({reminderId:999,reminderReq:{wantAgent:{pkgName:'other',uri:'fridge://reminders/2030-01-01'}}});
 await invoke(bridge,'sync',{cycles:[cycle()],copy:copy()});assert.equal(runtime.requests.length,1);assert.equal(runtime.cancelled.includes(999),false);
});
test('revocation cancels native requests/cards and rejects future channel calls',async()=>{
 reset();const bridge=new ReminderBridge(context,engine);await bridge.authorize();await invoke(bridge,'enable',{enabled:true});
 await invoke(bridge,'sync',{cycles:[cycle()],copy:copy()});await bridge.revoke();
 assert.equal(runtime.valid.length,0);assert.equal(runtime.cards.length,1);await assert.rejects(invoke(bridge,'status'),/CONSENT_REQUIRED/);
 const saved=JSON.parse(runtime.values.get('state'));assert.equal(saved.enabled,false);assert.equal(saved.pendingDay,'');
});
test('unknown channel method and malformed sync fail without native publication',async()=>{
 reset();const bridge=new ReminderBridge(context,engine);await bridge.authorize();
 await assert.rejects(invoke(bridge,'notReal'),/NOT_IMPLEMENTED/);await assert.rejects(invoke(bridge,'sync',{cycles:[{}],copy:copy()}));
 assert.equal(runtime.requests.length,0);
});
test('existing card is updated silently and atomically; dismissed or unchanged card is not recreated',async()=>{
 reset();const storage=new NativeReminderStorage(context),system=new NativeReminderSystem(context,storage);
 const batch={notificationId:20300101,day:'2030-01-01',title:'Check',content:'Check 1'};
 await system.updateCard(batch);assert.equal(runtime.cardUpdates.length,0);
 runtime.active=[{id:20300101,content:{normal:{title:'Check',text:'Check 2'}}}];
 await system.updateCard(batch);assert.equal(runtime.cardUpdates.length,1);
 const update=runtime.cardUpdates[0];assert.equal(update.updateOnly,true);assert.equal(update.isAlertOnce,true);
 assert.equal(update.wantAgent.wants[0].uri,'fridge://reminders/2030-01-01');
 runtime.active[0].content.normal.text='Check 1';await system.updateCard(batch);assert.equal(runtime.cardUpdates.length,1);
});
