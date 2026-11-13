import {DeletionFailure,validDeletionReceipt,deletionInstantMillis,type DeletionContext,type DeletionGateway,type DeletionReceipt} from '@fridge/platform-contracts';
import type {MiniIdentity} from './identity';
import {requestCancellation} from './request-cancellation';

/** Official SDK methods only. Never creates or restores a login. */
export class MiniDeletionGateway implements DeletionGateway {
  constructor(private identity:()=>MiniIdentity|null,private consent:()=>boolean,private cancelReminders:()=>Promise<void>){}
  async open():Promise<DeletionContext> {
    const identity=this.identity();
    if(!identity || !this.consent())throw new DeletionFailure('deletionUnavailable');
    const snapshot=identity.session.snapshot();
    if(snapshot.status!=='authenticated' || snapshot.identityKind==='guest' || snapshot.refreshing)throw new DeletionFailure('deletionLoginRequired');
    const captured=identity.session.captureSession(),revision=identity.revision,cancellation=requestCancellation();
    let submitting=false;
    const sameOwner=()=>this.consent() && this.identity()===identity && identity.revision===revision;
    const validOwner=()=>sameOwner() && captured();
    const current=()=>validOwner() && !cancellation.signal.aborted;
    const check=()=>{if(!current())throw new DeletionFailure('deletionCancelled');};
    const unsubscribe=identity.session.subscribe(()=>{if(!sameOwner() || !captured() && !submitting)cancellation.abort();});
    const options={signal:cancellation.signal};
    let userId:string;
    try {
      check();const profile=await identity.auth.currentUser(options);check();
      if(!profile || typeof profile.id!=='string' || !profile.id || profile.id.length>128 || profile.kind!=='HUMAN' || profile.status!=='ACTIVE')throw new DeletionFailure('deletionLoginRequired');
      userId=profile.id;
    }catch(error){unsubscribe();cancellation.abort();throw mapped(error);}
    let cleanupRevision=revision;
    const cancel=()=>{unsubscribe();cancellation.abort();};
    return {
      owner:JSON.stringify([new URL(identity.config.baseUrl).toString().replace(/\/$/,''),identity.config.clientId,userId]),current,cancel,
      challenge:async key=>{
        check();try {
          const result=await identity.auth.createFederatedDeletionChallenge('WECHAT',key,options);check();
          if(!result || !/^fdc-[A-Za-z0-9._:-]+$/.test(result.challengeId) || result.challengeId.length>128 || result.provider!=='WECHAT' ||
            !Number.isFinite(deletionInstantMillis(result.expiresAt)))throw new DeletionFailure('deletionFailed');
          return{id:result.challengeId,expiresAt:result.expiresAt};
        }catch(error){throw mapped(error);}
      },
      authorize:async()=>{check();try{const proof=await identity.deletionCode();check();return proof;}catch(error){throw mapped(error);}},
      confirm:async(id,proof,key)=>{
        check();try {
          const result=await identity.auth.confirmFederatedDeletionReauthentication(id,proof,options);check();
          if(!result || result.confirmationId!==id || result.deletionIdempotencyKey!==key || !Number.isFinite(deletionInstantMillis(result.expiresAt)))throw new DeletionFailure('deletionFailed');
          return result.confirmationId;
        }catch(error){throw mapped(error);}
      },
      stopReminders:async()=>{check();try{await this.cancelReminders();check();}catch(error){throw error instanceof DeletionFailure?error:new DeletionFailure('miniCancelFailed');}},
      submit:async(key,id)=>{
        check();submitting=true;
        let result;
        try {result=await identity.auth.requestData('DELETE',key,{...options,actionConfirmationId:id});}
        finally{submitting=false;}
        // A genuine ACK from the original request remains meaningful even if a
        // concurrent401 already invalidated that session. The application owns consent fencing.
        const receipt:DeletionReceipt={id:result.id,requestedAt:result.requestedAt,eligibleAt:result.nextAttemptAt||''};
        if(result.type!=='DELETE' || result.status!=='PENDING' || result.userId!==userId || !validDeletionReceipt(receipt))throw new DeletionFailure('deletionUnknown');
        return receipt;
      },
      finish:async()=>{
        // Local only. A newer human/guest identity is never removed by an old ACK.
        if(!this.consent() || this.identity()!==identity || identity.revision!==cleanupRevision)return;
        try {await identity.endLocalSession();}finally{cleanupRevision=identity.revision;}
      },
    };
  }
}
function mapped(error:unknown):DeletionFailure {
  if(error instanceof DeletionFailure)return error;
  const failure=error as {code?:string;message?:string;errMsg?:string};
  if(failure?.code==='REQUEST_CANCELLED' || failure?.message==='loginCancelled' || /cancel/i.test(failure?.errMsg||''))return new DeletionFailure('deletionCancelled');
  return new DeletionFailure('deletionFailed');
}
