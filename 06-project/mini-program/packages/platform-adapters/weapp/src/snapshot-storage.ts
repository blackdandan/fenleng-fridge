import {decodeInventory, encodeInventory, type InventoryState} from '@fridge/domain';
import type {InventoryStoragePort} from '@fridge/platform-contracts';

const main = 'fenleng-fridge-inventory-v1';
const backup = 'fenleng-fridge-inventory-backup-v1';
export interface InventoryStorageDriver {
  keys(): string[];
  read(key: string): Promise<string>;
  write(key: string, data: string): Promise<void>;
}
/** Construct only after explicit consent. Never treat quota/read errors as empty data. */
export class SnapshotInventoryStorage implements InventoryStoragePort {
  private recovered = false;
  constructor(private readonly driver: InventoryStorageDriver) {}
  async load(): Promise<InventoryState | null> {
    const keys = this.driver.keys();
    if (keys.includes(main)) {
      const stored = await this.driver.read(main);
      try { return decodeInventory(stored); }
      catch (error) {
        if (!keys.includes(backup)) throw error;
        const recovered = decodeInventory(await this.driver.read(backup));
        this.recovered = true;
        return recovered;
      }
    }
    if (keys.includes(backup)) {
      const recovered = decodeInventory(await this.driver.read(backup));
      this.recovered = true;
      return recovered;
    }
    return null;
  }
  async save(state: InventoryState): Promise<void> {
    const data = encodeInventory(state);
    const previousKey = this.recovered ? backup : main;
    if (this.driver.keys().includes(previousKey)) {
      const previous = decodeInventory(await this.driver.read(previousKey));
      // Keep the last snapshot recoverable, excluding records explicitly removed
      // by this commit. A backup cannot undo permanent deletion or recycle IDs.
      const recoverable: InventoryState = {...previous,
        foods: Object.fromEntries(Object.entries(previous.foods).filter(([id]) => Object.hasOwn(state.foods, id))),
        nextNumber: Math.max(previous.nextNumber, state.nextNumber)};
      await this.driver.write(backup, encodeInventory(recoverable));
    }
    await this.driver.write(main, data);
    this.recovered = false;
  }
}
