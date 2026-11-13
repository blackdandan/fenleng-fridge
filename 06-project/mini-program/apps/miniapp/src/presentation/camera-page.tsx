import {useEffect, useRef, useState} from 'react';
import {Camera, CoverView, Picker, Text, View} from '@tarojs/components';
import {useDidHide, useDidShow} from '@tarojs/taro';
import {zones} from '@fridge/domain';
import {cameraGranted, openCameraSettings, requestCamera} from '@fridge/weapp';
import {ActionButton, CameraView, FridgeDialog} from '@fridge/ui-kit';
import {useFridge} from '../runtime';

export function CameraPage() {
  const {controller, state, strings} = useFridge();
  const [permission, setPermission] = useState<'checking' | 'explain' | 'denied' | 'granted'>('checking');
  const [ready, setReady] = useState(false);
  const [requesting, setRequesting] = useState(false);
  const [foreground, setForeground] = useState(true);
  const [discard, setDiscard] = useState(false);
  const active = useRef(true);
  useEffect(() => {
    void cameraGranted().then(granted => {if (active.current) setPermission(granted ? 'granted' : 'explain');})
      .catch(() => {if (active.current) setPermission('explain');});
    return () => {active.current = false;};
  }, []);
  useDidHide(() => {setForeground(false); setReady(false);});
  useDidShow(() => setForeground(true));
  if (!state.capture) return null;
  const capture = state.capture;
  async function authorize(settings = false) {
    if (requesting) return;
    setRequesting(true);
    try {
      const granted = await (settings ? openCameraSettings() : requestCamera());
      if (active.current) {setPermission(granted ? 'granted' : 'denied');controller.recordEvent('fridge.permission.resolved.v1',{permission:'camera',result:granted?'granted':'denied'});}
    } catch {if (active.current) {setPermission('denied');controller.recordEvent('fridge.permission.resolved.v1',{permission:'camera',result:'restricted'});}}
    finally {if (active.current) setRequesting(false);}
  }
  async function finish() {if (!await controller.finishCapture() && capture.pendingCount) setDiscard(true);}
  async function album() {setPermission(value => value === 'explain' ? 'denied' : value); await controller.album();}
  const preview = permission === 'granted' && foreground ? <>
    <Camera className='fridge-native-camera' mode='normal' devicePosition='back' flash='off' resolution='high'
      onInitDone={() => setReady(true)} onError={() => {setReady(false); setPermission('denied');}} />
    <CoverView className='fridge-camera-guide'><CoverView className='fridge-camera-guide-caption'>{strings.text('cameraSingleCaption')}</CoverView></CoverView>
  </> : null;
  const selector = <Picker mode='selector' range={zones.map(zone => strings.text(zone))} value={zones.indexOf(capture.zone)}
    disabled={state.busy || capture.busy} onChange={event => controller.selectCaptureZone(zones[Number(event.detail.value)])}>
    <View>{strings.text(capture.zone)}</View>
  </Picker>;
  return <>
    <CameraView strings={strings} capture={capture} preview={preview} selector={selector} ready={ready} permission={permission}
      busy={state.busy || requesting} errorKey={state.errorKey} onBack={() => void finish()} onFinish={() => void finish()}
      onAlbum={() => void album()} onCapture={controller.capture} onRetry={controller.retryCapture}
      onRequest={() => void authorize()} onSettings={() => void authorize(true)} onDecline={() => {
        setPermission('denied');controller.recordEvent('fridge.permission.resolved.v1',{permission:'camera',result:'cancelled'});
      }} />
    {discard && <FridgeDialog><Text>{strings.text('discardCapture')}</Text><View className='fridge-dialog-actions'>
      <ActionButton onClick={() => void controller.finishCapture(true)}>{strings.text('back')}</ActionButton>
      <ActionButton secondary onClick={() => setDiscard(false)}>{strings.text('cancel')}</ActionButton>
    </View></FridgeDialog>}
  </>;
}
