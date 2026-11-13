import {test} from 'node:test';
import assert from 'node:assert/strict';
import {emptyInventory, addFood, editFood, changeDefaults, organize, collectDue, pending, hasPending, restoreFood, deleteFood,
  activeFoods, shouldShowInactivity, encodeInventory, decodeInventory} from '../src/index';

const start = new Date(2026, 10, 1, 10);
const now = new Date(2026, 10, 4, 18);
const add = (id: string, state = emptyInventory(), date = start) => addFood(state, id, `${id}.jpg`, 'cold', date);

test('empty install, calendar defaults and non-retroactive default changes', () => {
  assert.equal(activeFoods(emptyInventory()).length, 0);
  const state = add('a');
  assert.equal(+new Date(state.foods.a.dueAt), +new Date(2026, 10, 4, 17, 30));
  const updated = changeDefaults(state, {cold: 8});
  assert.equal(updated.foods.a.intervalDays, 3);
  assert.equal(add('b', updated).foods.b.intervalDays, 8);
});
test('same-day incremental reminders merge, multi-day catchup and deduplication', () => {
  let state = add('c', add('b', add('a')), new Date(2026, 10, 2, 10));
  state = editFood(state, 'b', {dueAt: new Date(2026, 10, 4, 20).toISOString()});
  state = collectDue(state, now);
  assert.equal(state.reminders[0].references.length, 1);
  state = collectDue(state, new Date(2026, 10, 4, 21));
  assert.equal(state.reminders[0].references.length, 2);
  state = collectDue(collectDue(state, new Date(2026, 10, 8)), new Date(2026, 10, 8));
  assert.deepEqual(state.reminders.map(r => r.day), ['2026-11-05', '2026-11-04']);
  assert.equal(state.reminders[1].references.length, 2);
});
test('partial and complete resolution retain original count and unselected records', () => {
  let state = collectDue(add('b', add('a')), now);
  state = organize(state, {a: 'half'}, now);
  assert.equal(state.reminders[0].references.length, 2);
  assert.deepEqual(pending(state.reminders[0], state, now).map(f => f.id), ['b']);
  assert.equal(state.foods.b.confirmedAt, null);
  state = organize(state, {b: 'gone'}, now);
  assert.equal(hasPending(state, now), false);
  assert.equal(state.reminders.length, 1);
});
test('absolute remaining state, movement and interval change preserve due cycle', () => {
  let state = collectDue(add('a'), now);
  state = editFood(state, 'a', {zone: 'frozen', intervalDays: 14});
  assert.equal(hasPending(state, now), true);
  assert.equal(state.foods.a.addedAt, start.toISOString());
  state = organize(organize(state, {a: 'half'}, now), {a: 'half'}, now);
  assert.equal(state.foods.a.remaining, 'half');
  state = organize(state, {a: 'full'}, now);
  assert.equal(state.foods.a.remaining, 'full');
  assert.equal(+new Date(state.foods.a.dueAt), +new Date(2026, 10, 18, 17, 30));
});
test('reschedule and history restoration never reactivate old reminder cycle', () => {
  let state = collectDue(add('a'), now);
  state = editFood(state, 'a', {dueAt: new Date(2026, 10, 10).toISOString()});
  assert.equal(hasPending(state, now), false);
  state = organize(state, {a: 'gone'}, now);
  const cycle = state.foods.a.cycle;
  state = restoreFood(state, 'a', now);
  assert.equal(state.foods.a.cycle, cycle + 1);
  assert.equal(pending(state.reminders[0], state, new Date(2026, 11, 1)).length, 0);
  state = collectDue(state, new Date(2026, 11, 1));
  assert.equal(pending(state.reminders[0], state, new Date(2026, 11, 1)).length, 1);
  assert.equal(hasPending(deleteFood(state, 'a'), new Date(2026, 11, 1)), false);
});
test('new cycle notifies and persistence keeps old reminder completed', () => {
  let state = collectDue(add('a'), now);
  state = organize(state, {a: 'small'}, now);
  state = collectDue(state, new Date(2026, 10, 8));
  state = decodeInventory(encodeInventory(state));
  assert.equal(state.reminders.length, 2);
  assert.equal(pending(state.reminders[1], state, new Date(2026, 10, 8)).length, 0);
  assert.equal(pending(state.reminders[0], state, new Date(2026, 10, 8)).length, 1);
});
test('inactivity resets only by actual organization, due card has priority', () => {
  let state = addFood(emptyInventory(), 'a', 'a.jpg', 'frozen', start);
  assert.equal(shouldShowInactivity(state, now), true);
  state = add('b', state, now);
  assert.equal(shouldShowInactivity(state, now), true);
  state = organize(state, {a: 'full'}, now);
  assert.equal(shouldShowInactivity(state, now), false);
  assert.equal(shouldShowInactivity(state, new Date(2026, 10, 8)), false);
});
test('invalid intervals and corrupt snapshots rejected without mutation', () => {
  const state = add('a');
  assert.throws(() => add('a', state), /INVALID/);
  assert.throws(() => changeDefaults(state, {cold: 0}), /INVALID/);
  assert.throws(() => decodeInventory('{"schemaVersion":9}'), /UNSUPPORTED/);
  assert.equal(state.foods.a.intervalDays, 3);
});
