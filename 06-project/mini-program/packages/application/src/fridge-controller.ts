import {activeFoods, organize, restoreFood, deleteFood, editFood, changeDefaults, type FoodEdit,
  pending, calendarDay, type FoodRecord, type InventoryState, type StorageZone, type Remaining} from '@fridge/domain';
import type {MediaPort, PreferencesPort} from '@fridge/platform-contracts';
import {InventoryRepository} from './inventory-repository';
import {CaptureSession, type CaptureSnapshot} from './capture-session';
import {RecordEditor} from './record-editor';
import {emitProductEvent,type ProductEventSink} from './product-events';

export type FridgeRoute = {name: 'home' | 'settings' | 'history' | 'reminders' | 'language' | 'appearance' | 'feedback'} |
  {name: 'zone' | 'camera'; zone: StorageZone} | {name: 'review'; zone?: StorageZone; day?: string} |
  {name: 'detail'; id: string} | {name: 'legal'; document: 'terms' | 'privacy'};
export interface FridgeSnapshot {
  readonly stage: 'loading' | 'consent' | 'declined' | 'ready' | 'error' | 'withdrawing' | 'withdrawal-error';
  readonly route: FridgeRoute; readonly inventory: InventoryState;
  readonly busy: boolean; readonly errorKey: string | null;
  readonly locale: string | null; readonly theme: 'system' | 'light' | 'dark';
  readonly capture: CaptureSnapshot | null;
  readonly undoRevision: number | null;
  readonly privacyWithdrawalRequested: boolean;
}

