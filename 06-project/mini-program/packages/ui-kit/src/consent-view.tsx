import {Button, Text, View} from '@tarojs/components';
import {ActionButton, FridgeDialog, FridgePage} from './primitives';
import type {FridgeStrings} from './strings';
import './consent.scss';

export function ConsentView({strings, declined, busy, errorKey, onAccept, onDecline, onReconsider, onDocument}: {
  strings: FridgeStrings; declined: boolean; busy: boolean; errorKey: string | null;
  onAccept: () => void; onDecline: () => void; onReconsider: () => void; onDocument: (key: 'terms' | 'privacy') => void;
}) {
  return <>
    <FridgePage title={strings.text('home')} strings={strings}><Text className='fridge-welcome-caption'>{strings.text('localOnly')}</Text></FridgePage>
    <FridgeDialog><View className='fridge-consent'>
      <Text className='fridge-dialog-title'>{strings.text('consentTitle')}</Text>
      <Text className='fridge-consent-body fridge-consent-body--first'>{strings.text('consentBody')}</Text>
      <Text className='fridge-consent-body'>{strings.text('consentPermissions')}</Text>
      <View className='fridge-document-links'>
        <Button onClick={() => onDocument('terms')}>{strings.text('terms')}</Button>
        <Button onClick={() => onDocument('privacy')}>{strings.text('privacy')}</Button>
      </View>
      <View className='fridge-dialog-actions'>
        <ActionButton disabled={busy} onClick={declined ? onReconsider : onAccept}>{strings.text(busy ? 'loading' : declined ? 'retry' : 'agree')}</ActionButton>
        {!declined && <ActionButton secondary disabled={busy} onClick={onDecline}>{strings.text('decline')}</ActionButton>}
      </View>
      {errorKey && <Text className='fridge-inline-error'>{strings.text(errorKey)}</Text>}
    </View></FridgeDialog>
  </>;
}
