import {useSyncExternalStore} from 'react';
import Taro from '@tarojs/taro';
import {Text,View} from '@tarojs/components';
import {ActionButton} from '@fridge/ui-kit';
import {useFridge} from '../runtime';

export function SubscriptionSettings() {
  const {runtime,strings}=useFridge(),session=runtime.online.reminders;
  const state=useSyncExternalStore(session.subscribe,session.snapshot,session.snapshot);
  const busy=['preparing','permission','cancelling'].includes(state.phase);
  const cancelFailed=state.errorKey==='miniCancelFailed';
  return <View>
    <Text className='fridge-settings-section'>{strings.text('miniSubscriptionTitle')}</Text>
    <View className='fridge-settings-card fridge-subscription-card'>
      <Text className='fridge-settings-hint'>{strings.text('miniSubscriptionHint')}</Text>
      {(state.errorKey || state.messageKey) && <View role='status'><Text className='fridge-settings-hint'>
        {strings.text(state.errorKey || state.messageKey!)}
      </Text></View>}
      <View className='fridge-subscription-actions'>
        {cancelFailed?<ActionButton disabled={busy} onClick={()=>{void session.cancel().catch(()=>{});}}>{strings.text('retry')}</ActionButton>:
          !state.enabled?<ActionButton disabled={busy} onClick={()=>{void session.enable();}}>{strings.text(busy?'loading':'miniEnable')}</ActionButton>:
          state.phase==='needs-login'?<ActionButton onClick={()=>{void Taro.navigateTo({url:'/pages/account/index'});}}>{strings.text('wechatLogin')}</ActionButton>:
          state.phase==='ready'?<ActionButton onClick={()=>{void session.requestPermission();}}>{strings.text('miniGrant')}</ActionButton>:
          <ActionButton disabled={busy} onClick={()=>{void session.refresh();}}>{strings.text(busy?'loading':'retry')}</ActionButton>}
        {state.enabled && <ActionButton secondary disabled={state.phase==='cancelling'} onClick={()=>{void session.cancel().catch(()=>{});}}>
          {strings.text('miniDisable')}
        </ActionButton>}
      </View>
    </View>
  </View>;
}
