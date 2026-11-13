import type {MiniReminderCalendar} from '@fridge/domain';
import {emitProductEvent,type ProductEventSink} from './product-events';

export type MiniPermissionResult='accept'|'reject'|'ban'|'filter';
export interface MiniReminderGateway {
  configuration():Promise<{configured:boolean;templateId:string|null}>;
  sync(calendar:MiniReminderCalendar):Promise<unknown>;
  retryObservations():Promise<{observedAcceptances:number}|null>;
  observe(templateId:string,result:MiniPermissionResult):Promise<{observedAcceptances:number}|null>;
  requestPermission(templateId:string):Promise<MiniPermissionResult>;
  revoke():Promise<unknown>;
}
export interface MiniReminderSessionPorts {
  consent():boolean;
  available?():boolean;
  events?:ProductEventSink;
  accountReady():Promise<boolean>;
  calendar():MiniReminderCalendar;
  readEnabled():Promise<boolean>;
  writeEnabled(enabled:boolean):Promise<void>;
  create():MiniReminderGateway;
  cancelStored():Promise<unknown>;
}
export interface MiniReminderSessionState {
  readonly enabled:boolean;
  readonly phase:'off'|'preparing'|'needs-login'|'unconfigured'|'ready'|'permission'|'cancelling'|'error';
  readonly errorKey:string|null;readonly messageKey:string|null;
  readonly observedAcceptances:number;
}

