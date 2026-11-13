import test from 'node:test';
import assert from 'node:assert/strict';
import {SnapshotPreferences, type PreferencesDriver} from '../src/snapshot-preferences';

class Driver implements PreferencesDriver {
  values = new Map<string,unknown>(); fail = false;
  keys() {return [...this.values.keys()];}
  read(key: string) {return this.values.get(key);}
  async write(key: string,value: unknown) {if (this.fail) throw new Error('QUOTA'); this.values.set(key,structuredClone(value));}
  async remove(key: string) {if (this.fail) throw new Error('QUOTA'); this.values.delete(key);}
}
test('legacy display is readable; atomic combined display survives a fresh adapter and keeps legacy keys',async () => {
  const driver = new Driver(); driver.values.set('fridge.locale','ja'); driver.values.set('fridge.theme','dark');
  const prefs = new SnapshotPreferences(driver); assert.deepEqual(await prefs.readDisplay(),{locale:'ja',theme:'dark'});
  await prefs.writeDisplay({locale:'ar',theme:'light'});
  assert.deepEqual(await new SnapshotPreferences(driver).readDisplay(),{locale:'ar',theme:'light'});
  assert.equal(driver.read('fridge.locale'),'ja');
});
test('quota failure cannot leave half language/theme committed',async () => {
  const driver = new Driver(); const prefs = new SnapshotPreferences(driver);
  await prefs.writeDisplay({locale:'en',theme:'system'}); driver.fail = true;
  await assert.rejects(prefs.writeDisplay({locale:'ko',theme:'dark'}),/QUOTA/);
  assert.deepEqual(await new SnapshotPreferences(driver).readDisplay(),{locale:'en',theme:'system'});
});
test('corrupt display falls back in memory without overwriting evidence or blocking inventory; failed consent is not accepted',async () => {
  const driver = new Driver(); const prefs = new SnapshotPreferences(driver);
  driver.values.set('fridge.display.v1',{locale:null,theme:'invalid'});
  assert.deepEqual(await prefs.readDisplay(),{locale:null,theme:'system'}); assert.equal((driver.read('fridge.display.v1') as {theme:string}).theme,'invalid');
  driver.fail = true; await assert.rejects(prefs.writePrivacy({policyVersion:'V0.4',acceptedAt:'2026-11-13'}));
  assert.equal(await prefs.readPrivacy(),null);
});
test('withdrawal marker survives adapter recreation and a failed finish without touching consent/display',async()=>{
  const driver=new Driver(),prefs=new SnapshotPreferences(driver);
  await prefs.writePrivacy({policyVersion:'V0.4',acceptedAt:'2026-11-13T12:00:00Z'});
  await prefs.writeDisplay({locale:'ar',theme:'dark'});await prefs.beginWithdrawal();
  assert.equal(await new SnapshotPreferences(driver).readWithdrawalPending(),true);
  driver.fail=true;await assert.rejects(prefs.finishWithdrawal());
  assert.equal(await prefs.readWithdrawalPending(),true);assert.notEqual(await prefs.readPrivacy(),null);
  driver.fail=false;await prefs.finishWithdrawal();assert.equal(await prefs.readWithdrawalPending(),false);
  assert.deepEqual(await prefs.readDisplay(),{locale:'ar',theme:'dark'});
});
