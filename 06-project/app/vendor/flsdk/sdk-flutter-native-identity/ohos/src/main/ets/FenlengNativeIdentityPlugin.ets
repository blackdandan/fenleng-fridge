import { common, Want, AbilityConstant, bundleManager } from '@kit.AbilityKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import * as wechat from '@tencent/wechat_open_sdk';
import { FlutterPlugin, FlutterPluginBinding, AbilityAware, AbilityPluginBinding,
  MethodChannel, MethodCall, MethodCallHandler, MethodResult, NewWantListener,
  WindowFocusChangedListener } from '@ohos/flutter_ohos';

// Registered by the post-consent host; configuration performs no WeChat calls.
export default class FenlengNativeIdentityPlugin implements FlutterPlugin, AbilityAware,
  MethodCallHandler, NewWantListener, WindowFocusChangedListener, wechat.WXApiEventHandler {
  private channel: MethodChannel | undefined;
  private binding: AbilityPluginBinding | undefined;
  private context: common.UIAbilityContext | undefined;
  private appId: string | undefined;
  private scope: string = 'snsapi_userinfo';
  private api: wechat.WXApi | undefined;
  private pending: MethodResult | undefined;
  private state: string | undefined;
  private retiredStates: string[] = [];
  private timer: number | undefined;
  private returnedTimer: number | undefined;
  private departed: boolean = false;

  getUniqueClassName(): string { return 'FenlengNativeIdentityPlugin'; }
  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'com.fenleng.sdk/native_identity');
    this.channel.setMethodCallHandler(this);
  }
  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.binding = binding;
    this.context = binding.getAbility().context;
    binding.addOnNewWantListener(this);
    binding.addOnWindowFocusChangedListener(this);
  }
  onDetachedFromAbility(): void {
    this.binding?.removeOnNewWantListener(this);
    this.binding?.removeOnWindowFocusChangedListener(this);
    this.binding = undefined;
    this.context = undefined;
    this.api = undefined;
    this.fail('IDENTITY_ENGINE_DETACHED', 'Identity authorization is no longer active');
  }
  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.onDetachedFromAbility();
    this.channel?.setMethodCallHandler(null);
    this.channel = undefined;
  }
  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method === 'configureWechat') {
      if (this.pending) {
        result.error('IDENTITY_AUTH_IN_PROGRESS', 'Identity authorization is in progress', null); return;
      }
      const appId = call.argument('appId') as string | null;
      const scope = call.argument('scope') as string | null;
      if (typeof appId !== 'string' || appId.length === 0) {
        result.error('IDENTITY_CONFIG_INVALID', 'WeChat AppID is required', null); return;
      }
      this.appId = appId;
      this.scope = typeof scope === 'string' && scope.length > 0 ? scope : 'snsapi_userinfo';
      result.success(null);
      return;
    }
    if (call.method !== 'isAvailable' && call.method !== 'authorize') {
      result.notImplemented(); return;
    }
    if (call.argument('provider') !== 'wechat') {
      if (call.method === 'isAvailable') result.success(false);
      else result.error('IDENTITY_PROVIDER_UNSUPPORTED', 'Identity provider is not supported', null);
      return;
    }
    if (!this.appId) {
      result.error('IDENTITY_NOT_CONFIGURED', 'WeChat identity is not configured', null); return;
    }
    if (call.method === 'isAvailable') {
      try { result.success(bundleManager.canOpenLink('weixin://')); }
      catch (_) { result.success(false); }
      return;
    }
    this.authorize(result);
  }
  private async authorize(result: MethodResult): Promise<void> {
    const context = this.context;
    if (!context) {
      result.error('IDENTITY_ACTIVITY_UNAVAILABLE', 'Authorization requires an active ability', null); return;
    }
    if (this.pending) {
      result.error('IDENTITY_AUTH_IN_PROGRESS', 'Identity authorization is in progress', null); return;
    }
    let started = false;
    try {
      if (!bundleManager.canOpenLink('weixin://')) {
        result.error('WECHAT_NOT_INSTALLED', 'WeChat is not installed', null); return;
      }
      wechat.Log.setLogImpl({ print: (level: wechat.LogLevel, tag: string, message: string): void => {} });
      const api = wechat.WXAPIFactory.createWXAPI(this.appId!, context);
      const random = cryptoFramework.createRandom().generateRandomSync(24).data;
      let nonce = '';
      for (let index = 0; index < random.length; index++) nonce += random[index].toString(16).padStart(2, '0');
      const request = new wechat.SendAuthReq();
      request.scope = this.scope;
      request.state = `fenleng_${nonce}`;
      request.transaction = request.state;
      request.callbackAbility = 'EntryAbility';
      this.api = api;
      this.state = request.state;
      this.pending = result;
      started = true;
      this.departed = false;
      // Install this instance's handler without replaying a previous launch Want.
      api.handleWant({}, this);
      this.timer = setTimeout(() => {
        if (this.pending === result) this.fail('WECHAT_AUTH_TIMEOUT', 'WeChat authorization timed out');
      }, 120000);
      const launched = await api.sendReq(context, request);
      if (this.pending === result && !launched) this.fail('WECHAT_SEND_FAILED', 'WeChat authorization could not be opened');
    } catch (_) {
      if (this.pending === result) this.fail('WECHAT_AUTH_FAILED', 'WeChat authorization did not complete');
      else if (!started) result.error('WECHAT_AUTH_FAILED', 'WeChat authorization did not complete', null);
    }
  }
  onNewWant(want: Want, launchParams: AbilityConstant.LaunchParam): void {
    try { this.api?.handleWant(want, this); }
    catch (_) { this.fail('WECHAT_AUTH_FAILED', 'WeChat authorization did not complete'); }
  }
  onReq(req: wechat.BaseReq): void { }
  onResp(resp: wechat.BaseResp): void {
    if (!(resp instanceof wechat.SendAuthResp) || !this.pending || !this.state) return;
    if (resp.transaction && resp.transaction !== this.state) return;
    if (resp.state && this.retiredStates.includes(resp.state)) return;
    if (resp.state !== this.state) {
      this.fail('WECHAT_STATE_MISMATCH', 'WeChat authorization state did not match'); return;
    }
    if (resp.errCode === -2) { this.fail('WECHAT_AUTH_CANCELLED', 'WeChat authorization was cancelled'); return; }
    if (resp.errCode === -4) { this.fail('WECHAT_AUTH_DENIED', 'WeChat authorization was denied'); return; }
    if (resp.errCode !== 0) { this.fail('WECHAT_AUTH_FAILED', 'WeChat authorization did not complete'); return; }
    if (!resp.code) { this.fail('WECHAT_CODE_MISSING', 'WeChat did not return an authorization code'); return; }
    const result = this.pending;
    this.clear();
    // Only the one-time code crosses the channel. Token exchange stays on the server.
    result.success(resp.code);
  }
  onWindowFocusChanged(hasFocus: boolean): void {
    if (!this.pending) return;
    if (!hasFocus) { this.departed = true; return; }
    if (!this.departed) return;
    const result = this.pending;
    if (this.returnedTimer !== undefined) clearTimeout(this.returnedTimer);
    this.returnedTimer = setTimeout(() => {
      if (this.pending === result) this.fail('WECHAT_AUTH_UNCONFIRMED', 'WeChat did not return an authorization result');
    }, 500);
  }
  private clear(): void {
    if (this.state) {
      this.retiredStates.push(this.state);
      if (this.retiredStates.length > 8) this.retiredStates.shift();
    }
    if (this.timer !== undefined) clearTimeout(this.timer);
    if (this.returnedTimer !== undefined) clearTimeout(this.returnedTimer);
    this.timer = undefined;
    this.returnedTimer = undefined;
    this.pending = undefined;
    this.state = undefined;
    this.departed = false;
  }
  private fail(code: string, message: string): void {
    const result = this.pending;
    this.clear();
    result?.error(code, message, null);
  }
}
