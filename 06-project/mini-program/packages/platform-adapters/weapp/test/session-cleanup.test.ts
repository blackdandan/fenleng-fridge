import test from 'node:test';import assert from 'node:assert/strict';
import {clearPlatformSession} from '../src/session-cleanup';
test('withdrawal clears all three exact SDK keys while preserving local business data',async()=>{
  const values=new Map([['fridge.platform.v1:fl_session_token','access'],['fridge.platform.v1:fl_session_token:refresh','refresh'],['fridge.platform.v1:fl_session_token:kind','guest'],['fridge.inventory.v1','stock'],['fridge.feedback.v1','draft']]);
  await clearPlatformSession({read:key=>values.get(key),remove:key=>{values.delete(key);}});
  assert.deepEqual([...values],[['fridge.inventory.v1','stock'],['fridge.feedback.v1','draft']]);
});
test('one failed token removal still attempts the remaining keys and reports failure',async()=>{
  const removed:string[]=[];
  await assert.rejects(clearPlatformSession({read:()=>null,remove:key=>{removed.push(key);if(key.endsWith('fl_session_token'))throw new Error('QUOTA');}}),/SESSION_CLEANUP_FAILED/);
  assert.equal(removed.length,3);
});
