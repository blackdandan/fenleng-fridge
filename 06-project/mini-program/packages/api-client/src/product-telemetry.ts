import {TaroTelemetrySDK,type TaroSdkClient,type TelemetryContext} from '@fenleng/sdk-taro';
import type {MiniIdentity} from './identity';

type Identity=Pick<MiniIdentity,'client'|'ensureSession'|'session'>;
interface Catalog {consentSource:string;separateAnalyticsToggle:boolean;events:readonly {name:string;properties:Readonly<Record<string,readonly string[]>>}[];}
interface Options {
  enabled:boolean;consent():boolean;identity():Identity|null;ready():Promise<Identity|null>;
  catalog:unknown;context():TelemetryContext;nextKey():Promise<string>;
  nextDeliveryId?:()=>string|Promise<string>;
  debounceMs?:number;pause?:(ms:number)=>Promise<void>;
  timers?:{setTimeout(callback:()=>void,ms:number):unknown;clearTimeout(id:unknown):void};
}
/** Only the official SDK owns the queue, HTTP payload, pinned batch/key and ACK handling. */
export class MiniProductTelemetry {
  private readonly catalog=new Map<string,Readonly<Record<string,readonly string[]>>>();
  private sdk:TaroTelemetrySDK|null=null;
  private timer:unknown=null;
  private running:Promise<number>|null=null;
  private binding:{identity:Identity;active:()=>boolean}|null=null;
  private cancellation:ReturnType<typeof cancellableRequest>|null=null;
  private epoch=0;
  private foreground=true;
  private closed=false;
  private readonly timers:NonNullable<Options['timers']>;
  private readonly pause:(ms:number)=>Promise<void>;
  constructor(private options:Options) {
    const catalog=options.catalog as Catalog|null;
    if(!catalog || catalog.consentSource!=='unified-privacy-v0.4' || catalog.separateAnalyticsToggle!==false || !Array.isArray(catalog.events))throw new Error('TELEMETRY_CATALOG_INVALID');
    for(const event of catalog.events) {
      if(!event || typeof event.name!=='string' || this.catalog.has(event.name) || !event.properties || typeof event.properties!=='object' || Array.isArray(event.properties))throw new Error('TELEMETRY_CATALOG_INVALID');
      const properties=Object.fromEntries(Object.entries(event.properties).map(([key,values])=>{
        if(!Array.isArray(values) || !values.length || values.some(value=>typeof value!=='string'))throw new Error('TELEMETRY_CATALOG_INVALID');
        return [key,[...values]];
      }));
      if(event.name!=='fridge.website.preview.opened.v1')this.catalog.set(event.name,properties);
    }
    this.timers=options.timers ?? {setTimeout:(fn,ms)=>setTimeout(fn,ms),clearTimeout:id=>clearTimeout(id as ReturnType<typeof setTimeout>)};
    this.pause=options.pause ?? (ms=>new Promise(resolve=>setTimeout(resolve,ms)));
  }
  get pendingCount():number {return this.sdk?.pendingCount ?? 0;}
  record=(name:string,properties:Readonly<Record<string,string>>={}):boolean=>{
    if(this.closed || !this.options.consent() || properties===null || typeof properties!=='object' || Array.isArray(properties))return false;
    const allowed=this.catalog.get(name);
    if(!allowed || Object.keys(properties).length!==Object.keys(allowed).length ||
      Object.entries(properties).some(([key,value])=>!Object.hasOwn(allowed,key) || !allowed[key].includes(value)))return false;
    try {
      if(!this.sdk) {
        const client:TaroSdkClient={tokenKey:'unused',storage:{async getItem(){return null;},async setItem(){},async removeItem(){}},
          request:(endpoint,method,body,options)=>{
            const binding=this.binding;
            if(!binding || this.closed || !this.options.consent() || !binding.active() || binding.identity!==this.options.identity())throw new Error('SESSION_CHANGED');
            return binding.identity.client.request(endpoint,method,body,options);
          }};
        this.sdk=new TaroTelemetrySDK(client,{catalog:[...this.catalog.keys()],consent:()=>!this.closed && this.options.consent(),
          context:this.options.context,deliveryIdFactory:this.options.nextDeliveryId,maxQueueSize:100,batchSize:50});
      }
      this.sdk.track(name,properties);this.schedule();return true;
    }catch {return false;}
  };
  private schedule():void {
    if(!this.options.enabled || this.closed || !this.foreground || !this.options.consent() || this.timer!==null)return;
    this.timer=this.timers.setTimeout(()=>{this.timer=null;void this.flush();},this.options.debounceMs ?? 2000);
  }
  flush():Promise<number> {
    if(this.running)return this.running;
    if(!this.options.enabled || this.closed || !this.options.consent() || !this.sdk || !this.pendingCount)return Promise.resolve(0);
    const epoch=this.epoch;
    this.running=this.drain(epoch).finally(()=>{this.running=null;if(epoch!==this.epoch && this.pendingCount)this.schedule();});
    return this.running;
  }
  private async drain(epoch:number):Promise<number> {
    const cancellation=cancellableRequest();this.cancellation=cancellation;
    try {
      for(let attempt=0;attempt<3;attempt++) {
        if(!this.current(epoch))return 0;
        let identity:Identity|null=null;
        try {
          identity=await this.options.ready();
          if(!this.current(epoch) || !identity || identity!==this.options.identity() || !await identity.ensureSession() || !this.current(epoch))return 0;
          const active=identity.session.captureSession();if(!active())return 0;
          this.binding={identity,active};
          const key=await this.options.nextKey();
          if(!this.current(epoch) || !active() || identity!==this.options.identity())return 0;
          const accepted=await this.sdk!.flush({idempotencyKey:key,signal:cancellation.signal});
          if(this.current(epoch) && this.pendingCount)this.schedule();return accepted;
        }catch(error) {
          if(!this.current(epoch))return 0;
          if((error as {status?:number})?.status===401) {
            this.withdraw();await identity?.session.invalidate().catch(()=>{});return 0;
          }
          if(attempt<2)await this.pause(300*(attempt+1));
        }
      }
      return 0;
    }finally {this.binding=null;if(this.cancellation===cancellation)this.cancellation=null;}
  }
  private current(epoch:number):boolean {return !this.closed && this.options.consent() && this.epoch===epoch;}
  resume():void {this.foreground=true;if(this.pendingCount)this.schedule();}
  async suspend():Promise<void> {
    this.foreground=false;this.clearTimer();
    await Promise.race([this.flush().catch(()=>0),this.pause(2000)]);
  }
  private clearTimer():void {if(this.timer!==null)this.timers.clearTimeout(this.timer);this.timer=null;}
  withdraw():void {this.epoch++;this.clearTimer();this.cancellation?.abort();this.sdk?.withdrawConsent();}
  close():void {this.closed=true;this.withdraw();}
}

/** Taro transport needs only this cancellation surface; no browser AbortController global required. */
function cancellableRequest() {
  const listeners=new Set<()=>void>();
  const signal={aborted:false,addEventListener:(_type:string,listener:()=>void)=>{listeners.add(listener);},
    removeEventListener:(_type:string,listener:()=>void)=>{listeners.delete(listener);}};
  return {signal:signal as unknown as AbortSignal,abort:()=>{signal.aborted=true;for(const listener of listeners)try {listener();}catch {}listeners.clear();}};
}
