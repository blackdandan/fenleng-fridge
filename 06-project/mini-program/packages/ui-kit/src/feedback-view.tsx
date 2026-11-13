import {Text, Textarea, View} from '@tarojs/components';
import {ActionButton, FridgePage} from './primitives';
import type {FridgeStrings} from './strings';
import './feedback.scss';

export function FeedbackView({strings,text,receipt,errorKey,loading,busy,initialized,onBack,onEdit,onSubmit,onRetry,onAnother}: {
  strings: FridgeStrings; text: string; receipt: string | null; errorKey: string | null;
  loading: boolean; busy: boolean; initialized: boolean;
  onBack: () => void; onEdit: (value: string) => void; onSubmit: () => void; onRetry: () => void; onAnother: () => void;
}) {
  const error = errorKey && <View className='fridge-feedback-error' role='alert'><Text>{strings.text(errorKey)}</Text></View>;
  return <FridgePage title={strings.text('feedback')} strings={strings} onBack={() => {if (!busy) onBack();}}>
    <View className='fridge-feedback'>
      {loading ? <Text>{strings.text('loading')}</Text> : !initialized ? <>
        {error}<ActionButton onClick={onRetry}>{strings.text('retry')}</ActionButton>
      </> : receipt ? <>
        <Text className='fridge-feedback-success'>{strings.text('feedbackAccepted')}</Text>
        <Text className='fridge-feedback-receipt' selectable>{strings.format('feedbackReceipt',{id:receipt})}</Text>
        <Text className='fridge-feedback-help'>{strings.text('feedbackAcceptedBody')}</Text>
        {error}<ActionButton secondary disabled={busy} onClick={onAnother}>{strings.text('feedbackWriteAnother')}</ActionButton>
      </> : <>
        <Text className='fridge-feedback-label'>{strings.text('feedbackSubject')}</Text>
        <Textarea className='fridge-feedback-input' placeholderClass='fridge-feedback-placeholder'
          aria-label={strings.text('feedbackSubject')} value={text} maxlength={4000} disabled={busy}
          placeholder={strings.text('feedbackPlaceholder')} onInput={event => onEdit(event.detail.value)} />
        <Text className='fridge-feedback-help'>{strings.text('feedbackPrivacy')}</Text>
        {error}<View className='fridge-feedback-actions'><ActionButton disabled={busy || !text.trim()} onClick={onSubmit}>
          {strings.text(busy ? 'loading' : errorKey ? 'feedbackRetrySubmit' : 'feedbackSubmit')}
        </ActionButton></View>
      </>}
    </View>
  </FridgePage>;
}
