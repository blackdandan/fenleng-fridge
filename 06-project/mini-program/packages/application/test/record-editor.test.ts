import test from 'node:test';
import assert from 'node:assert/strict';
import {addFood, editFood, emptyInventory, pending, type InventoryState} from '@fridge/domain';
import type {InventoryStoragePort, MediaPort} from '@fridge/platform-contracts';
import {InventoryRepository, RecordEditor, intervalFromText, localDateTime} from '../src/index';

class Storage implements InventoryStoragePort {
  fail = false; writes = 0;
  constructor(public state: InventoryState) {}
  async load() {return this.state;}
  async save(value: InventoryState) {this.writes++; if (this.fail) throw new Error('QUOTA'); this.state = value;}
}
class Media implements MediaPort {
  removed: string[] = []; copies = 0;
  chooseAlbum = async () => ['temporary'];
  attachCamera() {}
  async takePhoto() {return 'camera';}
  async persist(_source: string) {return `private/candidate-${++this.copies}.jpg`;}
  async removeManaged(path: string) {this.removed.push(path);}
}
const now = new Date(2026,10,13,12);
async function setup(shared = false) {
  let inventory = addFood(emptyInventory(),'001','private/original.jpg','cold',new Date(2026,10,1,10,22,33,444));
  inventory = addFood(inventory,'002',shared ? 'private/original.jpg' : 'private/other.jpg','cold',new Date(2026,10,1));
  const storage = new Storage(inventory); const repository = new InventoryRepository(storage,() => now);
  await repository.open(); const media = new Media(); let allowed = true;
  const food = repository.snapshot().foods['001'];
  const editor = new RecordEditor(food,repository,media,() => allowed);
  return {repository,storage,media,food,editor,revoke: () => {allowed = false;}};
}

