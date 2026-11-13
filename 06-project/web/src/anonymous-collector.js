import {FenlengBaseClient,WebAnonymousTelemetrySDK} from '@fenleng/sdk-web';

/** Sole collection/queue/transport is the official anonymous SDK. */
export function createAnonymousCollector(config,{consent,locale,fetch:send=globalThis.fetch?.bind(globalThis),timers=globalThis}={}) {
  if(!config.enabled || typeof consent!=='function' || typeof locale!=='function')return null;
  const url=new URL(config.baseUrl);
  if(url.username || url.password || url.search || url.hash)throw Error('WEBSITE_ANALYTICS_CONFIG_INVALID');
  let closed=false,foreground=true,timer=null,running=null,epoch=0,abort=null;
  const client=new FenlengBaseClient({baseUrl:config.baseUrl,authMode:'anonymous',maxRetries:0,timeoutMs:3000,
    storage:{getItem(){throw Error('Anonymous telemetry must not read identity storage');}},
    fetch:(endpoint,options)=>send(endpoint,{...options,keepalive:true})});
  const allowed=()=>!closed && consent();
  const sdk=new WebAnonymousTelemetrySDK(client,{clientId:config.clientId,catalog:['fridge.website.preview.opened.v1'],consent:allowed,
    context:()=>({platform:'web',appVersion:config.version,buildNumber:config.buildNumber,releaseChannel:'china',locale:locale()}),
    maxQueueSize:100,batchSize:50});
  const clear=()=>{if(timer!==null)timers.clearTimeout(timer);timer=null;};
  const schedule=()=>{if(closed || !foreground || !allowed() || timer!==null)return;
    timer=timers.setTimeout(()=>{timer=null;void flush();},100);};
  function flush() {
    if(running)return running;
    if(!allowed() || !sdk.pendingCount)return Promise.resolve(0);
    const generation=epoch,controller=new AbortController();abort=controller;
    running=(async()=>{
      for(let attempt=0;attempt<3;attempt++) {
        if(!allowed() || epoch!==generation)return 0;
        try {const accepted=await sdk.flush({signal:controller.signal});if(sdk.pendingCount)schedule();return accepted;}
        catch {if(attempt<2 && allowed() && epoch===generation)await new Promise(resolve=>timers.setTimeout(resolve,100*(attempt+1)));}
      }return 0;
    })().finally(()=>{running=null;if(abort===controller)abort=null;});
    return running;
  }
  return {
    appEntry(){if(!allowed())return false;try {sdk.track('fridge.website.preview.opened.v1',{target:'app'});schedule();void flush();return true;}catch{return false;}},
    flush,
    suspend(){foreground=false;clear();void flush();},
    resume(){foreground=true;if(sdk.pendingCount)schedule();},
    close(){closed=true;epoch++;clear();abort?.abort();sdk.withdrawConsent();},
    get pendingCount(){return sdk.pendingCount;},
  };
}
