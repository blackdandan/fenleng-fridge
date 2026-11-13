import type {MiniIdentity} from './identity';

export interface ConsentSource {snapshot(): {stage: string}; subscribe(listener: () => void): () => void;}
/** A single owner serializes consent epochs and all token-storage cleanup. */
export class MiniIdentityOwner {
  identity: MiniIdentity | null = null;
  private tail: Promise<void> = Promise.resolve();
  private wasReady = false;
  private epoch = 0;
  private closed = false;
  private unsubscribe: () => void;
  constructor(source: ConsentSource, enabled: boolean, create: () => MiniIdentity) {
    const consent = () => !this.closed && source.snapshot().stage === 'ready';
    const update = () => {
      const ready = consent();
      if (ready === this.wasReady) return;
      this.wasReady = ready;
      const epoch = ++this.epoch,previous = this.identity;
      const revoking = !ready && previous ? (() => {
        previous.cancelLogin();previous.session.suspend();
        const pending=previous.session.withdrawConsent();void pending.catch(() => {});return pending;
      })() : null;
      if (!ready) this.identity = null;
      this.tail = this.tail.then(async () => {
        if (!ready) {
          try {await revoking;} finally {await previous?.close();}
          return;
        }
        if (epoch !== this.epoch || !consent() || !enabled) return;
        this.identity = create();
        await this.identity.ensureSession();
      }).catch(() => {});
    };
    this.unsubscribe = source.subscribe(update);update();
  }
  async ready(): Promise<MiniIdentity | null> {await this.tail;return this.identity;}
  resume(): void {void this.identity?.session.resume().catch(() => {});}
  suspend(): void {this.identity?.session.suspend();}
  async close(): Promise<void> {
    this.closed = true;this.unsubscribe();
    await this.tail;await this.identity?.close();
  }
}
