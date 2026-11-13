import {useEffect, useRef, useState,useSyncExternalStore} from 'react';
import {Text, View} from '@tarojs/components';
import Taro,{useDidHide,useDidShow} from '@tarojs/taro';
import {miniIdentityError, type MiniIdentity} from '@fridge/api-client';
import {ActionButton,AccountDeletionView, FridgePage} from '@fridge/ui-kit';
import {useFridge} from '../../runtime';
import {PageFrame} from '../../presentation/page-frame';
import './index.scss';

function AccountContent() {
  const {state, strings, runtime} = useFridge();
  const [identity, setIdentity] = useState<MiniIdentity | null>(null);
  const [signedIn, setSignedIn] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [confirming,setConfirming]=useState(false);
  const confirmResult=useRef<((accept:boolean)=>void)|null>(null);
  const updateIdentity=useRef<(()=>void)|null>(null);
  const active = useRef(false);
  const locked = useRef(false);
  const consent = state.stage === 'ready';
  const deletion=runtime.online.deletion;
  const deletionState=useSyncExternalStore(deletion.subscribe,deletion.snapshot,deletion.snapshot);
  const settleConfirmation=(accept:boolean)=>{
    const resolve=confirmResult.current;confirmResult.current=null;
    if(active.current)setConfirming(false);resolve?.(accept);
  };
  useDidHide(()=>{
    settleConfirmation(false);active.current=false;deletion.freeze();
    if(locked.current)identity?.cancelLogin();
  });
  useDidShow(()=>{
    active.current=true;if(!locked.current)setBusy(false);
    if(!confirmResult.current)setConfirming(false);updateIdentity.current?.();
  });
  useEffect(() => {
    active.current = true;
    let instance: MiniIdentity | undefined;
    let unsubscribe: (() => void) | undefined;
    if (consent) {
      setBusy(true);
      void runtime.online.ready().then(current => {
        if (!active.current) return;
        if (!current) {setError('loginNotConfigured');return;}
        instance = current;
        setIdentity(current);
        let ownerRevision=-1;
        const update = () => {
          if (!active.current) return;
          const snapshot = current.session.snapshot();
          const human=snapshot.status === 'authenticated' && snapshot.identityKind !== 'guest';
          setSignedIn(human);
          if(human && !snapshot.refreshing && ownerRevision!==current.revision){
            ownerRevision=current.revision;void deletion.refreshOwner();
          }
          if (snapshot.errorCode && !['accepted','unknown','submitting'].includes(deletion.snapshot().entry?.phase||''))setError(miniIdentityError({code:snapshot.errorCode}));
        };
        updateIdentity.current=update;unsubscribe = current.session.subscribe(update);update();
      }).catch(cause => {if (active.current) setError(miniIdentityError(cause));})
        .finally(() => {if (active.current) setBusy(false);});
    }
    void deletion.start();
    return () => {active.current = false;confirmResult.current?.(false);confirmResult.current=null;updateIdentity.current=null;deletion.freeze();unsubscribe?.();if (locked.current) instance?.cancelLogin();};
  }, [consent,runtime,deletion]);
  async function submit() {
    if (busy || locked.current || deletionState.busy) return;
    if (!identity) {setError('loginNotConfigured'); return;}
    locked.current = true; setBusy(true); setError(null);
    try {if (signedIn) await runtime.online.logout(); else {
      await runtime.online.login(()=>active.current);
      if(active.current)await deletion.refreshOwner(true);
    }}
    catch (cause) {if (active.current) setError(cause instanceof Error && cause.message==='miniCancelFailed'?'miniCancelFailed':miniIdentityError(cause));}
    finally {locked.current = false; if (active.current) setBusy(false);}
  }
  async function removeAccount(receiptOnly=false){
    if(busy || locked.current || deletionState.busy)return;
    locked.current=true;setBusy(true);setError(null);
    try {
      if(receiptOnly)await runtime.online.retryDeletionReceipt();
      else await runtime.online.deleteAccount(()=>{
        if(!active.current)return Promise.resolve(false);
        return new Promise<boolean>(resolve=>{confirmResult.current=resolve;setConfirming(true);});
      });
    }catch(cause){if(active.current)setError(miniIdentityError(cause));}
    finally{locked.current=false;if(active.current)setBusy(false);}
  }
  const incompleteReceipt=deletionState.entry?.phase==='accepted' && (!deletionState.durable || deletionState.cleanupPending);
  const loginWarning=!signedIn && ['accepted','unknown'].includes(deletionState.entry?.phase||'');
  return <FridgePage title={strings.text('account')} strings={strings} onBack={() => {settleConfirmation(false);deletion.freeze();void Taro.navigateBack();}}>
    <View className='account-content'>
      <Text className='account-status'>{strings.text(signedIn ? 'loggedIn' : 'guest')}</Text>
      <Text className='fridge-muted'>{strings.text('localOnly')}</Text>
      {loginWarning && <Text>{strings.text('deletionLoginRecovery')}</Text>}
      <ActionButton disabled={busy || deletionState.busy || incompleteReceipt} onClick={() => {void submit();}}>
        {strings.text(busy ? 'loading' : signedIn ? 'logout' : 'wechatLogin')}
      </ActionButton>
      {error && <View className='account-error' role='alert'><Text>{strings.text(error)}</Text></View>}
      <AccountDeletionView strings={strings} state={deletionState} signedIn={signedIn} disabled={busy} confirming={confirming}
        onSubmit={()=>{void removeAccount();}} onRetryReceipt={()=>{void removeAccount(true);}}
        onReload={()=>{void deletion.start();}} onConfirm={()=>settleConfirmation(true)} onCancel={()=>settleConfirmation(false)}/>
    </View>
  </FridgePage>;
}
export default function AccountPage() {return <PageFrame><AccountContent /></PageFrame>;}
