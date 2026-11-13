export interface DeletionReceipt {readonly id:string;readonly requestedAt:string;readonly eligibleAt:string;}
export interface DeletionEntry {
  readonly owner:string;readonly key:string;readonly phase:'prepared'|'submitting'|'unknown'|'accepted'|'cancelled';
  readonly receipt:DeletionReceipt|null;
}
export interface DeletionStorage {load():Promise<readonly DeletionEntry[]>;save(entries:readonly DeletionEntry[]):Promise<void>;}
export interface DeletionContext {
  readonly owner:string;
  current():boolean;
  challenge(key:string):Promise<{id:string;expiresAt:string}>;
  authorize():Promise<string>;
  confirm(challengeId:string,proof:string,key:string):Promise<string>;
  stopReminders():Promise<void>;
  submit(key:string,confirmationId:string):Promise<DeletionReceipt>;
  finish():Promise<void>;
  cancel():void;
}
export interface DeletionGateway {open():Promise<DeletionContext>;}
export class DeletionFailure extends Error {constructor(readonly key:string){super(key);}}

export function deletionInstantMillis(value:unknown):number {
  if(typeof value!=='string')return NaN;
  const parts=/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,9}))?Z$/.exec(value);
  if(!parts)return NaN;
  // Java Instant may contain nanoseconds; do not depend on engine-specific Date.parse extensions.
  const date=new Date(0);date.setUTCFullYear(Number(parts[1]),Number(parts[2])-1,Number(parts[3]));
  date.setUTCHours(Number(parts[4]),Number(parts[5]),Number(parts[6]),Number((parts[7]||'').slice(0,3).padEnd(3,'0')));
  return [date.getUTCFullYear(),date.getUTCMonth()+1,date.getUTCDate(),date.getUTCHours(),date.getUTCMinutes(),date.getUTCSeconds()]
    .every((part,index)=>part===Number(parts[index+1]))?date.getTime():NaN;
}
export function validDeletionReceipt(value:unknown):value is DeletionReceipt {
  const receipt=value as DeletionReceipt|null;
  return !!receipt && typeof receipt.id==='string' && /^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/.test(receipt.id) &&
    Number.isFinite(deletionInstantMillis(receipt.requestedAt)) && Number.isFinite(deletionInstantMillis(receipt.eligibleAt)) &&
    deletionInstantMillis(receipt.eligibleAt)-deletionInstantMillis(receipt.requestedAt)>=7*86400000;
}
export function validDeletionEntry(value:unknown):value is DeletionEntry {
  const entry=value as DeletionEntry|null;
  if(!entry || typeof entry.owner!=='string' || entry.owner.length>1024 || typeof entry.key!=='string' ||
    !/^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$/.test(entry.key) || !['prepared','submitting','unknown','accepted','cancelled'].includes(entry.phase))return false;
  try {const owner=JSON.parse(entry.owner) as unknown;
    if(!Array.isArray(owner) || owner.length!==3 || owner.some(part=>typeof part!=='string' || !part || part.length>512))return false;
  }catch{return false;}
  return entry.phase==='accepted'?validDeletionReceipt(entry.receipt):entry.phase==='cancelled'?
    entry.receipt===null || validDeletionReceipt(entry.receipt):entry.receipt===null;
}
