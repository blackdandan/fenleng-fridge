import Taro from '@tarojs/taro';
import {FeedbackSession, type FridgeController} from '@fridge/application';
import {MiniFeedbackGateway, MiniIdentityOwner} from '@fridge/api-client';
import {createWeappIdentity, SnapshotFeedbackStorage, clearPlatformSession} from '@fridge/weapp';
import {identityConfig} from './config/identity';
import {createReminderSession} from './reminder-runtime';
import {createProductTelemetry} from './telemetry-runtime';
import {createDeletionSession} from './deletion-runtime';

/** One identity owner for account, feedback and later telemetry. */
export class OnlineRuntime {
  readonly sessions: MiniIdentityOwner;
  feedback: FeedbackSession;
  readonly reminders:ReturnType<typeof createReminderSession>;
  readonly telemetry:ReturnType<typeof createProductTelemetry>;
  deletion:ReturnType<typeof createDeletionSession>;
  private unsubscribeReminders:()=>void;
  private unsubscribeIdentity:(()=>void)|null=null;
  private boundIdentity:unknown=null;
  private closed = false;
  private foreground=true;
  private identityChanging=false;
  constructor(private controller: FridgeController,systemLanguage='zh-CN') {
    this.sessions = new MiniIdentityOwner(controller,identityConfig.enabled,() => createWeappIdentity(identityConfig,true));
    this.feedback=this.createFeedback();
    this.reminders=createReminderSession(controller,this.sessions,systemLanguage);
    this.deletion=createDeletionSession(controller,this.sessions,()=>this.reminders.cancel());
    this.telemetry=createProductTelemetry(controller,this.sessions,systemLanguage,()=>!this.closed && !this.identityChanging);
    controller.setEventSink(this.telemetry.record);
    let previous=controller.snapshot();
    this.unsubscribeReminders=controller.subscribe(()=>{
      const state=controller.snapshot(),wasReady=previous.stage==='ready';
      const changed=state.inventory!==previous.inventory || state.locale!==previous.locale || !wasReady;
      previous=state;
      if(state.stage==='ready' && changed){void this.deletion.start();void this.watchIdentity();void this.reminders.refresh();}
      else if(state.stage!=='ready' && wasReady){this.deletion.freeze();this.telemetry.withdraw();this.reminders.freeze();this.unsubscribeIdentity?.();this.unsubscribeIdentity=null;this.boundIdentity=null;}
    });
    controller.setPrivacyCleanup(async () => {
      this.telemetry.withdraw();
      await this.deletion.close();
      await this.feedback.close();
      await this.reminders.cancel();
      await this.sessions.ready();
      await clearPlatformSession({remove:key => Taro.removeStorageSync(key),read:key => Taro.getStorageSync(key)});
      this.feedback=this.createFeedback();
      this.deletion=createDeletionSession(controller,this.sessions,()=>this.reminders.cancel());
    });
    if(controller.snapshot().stage==='ready')void this.deletion.start();
  }
  private createFeedback(): FeedbackSession {
    const consent=() => !this.closed && this.controller.snapshot().stage==='ready';
    return new FeedbackSession(new SnapshotFeedbackStorage({
      get:key => Taro.getStorageSync(key), set:(key,value) => Taro.setStorageSync(key,value),
    }),new MiniFeedbackGateway(() => this.sessions.identity,consent),consent,
    () => `fridge-feedback-${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}-${Math.random().toString(36).slice(2)}`,this.controller.recordEvent);
  }
  ready() {return this.sessions.ready();}
  private async watchIdentity():Promise<void> {
    const identity=await this.sessions.ready();
    if(this.closed || this.controller.snapshot().stage!=='ready' || identity===this.boundIdentity)return;
    this.unsubscribeIdentity?.();this.boundIdentity=identity;
    if(!identity){this.unsubscribeIdentity=null;return;}
    let previous=identity.session.snapshot();
    this.unsubscribeIdentity=identity.session.subscribe(()=>{
      const state=identity.session.snapshot();
      if(state.status===previous.status && state.identityKind===previous.identityKind)return;
      previous=state;
      this.telemetry.withdraw();
      if(state.status==='authenticated' && state.identityKind!=='guest')void this.reminders.refresh();
      else if((state.status==='authenticated' && state.identityKind==='guest' ||
        ['anonymous','reauthentication-required','blocked','binding-required'].includes(state.status)) && this.reminders.snapshot().enabled) {
        void this.reminders.cancel().catch(()=>{});
      }
    });
  }
  async login(active:()=>boolean=()=>true):Promise<void> {
    if(this.identityChanging)throw new Error('loginCancelled');
    this.identityChanging=true;this.telemetry.withdraw();
    try {
    const identity=await this.sessions.ready();if(!identity)throw new Error('loginNotConfigured');
    const enabled=this.reminders.snapshot().enabled;
    await this.reminders.cancel();
    if(!active() || this.controller.snapshot().stage!=='ready')throw new Error('loginCancelled');
    await identity.login();
    if(enabled)await this.reminders.enable();
    }finally {this.identityChanging=false;if(this.foreground && !this.closed)this.telemetry.resume();}
  }
  async logout():Promise<void> {
    if(this.identityChanging)throw new Error('loginCancelled');
    this.identityChanging=true;this.telemetry.withdraw();
    try {
    const identity=await this.sessions.ready();
    await this.reminders.cancel();await identity?.logout();
    }finally {this.identityChanging=false;if(this.foreground && !this.closed)this.telemetry.resume();}
  }
  async deleteAccount(confirm:()=>Promise<boolean>):Promise<void> {
    if(this.identityChanging)throw new Error('loginCancelled');
    this.identityChanging=true;this.telemetry.withdraw();
    try {const identity=await this.sessions.ready();identity?.session.suspend();await this.feedback.close();await this.deletion.submit(confirm);}
    finally {this.feedback=this.createFeedback();this.identityChanging=false;if(this.foreground && !this.closed && !this.receiptIncomplete()){this.sessions.resume();this.telemetry.resume();}}
  }
  async retryDeletionReceipt():Promise<void> {
    if(this.identityChanging)throw new Error('loginCancelled');
    this.identityChanging=true;this.telemetry.withdraw();
    try {await this.feedback.close();await this.deletion.retryReceipt();}
    finally {this.feedback=this.createFeedback();this.identityChanging=false;if(this.foreground && !this.closed && !this.receiptIncomplete()){this.sessions.resume();this.telemetry.resume();}}
  }
  private receiptIncomplete():boolean {const state=this.deletion.snapshot();return state.entry?.phase==='accepted' && (!state.durable || state.cleanupPending);}
  resume(): void {this.foreground=true;if(!this.receiptIncomplete()){this.sessions.resume();this.telemetry.resume();void this.reminders.refresh();}}
  suspend(): void {this.foreground=false;void this.telemetry.suspend();this.sessions.suspend();}
  async close(): Promise<void> {
    this.closed = true;
    this.telemetry.close();
    this.unsubscribeReminders();this.unsubscribeIdentity?.();this.reminders.close();
    await Promise.all([this.deletion.close(),this.feedback.close(),this.sessions.close()]);
  }
}
