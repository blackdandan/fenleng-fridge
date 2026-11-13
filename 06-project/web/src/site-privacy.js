export const WEBSITE_PRIVACY_KEY='fridge.website.privacy.v1';
export class WebsitePrivacy {
  constructor({storage,loadCollector,version='V0.4',now=()=>new Date().toISOString()}) {
    this.storage=storage;this.loadCollector=loadCollector;this.version=version;this.now=now;
    this.value={choice:'unknown',show:false,error:null};this.raw=undefined;this.collector=null;
    this.listeners=new Set();this.loading=null;this.epoch=0;this.closed=false;
  }
  snapshot=()=>this.value;
  subscribe(listener){this.listeners.add(listener);return()=>this.listeners.delete(listener);}
  publish(change){this.value={...this.value,...change};for(const listener of this.listeners)listener();}
  read(){
    try {
      const raw=this.storage.getItem(WEBSITE_PRIVACY_KEY),record=JSON.parse(raw);
      const valid=record?.policyVersion===this.version && typeof record.accepted==='boolean' &&
        (!record.accepted || typeof record.acceptedAt==='string' && Number.isFinite(Date.parse(record.acceptedAt)));
      return {raw,choice:valid?(record.accepted?'accepted':'declined'):'unknown'};
    }catch{return {raw:null,choice:'unknown'};}
  }
  hasConsent=()=>{if(this.closed || this.value.choice!=='accepted')return false;const record=this.read();return record.choice==='accepted' && record.raw===this.raw;};
  stop(){this.epoch++;try {this.collector?.close();}catch{}this.collector=null;this.loading=null;}
  start(){return this.refresh();}
  refresh(){
    if(this.closed)return Promise.resolve(null);
    const record=this.read();
    if(record.raw!==this.raw){this.stop();this.raw=record.raw;this.publish({choice:record.choice,show:record.choice==='unknown',error:null});}
    return this.hasConsent()?this.ensureCollector():Promise.resolve(null);
  }
  accept(){
    if(this.closed)return false;
    try {this.storage.setItem(WEBSITE_PRIVACY_KEY,JSON.stringify({policyVersion:this.version,accepted:true,acceptedAt:this.now()}));}
    catch{this.publish({show:true,error:'error'});return false;}
    void this.refresh();return true;
  }
  decline(){
    if(this.closed)return false;
    this.stop();this.publish({choice:'declined',show:false,error:null});
    try {this.storage.setItem(WEBSITE_PRIVACY_KEY,JSON.stringify({policyVersion:this.version,accepted:false}));this.raw=this.storage.getItem(WEBSITE_PRIVACY_KEY);}
    catch{this.publish(this.read().choice==='accepted'?{show:true,error:'privacyWithdrawFailed'}:{show:false,error:null});}return false;
  }
  withdraw(){
    if(this.closed)return false;
    this.stop();this.publish({choice:'unknown',show:true,error:null});
    try {this.storage.removeItem(WEBSITE_PRIVACY_KEY);this.raw=null;return true;}
    catch{this.publish({error:'privacyWithdrawFailed'});return false;}
  }
  showChoices(){this.publish({show:true,error:this.value.error==='privacyWithdrawFailed'?this.value.error:null});}
  hideChoices(){this.publish({show:false});}
  ensureCollector(){
    if(this.collector)return Promise.resolve(this.collector);
    if(!this.hasConsent())return Promise.resolve(null);
    if(this.loading)return this.loading;
    const epoch=this.epoch;
    const loading=Promise.resolve().then(()=>this.loadCollector()).then(collector=>{
      if(epoch!==this.epoch || !this.hasConsent()){collector?.close();return null;}
      this.collector=collector;return collector;
    }).catch(()=>null).finally(()=>{if(this.loading===loading)this.loading=null;});
    this.loading=loading;return loading;
  }
  async appEntry(){
    if(!this.hasConsent())return false;
    const epoch=this.epoch,collector=await this.ensureCollector();
    if(epoch!==this.epoch || !this.hasConsent())return false;
    try {return collector?.appEntry() ?? false;}catch{return false;}
  }
  suspend(){try{this.collector?.suspend();}catch{}}
  resume(){try{this.collector?.resume();}catch{}}
  close(){this.closed=true;this.stop();this.listeners.clear();}
}
