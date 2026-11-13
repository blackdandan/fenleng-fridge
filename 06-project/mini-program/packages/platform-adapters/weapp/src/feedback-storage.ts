import type {FeedbackDraft, FeedbackStoragePort} from '@fridge/platform-contracts';

export interface FeedbackStorageDriver {get(key: string): unknown; set(key: string, value: string): void;}
/** One host storage replacement keeps text/key/receipt together. */
export class SnapshotFeedbackStorage implements FeedbackStoragePort {
  static readonly key = 'fridge.feedback.v1';
  constructor(private driver: FeedbackStorageDriver) {}
  async load(): Promise<FeedbackDraft> {
    const raw = this.driver.get(SnapshotFeedbackStorage.key);
    if (raw === undefined || raw === null || raw === '') return {text:'',key:null,receipt:null};
    if (typeof raw !== 'string') throw new Error('FEEDBACK_DRAFT_INVALID');
    const value = JSON.parse(raw) as FeedbackDraft;
    if (!value || typeof value.text !== 'string' || value.text.length > 4000 ||
      !(value.key === null || typeof value.key === 'string' && /^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$/.test(value.key)) ||
      !(value.receipt === null || typeof value.receipt === 'string' && value.receipt.trim() && value.receipt.length <= 128)) {
      throw new Error('FEEDBACK_DRAFT_INVALID');
    }
    return {text:value.text,key:value.key,receipt:value.receipt};
  }
  async save(value: FeedbackDraft): Promise<void> {this.driver.set(SnapshotFeedbackStorage.key,JSON.stringify(value));}
}
