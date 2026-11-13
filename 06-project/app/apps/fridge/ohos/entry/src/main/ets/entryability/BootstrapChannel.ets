import common from '@ohos.app.ability.common';
import preferences from '@ohos.data.preferences';
import { FlutterEngine } from '@ohos/flutter_ohos';
import MethodChannel, { MethodCallHandler, MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import ReminderBridge from '../reminders/ReminderBridge';

class ConsentRecord {
  policyVersion: string = '';
  releaseChannel: string = '';
  acceptedAt: string = '';
}

export default class BootstrapChannel implements MethodCallHandler {
  private engine: FlutterEngine;
  private context: common.UIAbilityContext;
  private preferences: preferences.Preferences;
  private channel: MethodChannel;
  private registered: boolean = false;
  private allowed: boolean = false;
  private legalBusy: boolean = false;
  private reminders: ReminderBridge;

  constructor(context: common.UIAbilityContext, engine: FlutterEngine) {
    this.context = context;
    this.engine = engine;
    this.reminders = new ReminderBridge(context, engine);
    this.preferences = preferences.getPreferencesSync(context, { name: 'privacy-consent' });
    this.channel = new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), 'fenleng.fridge/bootstrap');
    this.channel.setMethodCallHandler(this);
  }

  receiveReminder(uri: string): void { this.reminders.receive(uri); }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    this.handle(call, result).catch(() => result.error('BOOTSTRAP_FAILED', null, null));
  }

  private read(): ConsentRecord {
    const raw = this.preferences.getSync('consent', '') as string;
    if (raw.length === 0) return new ConsentRecord();
    try {
      const value = JSON.parse(raw) as ConsentRecord;
      if (!value || typeof value.policyVersion !== 'string' || typeof value.releaseChannel !== 'string' || typeof value.acceptedAt !== 'string') return new ConsentRecord();
      return value;
    }
    catch (_) { return new ConsentRecord(); }
  }

  private async handle(call: MethodCall, result: MethodResult): Promise<void> {
    const record = this.read();
    switch (call.method) {
      case 'legal.open':
        if (this.legalBusy) { result.error('LEGAL_READER_BUSY', null, null); break; }
        const html = call.argument('htmlBase64') as string;
        if (!html) { result.error('LEGAL_INVALID', null, null); break; }
        this.legalBusy = true;
        try {
        const legalResponse = await this.context.startAbilityForResult({
          bundleName: this.context.abilityInfo.bundleName,
          abilityName: 'LegalAbility',
          parameters: { htmlBase64: html, title: call.argument('title') as string,
            backLabel: call.argument('backLabel') as string,
            withdrawalEnabled: call.argument('withdrawalEnabled') as string },
        });
        result.success(legalResponse.want?.parameters?.action === 'withdraw' ? 'withdraw' : true);
        } finally { this.legalBusy = false; }
        break;
      case 'privacy.read':
        const values = new Map<string, string | boolean | null>();
        values.set('policyVersion', record.policyVersion);
        values.set('releaseChannel', record.releaseChannel);
        values.set('acceptedAt', record.acceptedAt);
        values.set('locale', (this.preferences.getSync('locale', '') as string) || null);
        values.set('appearance', this.preferences.getSync('appearance', 'system') as string);
        values.set('withdrawalPending', this.preferences.getSync('withdrawalPending', false) as boolean);
        result.success(values);
        break;
      case 'privacy.accept':
        const version = call.argument('policyVersion') as string;
        const channel = call.argument('releaseChannel') as string;
        const acceptedAt = call.argument('acceptedAt') as string;
        if (!version || channel !== 'china' || !acceptedAt) { result.error('CONSENT_INVALID', null, null); break; }
        const previous = this.preferences.getSync('consent', '') as string;
        const next = new ConsentRecord();
        next.policyVersion = version; next.releaseChannel = channel; next.acceptedAt = acceptedAt;
        this.preferences.putSync('consent', JSON.stringify(next));
        try { await this.preferences.flush(); result.success(true); }
        catch (_) { this.preferences.putSync('consent', previous); result.error('CONSENT_WRITE_FAILED', null, null); }
        break;
      case 'plugins.initialize':
        const buildChannel = call.argument('releaseChannel') as string;
        const accepted = record.policyVersion === call.argument('policyVersion') && record.releaseChannel === 'china' && record.acceptedAt.length > 0;
        if (buildChannel !== 'global' && !(buildChannel === 'china' && accepted)) {
          result.error('CONSENT_REQUIRED', null, null); break;
        }
        if (!this.registered) { GeneratedPluginRegistrant.registerWith(this.engine); this.registered = true; }
        this.allowed = true;
        await this.reminders.authorize();
        result.success(true);
        break;
      case 'data.directory':
        if (!this.allowed) result.error('CONSENT_REQUIRED', null, null);
        else result.success(`${this.context.filesDir}/fridge`);
        break;
      case 'display.locale':
        const previousLocale = this.preferences.getSync('locale', '') as string;
        this.preferences.putSync('locale', (call.argument('locale') as string) || '');
        try { await this.preferences.flush(); result.success(true); }
        catch (_) { this.preferences.putSync('locale', previousLocale); result.error('DISPLAY_WRITE_FAILED', null, null); }
        break;
      case 'display.theme':
        const appearance = call.argument('appearance') as string;
        if (appearance !== 'system' && appearance !== 'light' && appearance !== 'dark') { result.error('DISPLAY_INVALID', null, null); break; }
        const previousAppearance = this.preferences.getSync('appearance', 'system') as string;
        this.preferences.putSync('appearance', appearance);
        try { await this.preferences.flush(); result.success(true); }
        catch (_) { this.preferences.putSync('appearance', previousAppearance); result.error('DISPLAY_WRITE_FAILED', null, null); }
        break;
      case 'filing.open':
        await this.context.openLink('https://beian.miit.gov.cn', { appLinkingOnly: false });
        result.success(true);
        break;
      case 'privacy.revoke':
        this.preferences.deleteSync('consent');
        this.preferences.putSync('withdrawalPending', true);
        this.allowed = false;
        // Fence new native work immediately, even if persisting the marker fails.
        const reminderRevocation = this.reminders.revoke();
        await Promise.all([this.preferences.flush(), reminderRevocation]);
        result.success(true);
        break;
      case 'privacy.directory':
        if (!(this.preferences.getSync('withdrawalPending', false) as boolean)) result.error('CONSENT_REQUIRED', null, null);
        else result.success(`${this.context.filesDir}/fridge`);
        break;
      case 'privacy.finishRevoke':
        await this.reminders.revoke();
        this.preferences.deleteSync('withdrawalPending');
        await this.preferences.flush();
        result.success(true);
        break;
      default: result.notImplemented();
    }
  }
}
