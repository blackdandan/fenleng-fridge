import {type InventoryState, type FoodRecord, zones} from './models';

function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('INVENTORY_DATA_INVALID');
  return value as Record<string, unknown>;
}
export function decodeInventory(raw: string): InventoryState {
  const value = object(JSON.parse(raw));
  if (value.schemaVersion !== 1 || !Array.isArray(value.foods) || !Array.isArray(value.reminders)) throw new Error('INVENTORY_SCHEMA_UNSUPPORTED');
  const records: FoodRecord[] = value.foods.map(item => {
    const food = object(item);
    if (typeof food.id !== 'string' || !food.id || typeof food.photoPath !== 'string' || !food.photoPath ||
        !zones.includes(food.zone as never) || !['full','half','small','gone'].includes(String(food.remaining)) ||
        !Number.isInteger(food.intervalDays) || Number(food.intervalDays) < 1 || Number(food.intervalDays) > 3650 ||
        !Number.isInteger(food.cycle) || Number(food.cycle) < 0 ||
        !Number.isFinite(+new Date(String(food.addedAt))) || !Number.isFinite(+new Date(String(food.dueAt))) ||
        (food.confirmedAt !== null && !Number.isFinite(+new Date(String(food.confirmedAt))))) throw new Error('INVENTORY_RECORD_INVALID');
    return food as unknown as FoodRecord;
  });
  if (new Set(records.map(f => f.id)).size !== records.length) throw new Error('INVENTORY_DUPLICATE_ID');
  const defaults = object(value.defaults);
  if (zones.some(z => !Number.isInteger(defaults[z]) || Number(defaults[z]) < 1 || Number(defaults[z]) > 3650) ||
      !Number.isInteger(value.reminderHour) || Number(value.reminderHour) < 0 || Number(value.reminderHour) > 23 ||
      !Number.isInteger(value.reminderMinute) || Number(value.reminderMinute) < 0 || Number(value.reminderMinute) > 59) {
    throw new Error('INVENTORY_DEFAULTS_INVALID');
  }
  for (const reminder of value.reminders) {
    const r = object(reminder);
    if (typeof r.day !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(r.day) || !Array.isArray(r.references)) throw new Error('INVENTORY_REMINDER_INVALID');
    for (const ref of r.references) {
      const item = object(ref);
      if (typeof item.foodId !== 'string' || !Number.isInteger(item.cycle) || Number(item.cycle) < 0) throw new Error('INVENTORY_REFERENCE_INVALID');
    }
  }
  if (value.lastOrganizedAt !== null && !Number.isFinite(+new Date(String(value.lastOrganizedAt)))) throw new Error('INVENTORY_DATE_INVALID');
  const nextNumber = value.nextNumber ?? Math.max(1, ...records.map(f => /^\d+$/.test(f.id) ? Number(f.id) + 1 : 1));
  if (!Number.isSafeInteger(nextNumber) || Number(nextNumber) < 1) throw new Error('INVENTORY_SEQUENCE_INVALID');
  return {...value, nextNumber, foods: Object.fromEntries(records.map(f => [f.id, f]))} as unknown as InventoryState;
}
export function encodeInventory(state: InventoryState): string {
  return JSON.stringify({...state, foods: Object.values(state.foods)});
}