/** Single online owner. Native permission is called synchronously, only from an explicit click. */
export class MiniReminderSession {
  private value:MiniReminderSessionState={enabled:false,phase:'off',errorKey:null,messageKey:null,observedAcceptances:0};
  private listeners=new Set<()=>void>();
  private gateway:MiniReminderGateway|null=null;
  private initialized=false;
  private epoch=0;
  private template:string|null=null;
  private refreshing:Promise<void>|null=null;
  private action:Promise<void>|null=null;
  private dirty=false;
  private saving:Promise<void>=Promise.resolve();
  private closed=false;
  constructor(private ports:MiniReminderSessionPorts) {}
  snapshot=():MiniReminderSessionState=>this.value;
  subscribe=(listener:()=>void):(()=>void)=>{this.listeners.add(listener);return()=>{this.listeners.delete(listener);};};
  private publish(change:Partial<MiniReminderSessionState>) {this.value={...this.value,...change};this.listeners.forEach(listener=>listener());}
  private current(epoch:number) {return !this.closed && this.ports.consent() && epoch===this.epoch;}
  refresh():Promise<void> {
    if(this.closed || !this.ports.consent() || this.action || this.value.errorKey==='miniCancelFailed')return Promise.resolve();
    this.dirty=true;
    if(this.refreshing)return this.refreshing;
    const epoch=this.epoch;
    this.refreshing=(async()=>{
      do {
        this.dirty=false;
        try {
          if(!this.initialized) {
            const enabled=await this.ports.readEnabled();if(!this.current(epoch))return;
            this.initialized=true;this.publish({enabled});
            // A previous disable may have crashed before the SDK cancellation marker was committed.
            if(!enabled) {
              try {await this.ports.cancelStored();}catch {throw new Error('miniCancelFailed');}
              if(!this.current(epoch))return;
            }
          }
          if(!this.value.enabled){this.publish({phase:'off',errorKey:null,messageKey:null});return;}
          if(this.ports.available?.()===false){this.publish({phase:'unconfigured',messageKey:'miniUnconfigured'});return;}
          this.publish({phase:'preparing',errorKey:null});
          if(!await this.ports.accountReady()) {
            if(!this.current(epoch))return;
            const previous=this.gateway;this.gateway=null;this.template=null;
            try {await (previous?previous.revoke():this.ports.cancelStored());}catch {throw new Error('miniCancelFailed');}
            if(this.current(epoch))this.publish({phase:'needs-login',messageKey:'miniNeedsLogin'});return;
          }
          if(!this.current(epoch))return;
          const gateway=this.gateway ?? (this.gateway=this.ports.create());
          const config=await gateway.configuration();if(!this.current(epoch))return;
          if(!config.configured || !config.templateId) {this.template=null;this.publish({phase:'unconfigured',messageKey:'miniUnconfigured'});return;}
          this.template=config.templateId;
          await gateway.sync(this.ports.calendar());if(!this.current(epoch))return;
          const observed=await gateway.retryObservations();if(!this.current(epoch))return;
          this.publish({phase:'ready',errorKey:null,observedAcceptances:observed?.observedAcceptances ?? 0,
            messageKey:observed?.observedAcceptances?'miniGranted':'miniReady'});
        }catch(error) {if(this.current(epoch))this.publish({phase:'error',errorKey:
          error instanceof Error && error.message==='miniCancelFailed' || (error as {code?:string})?.code==='MINI_CANCELLATION_PENDING'
            ?'miniCancelFailed':'miniSyncFailed',messageKey:null});return;}
      }while(this.dirty && this.current(epoch));
    })().finally(()=>{this.refreshing=null;if(this.dirty && !this.closed && this.ports.consent() && !this.action)void this.refresh();});
    return this.refreshing;
  }
  async enable():Promise<void> {
    if(this.closed || !this.ports.consent() || this.action || this.value.errorKey==='miniCancelFailed')return;
    const epoch=++this.epoch;
    const previous=this.refreshing;
    this.publish({phase:'preparing',errorKey:null});
    const action=(async()=>{
      try {
        await previous;if(!this.current(epoch))return;await this.ports.writeEnabled(true);
        if(this.current(epoch)){this.initialized=true;this.publish({enabled:true});}
      }catch {if(this.current(epoch))this.publish({phase:'error',errorKey:'miniSyncFailed'});}
    })();
    this.action=action;this.saving=action;await action;if(this.action===action)this.action=null;
    if(this.current(epoch) && this.value.enabled)await this.refresh();
  }
  requestPermission():Promise<void> {
    if(this.closed || !this.ports.consent() || this.value.phase!=='ready' || !this.gateway || !this.template || this.action)return Promise.resolve();
    const epoch=this.epoch,gateway=this.gateway,template=this.template;
    // No async preparation before this call; the host still has the click gesture.
    let native:Promise<MiniPermissionResult>;
    try {native=gateway.requestPermission(template);}catch {this.publish({errorKey:'miniPermissionFailed'});return Promise.resolve();}
    this.publish({phase:'permission',errorKey:null});
    const action=(async()=>{
      let result:MiniPermissionResult;
      try {
        result=await native;if(!this.current(epoch))return;
      }catch(error) {
        if(this.current(epoch)) {
          emitProductEvent(this.ports.events ?? (()=>{}),'fridge.permission.resolved.v1',{
            permission:'notifications',result:error instanceof Error && error.message==='MINI_PERMISSION_CANCELLED'?'cancelled':'restricted'});
          this.publish({phase:'ready',errorKey:'miniPermissionFailed'});
        }return;
      }
      emitProductEvent(this.ports.events ?? (()=>{}),'fridge.permission.resolved.v1',{
        permission:'notifications',result:result==='accept'?'granted':result==='reject'?'denied':'restricted'});
      try {
        const receipt=await gateway.observe(template,result);if(!this.current(epoch))return;
        this.publish({phase:'ready',observedAcceptances:receipt?.observedAcceptances ?? 0,
          messageKey:result==='accept'?'miniGranted':'miniPermissionFailed'});
      }catch {if(this.current(epoch))this.publish({phase:'error',errorKey:'miniSyncFailed'});}
    })();
    this.action=action;void action.finally(()=>{if(this.action===action)this.action=null;});return action;
  }
  /** Also used after consent is gone, before privacy cleanup can acknowledge success. */
  cancel():Promise<void> {
    if(this.value.phase==='cancelling' && this.action)return this.action;
    ++this.epoch;this.dirty=false;this.template=null;
    const gateway=this.gateway;this.gateway=null;
    const saving=this.saving;
    this.publish({enabled:false,phase:'cancelling',errorKey:null,messageKey:null});
    const action=(async()=>{
      try {
        // Fence SDK immediately, including when a preference commit is still in progress.
        const revoking=gateway?gateway.revoke():this.ports.cancelStored();void revoking.catch(()=>{});
        const results=await Promise.allSettled([saving.then(()=>this.ports.writeEnabled(false)),revoking]);
        if(results.some(result=>result.status==='rejected'))throw new Error('CANCEL_NOT_COMMITTED');
        this.initialized=true;this.publish({phase:'off',observedAcceptances:0});
      }catch {this.initialized=false;this.publish({phase:'error',errorKey:'miniCancelFailed'});throw new Error('miniCancelFailed');}
    })();
    this.action=action;void action.catch(()=>{}).finally(()=>{if(this.action===action)this.action=null;});return action;
  }
  freeze():void {++this.epoch;this.dirty=false;}
  close():void {this.closed=true;this.freeze();this.listeners.clear();}
}
