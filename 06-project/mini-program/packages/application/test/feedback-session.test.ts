import test from 'node:test';
import assert from 'node:assert/strict';
import {FeedbackSession} from '../src/feedback-session.ts';
import {FeedbackFailure, type FeedbackDraft} from '../../platform-contracts/src/index.ts';
const empty: FeedbackDraft = {text:'',key:null,receipt:null};
function fixture() {
  let draft = {...empty}, consent = true, writes = 0, failWrite = 0, calls = 0;
  const keys: string[] = [];
  let send: (message: string,key: string) => Promise<string> = async () => 'feedback-1';
  const storage = {load:async () => ({...draft}),save:async (value: FeedbackDraft) => {
    if (++writes === failWrite) throw Error('quota');draft = {...value};
  }};
  const gateway = {submit:async (message: string,key: string) => {calls++;keys.push(key);return send(message,key);}};
  const create = () => new FeedbackSession(storage,gateway,() => consent,() => `feedback-test-${keys.length+1}`);
  return {create,storage,keys,calls:() => calls,draft:() => draft,fail:(value: number) => {failWrite=value;},
    consent:(value: boolean) => {consent=value;},send:(value: typeof send) => {send=value;}};
}
test('failed submission and process recreation preserve payload and idempotency key', async () => {
  const f=fixture();let session=f.create();await session.start();await session.edit('text');
  f.send(async()=>{throw Error('private network details');});await session.submit();
  assert.equal(session.snapshot().errorKey,'feedbackFailed');assert.equal(f.draft().text,'text');
  await session.close();session=f.create();await session.start();
  f.send(async()=> 'feedback-1');await session.submit();assert.equal(f.keys[0],f.keys[1]);
  assert.deepEqual(f.draft(),{text:'',key:null,receipt:'feedback-1'});await session.close();
});
test('concurrent submit sends one request and locks edits', async () => {
  const f=fixture(),session=f.create();await session.start();await session.edit('text');
  let resolve!: (id: string) => void;f.send(()=>new Promise(yes=>{resolve=yes;}));
  const first=session.submit(),second=session.submit();assert.equal(first,second);
  await new Promise(resolve=>setImmediate(resolve));await session.edit('changed');
  assert.equal(f.calls(),1);assert.equal(session.snapshot().text,'text');
  resolve('receipt-1');await first;assert.equal(session.snapshot().receipt,'receipt-1');await session.close();
});
test('synchronous loading/busy observers cannot trigger duplicate work', async () => {
  const f=fixture(),session=f.create();let loads=0;const load=f.storage.load;
  f.storage.load=async()=>{loads++;return load();};
  const unsubscribe=session.subscribe(()=>{
    if (session.snapshot().loading) void session.start();
    if (session.snapshot().busy) void session.submit();
  });
  await session.start();await session.edit('text');await session.submit();
  assert.equal(loads,1);assert.equal(f.calls(),1);unsubscribe();await session.close();
});
test('draft persistence failure prevents network, and receipt persistence failure retains retry key', async () => {
  const f=fixture(),session=f.create();await session.start();await session.edit('text');
  f.fail(2);await session.submit();assert.equal(f.calls(),0);
  assert.equal(session.snapshot().errorKey,'feedbackDraftSaveFailed');
  f.fail(4);await session.submit();assert.equal(f.calls(),1);
  assert.equal(session.snapshot().receipt,null);assert.equal(session.snapshot().text,'text');
  await session.submit();assert.equal(f.keys[0],f.keys[1]);assert.equal(session.snapshot().receipt,'feedback-1');
  await session.close();
});
test('changed payload gets a new key while surrounding whitespace retains existing key', async () => {
  const f=fixture(),session=f.create();await session.start();await session.edit('text');
  f.send(async()=>{throw Error('offline');});await session.submit();const key=session.snapshot().key;
  await session.edit(' text ');assert.equal(session.snapshot().key,key);
  await session.edit('changed');assert.equal(session.snapshot().key,null);await session.submit();
  assert.notEqual(f.keys[0],f.keys[1]);await session.close();
});
test('invalid input and absent consent never send; withdrawal ignores late success', async () => {
  const f=fixture(),session=f.create();await session.start();await session.submit();
  assert.equal(session.snapshot().errorKey,'feedbackValidation');assert.equal(f.calls(),0);
  await session.edit('text');f.consent(false);await session.submit();assert.equal(f.calls(),0);
  f.consent(true);let resolve!: (id: string) => void;
  f.send(()=>new Promise(yes=>{resolve=yes;}));const sending=session.submit();
  await new Promise(resolve=>setImmediate(resolve));f.consent(false);resolve('late-success');await sending;
  assert.equal(session.snapshot().receipt,null);assert.equal(f.draft().text,'text');await session.close();
});
test('load failure is retryable and received receipt survives reopening until write another', async () => {
  const f=fixture(),load=f.storage.load;let failed=true;
  f.storage.load=async()=>{if(failed)throw Error('corrupt');return load();};
  let session=f.create();await session.start();assert.equal(session.snapshot().initialized,false);
  failed=false;await session.start();await session.edit('text');await session.submit();await session.close();
  session=f.create();await session.start();assert.equal(session.snapshot().receipt,'feedback-1');
  await session.submit();assert.equal(f.calls(),1);await session.writeAnother();assert.deepEqual(f.draft(),empty);
  await session.close();
});
test('missing service errors stay translated and close prevents late receipt publication', async () => {
  const f=fixture(),session=f.create();await session.start();await session.edit('text');
  f.send(async()=>{throw new FeedbackFailure('feedbackSessionUnavailable');});await session.submit();
  assert.equal(session.snapshot().errorKey,'feedbackSessionUnavailable');
  let resolve!: (id: string) => void;f.send(()=>new Promise(yes=>{resolve=yes;}));
  const sending=session.submit();await new Promise(resolve=>setImmediate(resolve));const closing=session.close();
  resolve('late-success');await Promise.all([sending,closing]);assert.equal(f.draft().receipt,null);
});
