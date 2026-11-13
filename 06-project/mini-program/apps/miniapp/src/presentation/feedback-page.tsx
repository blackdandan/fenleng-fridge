import {useEffect, useSyncExternalStore} from 'react';
import {FeedbackView} from '@fridge/ui-kit';
import {useFridge} from '../runtime';

export function FeedbackPage() {
  const {runtime,controller,strings} = useFridge();
  const session = runtime.online.feedback;
  const state = useSyncExternalStore(session.subscribe,session.snapshot,session.snapshot);
  useEffect(() => {void session.start();},[session]);
  return <FeedbackView strings={strings} text={state.text} receipt={state.receipt} errorKey={state.errorKey}
    loading={state.loading} busy={state.busy} initialized={state.initialized} onBack={controller.back}
    onEdit={value => {void session.edit(value);}} onSubmit={() => {void session.submit();}}
    onRetry={() => {void session.start();}} onAnother={() => {void session.writeAnother();}} />;
}