export class FridgeController {
  static readonly policyVersion = 'V0.4';
  private listeners = new Set<() => void>();
  private routes: FridgeRoute[] = [];
  private flow: CaptureSession | null = null;
  private timer: ReturnType<typeof setInterval> | null = null;
  private closed = false;
  private withdrawing: Promise<void> | null = null;
  private privacyCleanup: (() => Promise<void>) | null = null;
  private reminderDay:string|null=null;
  private openingReminder:Promise<void>|null=null;
  private events:ProductEventSink=()=>{};
  setEventSink(sink:ProductEventSink):void {this.events=sink;}
  recordEvent=(name:string,properties:Readonly<Record<string,string>>={}):void=>{
    if(!this.closed && this.value.stage==='ready')emitProductEvent(this.events,name,properties);
  };
  setPrivacyCleanup(cleanup: () => Promise<void>): void {this.privacyCleanup = cleanup;}
  private value: FridgeSnapshot;
  private unsubscribe: () => void;
  constructor(readonly repository: InventoryRepository, private preferences: PreferencesPort,
    private media: MediaPort, private clock: () => Date = () => new Date()) {
    this.value = {stage: 'loading', route: {name: 'home'}, inventory: repository.snapshot(), busy: false,
      errorKey: null, locale: null, theme: 'system', capture: null, undoRevision: null,privacyWithdrawalRequested:false};
    this.unsubscribe = repository.subscribe(() => this.publish({inventory: repository.snapshot(), undoRevision: null}));
  }
  snapshot = (): FridgeSnapshot => this.value;
  get backgroundRoute(): FridgeRoute {return this.routes.at(-1) ?? {name:'home'};}
  subscribe = (listener: () => void): (() => void) => {this.listeners.add(listener); return () => this.listeners.delete(listener);};
  private publish(change: Partial<FridgeSnapshot>): void {
    if (this.closed) return;
    this.value = {...this.value, ...change}; this.listeners.forEach(listener => listener());
  }
  async initialize(): Promise<void> {
    if (this.closed || this.value.busy) return;
    this.publish({busy: true, errorKey: null});
    try {
      const display = await this.preferences.readDisplay();
      this.publish(display);
      if (await this.preferences.readWithdrawalPending?.()) {await this.runWithdrawal();return;}
      const consent = await this.preferences.readPrivacy();
      if (consent?.policyVersion === FridgeController.policyVersion && Number.isFinite(Date.parse(consent.acceptedAt))) await this.start();
      else this.publish({stage: 'consent'});
    } catch {this.publish({stage: 'error', errorKey: 'error'});}
    finally {this.publish({busy: false});}
  }
  private async start(): Promise<void> {
    if (this.closed) return;
    await this.repository.open();
    if (this.closed) return;
    // Before ready, no capture/editor candidate can race startup collection.
    await this.media.collectUnused?.(this.repository.retainedPhotoPaths).catch(() => {});
    if (this.closed) return;
    this.publish({stage: 'ready'}); this.resume();await this.openQueuedReminder();
  }
  accept = (): Promise<void> => !['consent','declined'].includes(this.value.stage) ? Promise.resolve() : this.perform(async () => {
    await this.preferences.writePrivacy({policyVersion: FridgeController.policyVersion, acceptedAt: this.clock().toISOString()});
    await this.start();
  }, true);
  decline = (): void => {this.publish({stage: 'declined'});};
  reconsider = (): void => {this.publish({stage: 'consent'});};
  navigate = (route: FridgeRoute,reminderSource:'home'|'settings'|'notification'='home'): void => {
    if (this.value.stage !== 'ready' && route.name !== 'legal') return;
    this.routes.push(this.value.route);
    this.publish({route, errorKey: null, undoRevision: null});
    if(route.name==='reminders' || reminderSource==='notification')this.recordEvent('fridge.reminder.opened.v1',{
      source:reminderSource==='home' && this.routes.at(-1)?.name==='settings'?'settings':reminderSource});
  };
  back = (): void => {this.publish({route: this.routes.pop() ?? {name: 'home'}, errorKey: null, undoRevision: null});};
  requestReminderDay(day:string):Promise<void> {
    if(!/^\d{4}-\d{2}-\d{2}$/.test(day) || !Number.isFinite(Date.parse(day)) ||
      new Date(day).toISOString().slice(0,10)!==day || day>calendarDay(this.clock()))return Promise.resolve();
    this.reminderDay=day;return this.openQueuedReminder();
  }
  private openQueuedReminder():Promise<void> {
    if(this.closed || this.value.stage!=='ready' || !this.reminderDay)return Promise.resolve();
    if(this.openingReminder)return this.openingReminder;
    this.openingReminder=(async()=>{
      while(this.reminderDay && !this.closed && this.value.stage==='ready') {
        const day=this.reminderDay;this.reminderDay=null;
        await this.repository.refreshDue();
        if(this.closed || this.value.stage!=='ready')return;
        const reminder=this.value.inventory.reminders.find(item=>item.day===day);
        // Old messages never invent an empty completed checklist or revive a previous cycle.
        const route:FridgeRoute=reminder && pending(reminder,this.value.inventory,this.clock()).length?{name:'review',day}:{name:'reminders'};
        if(JSON.stringify(this.value.route)!==JSON.stringify(route))this.navigate(route,'notification');
      }
    })().catch(()=>{if(this.value.stage==='ready')this.publish({errorKey:'error'});}).finally(()=>{this.openingReminder=null;});
    return this.openingReminder;
  }
  openZone = (zone: StorageZone): void => {
    if (this.closed || this.value.stage !== 'ready') return;
    if (!activeFoods(this.value.inventory).some(food => food.zone === zone)) this.openCamera(zone);
    else this.navigate({name: 'zone', zone});
  };
  openCamera = (zone: StorageZone): void => {
    if (this.closed || this.value.stage !== 'ready') return;
    this.flow = new CaptureSession(this.repository, this.media, zone,
      () => this.publish({capture: this.flow!.snapshot()}), this.clock,this.recordEvent);
    this.publish({capture: this.flow.snapshot()}); this.navigate({name: 'camera', zone});
  };
  selectCaptureZone = (zone: StorageZone): void => {this.flow?.selectZone(zone);};
  capture = (): Promise<void> => this.perform(() => this.flow!.capture());
  album = (): Promise<void> => this.perform(() => this.flow!.album());
  retryCapture = (): Promise<void> => this.perform(() => this.flow!.retry());
  async finishCapture(discardPending = false): Promise<boolean> {
    if (this.value.busy || this.flow?.snapshot().busy) return false;
    if (this.flow?.snapshot().pendingCount && !discardPending) return false;
    await this.flow?.abandon(); this.flow = null; this.publish({capture: null}); this.back(); return true;
  }
  reviewFoods(route: FridgeRoute = this.value.route): FoodRecord[] {
    const {inventory} = this.value;
    if (route.name !== 'review') return [];
    if (route.day) {
      const reminder = inventory.reminders.find(reminder => reminder.day === route.day);
      return reminder ? pending(reminder, inventory, this.clock()) : [];
    }
    return activeFoods(inventory).filter(food => !route.zone || food.zone === route.zone)
      .sort((a, b) => +new Date(a.dueAt) - +new Date(b.dueAt));
  }
  organize = (id: string, remaining: Remaining): Promise<void> => this.perform(async () => {
    const zone=this.value.inventory.foods[id]?.zone;
    await this.repository.update(state => organize(state, {[id]: remaining}, this.clock()));
    if(zone)this.recordEvent('fridge.review.updated.v1',{state:remaining==='small'?'little':remaining,zone});
    this.publish({undoRevision: this.repository.revision});
  });
  undo = (revision: number): Promise<void> => this.perform(() => this.repository.undo(revision));
  restore = (id: string): Promise<void> => this.perform(() =>
    this.repository.update(state => restoreFood(state, id, this.clock())));
  edit = (id: string, edit: FoodEdit): Promise<void> => this.perform(() => this.repository.update(state => editFood(state, id, edit)));
  editor(id: string): RecordEditor {
    if (this.closed || this.value.stage !== 'ready' || !this.value.inventory.foods[id]) throw new Error('INVENTORY_RECORD_MISSING');
    return new RecordEditor(this.value.inventory.foods[id], this.repository, this.media,
      () => !this.closed && this.value.stage === 'ready');
  }
  delete = (id: string): Promise<void> => this.perform(async () => {
    const food = this.value.inventory.foods[id];
    await this.repository.update(state => deleteFood(state, id), false, true);
    if (!this.repository.retainedPhotoPaths.has(food.photoPath)) await this.media.removeManaged(food.photoPath).catch(() => {});
    this.back();
  });
  defaults = (values: Partial<Record<StorageZone, number>>, hour?: number, minute?: number): Promise<void> => this.perform(() =>
    this.repository.update(state => changeDefaults(state, values, hour, minute), false, true));
  display = (locale: string | null, theme = this.value.theme): Promise<void> => this.perform(async () => {
    await this.preferences.writeDisplay({locale, theme}); this.publish({locale, theme});
  }, true);
  withdraw = (): Promise<void> => {
    if (this.withdrawing) return this.withdrawing;
    if (this.closed || this.value.busy || !['ready','withdrawal-error'].includes(this.value.stage)) return Promise.resolve();
    return this.runWithdrawal();
  };
  requestPrivacyWithdrawal = (): void => {
    if (this.value.stage==='ready' && this.value.route.name==='legal' && this.value.route.document==='privacy') this.publish({privacyWithdrawalRequested:true});
  };
  cancelPrivacyWithdrawal = (): void => {this.publish({privacyWithdrawalRequested:false});};
  private runWithdrawal(): Promise<void> {
    if (this.withdrawing) return this.withdrawing;
    this.suspend();this.routes = [];this.reminderDay=null;
    const flow = this.flow;this.flow = null;
    this.withdrawing = Promise.resolve().then(async () => {
      try {
        if (!this.preferences.beginWithdrawal || !this.preferences.finishWithdrawal || !this.privacyCleanup) throw new Error('PRIVACY_CLEANUP_UNAVAILABLE');
        await this.preferences.beginWithdrawal();
        await this.preferences.writePrivacy(null);
        await this.privacyCleanup();
        await flow?.abandon();
        await this.preferences.finishWithdrawal();
        this.publish({stage:'consent',errorKey:null});
      } catch {this.publish({stage:'withdrawal-error',errorKey:'privacyWithdrawFailed'});}
      finally {this.withdrawing=null;this.publish({busy:false});}
    });
    this.publish({stage:'withdrawing',route:{name:'home'},capture:null,busy:true,errorKey:null,undoRevision:null,privacyWithdrawalRequested:false});
    return this.withdrawing;
  }
  private async perform(action: () => Promise<void>, beforeConsent = false): Promise<void> {
    if (this.closed || this.value.busy) return;
    this.publish({busy: true, errorKey: null});
    try {if (!beforeConsent && this.value.stage !== 'ready') throw new Error('CONSENT_REQUIRED'); await action();}
    catch (cause) {this.publish({errorKey: cause instanceof Error && cause.message === 'UNDO_STATE_CHANGED' ? 'undoExpired' : 'error'});}
    finally {this.publish({busy: false});}
  }
  resume(): void {
    this.suspend();
    if (this.closed || this.value.stage !== 'ready') return;
    const refresh = () => {void this.repository.refreshDue().then(() => this.publish({})).catch(() => this.publish({errorKey: 'error'}));};
    refresh();
    this.timer = setInterval(refresh, 60000);
  }
  suspend(): void {if (this.timer) clearInterval(this.timer); this.timer = null;}
  close(): void {this.closed = true; this.suspend(); this.unsubscribe(); this.listeners.clear();}
}
