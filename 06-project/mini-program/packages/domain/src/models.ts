export const zones = ['cold', 'frozen', 'pantry'] as const;
export type StorageZone = typeof zones[number];
export type Remaining = 'full' | 'half' | 'small' | 'gone';
export interface FoodRecord {
  readonly id: string;
  readonly photoPath: string;
  readonly zone: StorageZone;
  readonly remaining: Remaining;
  readonly addedAt: string;
  readonly confirmedAt: string | null;
  readonly dueAt: string;
  readonly intervalDays: number;
  readonly cycle: number;
}
export interface CycleReference { readonly foodId: string; readonly cycle: number }
export interface CheckReminder { readonly day: string; readonly references: readonly CycleReference[] }
export interface InventoryState {
  readonly schemaVersion: 1;
  readonly nextNumber: number;
  readonly foods: Readonly<Record<string, FoodRecord>>;
  readonly reminders: readonly CheckReminder[];
  readonly defaults: Readonly<Record<StorageZone, number>>;
  readonly lastOrganizedAt: string | null;
  readonly reminderHour: number;
  readonly reminderMinute: number;
}
export const emptyInventory = (): InventoryState => ({schemaVersion: 1, nextNumber: 1, foods: {}, reminders: [],
  defaults: {cold: 3, frozen: 14, pantry: 3}, lastOrganizedAt: null, reminderHour: 17, reminderMinute: 30});

export function calendarDay(value: Date | string): string {
  const d = new Date(value);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
export function scheduleCheck(from: Date, days: number, hour = 17, minute = 30): string {
  if (!Number.isInteger(days) || days < 1 || days > 3650 || !Number.isInteger(hour) || hour < 0 || hour > 23 ||
      !Number.isInteger(minute) || minute < 0 || minute > 59) throw new Error('CHECK_SCHEDULE_INVALID');
  return new Date(from.getFullYear(), from.getMonth(), from.getDate() + days, hour, minute).toISOString();
}
export function pending(reminder: CheckReminder, state: InventoryState, now: Date): FoodRecord[] {
  return reminder.references.flatMap(ref => {
    const food = state.foods[ref.foodId];
    return food && food.remaining !== 'gone' && food.cycle === ref.cycle && new Date(food.dueAt) <= now ? [food] : [];
  });
}
export const activeFoods = (state: InventoryState): FoodRecord[] => Object.values(state.foods).filter(f => f.remaining !== 'gone');
export const historyFoods = (state: InventoryState): FoodRecord[] => Object.values(state.foods).filter(f => f.remaining === 'gone');
export const hasPending = (state: InventoryState, now: Date): boolean => state.reminders.some(r => pending(r, state, now).length > 0);
export function shouldShowInactivity(state: InventoryState, now: Date): boolean {
  const active = activeFoods(state);
  if (!active.length || active.some(f => new Date(f.dueAt) <= now)) return false;
  const origin = state.lastOrganizedAt ? +new Date(state.lastOrganizedAt) : Math.min(...active.map(f => +new Date(f.addedAt)));
  return +now - origin > 2 * 86400000;
}
