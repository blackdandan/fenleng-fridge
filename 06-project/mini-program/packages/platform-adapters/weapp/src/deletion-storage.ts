import {validDeletionEntry,type DeletionEntry,type DeletionStorage} from '@fridge/platform-contracts';

export interface DeletionStorageDriver {get(key:string):unknown;set(key:string,value:string):void;}
/** Noncredential journal survives auth cleanup. A single host write replaces the snapshot. */
export class SnapshotDeletionStorage implements DeletionStorage {
  static readonly key='fridge.account-deletion.v1';
  constructor(private driver:DeletionStorageDriver){}
  async load():Promise<readonly DeletionEntry[]> {
    const raw=this.driver.get(SnapshotDeletionStorage.key);
    if(raw===undefined || raw===null || raw==='')return [];
    if(typeof raw!=='string')throw new Error('DELETION_JOURNAL_INVALID');
    const value=JSON.parse(raw) as {version:number;entries:unknown[]};
    if(!value || value.version!==1 || !Array.isArray(value.entries) || value.entries.some(entry=>!validDeletionEntry(entry)))throw new Error('DELETION_JOURNAL_INVALID');
    const entries=value.entries as DeletionEntry[];
    if(new Set(entries.map(entry=>entry.owner)).size!==entries.length)throw new Error('DELETION_JOURNAL_INVALID');
    // Do not retain accidental unknown fields or provider credentials from a malformed writer.
    return entries.map(entry=>({owner:entry.owner,key:entry.key,phase:entry.phase,receipt:entry.receipt?{
      id:entry.receipt.id,requestedAt:entry.receipt.requestedAt,eligibleAt:entry.receipt.eligibleAt}:null}));
  }
  async save(entries:readonly DeletionEntry[]):Promise<void> {
    if(entries.some(entry=>!validDeletionEntry(entry)) || new Set(entries.map(entry=>entry.owner)).size!==entries.length)throw new Error('DELETION_JOURNAL_INVALID');
    const values=entries.map(entry=>({owner:entry.owner,key:entry.key,phase:entry.phase,receipt:entry.receipt?{
      id:entry.receipt.id,requestedAt:entry.receipt.requestedAt,eligibleAt:entry.receipt.eligibleAt}:null}));
    this.driver.set(SnapshotDeletionStorage.key,JSON.stringify({version:1,entries:values}));
  }
}
