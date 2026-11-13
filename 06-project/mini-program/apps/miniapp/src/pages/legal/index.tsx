import {useEffect,useRef,useState} from 'react';
import Taro,{useRouter} from '@tarojs/taro';
import {WebView,Text} from '@tarojs/components';
import {ActionButton,FridgePage} from '@fridge/ui-kit';
import {useFridge} from '../../runtime';
import {PageFrame} from '../../presentation/page-frame';
import {isPrivacyWithdrawalMessage} from '@fridge/application';
export default function LegalWebPage() {
  const {controller,state,strings}=useFridge();
  const key=useRouter().params.document==='privacy' ? 'privacy' : 'terms';
  const nonce=useRef(`legal-${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`).current;
  const [failed,setFailed]=useState(false);
  const allowed=useRef(key==='privacy' && state.stage==='ready').current;
  useEffect(() => {void Taro.setNavigationBarTitle({title:strings.text(key)});},[key,strings.locale]);
  const src=`https://fridge.fenlengtech.com/${key}/?mini=1&withdraw=${allowed ? '1':'0'}&nonce=${encodeURIComponent(nonce)}&locale=${encodeURIComponent(strings.locale)}`;
  if (failed) return <PageFrame contentOnly><FridgePage title={strings.text(key)} strings={strings}>
    <Text>{strings.text('error')}</Text><ActionButton onClick={() => setFailed(false)}>{strings.text('retry')}</ActionButton>
    <ActionButton secondary onClick={() => {void Taro.navigateBack();}}>{strings.text('back')}</ActionButton>
  </FridgePage></PageFrame>;
  return <WebView src={src} onError={() => setFailed(true)} onMessage={event => {
    if (!allowed) return;
    if (isPrivacyWithdrawalMessage(event.detail.data,nonce)) controller.requestPrivacyWithdrawal();
  }} />;
}
