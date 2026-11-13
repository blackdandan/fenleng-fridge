export type MiniSubscriptionResult='accept'|'reject'|'ban'|'filter';
export type MiniSubscriptionRequester=(input:{tmplIds:string[]})=>Promise<unknown>;

/** Invoke directly from the user click: no login, crypto, storage or HTTP before the native call. */
export function requestSubscriptionFromGesture(templateId:string,request:MiniSubscriptionRequester):Promise<MiniSubscriptionResult> {
  if(!/^[A-Za-z0-9_-]{1,128}$/.test(templateId))return Promise.reject(new Error('MINI_TEMPLATE_INVALID'));
  const failure=(error:unknown)=>new Error(/cancel/i.test((error as {errMsg?:string})?.errMsg || '')?'MINI_PERMISSION_CANCELLED':'MINI_PERMISSION_UNAVAILABLE');
  let native:Promise<unknown>;
  try {native=request({tmplIds:[templateId]});}catch(error) {return Promise.reject(failure(error));}
  return Promise.resolve(native).then(value=>{
    const result=(value as Record<string,unknown> | null)?.[templateId];
    if(result==='accept' || result==='reject' || result==='ban' || result==='filter')return result;
    throw new Error('MINI_PERMISSION_UNCONFIRMED');
  },error=>{throw failure(error);});
}
