import { ReminderBatch, ReminderCycle, ReminderCopy, makeBatches, validDay, cycleTime } from './ReminderPlan';

export class ScheduledReminder {
  batch: ReminderBatch = new ReminderBatch();
  osId: number = -1;
}

export class ReminderState {
  version: number = 1;
  enabled: boolean = false;
  requested: boolean = false;
  limited: boolean = false;
  seen: string[] = [];
  scheduled: ScheduledReminder[] = [];
  // Saved before native publication, enabling recovery of a crash before ACK.
  intent: ReminderBatch | null = null;
  pendingDay: string = '';
  cardDays: string[] = [];
}

export interface ReminderStorage {
  read(): ReminderState;
  write(state: ReminderState): Promise<void>;
}

export interface ReminderSystem {
  authorized(): Promise<boolean>;
  capacity(): number;
  list(): Promise<ScheduledReminder[]>;
  publish(batch: ReminderBatch): Promise<number>;
  cancel(id: number): Promise<void>;
  cancelCard(day: string): Promise<void>;
  updateCard(batch: ReminderBatch): Promise<void>;
}

export class ReminderCoordinator {
  private storage: ReminderStorage;
  private system: ReminderSystem;
  private permitted: () => boolean;
  private format: (count: number, locale: string) => string;
  constructor(storage: ReminderStorage, system: ReminderSystem, permitted: () => boolean,
    format: (count: number, locale: string) => string = (count: number): string => count.toString()) {
    this.storage = storage; this.system = system; this.permitted = permitted; this.format = format;
  }

  private gate(): void { if (!this.permitted()) throw new Error('CONSENT_REQUIRED'); }

  async clear(): Promise<void> {
    const state = this.storage.read();
    state.enabled = false; state.pendingDay = ''; state.limited = false;
    // Durable disable precedes cancellation. Retain all IDs until every cancel ACK.
    let failure: Error | null = null;
    try { await this.storage.write(state); } catch (error) { failure = error as Error; }
    if (!state.scheduled.length && state.intent === null && !state.cardDays.length) {
      if (failure) throw failure;
      return;
    }
    let actual: ScheduledReminder[] = [];
    try { actual = await this.system.list(); } catch (error) { failure = error as Error; }
    for (const item of actual) {
      try { await this.system.cancel(item.osId); } catch (error) { failure = error as Error; }
    }
    for (const day of state.cardDays) {
      try { await this.system.cancelCard(day); } catch (error) { failure = error as Error; }
    }
    if (failure) throw failure;
    state.scheduled = []; state.intent = null; state.cardDays = [];
    await this.storage.write(state);
  }

  async sync(cycles: ReminderCycle[], copy: ReminderCopy, now: number): Promise<void> {
    this.gate();
    // Validate the entire new snapshot before querying/cancelling OS state.
    makeBatches(cycles, [], copy, now, this.format);
    const state = this.storage.read();
    if (!state.enabled || !await this.system.authorized()) {
      // Preserve the app preference when the OS setting alone is disabled.
      const enabled = state.enabled;
      await this.clear(); this.gate(); const cleared = this.storage.read();
      cleared.enabled = enabled; await this.storage.write(cleared); return;
    }
    this.gate();
    const actual = await this.system.list();
    this.gate();
    const handedOff = (keys: string[]): string[] => keys.filter((key: string): boolean => {
      const current = cycles.find((cycle: ReminderCycle): boolean => cycle.key === key);
      return !current || cycleTime(current) <= now;
    });
    // Recover an uncertain publish using its exact date/content, never republish it.
    if (state.intent) {
      const intent = state.intent;
      const recovered = actual.find((item: ScheduledReminder): boolean => item.batch.identity === intent.identity);
      if (recovered && !state.scheduled.some((item: ScheduledReminder): boolean => item.osId === recovered.osId)) {
        recovered.batch = intent; state.scheduled.push(recovered);
      }
      // If it is no longer valid and already due, treat it as handed off, not seen by user.
      if (!recovered && intent.at <= now) state.seen = Array.from(new Set<string>(state.seen.concat(handedOff(intent.keys))));
      state.intent = null; await this.storage.write(state);
    }
    for (const item of state.scheduled) {
      if (item.batch.at <= now && !actual.some((other: ScheduledReminder): boolean => other.osId === item.osId)) {
        state.seen = Array.from(new Set<string>(state.seen.concat(handedOff(item.batch.keys))));
      }
    }
    await this.storage.write(state);
    const desired = makeBatches(cycles, state.seen, copy, now, this.format);
    const desiredIds = new Set<string>(desired.map((batch: ReminderBatch): string => batch.identity));
    const activeDays = new Set<string>(cycles.map((cycle: ReminderCycle): string => cycle.day));
    // Cancel OS requests no longer representing current inventory; this includes crash orphans.
    for (const item of actual) {
      this.gate();
      if (!desiredIds.has(item.batch.identity)) await this.system.cancel(item.osId);
    }
    const retained = state.scheduled.filter((item: ScheduledReminder): boolean => desiredIds.has(item.batch.identity) &&
      actual.some((other: ScheduledReminder): boolean => other.osId === item.osId));
    state.scheduled = retained;
    for (const day of state.cardDays) {
      if (!activeDays.has(day)) await this.system.cancelCard(day);
    }
    state.cardDays = state.cardDays.filter((day: string): boolean => activeDays.has(day));
    // Update an existing card only. Dismissed/tapped cards must never reappear.
    for (const day of state.cardDays) {
      this.gate();
      const due = cycles.filter((cycle: ReminderCycle): boolean => cycle.day === day && cycleTime(cycle) <= now);
      if (!due.length) { await this.system.cancelCard(day); continue; }
      const card = new ReminderBatch(); card.day = day; card.notificationId = Number(day.replace(/-/g, ''));
      card.title = copy.title; card.count = due.length;
      card.content = copy.body.split('{count}').join(this.format(due.length, copy.locale || 'en'));
      await this.system.updateCard(card);
    }
    await this.storage.write(state);
    const limit = this.system.capacity();
    state.limited = desired.length > limit;
    for (const batch of desired.slice(0, limit)) {
      if (state.scheduled.some((item: ScheduledReminder): boolean => item.batch.identity === batch.identity)) continue;
      this.gate();
      state.intent = batch;
      // This card may appear even if the application dies after publish.
      state.cardDays = Array.from(new Set<string>(state.cardDays.concat([batch.day])));
      await this.storage.write(state); this.gate();
      const osId = await this.system.publish(batch);
      // Do not leave a late native ACK scheduled after privacy withdrawal.
      if (!this.permitted()) { await this.system.cancel(osId); throw new Error('CONSENT_REQUIRED'); }
      const item = new ScheduledReminder(); item.batch = batch; item.osId = osId;
      state.scheduled.push(item); state.intent = null;
      await this.storage.write(state);
    }
    await this.storage.write(state);
  }

  async receive(day: string): Promise<void> {
    this.gate(); if (!validDay(day)) throw new Error('NOTIFICATION_PLAN_INVALID');
    const state = this.storage.read(); state.pendingDay = day; await this.storage.write(state);
  }

  async consume(): Promise<string | null> {
    this.gate(); const state = this.storage.read(); const day = state.pendingDay;
    state.pendingDay = ''; await this.storage.write(state); return validDay(day) ? day : null;
  }
}
