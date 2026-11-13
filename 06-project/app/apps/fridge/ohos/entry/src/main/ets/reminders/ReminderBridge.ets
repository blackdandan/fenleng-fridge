import common from '@ohos.app.ability.common';
import notificationManager from '@ohos.notificationManager';
import { BusinessError } from '@ohos.base';
import intl from '@ohos.intl';
import { FlutterEngine } from '@ohos/flutter_ohos';
import MethodChannel, { MethodCallHandler, MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import { ReminderCycle, ReminderCopy, validDay } from './ReminderPlan';
import { ReminderCoordinator } from './ReminderCoordinator';
import { NativeReminderStorage, NativeReminderSystem } from './ReminderNative';

export default class ReminderBridge implements MethodCallHandler {
  private context: common.UIAbilityContext;
  private engine: FlutterEngine;
  private allowed: boolean = false;
  private earlyDay: string = '';
  private channel: MethodChannel | null = null;
  private storage: NativeReminderStorage | null = null;
  private system: NativeReminderSystem | null = null;
  private coordinator: ReminderCoordinator | null = null;
  private tail: Promise<void> = Promise.resolve();

  constructor(context: common.UIAbilityContext, engine: FlutterEngine) { this.context = context; this.engine = engine; }
  private enqueue(operation: () => Promise<void>): Promise<void> {
    const result = this.tail.then(operation);
    this.tail = result.catch(() => {}); return result;
  }
  private initialize(): void {
    if (this.storage) return;
    const storage = new NativeReminderStorage(this.context);
    const system = new NativeReminderSystem(this.context, storage);
    this.storage = storage; this.system = system;
    this.coordinator = new ReminderCoordinator(storage, system, (): boolean => this.allowed,
      (count: number, locale: string): string => new intl.NumberFormat(locale, { style: 'decimal' }).format(count));
  }
  async authorize(): Promise<void> {
    this.allowed = true;
    await this.enqueue(async (): Promise<void> => {
      if (!this.allowed) throw new Error('CONSENT_REQUIRED');
      this.initialize();
      if (!this.channel) {
        this.channel = new MethodChannel(this.engine.getDartExecutor().getBinaryMessenger(), 'fenleng.fridge/notifications');
        this.channel.setMethodCallHandler(this);
      }
      if (this.earlyDay) { const day = this.earlyDay; this.earlyDay = ''; await this.deliver(day); }
    });
  }
  revoke(): Promise<void> {
    this.allowed = false; this.earlyDay = '';
    return this.enqueue(async (): Promise<void> => { this.initialize(); await this.coordinator!.clear(); });
  }
  receive(uri: string): void {
    const prefix = 'fridge://reminders/';
    if (!uri.startsWith(prefix)) return;
    const day = uri.slice(prefix.length);
    if (!validDay(day)) return;
    // The app can be launched before China consent: retain only an in-memory date.
    if (!this.allowed) { this.earlyDay = day; return; }
    this.enqueue(async (): Promise<void> => { if (this.allowed) await this.deliver(day); }).catch(() => {});
  }
  private async deliver(day: string): Promise<void> {
    await this.coordinator!.receive(day);
    if (this.allowed) this.channel?.invokeMethod('openReminder', new Map<string, string>([['day', day]]));
  }
  onMethodCall(call: MethodCall, result: MethodResult): void {
    this.enqueue(async (): Promise<void> => {
      if (!this.allowed) throw new Error('CONSENT_REQUIRED');
      await this.handle(call, result);
    }).catch((error: Error): void => {
      const codes = ['CONSENT_REQUIRED', 'NOTIFICATION_PLAN_INVALID', 'NOTIFICATION_STORE_INVALID', 'NOTIFICATION_WRITE_FAILED'];
      result.error(codes.includes(error.message) ? error.message : 'NOTIFICATIONS_UNAVAILABLE', null, null);
    });
  }
  private async status(): Promise<Map<string, boolean>> {
    const state = this.storage!.read();
    const values = new Map<string, boolean>();
    values.set('enabled', state.enabled); values.set('requested', state.requested);
    values.set('limited', state.limited); values.set('authorized', await this.system!.authorized());
    return values;
  }
  private async handle(call: MethodCall, result: MethodResult): Promise<void> {
    switch (call.method) {
      case 'status': result.success(await this.status()); break;
      case 'request':
        const request = this.storage!.read(); request.requested = true; await this.storage!.write(request);
        try { await notificationManager.requestEnableNotification(this.context); }
        catch (error) { if ((error as BusinessError).code !== 1600004) throw error; }
        result.success(await this.status()); break;
      case 'enable':
        const enabled = call.argument('enabled') as boolean;
        if (typeof enabled !== 'boolean') throw new Error('NOTIFICATION_PLAN_INVALID');
        if (enabled) {
          if (!await this.system!.authorized() || !this.allowed) throw new Error('CONSENT_REQUIRED');
          const state = this.storage!.read(); state.enabled = true; await this.storage!.write(state);
        } else await this.coordinator!.clear();
        result.success(await this.status()); break;
      case 'sync':
        // StandardMessageCodec represents Flutter maps as Map in Flutter-OH.
        const rawCycles = call.argument('cycles') as Map<string, Object>[];
        const decoded: ReminderCycle[] = [];
        for (const raw of rawCycles) {
          const cycle = new ReminderCycle();
          cycle.key = raw.get('key') as string; cycle.day = raw.get('day') as string;
          cycle.hour = raw.get('hour') as number; cycle.minute = raw.get('minute') as number;
          cycle.second = raw.get('second') as number; cycle.millisecond = raw.get('millisecond') as number;
          decoded.push(cycle);
        }
        const rawCopy = call.argument('copy') as Map<string, string>;
        const copy = new ReminderCopy();
        copy.title = rawCopy.get('title') || ''; copy.body = rawCopy.get('body') || '';
        copy.channel = rawCopy.get('channel') || ''; copy.locale = rawCopy.get('locale') || '';
        await this.coordinator!.sync(decoded, copy, Date.now()); result.success(true); break;
      case 'consumeTap': result.success(await this.coordinator!.consume()); break;
      case 'settings': await notificationManager.openNotificationSettings(this.context); result.success(true); break;
      default: result.notImplemented();
    }
  }
}
