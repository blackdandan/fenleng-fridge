import test from 'node:test';import assert from 'node:assert/strict';
import {WebsitePrivacy,WEBSITE_PRIVACY_KEY} from '../src/site-privacy.js';
import {websiteAnalyticsConfig} from './analytics-config.mjs';

function fixture() {
  const data=new Map(),calls=[];let loads=0,entries=0,closed=0,writeFails=false,removeFails=false;
  const storage={getItem:key=>data.get(key) ?? null,setItem:(key,value)=>{if(writeFails)throw Error('quota');data.set(key,value);},
    removeItem:key=>{if(removeFails)throw Error('blocked');data.delete(key);}};
  const privacy=new WebsitePrivacy({storage,loadCollector:async()=>{loads++;return {appEntry(){entries++;return true;},close(){closed++;},suspend(){calls.push('suspend');},resume(){calls.push('resume');}};}});
  return {privacy,storage,data,calls,loads:()=>loads,entries:()=>entries,closed:()=>closed,
    failWrite:value=>{writeFails=value;},failRemove:value=>{removeFails=value;}};
}
test('no consent or an explicit decline loads no SDK and never replays an earlier entry',async()=>{
  const f=fixture();await f.privacy.start();assert.equal(f.privacy.snapshot().show,true);assert.equal(await f.privacy.appEntry(),false);assert.equal(f.loads(),0);
  f.privacy.decline();assert.equal(f.privacy.snapshot().show,false);assert.equal(f.loads(),0);
  assert.equal(f.privacy.accept(),true);await f.privacy.ensureCollector();assert.equal(f.entries(),0);
  assert.equal(await f.privacy.appEntry(),true);assert.equal(f.entries(),1);
  assert.equal(JSON.parse(f.data.get(WEBSITE_PRIVACY_KEY)).accepted,true);f.privacy.close();
});
test('version mismatch and corrupt storage never imply consent or silently overwrite evidence',async()=>{
  for(const value of ['{bad',JSON.stringify({policyVersion:'V0.3',accepted:true,acceptedAt:'2026-11-13T00:00:00Z'})]) {
    const f=fixture();f.data.set(WEBSITE_PRIVACY_KEY,value);await f.privacy.start();assert.equal(f.privacy.hasConsent(),false);assert.equal(f.loads(),0);
    assert.equal(f.data.get(WEBSITE_PRIVACY_KEY),value);f.privacy.close();
  }
});
test('durable acceptance precedes SDK creation and failed saving leaves browsing possible without collection',async()=>{
  const f=fixture();await f.privacy.start();f.failWrite(true);assert.equal(f.privacy.accept(),false);
  assert.equal(f.privacy.snapshot().error,'error');assert.equal(await f.privacy.appEntry(),false);assert.equal(f.loads(),0);
  f.privacy.decline();assert.equal(f.privacy.snapshot().show,false);assert.equal(f.privacy.hasConsent(),false);f.privacy.close();
});
test('withdraw stops collection immediately and cannot claim success if the local preference was not cleared',async()=>{
  const f=fixture();f.privacy.accept();await f.privacy.ensureCollector();f.failRemove(true);
  assert.equal(f.privacy.withdraw(),false);assert.equal(f.closed(),1);assert.equal(await f.privacy.appEntry(),false);
  assert.equal(f.privacy.snapshot().error,'privacyWithdrawFailed');f.privacy.showChoices();assert.equal(f.privacy.snapshot().error,'privacyWithdrawFailed');
  f.failRemove(false);assert.equal(f.privacy.withdraw(),true);assert.equal(f.data.has(WEBSITE_PRIVACY_KEY),false);f.privacy.close();
});
test('cross-tab withdrawal is checked before an event even before a storage event handler runs',async()=>{
  const f=fixture();f.privacy.accept();await f.privacy.ensureCollector();f.storage.removeItem(WEBSITE_PRIVACY_KEY);
  assert.equal(await f.privacy.appEntry(),false);await f.privacy.refresh();assert.equal(f.closed(),1);assert.equal(f.privacy.snapshot().choice,'unknown');f.privacy.close();
});
test('late SDK load after withdrawal is closed and never receives a queued entry',async()=>{
  const data=new Map();let release,closed=0,entries=0;
  const privacy=new WebsitePrivacy({storage:{getItem:key=>data.get(key)??null,setItem:(key,value)=>data.set(key,value),removeItem:key=>data.delete(key)},
    loadCollector:()=>new Promise(resolve=>{release=()=>resolve({appEntry(){entries++;},close(){closed++;}});})});
  privacy.accept();await Promise.resolve();const pending=privacy.appEntry();privacy.withdraw();release();
  assert.equal(await pending,false);assert.equal(entries,0);assert.equal(closed,1);privacy.close();
});
test('SDK failure is isolated from privacy preference and subsequent explicit retries',async()=>{
  const data=new Map();let attempts=0;
  const privacy=new WebsitePrivacy({storage:{getItem:key=>data.get(key)??null,setItem:(key,value)=>data.set(key,value),removeItem:key=>data.delete(key)},
    loadCollector:async()=>{attempts++;throw Error('load failed');}});
  privacy.accept();assert.equal(await privacy.appEntry(),false);assert.equal(privacy.hasConsent(),true);assert.ok(attempts>=1);
  assert.equal(privacy.withdraw(),true);privacy.close();
});
test('anonymous endpoint config is opt in, public only, and reports no raw configuration data on invalid input',()=>{
  assert.equal(websiteAnalyticsConfig({},'0.1.0').enabled,false);
  const enabled={FRIDGE_WEB_TELEMETRY_ENABLED:'true',FRIDGE_PLATFORM_URL:'https://platform.test'};
  assert.equal(websiteAnalyticsConfig(enabled,'0.1.0').clientId,'fenleng-fridge-website');
  for(const url of ['bad-private-value','http://platform.test','https://user:private@platform.test','https://platform.test/?secret=private']) {
    assert.throws(()=>websiteAnalyticsConfig({...enabled,FRIDGE_PLATFORM_URL:url},'0.1.0'),error=>error.message==='WEBSITE_ANALYTICS_CONFIG_INVALID');
  }
});
