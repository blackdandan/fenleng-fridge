import test from 'node:test';
import assert from 'node:assert/strict';
import {addFood, emptyInventory, type InventoryState} from '@fridge/domain';
import type {InventoryStoragePort, MediaPort, PreferencesPort, PrivacyRecord} from '@fridge/platform-contracts';
import {CaptureSession, FridgeController, InventoryRepository, reminderModels} from '../src/index';

const now = new Date(2026, 10, 6, 18);
class Storage implements InventoryStoragePort {
  state: InventoryState | null = null;
  loads = 0; writes = 0; failAt = 0;
  async load() {this.loads++; return this.state;}
  async save(state: InventoryState) {
    this.writes++;
    if (this.writes === this.failAt) throw new Error('QUOTA');
    this.state = state;
  }
}
class Media implements MediaPort {
  copies: string[] = []; removed: string[] = [];
  chooseAlbum = async () => ['temporary-one', 'temporary-two'];
  attachCamera() {}
  async takePhoto() {return 'temporary-camera';}
  async persist(path: string) {this.copies.push(path); return `private/${path}`;}
  async removeManaged(path: string) {this.removed.push(path);}
}
function preferences(): PreferencesPort & {consent: PrivacyRecord | null; fail: boolean} {
  return {
    consent: null, fail: false,
    async readPrivacy() {return this.consent;},
    async writePrivacy(record) {if (this.fail) throw new Error('QUOTA'); this.consent = record;},
    async readDisplay() {return {locale: null, theme: 'system' as const};},
    async writeDisplay() {},
  };
}
test('partial multi-photo import retries the persisted private copy without duplicates', async () => {
  const storage = new Storage(); const repository = new InventoryRepository(storage, () => now);
  await repository.open(); storage.failAt = 3;
  const media = new Media();
  const capture = new CaptureSession(repository, media, 'cold', () => {}, () => now);
  await assert.rejects(capture.album(), /QUOTA/);
  assert.equal(capture.snapshot().savedCount, 1);
  assert.equal(capture.snapshot().pendingCount, 1);
  assert.equal(capture.snapshot().busy, false);
  capture.selectZone('frozen');
  await capture.retry();
  assert.deepEqual(Object.keys(repository.snapshot().foods), ['001', '002']);
  assert.deepEqual(Object.values(repository.snapshot().foods).map(food => food.zone), ['cold', 'cold']);
  assert.deepEqual(media.copies, ['temporary-one', 'temporary-two']);
  assert.equal(capture.snapshot().savedCount, 2);
  assert.equal(capture.snapshot().pendingCount, 0);
});
test('abandon removes only uncommitted managed photos, preserving saved records', async () => {
  const storage = new Storage(); const repository = new InventoryRepository(storage, () => now);
  await repository.open(); storage.failAt = 3;
  const media = new Media(); const capture = new CaptureSession(repository, media, 'cold', () => {}, () => now);
  await assert.rejects(capture.album());
  await capture.abandon();
  assert.deepEqual(media.removed, ['private/temporary-two']);
  assert.equal(repository.snapshot().foods['001'].photoPath, 'private/temporary-one');
  assert.equal(capture.snapshot().pendingCount, 0);
});
test('first-entry and failed consent persistence cannot open business storage', async () => {
  const storage = new Storage(); const prefs = preferences();
  const controller = new FridgeController(new InventoryRepository(storage, () => now), prefs, new Media(), () => now);
  try {
    await controller.initialize();
    assert.equal(controller.snapshot().stage, 'consent');
    controller.decline(); await controller.capture();
    assert.equal(storage.loads, 0);
    prefs.fail = true; await controller.accept();
    assert.equal(storage.loads, 0);
    prefs.fail = false; await controller.accept();
    assert.equal(prefs.consent?.policyVersion, FridgeController.policyVersion);
    assert.equal(controller.snapshot().stage, 'ready');
    assert.equal(storage.loads, 1);
  } finally {controller.close();}
});
test('reminder review closes only selected cycles; undo restores the original pending record', async () => {
  const storage = new Storage(); let state = emptyInventory();
  for (const id of ['001', '002']) state = addFood(state, id, `${id}.jpg`, 'cold', new Date(2026, 10, 1));
  storage.state = state;
  const prefs = preferences(); prefs.consent = {policyVersion: FridgeController.policyVersion, acceptedAt: now.toISOString()};
  const controller = new FridgeController(new InventoryRepository(storage, () => now), prefs, new Media(), () => now);
  try {
    await controller.initialize();
    const day = controller.snapshot().inventory.reminders[0].day;
    controller.navigate({name: 'review', day});
    assert.equal(controller.reviewFoods().length, 2);
    assert.deepEqual(reminderModels(controller.snapshot().inventory, now)[0], {day, originalCount: 2, pendingCount: 2, stateKey: 'pendingCount'});
    await controller.organize('001', 'half');
    assert.deepEqual(controller.reviewFoods().map(food => food.id), ['002']);
    assert.deepEqual(reminderModels(controller.snapshot().inventory, now)[0], {day, originalCount: 2, pendingCount: 1, stateKey: 'partiallyHandled'});
    const ticket = controller.snapshot().undoRevision!;
    await controller.undo(ticket);
    assert.equal(controller.reviewFoods().length, 2);
    await controller.organize('001', 'gone');
    await controller.organize('002', 'full');
    assert.equal(controller.reviewFoods().length, 0);
    assert.deepEqual(reminderModels(controller.snapshot().inventory, now)[0], {day, originalCount: 2, pendingCount: 0, stateKey: 'handled'});
    assert.equal(controller.snapshot().inventory.reminders[0].references.length, 2);
  } finally {controller.close();}
});
