import { TaroAuthSDK, TaroPlatformClient, TaroSessionCoordinator, TaroStorageAdapter } from '@fenleng/sdk-taro';
import type { TaroNativeRequest, TaroStorageDriver } from '@fenleng/sdk-taro';

export interface IdentityConfig {
  enabled: boolean; baseUrl: string; clientId: string; guestEnabled?: boolean;
}
export interface IdentityDriver extends TaroStorageDriver {
  request(input: TaroNativeRequest): unknown;
  login(): Promise<{code: string}>;
}

/** Construct only after agreement acceptance. No platform API lives in domain. */
export class MiniIdentity {
  readonly session: TaroSessionCoordinator;
  readonly client: TaroPlatformClient;
  readonly auth:TaroAuthSDK;
  private lifecycleRevision=0;
  get revision():number{return this.lifecycleRevision;}
  private operation: Promise<void> | null = null;
  private starting: Promise<unknown> | null = null;
  private started = false;
  private generation = 0;
  private closed = false;
  private ensuring: Promise<boolean> | null = null;
  constructor(readonly config: IdentityConfig, private driver: IdentityDriver) {
    if (!config.enabled || !config.clientId.startsWith('fenleng-fridge-') ||
      !/^https:\/\/[^/\s]+/.test(config.baseUrl)) throw new Error('loginNotConfigured');
    const storage = new TaroStorageAdapter(driver, {prefix: 'fridge.platform.v1:'});
    const client = new TaroPlatformClient({baseUrl: config.baseUrl, storage, request: input => driver.request(input)});
    this.client = client;
    const auth = new TaroAuthSDK(client, {applicationCode: 'fenleng-fridge', clientId: config.clientId, clientTarget: 'miniapp'});
    this.auth=auth;
    this.session = new TaroSessionCoordinator(auth);
  }
  start(): Promise<unknown> {
    if (this.closed) return Promise.reject(new Error('loginCancelled'));
    if (this.started) return Promise.resolve();
    if (this.starting) return this.starting;
    this.starting = this.session.start({consent: true}).then(result => {
      this.started = true; return result;
    }).finally(() => {this.starting = null;});
    return this.starting;
  }
  login(): Promise<void> {
    if (this.closed) return Promise.reject(new Error('loginCancelled'));
    if (this.operation) return this.operation;
    const generation = this.generation;
    const operation = (async () => {
      if (this.ensuring) await this.ensuring;
      if (!this.started) await this.start();
      if (this.closed || generation !== this.generation) throw new Error('loginCancelled');
      ++this.lifecycleRevision;
      const {code} = await this.driver.login();
      if (this.closed || generation !== this.generation) throw new Error('loginCancelled');
      if (!code?.trim()) throw new Error('loginFailed');
      // The authorization code is exchanged once. Failed exchange requires a fresh code.
      await this.session.loginWithCode('wechat', code);
      if (this.closed || generation !== this.generation) {
        await this.session.logout({localOnly:true});
        throw new Error('loginCancelled');
      }
    })();
    this.operation = operation;
    return operation.finally(() => {if (this.operation === operation) this.operation = null;});
  }
  ensureSession(): Promise<boolean> {
    if (this.closed) return Promise.reject(new Error('loginCancelled'));
    if (this.ensuring) return this.ensuring;
    const pendingLogin = this.operation;
    const generation = this.generation;
    this.ensuring = (async () => {
      if (pendingLogin) await pendingLogin;
      if (!this.started) await this.start();
      if (this.closed || generation !== this.generation) throw new Error('loginCancelled');
      let status = this.session.snapshot().status;
      if (status === 'error' || status === 'reauthentication-required') {
        await this.session.restore(); status = this.session.snapshot().status;
      }
      if (status === 'anonymous' && this.config.guestEnabled) {++this.lifecycleRevision;await this.session.loginAsGuest();}
      if (this.closed || generation !== this.generation) throw new Error('loginCancelled');
      return this.session.snapshot().status === 'authenticated';
    })().finally(() => {this.ensuring = null;});
    return this.ensuring;
  }
  /** New one-use proof only: does not exchange a login or change the original session. */
  async deletionCode():Promise<string> {
    if(this.closed || this.operation || this.ensuring)throw new Error('loginCancelled');
    const generation=this.generation,revision=this.lifecycleRevision;
    const {code}=await this.driver.login();
    if(this.closed || generation!==this.generation || revision!==this.lifecycleRevision)throw new Error('loginCancelled');
    if(typeof code!=='string' || !code.trim() || code.length>1024)throw new Error('loginFailed');
    return code;
  }
  endLocalSession():Promise<void> {++this.generation;++this.lifecycleRevision;return this.session.logout({localOnly:true});}
  logout(): Promise<void> {++this.generation;++this.lifecycleRevision; return this.session.logout();}
  cancelLogin(): void {++this.generation;++this.lifecycleRevision;}
  async close(): Promise<void> {
    this.closed = true;
    ++this.lifecycleRevision;
    await this.session.close();
  }
}

/** Only stable, translated product keys cross into presentation. */
export function miniIdentityError(error: unknown): string {
  const failure = error as {code?: string; message?: string; errMsg?: string} | null;
  const code = failure?.code || failure?.message;
  if (code === 'loginNotConfigured' || code === 'CONFIGURATION_INVALID') return 'loginNotConfigured';
  if (code === 'loginCancelled' || code === 'SESSION_CHANGED' || /cancel/i.test(failure?.errMsg || '')) return 'loginCancelled';
  if (/timeout/i.test(failure?.errMsg || '') || code === 'REQUEST_TIMEOUT') return 'loginTimeout';
  return 'loginFailed';
}
