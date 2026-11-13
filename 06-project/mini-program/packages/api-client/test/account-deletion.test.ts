import test from 'node:test';import assert from 'node:assert/strict';
import {MiniIdentity,type IdentityDriver} from '../src/identity.ts';
import {MiniDeletionGateway} from '../src/account-deletion.ts';
import {AccountDeletionSession} from '../../application/src/account-deletion.ts';
import {SnapshotDeletionStorage} from '../../platform-adapters/weapp/src/deletion-storage.ts';
import type {TaroNativeRequest} from '@fenleng/sdk-taro';
const receipt={id:'request-one',userId:'user-one',type:'DELETE',status:'PENDING',requestedAt:'2030-01-01T00:00:00Z',nextAttemptAt:'2030-01-08T00:00:00Z'};
async function fixture(guest=false){
 const values=new Map<string,string>(),requests:TaroNativeRequest[]=[];let native=0,consent=true,reminders=0;
 let handler:(input:TaroNativeRequest)=>void=input=>{
  const path=new URL(input.url).pathname;
  input.success({statusCode:200,data:path.endsWith('/wechat/login') || path.endsWith('/guest/login')?{accessToken:'account-access',refreshToken:'account-refresh'}:
   path.endsWith('/users/me')?{id:'user-one',kind:'HUMAN',status:'ACTIVE',primaryEmail:'ignored@example.test'}:
   path.endsWith('/challenges')?{challengeId:'fdc-once',provider:'WECHAT',nonce:'server-nonce',expiresAt:'2030-01-01T00:05:00Z'}:
   path.endsWith('/confirm')?{confirmationId:'fdc-once',deletionIdempotencyKey:'delete-intent',expiresAt:'2030-01-01T00:05:00Z'}:receipt});
 };
 const driver:IdentityDriver={getStorageSync:key=>values.get(key),setStorageSync:(key,value)=>{values.set(key,value);},removeStorageSync:key=>{values.delete(key);},
  login:async()=>{native++;return{code:'fresh-wechat-code'};},request:input=>{requests.push(input);handler(input);return{abort:()=>{}};}};
 const identity=new MiniIdentity({enabled:true,guestEnabled:true,baseUrl:'https://platform.test',clientId:'fenleng-fridge-miniapp'},driver);
 if(guest)await identity.ensureSession();else await identity.login();identity.session.suspend();
 const gateway=new MiniDeletionGateway(()=>identity,()=>consent,async()=>{reminders++;});
 return{identity,gateway,driver,values,requests,native:()=>native,reminders:()=>reminders,consent:(v:boolean)=>consent=v,handler:(fn:typeof handler)=>handler=fn};
}
test('actual identity+SDK+durable model completes native proof to accepted receipt before local-only cleanup',async t=>{
 const f=await fixture();t.after(()=>f.identity.close());
 const storage=new SnapshotDeletionStorage({get:key=>f.values.get(key),set:(key,value)=>{f.values.set(key,value);}});
 const model=new AccountDeletionSession(storage,f.gateway,()=>true,async()=>'delete-intent');await model.submit(async()=>true);
 assert.equal(model.snapshot().entry?.phase,'accepted');assert.equal(model.snapshot().durable,true);assert.equal(f.native(),2);assert.equal(f.reminders(),1);
 const writes=f.requests.filter(req=>req.method==='POST');
 assert.deepEqual(writes.map(req=>new URL(req.url).pathname),['/api/platform/v1/auth/wechat/login','/api/platform/v1/auth/step-up/self-deletion/challenges','/api/platform/v1/auth/step-up/self-deletion/challenges/fdc-once/confirm','/api/platform/v1/users/me/data-requests']);
 const deletion=writes[writes.length-1];assert.equal(deletion.header['X-Action-Confirmation'],'fdc-once');assert.equal(deletion.header['Idempotency-Key'],'delete-intent');
 assert.equal(f.values.get('fridge.platform.v1:fl_session_token'),undefined);
 const raw=f.values.get(SnapshotDeletionStorage.key)!;assert.equal(raw.includes('fresh-wechat-code'),false);assert.equal(raw.includes('ignored@example.test'),false);
 assert.equal(raw.includes('account-access'),false);await model.close();
});
test('guest cannot start account deletion or trigger implicit WeChat login',async t=>{
 const f=await fixture(true);t.after(()=>f.identity.close());const before=f.requests.length;
 await assert.rejects(f.gateway.open(),e=>(e as Error).message==='deletionLoginRequired');
 assert.equal(f.native(),0);assert.equal(f.requests.length,before);
});
test('authorization is only a proof and leaves current platform tokens unchanged until finish',async t=>{
 const f=await fixture();t.after(()=>f.identity.close());const context=await f.gateway.open();
 await context.challenge('delete-intent');assert.equal(await context.authorize(),'fresh-wechat-code');
 await context.confirm('fdc-once','fresh-wechat-code','delete-intent');
 assert.equal(f.values.get('fridge.platform.v1:fl_session_token'),'account-access');assert.equal(f.requests.filter(req=>req.url.endsWith('/wechat/login')).length,1);
 context.cancel();await context.finish();assert.equal(f.values.get('fridge.platform.v1:fl_session_token'),undefined);
});
test('owner revision fences stale cleanup after a newer login',async t=>{
 const f=await fixture();t.after(()=>f.identity.close());const context=await f.gateway.open();
 await f.identity.logout();await f.identity.login();f.identity.session.suspend();context.cancel();await context.finish();
 assert.equal(f.values.get('fridge.platform.v1:fl_session_token'),'account-access');
});
test('cancellation before dispatch and late native proof do not submit DELETE',async t=>{
 const f=await fixture();t.after(()=>f.identity.close());let context=await f.gateway.open();const before=f.requests.length;
 const pending=context.submit('delete-intent','fdc-once');context.cancel();await assert.rejects(pending);assert.equal(f.requests.length,before);
 context=await f.gateway.open();let resolve!:(v:{code:string})=>void;f.driver.login=()=>new Promise(r=>resolve=r);
 const proof=context.authorize();context.cancel();resolve({code:'fresh-wechat-code'});await assert.rejects(proof);
 assert.equal(f.requests.some(req=>req.url.endsWith('/data-requests')),false);
});
test('malformed profile, foreign receipt and mismatched confirmation are never accepted',async t=>{
 const f=await fixture();t.after(()=>f.identity.close());f.handler(input=>input.success({statusCode:200,data:{id:'user-one',kind:'GUEST',status:'ACTIVE'}}));
 await assert.rejects(f.gateway.open());
 f.handler(input=>input.success({statusCode:200,data:input.url.endsWith('/users/me')?{id:'user-one',kind:'HUMAN',status:'ACTIVE'}:
  input.url.endsWith('/confirm')?{confirmationId:'fdc-once',deletionIdempotencyKey:'other-intent',expiresAt:'2030-01-01T00:05:00Z'}:{...receipt,userId:'other'}}));
 const context=await f.gateway.open();await assert.rejects(context.confirm('fdc-once','proof','delete-intent'));
 await assert.rejects(context.submit('delete-intent','fdc-once'));context.cancel();
});
test('an authentic original ACK remains available after a concurrent401 invalidates that session',async t=>{
 const f=await fixture();t.after(()=>f.identity.close());const context=await f.gateway.open();
 let respond!:()=>void;f.handler(input=>{respond=()=>input.success({statusCode:200,data:receipt});});
 const pending=context.submit('delete-intent','fdc-once');while(!respond)await new Promise(r=>setImmediate(r));
 await f.identity.session.invalidate();respond();assert.equal((await pending).id,'request-one');assert.equal(context.current(),false);context.cancel();
});
test('local cleanup write failure retries locally without another DELETE or loss of accepted receipt',async t=>{
 const f=await fixture();t.after(()=>f.identity.close());let fail=true;
 f.driver.removeStorageSync=key=>{if(fail && key.endsWith('fl_session_token')){fail=false;throw Error('quota');}f.values.delete(key);};
 const storage=new SnapshotDeletionStorage({get:key=>f.values.get(key),set:(key,value)=>{f.values.set(key,value);}});
 const model=new AccountDeletionSession(storage,f.gateway,()=>true,async()=>'delete-intent');await model.submit(async()=>true);
 assert.equal(model.snapshot().entry?.phase,'accepted');assert.equal(model.snapshot().errorKey,'deletionCleanupFailed');
 await model.retryReceipt();assert.equal(model.snapshot().errorKey,null);assert.equal(f.values.get('fridge.platform.v1:fl_session_token'),undefined);
 assert.equal(f.requests.filter(req=>req.url.endsWith('/data-requests')).length,1);await model.close();
});
