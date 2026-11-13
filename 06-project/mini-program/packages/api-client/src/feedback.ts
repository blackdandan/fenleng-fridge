import {TaroFeedbackSDK} from '@fenleng/sdk-taro';
import {FeedbackFailure, type FeedbackGatewayPort} from '@fridge/platform-contracts';
import type {MiniIdentity} from './identity';

export class MiniFeedbackGateway implements FeedbackGatewayPort {
  constructor(private identity: () => MiniIdentity | null, private consent: () => boolean) {}
  async submit(message: string, key: string): Promise<string> {
    if (!this.consent()) throw new FeedbackFailure('feedbackUnavailable');
    const identity = this.identity();
    if (!identity) throw new FeedbackFailure('feedbackUnavailable');
    try {
      if (!await identity.ensureSession()) throw new FeedbackFailure('feedbackSessionUnavailable');
    } catch {throw new FeedbackFailure('feedbackSessionUnavailable');}
    const active = identity.session.captureSession();
    if (!active() || !this.consent()) throw new FeedbackFailure('feedbackSessionUnavailable');
    const sdk = new TaroFeedbackSDK(identity.client,{projectId:'fenleng-fridge',version:'0.1.0+1'});
    let receipt;
    try {receipt = await sdk.submit(message,key);}
    catch (error) {
      if ((error as {status?: number})?.status === 401 && active()) {
        await identity.session.invalidate();
        throw new FeedbackFailure('feedbackSessionUnavailable');
      }
      throw error;
    }
    if (!active() || !this.consent()) throw new FeedbackFailure('feedbackUnavailable');
    return receipt.id;
  }
}
