import type {InventoryState} from '@fridge/domain';
export * from './account-deletion';

export interface InventoryStoragePort {
  load(): Promise<InventoryState | null>;
  save(state: InventoryState): Promise<void>;
}
export interface CapturedPhoto { readonly persistentPath: string }
export interface MediaPort {
  chooseAlbum(maxCount?: number): Promise<readonly string[]>;
  chooseReplacement?(): Promise<string | null>;
  attachCamera(id: string): void;
  takePhoto(): Promise<string>;
  persist(temporaryPath: string): Promise<string>;
  removeManaged(path: string): Promise<void>;
  collectUnused?(retained: ReadonlySet<string>): Promise<void>;
}
export interface PrivacyRecord { readonly policyVersion: string; readonly acceptedAt: string }
export interface PreferencesPort {
  readWithdrawalPending?(): Promise<boolean>;
  beginWithdrawal?(): Promise<void>;
  finishWithdrawal?(): Promise<void>;
  readPrivacy(): Promise<PrivacyRecord | null>;
  writePrivacy(record: PrivacyRecord | null): Promise<void>;
  readDisplay(): Promise<{locale: string | null; theme: 'system' | 'light' | 'dark'}>;
  writeDisplay(value: {locale: string | null; theme: 'system' | 'light' | 'dark'}): Promise<void>;
}
export interface SubscriptionPort {
  request(templateIds: readonly string[]): Promise<Readonly<Record<string, 'accept' | 'reject' | 'ban' | 'filter'>>>;
}

export interface FeedbackDraft {readonly text: string; readonly key: string | null; readonly receipt: string | null;}
export interface FeedbackStoragePort {load(): Promise<FeedbackDraft>; save(value: FeedbackDraft): Promise<void>;}
export interface FeedbackGatewayPort {submit(message: string, idempotencyKey: string): Promise<string>;}
export class FeedbackFailure extends Error {
  constructor(readonly key: string) {super(key);}
}
