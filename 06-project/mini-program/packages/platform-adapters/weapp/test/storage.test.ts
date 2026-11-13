import test from 'node:test';
import assert from 'node:assert/strict';
import {addFood, deleteFood, emptyInventory} from '@fridge/domain';
import {SnapshotInventoryStorage as WeappInventoryStorage, type InventoryStorageDriver} from '../src/snapshot-storage';

const main = 'fenleng-fridge-inventory-v1';
function fixture() {
  const values = new Map<string, string>();
  const driver: InventoryStorageDriver = {
    keys: () => [...values.keys()],
    read: async key => {if (!values.has(key)) throw new Error('READ_FAILED'); return values.get(key)!;},
    write: async (key, data) => {values.set(key, data);},
  };
  return {values, driver};
}
test('backup recovery cannot resurrect a permanently deleted photo record', async () => {
  const f = fixture(); const storage = new WeappInventoryStorage(f.driver);
  let state = emptyInventory();
  for (const id of ['001', '002']) state = addFood(state, id, `${id}.jpg`, 'cold', new Date(2026, 10, 1));
  await storage.save(state);
  await storage.save(deleteFood(state, '001'));
  f.values.set(main, '{broken');
  const recovery = new WeappInventoryStorage(f.driver);
  const recovered = (await recovery.load())!;
  assert.deepEqual(Object.keys(recovered.foods), ['002']);
  assert.equal(recovered.nextNumber, 3);
  await recovery.save(recovered);
  assert.deepEqual(Object.keys((await new WeappInventoryStorage(f.driver).load())!.foods), ['002']);
});
test('quota failure preserves committed main; a read failure is not an empty fridge', async () => {
  const f = fixture(); const storage = new WeappInventoryStorage(f.driver);
  const original = addFood(emptyInventory(), '001', 'one.jpg', 'cold', new Date());
  await storage.save(original);
  const write = f.driver.write;
  f.driver.write = async (key, data) => {if (key === main) throw new Error('QUOTA'); await write(key, data);};
  await assert.rejects(storage.save(deleteFood(original, '001')), /QUOTA/);
  assert.deepEqual(await new WeappInventoryStorage(f.driver).load(), original);
  f.driver.read = async () => {throw new Error('READ_FAILED');};
  await assert.rejects(new WeappInventoryStorage(f.driver).load(), /READ_FAILED/);
});
