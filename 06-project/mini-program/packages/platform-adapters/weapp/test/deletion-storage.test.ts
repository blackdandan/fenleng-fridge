import test from 'node:test';import assert from 'node:assert/strict';
import {SnapshotDeletionStorage} from '../src/deletion-storage.ts';
import {validDeletionReceipt,deletionInstantMillis,type DeletionEntry} from '@fridge/platform-contracts';
const entry:DeletionEntry={owner:JSON.stringify(['https://platform.test','fenleng-fridge-miniapp','user']),key:'delete-intent',phase:'accepted',
 receipt:{id:'request-one',requestedAt:'2030-01-01T00:00:00Z',eligibleAt:'2030-01-08T00:00:00Z'}};
test('journal writes and restores owner-scoped receipt in one replacement without credentials',async()=>{
 let raw:unknown='';const storage=new SnapshotDeletionStorage({get:()=>raw,set:(_key,value)=>raw=value});
 await storage.save([{...entry,identityToken:'must-not-persist'} as DeletionEntry]);
 assert.deepEqual(await storage.load(),[entry]);assert.equal(String(raw).includes('must-not-persist'),false);
});
test('malformed dates, premature eligibility, duplicate owners and corrupt state fail without overwriting',async()=>{
 let raw:unknown='broken';let writes=0;const storage=new SnapshotDeletionStorage({get:()=>raw,set:()=>{writes++;}});
 await assert.rejects(storage.load());assert.equal(raw,'broken');
 raw=JSON.stringify({version:1,entries:[entry,entry]});await assert.rejects(storage.load());
 for(const receipt of [{...entry.receipt!,requestedAt:'2030-02-30T00:00:00Z'},
  {...entry.receipt!,eligibleAt:'2030-01-07T23:59:59Z'}, {...entry.receipt!,eligibleAt:'2030-01-08'}])assert.equal(validDeletionReceipt(receipt),false);
 await assert.rejects(storage.save([{...entry,phase:'unknown'}]));assert.equal(writes,0);
});
test('Java nanosecond timestamps are parsed without browser-specific Date extensions',()=>{
 assert.equal(deletionInstantMillis('2030-01-01T00:00:00.123456789Z'),Date.UTC(2030,0,1,0,0,0,123));
 assert.equal(validDeletionReceipt({...entry.receipt!,requestedAt:'2030-01-01T00:00:00.123456789Z',eligibleAt:'2030-01-08T00:00:00.123456789Z'}),true);
 assert.equal(Number.isNaN(deletionInstantMillis('2030-02-30T00:00:00.000000001Z')),true);
});
