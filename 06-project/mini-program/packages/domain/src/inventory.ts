import {activeFoods, calendarDay, scheduleCheck, type InventoryState, type StorageZone, type Remaining, type FoodRecord, type CycleReference} from './models';

const requireFood = (state: InventoryState, id: string): FoodRecord => {
  const food = state.foods[id];
  if (!food) throw new Error('INVENTORY_RECORD_MISSING');
  return food;
};
export function addFood(state: InventoryState, id: string, photoPath: string, zone: StorageZone, now: Date): InventoryState {
  if (!id || !photoPath || state.foods[id] || state.reminders.some(r => r.references.some(ref => ref.foodId === id))) {
    throw new Error('INVENTORY_ID_OR_PHOTO_INVALID');
  }
  const food: FoodRecord = {id, photoPath, zone, remaining: 'full', addedAt: now.toISOString(), confirmedAt: null,
    intervalDays: state.defaults[zone], cycle: 0,
    dueAt: scheduleCheck(now, state.defaults[zone], state.reminderHour, state.reminderMinute)};
  return {...state, nextNumber: state.nextNumber + 1, foods: {...state.foods, [id]: food}};
}
export function organize(state: InventoryState, selected: Readonly<Record<string, Remaining>>, now: Date): InventoryState {
  if (!Object.keys(selected).length) return state;
  const foods = {...state.foods};
  for (const [id, remaining] of Object.entries(selected)) {
    const food = requireFood(state, id);
    if (food.remaining === 'gone') throw new Error('INVENTORY_RECORD_ARCHIVED');
    foods[id] = {...food, remaining, confirmedAt: now.toISOString(), cycle: food.cycle + 1,
      dueAt: scheduleCheck(now, food.intervalDays, state.reminderHour, state.reminderMinute)};
  }
  return {...state, foods, lastOrganizedAt: now.toISOString()};
}
export type FoodEdit = Partial<Pick<FoodRecord, 'photoPath' | 'zone' | 'intervalDays' | 'addedAt' | 'dueAt'>>;
export function editFood(state: InventoryState, id: string, edit: FoodEdit): InventoryState {
  const food = requireFood(state, id);
  if (edit.intervalDays !== undefined && (!Number.isInteger(edit.intervalDays) || edit.intervalDays < 1 || edit.intervalDays > 3650)) {
    throw new Error('CHECK_INTERVAL_INVALID');
  }
  if (edit.photoPath !== undefined && !edit.photoPath) throw new Error('PHOTO_PATH_INVALID');
  if ([edit.addedAt, edit.dueAt].some(d => d !== undefined && !Number.isFinite(+new Date(d)))) throw new Error('CHECK_DATE_INVALID');
  return {...state, foods: {...state.foods, [id]: {...food, ...edit, cycle: food.cycle + (edit.dueAt === undefined ? 0 : 1)}}};
}
export function restoreFood(state: InventoryState, id: string, now: Date): InventoryState {
  const food = requireFood(state, id);
  if (food.remaining !== 'gone') throw new Error('INVENTORY_RECORD_NOT_ARCHIVED');
  return {...state, foods: {...state.foods, [id]: {...food, remaining: 'full', confirmedAt: now.toISOString(), cycle: food.cycle + 1,
    dueAt: scheduleCheck(now, food.intervalDays, state.reminderHour, state.reminderMinute)}}};
}
export function deleteFood(state: InventoryState, id: string): InventoryState {
  requireFood(state, id);
  const foods = {...state.foods};
  delete foods[id];
  return {...state, foods};
}
export function changeDefaults(state: InventoryState, values: Partial<Record<StorageZone, number>>, hour = state.reminderHour, minute = state.reminderMinute): InventoryState {
  Object.values(values).forEach(days => scheduleCheck(new Date(0), days, hour, minute));
  scheduleCheck(new Date(0), 1, hour, minute);
  return {...state, defaults: {...state.defaults, ...values}, reminderHour: hour, reminderMinute: minute};
}
export function collectDue(state: InventoryState, now: Date): InventoryState {
  const byDay = new Map<string, CycleReference[]>(state.reminders.map(r => [r.day, [...r.references]]));
  for (const food of activeFoods(state)) {
    if (new Date(food.dueAt) > now || [...byDay.values()].some(refs => refs.some(ref => ref.foodId === food.id && ref.cycle === food.cycle))) continue;
    const day = calendarDay(food.dueAt);
    byDay.set(day, [...(byDay.get(day) ?? []), {foodId: food.id, cycle: food.cycle}]);
  }
  return {...state, reminders: [...byDay.keys()].sort().reverse().map(day => ({day, references: byDay.get(day)!}))};
}
