import {Text,View} from '@tarojs/components';
import {deletionInstantMillis,type AccountDeletionSnapshot} from '@fridge/application';
import {ActionButton,FridgeDialog} from './primitives';
import type {FridgeStrings} from './strings';
import './account-deletion.scss';

export function AccountDeletionView({strings,state,signedIn,disabled=false,confirming,onSubmit,onRetryReceipt,onReload,onConfirm,onCancel}: {
  strings:FridgeStrings;state:AccountDeletionSnapshot;signedIn:boolean;disabled?:boolean;confirming:boolean;
  onSubmit:()=>void;onRetryReceipt:()=>void;onReload:()=>void;onConfirm:()=>void;onCancel:()=>void;
}){
  const {entry,busy,loading,initialized,durable,errorKey}=state;
  const accepted=entry?.phase==='accepted',unknown=entry?.phase==='unknown';
  const receipt=entry?.receipt;
  const error=accepted && !durable?'deletionUnsaved':unknown && errorKey==='deletionUnknown'?null:errorKey;
  const retryReceipt=accepted && (!durable || state.cleanupPending || errorKey==='deletionCleanupFailed' || errorKey==='deletionStorageFailed');
  return <>
    <View className='fridge-deletion' aria-busy={busy || loading}>
      <Text className='fridge-deletion-title'>{strings.text('deletionTitle')}</Text>
      {loading?<Text>{strings.text('loading')}</Text>:<>
        {entry && <View className='fridge-deletion-record' aria-live='polite'>
          <Text className='fridge-deletion-meta'>{strings.text('deletionLocalRecord')}</Text>
          {accepted && <Text className='fridge-deletion-status'>{strings.text('deletionPending')}</Text>}
          {entry.phase==='cancelled' && <Text className='fridge-deletion-status'>{strings.text(receipt?'deletionRestored':'deletionLoginResolved')}</Text>}
          {unknown && <Text className='fridge-deletion-notice'>{strings.text('deletionUnknown')}</Text>}
          {receipt && <>
            <Text className='fridge-deletion-time'>{strings.format('deletionRequestedAt',{time:strings.timestamp(deletionInstantMillis(receipt.requestedAt))})}</Text>
            {accepted && <Text className='fridge-deletion-time'>{strings.format('deletionEligibleAt',{time:strings.timestamp(deletionInstantMillis(receipt.eligibleAt))})}</Text>}
          </>}
          {accepted && <Text>{strings.text('deletionWaitingHint')}</Text>}
        </View>}
        {!accepted && !unknown && <Text>{strings.text('deletionBody')}</Text>}
        {error && <View className='fridge-deletion-error' role='alert'><Text>{strings.text(error)}</Text></View>}
        {busy && !confirming && <View role='status'><Text>{strings.text('deletionProcessing')}</Text></View>}
        {!initialized?<ActionButton secondary disabled={busy || disabled} onClick={onReload}>{strings.text('retry')}</ActionButton>:
          retryReceipt?<ActionButton disabled={busy || disabled} onClick={onRetryReceipt}>{strings.text(busy?'deletionProcessing':'deletionRetryReceipt')}</ActionButton>:
          signedIn && !accepted?<View className='fridge-deletion-start'><ActionButton secondary disabled={busy || disabled} onClick={onSubmit}>
            {strings.text(busy?'deletionProcessing':unknown?'deletionRetry':'deletionTitle')}
          </ActionButton></View>:!signedIn && !accepted && !unknown?<Text className='fridge-deletion-meta'>{strings.text('deletionLoginRequired')}</Text>:null}
      </>}
    </View>
    {confirming && <FridgeDialog label={strings.text('deletionTitle')} className='fridge-deletion-dialog'>
      <View className='fridge-deletion-confirm'>
        <Text className='fridge-deletion-title'>{strings.text('deletionTitle')}</Text>
        <Text>{strings.text('deletionBody')}</Text>
        <View className='fridge-deletion-confirm-actions'>
          <ActionButton secondary onClick={onCancel}>{strings.text('cancel')}</ActionButton>
          <View className='fridge-deletion-start'><ActionButton secondary onClick={onConfirm}>{strings.text('deletionConfirmAction')}</ActionButton></View>
        </View>
      </View>
    </FridgeDialog>}
  </>;
}
