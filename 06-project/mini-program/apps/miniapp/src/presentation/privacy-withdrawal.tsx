import {Text,View} from '@tarojs/components';
import {ActionButton,FridgeDialog,FridgePage} from '@fridge/ui-kit';
import {useFridge} from '../runtime';
export function PrivacyWithdrawalConfirmation() {
  const {controller,state,strings}=useFridge();
  if (!state.privacyWithdrawalRequested || state.stage!=='ready') return null;
  return <FridgeDialog><View className='fridge-consent'><Text className='fridge-dialog-title'>{strings.text('privacyWithdrawTitle')}</Text>
    <Text className='fridge-consent-body'>{strings.text('privacyWithdrawBody')}</Text>
    <View className='fridge-dialog-actions'>
      <ActionButton onClick={() => {void controller.withdraw();}}>{strings.text('privacyWithdrawConfirm')}</ActionButton>
      <ActionButton secondary onClick={controller.cancelPrivacyWithdrawal}>{strings.text('cancel')}</ActionButton>
    </View></View></FridgeDialog>;
}
export function PrivacyWithdrawalError() {
  const {controller,strings}=useFridge();
  return <FridgePage title={strings.text('privacy')} strings={strings}>
    <View className='fridge-initial-state fridge-consent'><Text className='fridge-dialog-title'>{strings.text('privacyWithdrawFailed')}</Text>
      <Text className='fridge-consent-body'>{strings.text('privacyWithdrawRetryBody')}</Text>
      <View className='fridge-dialog-actions'><ActionButton onClick={() => {void controller.withdraw();}}>{strings.text('retry')}</ActionButton></View>
      <View className='fridge-document-links'>{(['terms','privacy'] as const).map(document =>
        <ActionButton key={document} secondary onClick={() => controller.navigate({name:'legal',document})}>{strings.text(document)}</ActionButton>)}</View>
    </View></FridgePage>;
}
