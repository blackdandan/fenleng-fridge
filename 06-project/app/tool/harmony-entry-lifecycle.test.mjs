import test from 'node:test';import assert from 'node:assert/strict';
import {createRequire} from 'node:module';import {readFile} from 'node:fs/promises';
const require=createRequire(new URL('../../web/package.json',import.meta.url));const {build}=require('esbuild');
const entry=new URL('../apps/fridge/ohos/entry/src/main/ets/entryability/EntryAbility.ets',import.meta.url);
const result=await build({stdin:{contents:await readFile(entry,'utf8'),loader:'ts'},bundle:true,write:false,format:'esm',platform:'node',
 plugins:[{name:'ability-port',setup(b){
  b.onResolve({filter:/.*/},a=>({path:a.path,namespace:'port'}));
  b.onLoad({filter:/.*/,namespace:'port'},a=>{
   if(a.path==='./BootstrapChannel')return {contents:`export default class Bootstrap {constructor(){globalThis.harmonyAbility.created++;}receiveReminder(uri){if(uri)globalThis.harmonyAbility.received.push(uri);}}`};
   if(a.path==='@ohos/flutter_ohos')return {contents:`export class FlutterAbility {context={};onCreate(){const start=()=>this.configureFlutterEngine({});if(globalThis.harmonyAbility.deferred)globalThis.harmonyAbility.start=start;else start();}onNewWant(){globalThis.harmonyAbility.forwarded++;}}`};
   throw Error('Unexpected lifecycle import '+a.path);
  });
 }}]});
const {default:EntryAbility}=await import('data:text/javascript;base64,'+Buffer.from(result.outputFiles[0].text).toString('base64'));
function reset(deferred=false){globalThis.harmonyAbility={deferred,created:0,received:[],forwarded:0,start:null};return globalThis.harmonyAbility;}
test('synchronous engine configuration forwards cold-start day once',()=>{
 const f=reset();const ability=new EntryAbility();ability.onCreate({uri:'fridge://reminders/2030-01-01'},{});
 assert.equal(f.created,1);assert.deepEqual(f.received,['fridge://reminders/2030-01-01']);
});
test('deferred engine configuration retains cold-start URI until engine is actually available',()=>{
 const f=reset(true);const ability=new EntryAbility();ability.onCreate({uri:'fridge://reminders/2030-01-01'},{});
 assert.equal(f.created,0);f.start();assert.deepEqual(f.received,['fridge://reminders/2030-01-01']);
});
test('latest want is retained before engine, hot wants still forward through Flutter superclass',()=>{
 const f=reset(true);const ability=new EntryAbility();ability.onCreate({uri:'fridge://reminders/2030-01-01'},{});
 ability.onNewWant({uri:'fridge://reminders/2030-01-02'},{});f.start();
 ability.onNewWant({uri:'fridge://reminders/2030-01-03'},{});
 assert.equal(f.forwarded,2);assert.deepEqual(f.received,['fridge://reminders/2030-01-02','fridge://reminders/2030-01-03']);
});