test('moving and changing interval preserve exact dates/cycle, existing reminder and other records',async () => {
  const {repository,editor,food} = await setup();
  const other = repository.snapshot().foods['002']; const refs = repository.snapshot().reminders;
  editor.change({zone:'frozen',interval:'٢١'}); await editor.save();
  const saved = repository.snapshot().foods['001'];
  assert.equal(editor.snapshot().saved,true); assert.equal(saved.zone,'frozen'); assert.equal(saved.intervalDays,21);
  assert.equal(saved.addedAt,food.addedAt); assert.equal(saved.dueAt,food.dueAt); assert.equal(saved.cycle,food.cycle);
  assert.deepEqual(repository.snapshot().reminders,refs); assert.equal(repository.snapshot().foods['002'],other);
  assert.equal(repository.snapshot().nextNumber,3); await editor.close();
});
test('invalid input cannot save; dates roundtrip and localized integers have explicit bounds',async () => {
  for (const raw of ['', '0','3651','1.5','2e2','-1']) assert.equal(intervalFromText(raw),null);
  assert.equal(intervalFromText('۳۶۵۰'),3650); assert.equal(intervalFromText('१२'),12);
  assert.throws(() => localDateTime('2026-02-30','10:00'));
  assert.throws(() => localDateTime('2026-11-13','24:00'));
  const {editor,storage} = await setup(); const writes = storage.writes;
  editor.change({interval:'0'}); await editor.save();
  assert.equal(editor.snapshot().errorKey,'invalidInterval'); assert.equal(storage.writes,writes);
  editor.change({interval:'3',dueDay:'2026-02-30'}); await editor.save();
  assert.equal(editor.snapshot().errorKey,'error'); assert.equal(editor.snapshot().saved,false); await editor.close();
});
test('changing reminder time creates only the selected new cycle without reviving old pending',async () => {
  const {repository,editor,food} = await setup(); const original = repository.snapshot().reminders[0];
  editor.change({dueDay:'2026-11-20',dueTime:'17:35'}); await editor.save();
  const saved = repository.snapshot().foods['001']; assert.equal(saved.cycle,food.cycle+1);
  assert.deepEqual(pending(original,repository.snapshot(),now).map(f => f.id),['002']);
  assert.equal(new Date(saved.dueAt).getMinutes(),35); await editor.close();
});
test('replacing twice and closing removes only uncommitted candidates',async () => {
  const {editor,media,repository} = await setup();
  await editor.choosePhoto(); await editor.choosePhoto(); await editor.close();
  assert.deepEqual(media.removed,['private/candidate-1.jpg','private/candidate-2.jpg']);
  assert.equal(repository.snapshot().foods['001'].photoPath,'private/original.jpg');
});
test('failed save retains candidate and draft for retry without copying again or claiming success',async () => {
  const {editor,media,storage,repository} = await setup();
  await editor.choosePhoto(); storage.fail = true; await editor.save();
  assert.equal(editor.snapshot().saved,false); assert.equal(editor.snapshot().errorKey,'error');
  assert.equal(repository.snapshot().foods['001'].photoPath,'private/original.jpg'); assert.deepEqual(media.removed,[]);
  storage.fail = false; await editor.save();
  const committedWrites = storage.writes; await editor.save(); assert.equal(storage.writes,committedWrites);
  await editor.close();
  assert.equal(media.copies,1); assert.equal(editor.snapshot().saved,true);
  assert.equal(repository.snapshot().foods['001'].photoPath,'private/candidate-1.jpg');
  assert(repository.retainedPhotoPaths.has('private/original.jpg'));
  await repository.undo(); assert.equal(repository.snapshot().foods['001'].photoPath,'private/original.jpg');
});
test('permanent deletion clears undo/backup references but never removes another record shared photo',async () => {
  const normal = await setup(); await normal.editor.choosePhoto(); await normal.editor.delete(); await normal.editor.close();
  assert.equal(normal.repository.snapshot().foods['001'],undefined); assert.equal(normal.repository.canUndo,false);
  assert(!normal.repository.retainedPhotoPaths.has('private/original.jpg'));
  assert.deepEqual(normal.media.removed,['private/candidate-1.jpg','private/original.jpg']);
  assert.equal(normal.repository.snapshot().nextNumber,3);
  const shared = await setup(true); await shared.editor.delete(); await shared.editor.close();
  assert.deepEqual(shared.media.removed,[]); assert(shared.repository.retainedPhotoPaths.has('private/original.jpg'));
});
test('late album response after close cannot copy or commit; double taps share one operation',async () => {
  const {editor,media} = await setup(); let finish!: (v: string[]) => void; let calls = 0;
  media.chooseAlbum = () => {calls++; return new Promise(resolve => {finish = resolve;});};
  const first = editor.choosePhoto(); await Promise.resolve(); const second = editor.choosePhoto();
  const closing = editor.close(); finish(['temporary']); await Promise.all([first,second,closing]);
  assert.equal(calls,1); assert.equal(media.copies,0);
});
test('withdrawal during private copy cleans the candidate and prevents inventory exchange',async () => {
  const {editor,media,revoke,repository} = await setup(); let finish!: (v: string) => void;
  media.persist = () => new Promise(resolve => {finish = resolve;});
  const operation = editor.choosePhoto(); await Promise.resolve(); await Promise.resolve();
  revoke(); finish('private/late.jpg'); await operation; await editor.close();
  assert.deepEqual(media.removed,['private/late.jpg']); assert.equal(repository.snapshot().foods['001'].photoPath,'private/original.jpg');
});
test('external record change rejects stale form while due collection alone keeps form valid',async () => {
  const {editor,repository} = await setup(); await repository.refreshDue();
  await repository.update(s => editFood(s,'001',{zone:'pantry'}));
  editor.change({interval:'10'}); await editor.save();
  assert.equal(editor.snapshot().saved,false); assert.equal(editor.snapshot().errorKey,'error');
  assert.equal(repository.snapshot().foods['001'].zone,'pantry'); await editor.close();
});
