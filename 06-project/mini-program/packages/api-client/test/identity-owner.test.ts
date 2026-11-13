import test from 'node:test';
import assert from 'node:assert/strict';
import {MiniIdentity} from '../src/identity.ts';
import {MiniIdentityOwner} from '../src/identity-owner.ts';
import type {IdentityDriver} from '../src/identity.ts';
function fixture() {
  let stage='consent',created=0,requests=0;
  const listeners=new Set<()=>void>(),values=new Map<string,string>();
  const source={snapshot:()=>({stage}),subscribe:(fn:()=>void)=>{listeners.add(fn);return ()=>{listeners.delete(fn);};}};
  const driver: IdentityDriver={getStorageSync:key=>values.get(key),setStorageSync:(key,value)=>{values.set(key,value);},
    removeStorageSync:key=>{values.delete(key);},login:async()=>({code:'wx-code'}),request:input=>{
      requests++;input.success({statusCode:200,data:{accessToken:'guest',refreshToken:'refresh'}});
    }};
  const create=()=>{created++;return new MiniIdentity({enabled:true,guestEnabled:true,baseUrl:'https://platform.example.test',clientId:'fenleng-fridge-miniapp'},driver);};
  return {source,driver,values,create,set:(value:string)=>{stage=value;listeners.forEach(fn=>fn());},created:()=>created,requests:()=>requests};
}
test('rapid consent changes skip stale setup and use one shared identity for business updates', async () => {
  const f=fixture(),owner=new MiniIdentityOwner(f.source,true,f.create);
  f.set('ready');f.set('consent');f.set('ready');const current=await owner.ready();
  assert.equal(f.created(),1);assert.equal(f.requests(),1);assert.equal(current,owner.identity);
  f.set('ready');assert.equal(await owner.ready(),current);assert.equal(f.created(),1);
  await owner.close();assert.equal(f.values.size,3);
});
test('withdrawal during guest setup drains and clears old tokens before a new identity starts', async () => {
  const f=fixture(),owner=new MiniIdentityOwner(f.source,true,f.create);let finish!: ()=>void;
  f.driver.request=input=>{finish=()=>input.success({statusCode:200,data:{accessToken:'late-guest',refreshToken:'late-refresh'}});};
  f.set('ready');await new Promise(resolve=>setImmediate(resolve));f.set('consent');assert.equal(owner.identity,null);
  finish();await owner.ready();assert.equal(f.values.size,0);
  f.driver.request=input=>input.success({statusCode:200,data:{accessToken:'new-guest',refreshToken:'new-refresh'}});
  f.set('ready');const current=await owner.ready();assert.equal(f.created(),2);
  assert.equal(await current!.session.accessToken(),'new-guest');await owner.close();
});
test('disabled configuration or missing consent performs no identity storage/network work', async () => {
  const f=fixture(),owner=new MiniIdentityOwner(f.source,false,f.create);
  assert.equal(await owner.ready(),null);f.set('ready');assert.equal(await owner.ready(),null);
  assert.equal(f.created(),0);assert.equal(f.values.size,0);await owner.close();
});

test('withdrawal fences an outstanding native WeChat code before a fresh guest session starts',async()=>{
  const f=fixture(),owner=new MiniIdentityOwner(f.source,true,f.create);f.set('ready');
  const original=(await owner.ready())!;let finish!:(value:{code:string})=>void;
  f.driver.login=()=>new Promise(resolve=>{finish=resolve;});
  const oldLogin=original.login();const rejected=assert.rejects(oldLogin,/loginCancelled/);
  await new Promise(resolve=>setImmediate(resolve));f.set('withdrawing');await owner.ready();
  assert.equal(f.values.size,0);
  f.driver.request=input=>{input.success({statusCode:200,data:{accessToken:'fresh-guest',refreshToken:'fresh-refresh'}});};
  f.set('ready');const fresh=(await owner.ready())!;
  finish({code:'late-code'});await rejected;
  assert.equal(await fresh.session.accessToken(),'fresh-guest');await owner.close();
});
