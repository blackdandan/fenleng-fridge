import {calendarDay, deleteFood, editFood, type FoodEdit, type FoodRecord, type StorageZone} from '@fridge/domain';
import type {MediaPort} from '@fridge/platform-contracts';
import type {InventoryRepository} from './inventory-repository';
import {intervalFromText, localDateTime, timeValue} from './editor-values';

export interface EditorDraft {
  readonly zone: StorageZone; readonly interval: string; readonly photoPath: string;
  readonly addedDay: string; readonly addedTime: string; readonly dueDay: string; readonly dueTime: string;
}
export interface EditorSnapshot {
  readonly draft: EditorDraft; readonly busy: boolean; readonly errorKey: string | null;
  readonly saved: boolean; readonly deleted: boolean;
}
export class RecordEditor {
  private listeners = new Set<() => void>();
  private closed = false;
  private candidate: string | null = null;
  private operation: Promise<void> | null = null;
  private value: EditorSnapshot;
  constructor(readonly food: FoodRecord, private repository: InventoryRepository,
    private media: MediaPort, private allowed: () => boolean) {
    this.value = {busy: false, errorKey: null, saved: false, deleted: false, draft: {
      zone: food.zone, interval: String(food.intervalDays), photoPath: food.photoPath,
      addedDay: calendarDay(food.addedAt), addedTime: timeValue(food.addedAt),
      dueDay: calendarDay(food.dueAt), dueTime: timeValue(food.dueAt),
    }};
  }
  snapshot = (): EditorSnapshot => this.value;
  subscribe = (listener: () => void): (() => void) => {this.listeners.add(listener); return () => this.listeners.delete(listener);};
  private publish(change: Partial<EditorSnapshot>) {
    this.value = {...this.value, ...change};
    if (!this.closed) this.listeners.forEach(listener => listener());
  }
  change = (change: Partial<EditorDraft>): void => {
    if (!this.closed && !this.value.busy) this.publish({draft: {...this.value.draft, ...change}, errorKey: null});
  };
  private async removeUnused(path: string | null): Promise<void> {
    if (path && !this.repository.retainedPhotoPaths.has(path)) await this.media.removeManaged(path).catch(() => {});
  }
  private checkCurrent(): void {
    if (this.closed || !this.allowed()) throw new Error('EDIT_CANCELLED');
    if (JSON.stringify(this.repository.snapshot().foods[this.food.id]) !== JSON.stringify(this.food)) throw new Error('EDIT_RECORD_CHANGED');
  }
  private run(action: () => Promise<void>): Promise<void> {
    if (this.closed || this.value.busy || this.value.saved || this.value.deleted) return this.operation ?? Promise.resolve();
    this.publish({busy: true, errorKey: null});
    const operation = Promise.resolve().then(async () => {
      try {this.checkCurrent(); await action();}
      catch (error) {this.publish({errorKey: error instanceof Error && error.message === 'CHECK_INTERVAL_INVALID' ? 'invalidInterval' : 'error'});}
      finally {this.publish({busy: false});}
    });
    this.operation = operation;
    return operation;
  }
  choosePhoto = (): Promise<void> => this.run(async () => {
    const source = this.media.chooseReplacement ? await this.media.chooseReplacement() : (await this.media.chooseAlbum(1))[0];
    if (!source || this.closed || !this.allowed()) return;
    const next = await this.media.persist(source);
    if (this.closed || !this.allowed()) {await this.removeUnused(next); return;}
    const previous = this.candidate; this.candidate = next;
    this.publish({draft: {...this.value.draft, photoPath: next}});
    await this.removeUnused(previous);
  });
  save = (): Promise<void> => this.run(async () => {
    const draft = this.value.draft; const intervalDays = intervalFromText(draft.interval);
    if (intervalDays === null) throw new Error('CHECK_INTERVAL_INVALID');
    // Preserve full stored precision unless the corresponding picker actually changed.
    const changedAdded = draft.addedDay !== calendarDay(this.food.addedAt) || draft.addedTime !== timeValue(this.food.addedAt);
    const changedDue = draft.dueDay !== calendarDay(this.food.dueAt) || draft.dueTime !== timeValue(this.food.dueAt);
    const edit: FoodEdit = {zone: draft.zone, intervalDays, photoPath: draft.photoPath,
      ...(changedAdded ? {addedAt: localDateTime(draft.addedDay, draft.addedTime)} : {}),
      ...(changedDue ? {dueAt: localDateTime(draft.dueDay, draft.dueTime)} : {}),
    };
    await this.repository.update(state => {this.checkCurrent(); return editFood(state, this.food.id, edit);});
    this.candidate = null; this.publish({saved: true});
    await this.removeUnused(this.food.photoPath);
  });
  delete = (): Promise<void> => this.run(async () => {
    await this.repository.update(state => {this.checkCurrent(); return deleteFood(state, this.food.id);}, false, true);
    await this.removeUnused(this.candidate); this.candidate = null;
    await this.removeUnused(this.food.photoPath); this.publish({deleted: true});
  });
  async close(): Promise<void> {
    this.closed = true; this.listeners.clear();
    await this.operation; await this.removeUnused(this.candidate); this.candidate = null;
  }
}
