import {activeFoods, hasPending, pending, shouldShowInactivity, type FoodRecord, type InventoryState, type StorageZone} from '@fridge/domain';
export interface CabinetDoorModel { readonly zone: StorageZone; readonly shown: readonly FoodRecord[]; readonly count: number; readonly extraCount: number }
export interface CabinetModel { readonly doors: readonly CabinetDoorModel[]; readonly hasPending: boolean; readonly hintKey: 'dueHint' | 'inactivityHint' | null }
export function cabinetModel(state: InventoryState, now: Date): CabinetModel {
  const active = activeFoods(state);
  return {
    doors: (['cold','frozen','pantry'] as const).map(zone => {
      const foods = active.filter(food => food.zone === zone);
      const capacity = zone === 'cold' ? 6 : 3;
      const shown = foods.slice(0, foods.length > capacity ? capacity - 1 : capacity);
      return {zone, shown, count: foods.length, extraCount: foods.length - shown.length};
    }),
    hasPending: hasPending(state, now),
    hintKey: active.some(food => +new Date(food.dueAt) <= +now) ? 'dueHint' : shouldShowInactivity(state, now) ? 'inactivityHint' : null,
  };
}
export interface ReminderModel {
  readonly day: string; readonly originalCount: number; readonly pendingCount: number;
  readonly stateKey: 'pendingCount' | 'partiallyHandled' | 'handled';
}
export function reminderModels(state: InventoryState, now: Date): readonly ReminderModel[] {
  return state.reminders.map(reminder => {
    const count = pending(reminder, state, now).length;
    return {day: reminder.day, originalCount: reminder.references.length, pendingCount: count,
      stateKey: count === 0 ? 'handled' : count < reminder.references.length ? 'partiallyHandled' : 'pendingCount'};
  });
}
