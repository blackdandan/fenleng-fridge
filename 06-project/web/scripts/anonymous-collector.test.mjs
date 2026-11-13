import test from 'node:test';import assert from 'node:assert/strict';
import {createAnonymousCollector} from '../src/anonymous-collector.js';
const config={enabled:true,baseUrl:'https://platform.test',clientId:'fenleng-fridge-website',version:'0.1.0',buildNumber:'1'};
const timers={setTimeout:callback=>{queueMicrotask(callback);return 1;},clearTimeout(){}};
test('official SDK sends a minimal anonymous event with no credentials and keepalive',async()=>{
  const calls=[];const collector=createAnonymousCollector(config,{consent:()=>true,locale:()=> 'ar',timers,
    fetch:async(url,options)=>{calls.push({url,options});return Response.json({accepted:1});}});
  assert.equal(collector.appEntry(),true);assert.equal(await collector.flush(),1);collector.close();
  assert.equal(calls.length,1);const {url,options}=calls[0];assert.ok(url.endsWith('/telemetry/anonymous/events'));
  assert.equal(options.credentials,'omit');assert.equal(options.keepalive,true);assert.equal(options.headers.Authorization,undefined);
  assert.equal(options.headers.Cookie,undefined);assert.equal(options.headers['X-Fenleng-Client-Id'],config.clientId);
  const payload=JSON.parse(options.body);assert.deepEqual(Object.keys(payload),['events']);assert.deepEqual(payload.events[0].properties,{target:'app'});
  assert.equal(payload.events[0].context.sessionId,undefined);assert.equal(payload.events[0].context.locale,'ar');assert.match(payload.events[0].eventId,/^[0-9a-f-]{36}$/);
});
test('network failure and bad ACK preserve the exact batch event IDs timestamp and dedupe key',async()=>{
  const calls=[];const collector=createAnonymousCollector(config,{consent:()=>true,locale:()=> 'en',timers,fetch:async(_url,options)=>{
    calls.push(options);if(calls.length===1)throw Error('network');return Response.json({accepted:calls.length===2?0:1});}});
  collector.appEntry();assert.equal(await collector.flush(),1);assert.equal(calls.length,3);
  for(const call of calls){assert.equal(call.body,calls[0].body);assert.equal(call.headers['Idempotency-Key'],calls[0].headers['Idempotency-Key']);}collector.close();
});
test('no consent records nothing and close discards old delivery without a replay after a late ACK',async()=>{
  let consent=false,calls=0,finish;const collector=createAnonymousCollector(config,{consent:()=>consent,locale:()=> 'en',timers,
    fetch:async()=>{calls++;return new Promise(resolve=>{finish=()=>resolve(Response.json({accepted:1}));});}});
  assert.equal(collector.appEntry(),false);assert.equal(await collector.flush(),0);assert.equal(calls,0);
  consent=true;collector.appEntry();const pending=collector.flush();while(!finish)await new Promise(resolve=>setImmediate(resolve));
  consent=false;collector.close();finish();assert.equal(await pending,0);assert.equal(collector.pendingCount,0);assert.equal(calls,1);
});
