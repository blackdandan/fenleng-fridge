import test from 'node:test';
import assert from 'node:assert/strict';
import {addFood, emptyInventory, organize, type InventoryState} from '@fridge/domain';
import type {MediaPort, PreferencesPort} from '@fridge/platform-contracts';
import {FridgeController, InventoryRepository} from '../src/index';
const now = new Date(2026,10,13,12);
async function setup() {
  let inventory = addFood(emptyInventory(),'001','old.jpg','cold',new Date(2026,10,1));
  inventory = addFood(inventory,'002','two.jpg','cold',new Date(2026,10,1));
  inventory = organize(inventory,{'001':'gone'},now);
  const storage = {state:inventory,fail:false,async load() {return this.state;},async save(state: InventoryState) {if (this.fail) throw new Error('QUOTA'); this.state = state;}};
  const display = {locale:null as string|null,theme:'system' as 'system'|'light'|'dark',fail:false};
  const prefs: PreferencesPort = {async readPrivacy() {return {policyVersion:'V0.4',acceptedAt:now.toISOString()};},async writePrivacy() {},
    async readDisplay() {return {locale:display.locale,theme:display.theme};}, async writeDisplay(value) {if (display.fail) throw new Error('QUOTA'); Object.assign(display,value);}};
  const retained: ReadonlySet<string>[] = [];
  const media: MediaPort = {attachCamera() {},async chooseAlbum() {return [];},async takePhoto() {return 'temp';},
    async persist() {return 'new.jpg';},async removeManaged() {}, async collectUnused(paths) {retained.push(new Set(paths));}};
  const repository = new InventoryRepository(storage,() => now);
  const controller = new FridgeController(repository,prefs,media,() => now); await controller.initialize();
  return {controller,repository,storage,display,retained};
}
test('defaults affect new capture only; existing dates/cycles remain untouched',async () => {
  const {controller,repository} = await setup();
  try {
    const existing = structuredClone(repository.snapshot().foods);
    await controller.defaults({cold:5,frozen:20,pantry:7},8,5);
    assert.deepEqual(repository.snapshot().foods,existing);
    controller.openCamera('cold'); await controller.capture();
    const photo = repository.snapshot().foods['003']; assert.equal(photo.intervalDays,5);
    assert.equal(new Date(photo.dueAt).getHours(),8); assert.equal(new Date(photo.dueAt).getMinutes(),5);
  } finally {controller.close();}
});
test('restore is retryable, creates one new cycle and does not modify other records',async () => {
  const {controller,repository,storage} = await setup();
  try {
    const old = repository.snapshot().foods['001']; const other = repository.snapshot().foods['002'];
    storage.fail = true; await controller.restore('001'); assert.equal(controller.snapshot().errorKey,'error');
    assert.equal(repository.snapshot().foods['001'],old);
    storage.fail = false; await Promise.all([controller.restore('001'),controller.restore('001')]);
    assert.equal(repository.snapshot().foods['001'].cycle,old.cycle+1);
    assert.equal(repository.snapshot().foods['001'].remaining,'full'); assert.equal(repository.snapshot().foods['002'],other);
  } finally {controller.close();}
});
test('failed display write leaves current UI preferences intact and successful retry commits both',async () => {
  const {controller,display} = await setup();
  try {
    display.fail = true; await controller.display('ar','dark'); assert.equal(controller.snapshot().locale,null);
    assert.equal(controller.snapshot().theme,'system'); assert.equal(controller.snapshot().busy,false);
    display.fail = false; await controller.display('ar','dark');
    assert.equal(controller.snapshot().locale,'ar'); assert.equal(controller.snapshot().theme,'dark');
  } finally {controller.close();}
});
test('detail keeps review background records and startup collection retains active plus historical photos',async () => {
  const {controller,retained} = await setup();
  try {
    assert.equal(retained.length,1); assert.deepEqual([...retained[0]].sort(),['old.jpg','two.jpg']);
    controller.navigate({name:'review'}); controller.navigate({name:'detail',id:'002'});
    assert.equal(controller.backgroundRoute.name,'review'); assert.deepEqual(controller.reviewFoods(controller.backgroundRoute).map(f => f.id),['002']);
    controller.back(); assert.equal(controller.snapshot().route.name,'review');
  } finally {controller.close();}
});
