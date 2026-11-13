import {DeletionFailure,validDeletionReceipt,type DeletionEntry,type DeletionContext,type DeletionGateway,type DeletionReceipt,type DeletionStorage} from '@fridge/platform-contracts';

export interface AccountDeletionSnapshot {
  readonly loading:boolean;readonly initialized:boolean;readonly busy:boolean;
  readonly entry:DeletionEntry|null;readonly durable:boolean;readonly cleanupPending:boolean;readonly errorKey:string|null;
}
/** A DELETE result is not guessed from logout,401 or transport failure. No automatic login. */
export class AccountDeletionSession {
  private value:AccountDeletionSnapshot={loading:true,initialized:false,busy:false,entry:null,durable:true,cleanupPending:false,errorKey:null};
  private entries:readonly DeletionEntry[]=[];
  private listeners=new Set<()=>void>();
  private operation:Promise<void>|null=null;
  private starting:Promise<void>|null=null;
  private context:DeletionContext|null=null;
  private pendingFinish:(()=>Promise<void>)|null=null;
  private closed=false;
  private generation=0;
  constructor(private storage:DeletionStorage,private gateway:DeletionGateway,private consent:()=>boolean,private nextKey:()=>Promise<string>){}
  snapshot=():AccountDeletionSnapshot=>this.value;
  subscribe=(listener:()=>void):(()=>void)=>{this.listeners.add(listener);return()=>{this.listeners.delete(listener);};};
  private publish(change:Partial<AccountDeletionSnapshot>):void {
    this.value={...this.value,...change};if(!this.closed)this.listeners.forEach(listener=>listener());
  }
  private gate(generation=this.generation,context:DeletionContext|null=null):void {
    if(this.closed || !this.consent() || generation!==this.generation || context && !context.current())throw new DeletionFailure('deletionCancelled');
  }
  start():Promise<void> {
    if(this.closed || this.value.initialized)return Promise.resolve();if(this.starting)return this.starting;
    this.starting=(async()=>{
      try {this.gate();const entries=await this.storage.load();this.gate();
        this.entries=entries.map(entry=>entry.phase==='submitting'?{...entry,phase:'unknown' as const}:entry);
        this.publish({initialized:true,entry:this.entries[this.entries.length-1]||null,errorKey:null});
      }catch {this.publish({errorKey:'deletionStorageFailed'});}finally{this.publish({loading:false});}
    })().finally(()=>{this.starting=null;});return this.starting;
  }
  private async save(entry:DeletionEntry):Promise<void> {
    this.gate();const next=[...this.entries.filter(item=>item.owner!==entry.owner),entry];
    try {await this.storage.save(next);}catch {throw new DeletionFailure('deletionStorageFailed');}
    this.gate();this.entries=next;this.publish({entry,durable:true});
  }
  private run(action:(generation:number)=>Promise<void>):Promise<void> {
    if(this.closed)return Promise.resolve();if(this.operation || this.value.busy)return this.operation||Promise.resolve();
    const generation=this.generation;this.publish({busy:true,errorKey:null});
    this.operation=Promise.resolve().then(async()=>{
      try {await this.start();this.gate(generation);if(!this.value.initialized)throw new DeletionFailure('deletionStorageFailed');await action(generation);}
      catch(error){this.publish({errorKey:error instanceof DeletionFailure?error.key:'deletionFailed'});}
      finally{this.context?.cancel();this.context=null;this.publish({busy:false});}
    }).finally(()=>{this.operation=null;});return this.operation;
  }
  /** Host supplies a visible confirmation. Returning false causes no challenge or DELETE. */
  submit(confirm:()=>Promise<boolean>):Promise<void> {
    if(this.value.entry?.phase==='accepted' && (!this.value.durable || this.pendingFinish))return this.retryReceipt();
    return this.run(async generation=>{
      const context=await this.gateway.open();this.context=context;this.gate(generation,context);
      let entry=this.entries.find(item=>item.owner===context.owner)||null;
      if(entry?.phase==='accepted'){
        // The old session was revoked by DELETE. A now-active session for this same
        // owner proves a subsequent successful login/restore cancelled the request.
        entry={...entry,phase:'cancelled'};await this.save(entry);
      }
      this.publish({entry,durable:true});
      if(!await confirm())return;
      this.gate(generation,context);
      const key=entry && entry.phase!=='cancelled'?entry.key:await this.nextKey();
      this.gate(generation,context);
      entry={owner:context.owner,key,phase:entry?.phase==='unknown'?'unknown':'prepared',receipt:null};
      await this.save(entry);this.gate(generation,context);
      const challenge=await context.challenge(key);this.gate(generation,context);
      const proof=await context.authorize();this.gate(generation,context);
      const confirmation=await context.confirm(challenge.id,proof,key);this.gate(generation,context);
      await context.stopReminders();this.gate(generation,context);
      entry={...entry,phase:'submitting'};await this.save(entry);this.gate(generation,context);
      let receipt:DeletionReceipt;
      try {receipt=await context.submit(key,confirmation);this.gate(generation);
        if(!validDeletionReceipt(receipt))throw new DeletionFailure('deletionUnknown');}
      catch(error){
        // Durable submitting marker survives a process loss even if this save fails.
        entry={...entry,phase:'unknown'};this.publish({entry});
        if(!this.closed && this.consent() && generation===this.generation)await this.save(entry);
        throw error instanceof DeletionFailure && error.key==='deletionCancelled'?error:new DeletionFailure('deletionUnknown');
      }
      entry={...entry,phase:'accepted',receipt};this.pendingFinish=()=>context.finish();this.publish({entry,durable:false,cleanupPending:true});
      await this.save(entry);this.gate(generation);
      await this.finish();
    });
  }
  /** Re-persist a known ACK without a second HTTP request, then retry local cleanup. */
  retryReceipt():Promise<void> {
    return this.run(async generation=>{
      const entry=this.value.entry;
      if(!entry || entry.phase!=='accepted' || !entry.receipt)return;
      await this.save(entry);this.gate(generation);
      await this.finish();
    });
  }
  /** Call only for an explicitly established human identity, never to start a login. */
  refreshOwner(afterLogin=false):Promise<void> {
    if(afterLogin && this.operation)return this.operation.then(()=>this.refreshOwner(true));
    return this.run(async generation=>{
      const context=await this.gateway.open();this.context=context;this.gate(generation,context);
      let entry=this.entries.find(item=>item.owner===context.owner)||null;
      if(entry?.phase==='accepted' || afterLogin && entry && ['unknown','submitting'].includes(entry.phase)){
        entry={...entry,phase:'cancelled'};await this.save(entry);
      }else this.publish({entry,durable:true});
    });
  }
  private async finish():Promise<void> {
    try {await this.pendingFinish?.();this.pendingFinish=null;this.publish({cleanupPending:false});}
    catch {throw new DeletionFailure('deletionCleanupFailed');}
  }
  freeze():void {++this.generation;this.context?.cancel();}
  async close():Promise<void> {this.closed=true;this.freeze();this.pendingFinish=null;this.listeners.clear();await this.starting;await this.operation;}
}
