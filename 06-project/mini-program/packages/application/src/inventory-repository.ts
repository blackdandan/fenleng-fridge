import {collectDue, emptyInventory, type InventoryState} from '@fridge/domain';
import type {InventoryStoragePort} from '@fridge/platform-contracts';

export class InventoryRepository {
  private current: InventoryState = emptyInventory();
  private previous: InventoryState | null = null;
  private backupSnapshot: InventoryState | null = null;
  private loaded = false;
  private version = 0;
  private tail: Promise<void> = Promise.resolve();
  private listeners = new Set<() => void>();
  constructor(private readonly storage: InventoryStoragePort, private readonly clock: () => Date = () => new Date()) {}
  snapshot = (): InventoryState => this.current;
  subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };
  get canUndo(): boolean { return this.previous !== null; }
  get revision(): number { return this.version; }
  get retainedPhotoPaths(): ReadonlySet<string> {
    return new Set([this.current, this.previous, this.backupSnapshot].flatMap(state =>
      state ? Object.values(state.foods).map(food => food.photoPath) : []));
  }
  private async commit(next: InventoryState): Promise<void> {
    await this.storage.save(next);
    this.backupSnapshot = {...this.current, foods: Object.fromEntries(
      Object.entries(this.current.foods).filter(([id]) => Object.hasOwn(next.foods, id)))};
  }
  private serialize(action: () => Promise<void>): Promise<void> {
    const operation = this.tail.then(action);
    this.tail = operation.catch(() => undefined);
    return operation;
  }
  private publish(state: InventoryState): void {
    this.current = state;
    this.version++;
    this.listeners.forEach(listener => listener());
  }
  open(): Promise<void> {
    return this.serialize(async () => {
      if (this.loaded) return;
      const next = collectDue(await this.storage.load() ?? emptyInventory(), this.clock());
      await this.commit(next);
      this.loaded = true;
      this.publish(next);
    });
  }
  update(action: (state: InventoryState) => InventoryState, undoable = true, invalidateUndo = false): Promise<void> {
    return this.serialize(async () => {
      if (!this.loaded) throw new Error('INVENTORY_NOT_OPEN');
      const next = collectDue(action(this.current), this.clock());
      await this.commit(next);
      if (undoable) this.previous = this.current;
      else if (invalidateUndo) this.previous = null;
      this.publish(next);
    });
  }
  refreshDue(): Promise<void> {
    return this.serialize(async () => {
      if (!this.loaded) throw new Error('INVENTORY_NOT_OPEN');
      const next = collectDue(this.current, this.clock());
      if (JSON.stringify(next) === JSON.stringify(this.current)) return;
      await this.commit(next);
      this.previous = null;
      this.publish(next);
    });
  }
  undo(expectedRevision?: number): Promise<void> {
    return this.serialize(async () => {
      if (expectedRevision !== undefined && expectedRevision !== this.version) throw new Error('UNDO_STATE_CHANGED');
      if (!this.previous) return;
      const next = collectDue({...this.previous, nextNumber: Math.max(this.previous.nextNumber, this.current.nextNumber)}, this.clock());
      await this.commit(next);
      this.previous = null;
      this.publish(next);
    });
  }
}
