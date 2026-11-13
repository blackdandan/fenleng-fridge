import test from 'node:test';import assert from 'node:assert/strict';
import {AccountDeletionSession} from '../src/account-deletion.ts';
import type {DeletionEntry,DeletionReceipt} from '@fridge/platform-contracts';
const owner=(user='one')=>JSON.stringify(['https://platform.test','fenleng-fridge-miniapp',user]);
const receipt:DeletionReceipt={id:'request-one',requestedAt:'2030-01-01T00:00:00Z',eligibleAt:'2030-01-08T00:00:00Z'};
const clone=<T>(value:T):T=>JSON.parse(JSON.stringify(value));
function fixture(initial:readonly DeletionEntry[]=[]){
 let entries=clone(initial),consent=true,current=true,who=owner(),keyCount=0,saves=0,failSave=0;
 const log:string[]=[];
 let send:()=>Promise<DeletionReceipt>=async()=>receipt;
 let authorize:()=>Promise<string>=async()=>'transient-native-proof';
 let cleanup:()=>Promise<void>=async()=>{};
 const storage={load:async()=>clone(entries),save:async(value:readonly DeletionEntry[])=>{
  log.push('save:'+value[value.length-1].phase);if(++saves===failSave)throw Error('private quota');entries=clone(value);
 }};
 const gateway={open:async()=>({owner:who,current:()=>current,
  challenge:async(key:string)=>{log.push('challenge:'+key);return{id:'fdc-once',expiresAt:'2030-01-01T00:05:00Z'};},
  authorize:async()=>{log.push('authorize');return authorize();},confirm:async(_id:string,proof:string,key:string)=>{
   assert.equal(proof,'transient-native-proof');log.push('confirm:'+key);return'fdc-once';},
  stopReminders:async()=>{log.push('cancel-reminders');},submit:async(key:string,id:string)=>{
   log.push('DELETE:'+key);assert.equal(id,'fdc-once');return send();},finish:async()=>{log.push('cleanup');await cleanup();},
  cancel:()=>{log.push('abort');},
 })};
 const create=()=>new AccountDeletionSession(storage,gateway,()=>consent,async()=>`delete-intent-${++keyCount}`);
 return{create,log,entries:()=>entries,consent:(v:boolean)=>consent=v,current:(v:boolean)=>current=v,owner:(v:string)=>who=owner(v),
  failSave:(n:number)=>failSave=n,send:(v:typeof send)=>send=v,authorize:(v:typeof authorize)=>authorize=v,cleanup:(v:typeof cleanup)=>cleanup=v};
}
test('visible cancellation issues no challenge, proof, reminder cancellation or DELETE',async()=>{
 const f=fixture(),s=f.create();await s.start();await s.submit(async()=>false);
 assert.deepEqual(f.log,['abort']);assert.equal(f.entries().length,0);assert.equal(s.snapshot().busy,false);
});
test('intent is durable before challenge; submitting marker precedes DELETE; receipt precedes local cleanup',async()=>{
 const f=fixture(),s=f.create();await s.submit(async()=>true);
 assert.deepEqual(f.log,['save:prepared','challenge:delete-intent-1','authorize','confirm:delete-intent-1','cancel-reminders','save:submitting','DELETE:delete-intent-1','save:accepted','cleanup','abort']);
 assert.equal(s.snapshot().entry?.phase,'accepted');assert.equal(s.snapshot().durable,true);
 assert.equal(JSON.stringify(f.entries()).includes('transient-native-proof'),false);
});
test('network/401 unknown outcome survives restart and reuses the same intent without automatic login',async()=>{
 const f=fixture();f.send(async()=>{throw Object.assign(Error('revoked'),{status:401});});let s=f.create();await s.submit(async()=>true);
 assert.equal(s.snapshot().entry?.phase,'unknown');assert.equal(s.snapshot().errorKey,'deletionUnknown');
 await s.close();s=f.create();await s.start();assert.equal(f.log.filter(v=>v.startsWith('DELETE')).length,1);
 f.send(async()=>receipt);await s.submit(async()=>true);
 assert.deepEqual(f.log.filter(v=>v.startsWith('DELETE')),['DELETE:delete-intent-1','DELETE:delete-intent-1']);
});
test('crash marker is displayed unknown on restore and never silently submitted',async()=>{
 const f=fixture([{owner:owner(),key:'existing-intent',phase:'submitting',receipt:null}]),s=f.create();await s.start();
 assert.equal(s.snapshot().entry?.phase,'unknown');assert.deepEqual(f.log,[]);
});
test('initial intent persistence failure prevents every remote write',async()=>{
 const f=fixture(),s=f.create();f.failSave(1);await s.submit(async()=>true);
 assert.equal(s.snapshot().errorKey,'deletionStorageFailed');assert.equal(f.log.some(v=>v.startsWith('challenge') || v.startsWith('DELETE')),false);
});
test('receipt save failure retains known ACK in memory and retry never resubmits DELETE',async()=>{
 const f=fixture(),s=f.create();f.failSave(3);await s.submit(async()=>true);
 assert.equal(s.snapshot().entry?.phase,'accepted');assert.equal(s.snapshot().durable,false);assert.equal(f.entries()[0].phase,'submitting');
 await s.retryReceipt();assert.equal(f.entries()[0].phase,'accepted');assert.equal(s.snapshot().durable,true);
 assert.equal(f.log.filter(v=>v.startsWith('DELETE')).length,1);assert.equal(f.log.filter(v=>v==='cleanup').length,1);
});
test('cleanup failure keeps accepted receipt and retries only local cleanup',async()=>{
 const f=fixture(),s=f.create();let failures=1;f.cleanup(async()=>{if(failures--)throw Error('quota');});
 await s.submit(async()=>true);assert.equal(s.snapshot().errorKey,'deletionCleanupFailed');assert.equal(s.snapshot().entry?.phase,'accepted');
 await s.retryReceipt();assert.equal(s.snapshot().errorKey,null);assert.equal(f.log.filter(v=>v==='cleanup').length,2);
 assert.equal(f.log.filter(v=>v.startsWith('DELETE')).length,1);
});
test('late native proof after page cancellation cannot reach platform confirmation or DELETE',async()=>{
 const f=fixture(),s=f.create();let resolve!:(value:string)=>void;f.authorize(()=>new Promise(r=>resolve=r));
 const operation=s.submit(async()=>true);while(!resolve)await new Promise(r=>setImmediate(r));s.freeze();resolve('transient-native-proof');await operation;
 assert.equal(f.log.some(v=>v.startsWith('confirm') || v.startsWith('DELETE')),false);assert.equal(f.entries()[0].phase,'prepared');
});
test('privacy withdrawal during DELETE retains durable uncertainty without a late receipt write',async()=>{
 const f=fixture(),s=f.create();let resolve!:(value:DeletionReceipt)=>void;f.send(()=>new Promise(r=>resolve=r));
 const operation=s.submit(async()=>true);while(!resolve)await new Promise(r=>setImmediate(r));f.consent(false);s.freeze();resolve(receipt);await operation;
 assert.equal(f.entries()[0].phase,'submitting');assert.equal(f.log.includes('save:accepted'),false);assert.equal(f.log.includes('cleanup'),false);
});
test('identity changes during explicit confirmation prevent proof or DELETE',async()=>{
 const f=fixture(),s=f.create();await s.submit(async()=>{f.current(false);return true;});
 assert.equal(f.log.some(v=>v.startsWith('challenge') || v.startsWith('DELETE')),false);
});
test('malformed successful response is unknown and never clears credentials',async()=>{
 const f=fixture(),s=f.create();f.send(async()=>({...receipt,eligibleAt:'2030-01-02T00:00:00Z'}));await s.submit(async()=>true);
 assert.equal(s.snapshot().entry?.phase,'unknown');assert.equal(f.log.includes('cleanup'),false);
});
test('concurrent taps join one operation',async()=>{
 const f=fixture(),s=f.create();let resolve!:(value:boolean)=>void;const first=s.submit(()=>new Promise(r=>resolve=r));
 const second=s.submit(async()=>true);assert.equal(first,second);while(!resolve)await new Promise(r=>setImmediate(r));resolve(true);await first;
 assert.equal(f.log.filter(v=>v.startsWith('DELETE')).length,1);
});
test('subsequent active owner marks accepted request cancelled and a new intent is used for a new application',async()=>{
 const f=fixture([{owner:owner(),key:'old-delete-intent',phase:'accepted',receipt}]),s=f.create();await s.start();await s.refreshOwner();
 assert.equal(s.snapshot().entry?.phase,'cancelled');await s.submit(async()=>true);
 assert.equal(f.log.includes('DELETE:delete-intent-1'),true);assert.equal(f.log.includes('DELETE:old-delete-intent'),false);
});
test('switching accounts selects only that owner and preserves the previous journal entry',async()=>{
 const f=fixture([{owner:owner(),key:'old-delete-intent',phase:'accepted',receipt}]),s=f.create();await s.start();f.owner('two');await s.refreshOwner();
 assert.equal(s.snapshot().entry,null);await s.submit(async()=>true);assert.equal(f.entries().length,2);
 assert.equal(f.entries()[0].owner,owner());assert.equal(f.entries()[1].owner,owner('two'));
});
test('explicit new login retires an unknown old intent instead of replaying its cached result',async()=>{
 const f=fixture([{owner:owner(),key:'old-delete-intent',phase:'unknown',receipt:null}]),s=f.create();await s.start();
 await s.refreshOwner();assert.equal(s.snapshot().entry?.phase,'unknown');
 await s.refreshOwner(true);assert.equal(s.snapshot().entry?.phase,'cancelled');assert.equal(s.snapshot().entry?.receipt,null);
 await s.submit(async()=>true);assert.equal(f.log.includes('DELETE:old-delete-intent'),false);assert.equal(f.log.includes('DELETE:delete-intent-1'),true);
});
