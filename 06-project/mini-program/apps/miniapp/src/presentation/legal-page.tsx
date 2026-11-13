import {useEffect,useState} from 'react';
import Taro from '@tarojs/taro';
import {RichText, View,Text} from '@tarojs/components';
import {FridgePage,ActionButton} from '@fridge/ui-kit';
import {PrivacyWithdrawalConfirmation} from './privacy-withdrawal';
import {useFridge} from '../runtime';
import documents from '../legal/documents.json';
declare const FRIDGE_LEGAL_WEB_ENABLED: boolean;

export function LegalPage() {
  const {controller, state, strings} = useFridge();
  const [failed,setFailed]=useState(false);
  const key=state.route.name==='legal' ? state.route.document : 'terms';
  const open=() => {setFailed(false);void Taro.navigateTo({url:`/pages/legal/index?document=${key}`}).catch(() => setFailed(true));};
  useEffect(() => {if (FRIDGE_LEGAL_WEB_ENABLED && state.route.name==='legal') open();},[key]);
  if (state.route.name !== 'legal') return null;
  return <><FridgePage title={strings.text(key)} strings={strings} onBack={controller.back}>
    {FRIDGE_LEGAL_WEB_ENABLED ? <View className='fridge-offline-legal'>
      {failed && <Text className='fridge-inline-error'>{strings.text('error')}</Text>}
      <ActionButton onClick={open}>{strings.text(key)}</ActionButton>
    </View> : <View className='fridge-offline-legal'><RichText nodes={documents[key].html} userSelect />
      {key==='privacy' && state.stage==='ready' && <ActionButton secondary onClick={controller.requestPrivacyWithdrawal}>{strings.text('privacyWithdrawLink')}</ActionButton>}
    </View>}
  </FridgePage><PrivacyWithdrawalConfirmation /></>;
}
