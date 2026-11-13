import {test} from 'node:test';
import assert from 'node:assert/strict';
import {addFood, emptyInventory, hasPending, organize, type InventoryState} from '@fridge/domain';
import type {InventoryStoragePort} from '@fridge/platform-contracts';
import {InventoryRepository} from '../src/index';

class MemoryStorage implements InventoryStoragePort {
  saved: InventoryState | null = null;
  fail = false;
  async load(): Promise<InventoryState | null> { return this.saved; }
  async save(state: InventoryState): Promise<void> {
    if (this.fail) throw new Error('QUOTA_EXCEEDED');
    this.saved = state;
  }
}
const now = new Date(2026, 10, 4, 18);

test('concurrent actions serialize; failed persistence never publishes success and can retry', async () => {
  const storage = new MemoryStorage();
  const repository = new InventoryRepository(storage, () => now);
  let changes = 0;
  repository.subscribe(() => changes++);
  await repository.open();
  const add = (id: string) => repository.update(s => addFood(s, id, `${id}.jpg`, 'cold', now));
  await Promise.all([add('a'), add('b')]);
  assert.equal(Object.keys(repository.snapshot().foods).length, 2);
  assert.equal(changes, 3);
  storage.fail = true;
  await assert.rejects(add('c'), /QUOTA/);
  assert.equal(repository.snapshot().foods.c, undefined);
  assert.equal(storage.saved!.foods.c, undefined);
  assert.equal(changes, 3);
  storage.fail = false;
  await add('c');
  assert.equal(Object.keys(repository.snapshot().foods).length, 3);
});

test('undo restores exact cycle and reminder; failed undo preserves retry state', async () => {
  const storage = new MemoryStorage();
  storage.saved = addFood(emptyInventory(), 'a', 'a.jpg', 'cold', new Date(2026, 10, 1));
  const repository = new InventoryRepository(storage, () => now);
  await repository.open();
  assert.equal(hasPending(repository.snapshot(), now), true);
  await repository.update(s => organize(s, {a: 'gone'}, now));
  assert.equal(hasPending(repository.snapshot(), now), false);
  storage.fail = true;
  await assert.rejects(repository.undo(), /QUOTA/);
  assert.equal(repository.canUndo, true);
  storage.fail = false;
  await repository.undo();
  assert.equal(hasPending(repository.snapshot(), now), true);
  assert.equal(repository.canUndo, false);
});

test('stale undo cannot erase a later capture or reuse its number', async () => {
  const repository = new InventoryRepository(new MemoryStorage(), () => now);
  await repository.open();
  await repository.update(state => addFood(state, '001', 'one.jpg', 'cold', now));
  const oldTicket = repository.revision;
  await repository.refreshDue();
  assert.equal(repository.revision, oldTicket);
  await repository.update(state => addFood(state, '002', 'two.jpg', 'cold', now));
  await assert.rejects(repository.undo(oldTicket), /UNDO_STATE_CHANGED/);
  assert.deepEqual(Object.keys(repository.snapshot().foods), ['001', '002']);
  await repository.undo(repository.revision);
  assert.deepEqual(Object.keys(repository.snapshot().foods), ['001']);
  assert.equal(repository.snapshot().nextNumber, 3);
});
