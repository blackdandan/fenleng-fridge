import {FeedbackFailure, type FeedbackDraft, type FeedbackStoragePort, type FeedbackGatewayPort} from '@fridge/platform-contracts';
import {emitProductEvent,type ProductEventSink} from './product-events';

export interface FeedbackSnapshot extends FeedbackDraft {
  readonly loading: boolean; readonly busy: boolean; readonly initialized: boolean; readonly errorKey: string | null;
}
/** Persistence precedes the write; only a durable receipt clears the draft. */
export class FeedbackSession {
  private value: FeedbackSnapshot = {text:'',key:null,receipt:null,loading:true,busy:false,initialized:false,errorKey:null};
  private listeners = new Set<() => void>();
  private starting: Promise<void> | null = null;
  private submission: Promise<void> | null = null;
  private writes: Promise<void> = Promise.resolve();
  private closed = false;
  private revision = 0;
  constructor(private storage: FeedbackStoragePort, private gateway: FeedbackGatewayPort,
    private consent: () => boolean, private nextKey: () => string,private events:ProductEventSink=()=>{}) {}
  snapshot = (): FeedbackSnapshot => this.value;
  subscribe = (listener: () => void): (() => void) => {this.listeners.add(listener);return () => this.listeners.delete(listener);};
  private publish(change: Partial<FeedbackSnapshot>): void {
    this.value = {...this.value,...change};
    if (!this.closed) this.listeners.forEach(listener => listener());
  }
  start(): Promise<void> {
    if (this.closed || this.value.initialized) return Promise.resolve();
    if (this.starting) return this.starting;
    this.starting = Promise.resolve().then(async () => {
      try {
        if (!this.consent()) throw new FeedbackFailure('feedbackUnavailable');
        const draft = await this.storage.load();
        this.publish({...draft,initialized:true});
      } catch {this.publish({errorKey:'feedbackDraftLoadFailed'});}
      finally {this.publish({loading:false});}
    }).finally(() => {this.starting = null;});
    this.publish({loading:true,errorKey:null});
    return this.starting;
  }
  private persist(value: FeedbackDraft): Promise<void> {
    const pending = this.writes.then(() => this.storage.save(value));
    this.writes = pending.catch(() => {});
    return pending;
  }
  async edit(text: string): Promise<void> {
    const current = this.value;
    if (this.closed || !this.consent() || !current.initialized || current.busy || current.receipt || text === current.text) return;
    const key = text.trim() === current.text.trim() ? current.key : null;
    const revision = ++this.revision;
    this.publish({text,key,errorKey:null});
    try {await this.persist({text,key,receipt:null});}
    catch {if (revision === this.revision && !this.value.busy) this.publish({errorKey:'feedbackDraftSaveFailed'});}
  }
  submit(): Promise<void> {
    if (this.closed || !this.value.initialized || this.value.receipt) return Promise.resolve();
    if (this.value.busy) return this.submission || Promise.resolve();
    const message = this.value.text.trim();
    if (!message || message.length > 4000) {this.publish({errorKey:'feedbackValidation'});return Promise.resolve();}
    this.publish({busy:true,errorKey:null});
    this.submission = Promise.resolve().then(async () => {
      try {
        this.requireConsent();
        const key = this.value.key || this.nextKey();
        this.publish({key});
        await this.saveOrFail({text:this.value.text,key,receipt:null});
        this.requireConsent();
        const receipt = await this.gateway.submit(message,key);
        this.requireConsent();
        if (!receipt.trim() || receipt.length > 128) throw new FeedbackFailure('feedbackFailed');
        await this.saveOrFail({text:'',key:null,receipt});
        this.publish({text:'',key:null,receipt,errorKey:null});
        this.event('success');
      } catch (error) {
        const key=error instanceof FeedbackFailure?error.key:null;
        this.event(key==='feedbackDraftSaveFailed'?'storage_failed':
          key==='feedbackSessionUnavailable' || key==='feedbackUnavailable'?'identity_unavailable':
          ['NETWORK_ERROR','REQUEST_TIMEOUT'].includes((error as {code?:string})?.code || '')?'network_failed':'submit_failed');
        this.publish({errorKey:key || 'feedbackFailed'});
      }
      finally {this.publish({busy:false});}
    }).finally(() => {this.submission = null;});
    return this.submission;
  }
  private requireConsent(): void {
    if (this.closed || !this.consent()) throw new FeedbackFailure('feedbackUnavailable');
  }
  private event(result:string):void {if(!this.closed && this.consent())emitProductEvent(this.events,'fridge.feedback.submitted.v1',{result});}
  private async saveOrFail(value: FeedbackDraft): Promise<void> {
    try {await this.persist(value);} catch {throw new FeedbackFailure('feedbackDraftSaveFailed');}
  }
  async writeAnother(): Promise<void> {
    if (this.closed || !this.consent() || this.value.busy || !this.value.receipt) return;
    this.publish({busy:true,errorKey:null});
    try {await this.saveOrFail({text:'',key:null,receipt:null});this.publish({text:'',key:null,receipt:null});}
    catch {this.publish({errorKey:'feedbackDraftSaveFailed'});}
    finally {this.publish({busy:false});}
  }
  async close(): Promise<void> {
    this.closed = true;this.listeners.clear();
    await this.starting;await this.submission;await this.writes;
  }
}
