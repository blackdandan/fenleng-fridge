import test from 'node:test';
import assert from 'node:assert/strict';
import {SnapshotFeedbackStorage} from '../src/feedback-storage.ts';
test('draft and receipt persist as one snapshot; corrupt data remains available for recovery', async () => {
  const values=new Map<string,unknown>(),driver={get:(key: string)=>values.get(key),set:(key: string,value: string)=>{values.set(key,value);}};
  const first=new SnapshotFeedbackStorage(driver);
  await first.save({text:'private test text',key:'feedback-key-1',receipt:null});
  assert.deepEqual(await new SnapshotFeedbackStorage(driver).load(),{text:'private test text',key:'feedback-key-1',receipt:null});
  values.set(SnapshotFeedbackStorage.key,'{broken');await assert.rejects(first.load());
  assert.equal(values.get(SnapshotFeedbackStorage.key),'{broken');
});
