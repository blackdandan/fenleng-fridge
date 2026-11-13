import {addFood, type StorageZone} from '@fridge/domain';
import type {MediaPort} from '@fridge/platform-contracts';
import type {InventoryRepository} from './inventory-repository';
import {emitProductEvent,type ProductEventSink} from './product-events';

interface PendingPhoto { source: string; origin:'camera'|'album'; zone: StorageZone; savedPath?: string }
export interface CaptureSnapshot { readonly busy: boolean; readonly savedCount: number; readonly pendingCount: number; readonly zone: StorageZone }

/** Capture, private copy and inventory commit are separate retryable steps. */
export class CaptureSession {
  private queue: PendingPhoto[] = [];
  private busy = false;
  private savedCount = 0;
  constructor(private repository: InventoryRepository, private media: MediaPort,
    private zone: StorageZone, private changed: () => void, private clock: () => Date = () => new Date(),private events:ProductEventSink=()=>{}) {}
  snapshot(): CaptureSnapshot {return {busy: this.busy, savedCount: this.savedCount, pendingCount: this.queue.length, zone: this.zone};}
  selectZone(zone: StorageZone): void {this.zone = zone; this.changed();}
  capture(): Promise<void> {return this.acquire(() => this.media.takePhoto().then(path => [path]),'camera');}
  album(): Promise<void> {return this.acquire(() => this.media.chooseAlbum(),'album');}
  private async acquire(action: () => Promise<readonly string[]>,origin:'camera'|'album'): Promise<void> {
    if (this.busy || this.queue.length) return;
    this.busy = true; this.changed();
    const zone = this.zone;
    emitProductEvent(this.events,'fridge.capture.started.v1',{source:origin,zone});
    try {
      const sources = await action();
      this.queue.push(...sources.map(source => ({source, zone,origin})));
      await this.commit();
    } finally {this.busy = false; this.changed();}
  }
  async retry(): Promise<void> {
    if (this.busy) return;
    this.busy = true; this.changed();
    try {await this.commit();} finally {this.busy = false; this.changed();}
  }
  private async commit(): Promise<void> {
    while (this.queue.length) {
      const photo = this.queue[0];
      try {photo.savedPath ??= await this.media.persist(photo.source);}
      catch(error){this.event(photo,'read_failed');throw error;}
      try {await this.repository.update(state => addFood(state, String(state.nextNumber).padStart(3, '0'), photo.savedPath!, photo.zone, this.clock()));}
      catch(error){this.event(photo,'save_failed');throw error;}
      this.queue.shift(); this.savedCount++; this.changed();
      this.event(photo,'success');
    }
  }
  private event(photo:PendingPhoto,result:string):void {
    emitProductEvent(this.events,'fridge.inventory.added.v1',{source:photo.origin,zone:photo.zone,result});
  }
  async abandon(): Promise<void> {
    if (this.busy) throw new Error('CAPTURE_BUSY');
    for (const photo of this.queue) {
      if (photo.savedPath) await this.media.removeManaged(photo.savedPath).catch(() => {});
    }
    this.queue = []; this.changed();
  }
}
