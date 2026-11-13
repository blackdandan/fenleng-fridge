import common from '@ohos.app.ability.common';
import preferences from '@ohos.data.preferences';
import reminderAgentManager from '@ohos.reminderAgentManager';
import notificationManager from '@ohos.notificationManager';
import { BusinessError } from '@ohos.base';
import deviceInfo from '@ohos.deviceInfo';
import wantAgent from '@ohos.app.ability.wantAgent';
import { ReminderBatch, validDay, localTimestamp } from './ReminderPlan';
import { ReminderState, ReminderStorage, ReminderSystem, ScheduledReminder } from './ReminderCoordinator';

export class NativeReminderStorage implements ReminderStorage {
  private preferences: preferences.Preferences;
  constructor(context: common.UIAbilityContext) {
    this.preferences = preferences.getPreferencesSync(context, { name: 'fridge-local-reminders-v1' });
  }
  read(): ReminderState {
    const raw = this.preferences.getSync('state', '') as string;
    if (!raw) return new ReminderState();
    try {
      const state = JSON.parse(raw) as ReminderState;
      if (!state || state.version !== 1 || typeof state.enabled !== 'boolean' || typeof state.requested !== 'boolean' ||
        typeof state.limited !== 'boolean' || !Array.isArray(state.seen) || !Array.isArray(state.scheduled) ||
        !Array.isArray(state.cardDays) || typeof state.pendingDay !== 'string') throw new Error('INVALID');
      for (const key of state.seen) if (typeof key !== 'string' || !key || key.length > 512) throw new Error('INVALID');
      for (const day of state.cardDays) if (!validDay(day)) throw new Error('INVALID');
      for (const item of state.scheduled) {
        if (!Number.isInteger(item.osId) || item.osId < 0) throw new Error('INVALID');
        this.validateBatch(item.batch);
      }
      if (state.intent !== null) this.validateBatch(state.intent);
      return state;
    } catch (_) { throw new Error('NOTIFICATION_STORE_INVALID'); }
  }
  private validateBatch(batch: ReminderBatch): void {
    if (!batch || !validDay(batch.day) || !Number.isFinite(batch.at) || batch.at < 0 ||
      typeof batch.localTime !== 'string' || !/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$/.test(batch.localTime) ||
      !Array.isArray(batch.keys) || batch.keys.some((key: string): boolean => typeof key !== 'string' || !key || key.length > 512) ||
      !batch.keys.length || !Number.isInteger(batch.count) || batch.count < 1 ||
      typeof batch.title !== 'string' || typeof batch.content !== 'string' ||
      batch.notificationId !== Number(batch.day.replace(/-/g, '')) ||
      batch.identity !== JSON.stringify([batch.day, batch.at, batch.keys, batch.title, batch.content])) throw new Error('INVALID');
  }
  async write(state: ReminderState): Promise<void> {
    const previous = this.preferences.getSync('state', '') as string;
    this.preferences.putSync('state', JSON.stringify(state));
    try { await this.preferences.flush(); }
    catch (_) { this.preferences.putSync('state', previous); throw new Error('NOTIFICATION_WRITE_FAILED'); }
  }
}

export class NativeReminderSystem implements ReminderSystem {
  private context: common.UIAbilityContext;
  private storage: ReminderStorage;
  private available: number = 30;
  constructor(context: common.UIAbilityContext, storage: ReminderStorage) { this.context = context; this.storage = storage; }
  authorized(): Promise<boolean> { return notificationManager.isNotificationEnabled(); }
  // Compatible API17 devices allow30, even though target API26 allows64.
  capacity(): number { return this.available; }
  async list(): Promise<ScheduledReminder[]> {
    const all = await reminderAgentManager.getAllValidReminders();
    const state = this.storage.read();
    const known = state.scheduled.map((item: ScheduledReminder): ReminderBatch => item.batch);
    if (state.intent) known.push(state.intent);
    const result: ScheduledReminder[] = [];
    for (const item of all) {
      const request = item.reminderReq;
      if (request.wantAgent?.pkgName !== this.context.abilityInfo.bundleName ||
        !request.wantAgent.uri?.startsWith('fridge://reminders/')) continue;
      const calendar = request as reminderAgentManager.ReminderRequestCalendar;
      const date = calendar.dateTime;
      if (!date) continue;
      const at = new Date(date.year, date.month - 1, date.day, date.hour, date.minute, date.second || 0).getTime();
      const day = request.wantAgent.uri.slice('fridge://reminders/'.length);
      if (!validDay(day)) continue;
      let batch = known.find((candidate: ReminderBatch): boolean => candidate.day === day && candidate.localTime === localTimestamp(new Date(at)) &&
        candidate.title === request.title && candidate.content === request.content);
      // Unknown feature-owned request is retained in the list so reconciliation can cancel it.
      if (!batch) { batch = new ReminderBatch(); batch.day = day; batch.at = at; }
      const record = new ScheduledReminder(); record.batch = batch; record.osId = item.reminderId; result.push(record);
    }
    this.available = Math.max(0, 30 - (all.length - result.length));
    return result;
  }
  publish(batch: ReminderBatch): Promise<number> {
    const at = new Date(batch.at);
    const request: reminderAgentManager.ReminderRequestCalendar = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
      dateTime: { year: at.getFullYear(), month: at.getMonth() + 1, day: at.getDate(),
        hour: at.getHours(), minute: at.getMinutes(), second: at.getSeconds() },
      title: batch.title, content: batch.content, expiredContent: batch.content,
      notificationId: batch.notificationId,
      slotType: notificationManager.SlotType.SERVICE_INFORMATION,
      ringDuration: 0, snoozeTimes: 0, tapDismissed: true,
      wantAgent: { pkgName: this.context.abilityInfo.bundleName, abilityName: 'EntryAbility',
        uri: `fridge://reminders/${batch.day}` },
    };
    return reminderAgentManager.publishReminder(request);
  }
  async cancel(id: number): Promise<void> {
    try { await reminderAgentManager.cancelReminder(id); }
    catch (error) {
      // Already consumed/absent is an idempotent cancellation, not a native failure.
      if ((error as BusinessError).code !== 1700003) throw error;
    }
  }
  async cancelCard(day: string): Promise<void> {
    try { await notificationManager.cancel(Number(day.replace(/-/g, ''))); }
    catch (error) { if ((error as BusinessError).code !== 1600007) throw error; }
  }
  async updateCard(batch: ReminderBatch): Promise<void> {
    const active = await notificationManager.getActiveNotifications();
    const existing = active.find((request: notificationManager.NotificationRequest): boolean =>
      request.id === batch.notificationId && !request.label);
    if (!existing) return;
    const basic = existing.content.normal;
    if (basic?.title === batch.title && basic.text === batch.content) return;
    // updateOnly prevents a dismissal racing this query from recreating the card.
    if (deviceInfo.sdkApiVersion < 18) throw new Error('NOTIFICATIONS_UNAVAILABLE');
    const target = await wantAgent.getWantAgent({
      wants: [{ bundleName: this.context.abilityInfo.bundleName, abilityName: 'EntryAbility', uri: `fridge://reminders/${batch.day}` }],
      operationType: wantAgent.OperationType.START_ABILITY, requestCode: batch.notificationId,
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG],
    });
    const request: notificationManager.NotificationRequest = {
      id: batch.notificationId, updateOnly: true, isAlertOnce: true, tapDismissed: true,
      notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION, wantAgent: target,
      content: { contentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: { title: batch.title, text: batch.content } },
    };
    try { await notificationManager.publish(request); }
    catch (error) { if ((error as BusinessError).code !== 1600007) throw error; }
  }
}
