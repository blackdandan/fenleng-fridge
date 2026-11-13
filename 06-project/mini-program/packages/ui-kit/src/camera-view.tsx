import type {ReactNode} from 'react';
import {Button, Text, View} from '@tarojs/components';
import type {CaptureSnapshot} from '@fridge/application';
import {ActionButton, FridgeDialog, FridgeIcon, FridgePage} from './primitives';
import type {FridgeStrings} from './strings';
import './camera.scss';

export function CameraView({strings, capture, preview, selector, ready, permission, busy, errorKey,
  onBack, onCapture, onAlbum, onRetry, onRequest, onSettings, onDecline, onFinish}: {
  strings: FridgeStrings; capture: CaptureSnapshot; preview: ReactNode; selector: ReactNode;
  ready: boolean; permission: 'checking' | 'explain' | 'denied' | 'granted'; busy: boolean; errorKey: string | null;
  onBack: () => void; onCapture: () => void; onAlbum: () => void; onRetry: () => void;
  onRequest: () => void; onSettings: () => void; onDecline: () => void; onFinish: () => void;
}) {
  const locked = busy || capture.busy || capture.pendingCount > 0;
  return <View className='fridge-camera'><FridgePage title={strings.text('add')} strings={strings} onBack={onBack} backIcon='cameraBack'>
    <Text className='fridge-camera-local'>{strings.text('localOnly')}</Text>
    <View className='fridge-camera-selector'>{selector}<FridgeIcon name='chevronDown' /></View>
    <View className='fridge-camera-preview'><View className='fridge-square-spacer' />
      <View className='fridge-camera-native'>{preview}</View>
      {permission !== 'granted' && <View className='fridge-camera-unavailable'><Text>{strings.text(permission === 'checking' ? 'loading' : 'cameraUnavailable')}</Text>
        {permission === 'denied' && <ActionButton secondary onClick={onSettings}>{strings.text('openSettings')}</ActionButton>}</View>}
    </View>
    <View className='fridge-camera-controls'>
      <Button className='fridge-camera-album' onClick={onAlbum} disabled={locked}><FridgeIcon name='album' /><Text>{strings.text('album')}</Text></Button>
      <Button className='fridge-shutter' aria-label={strings.text('captureNow')} disabled={locked || !ready} onClick={onCapture} />
      <View className='fridge-camera-count'><Text>{strings.text('capturedLabel')}</Text><Text>{strings.format('recordCountShort',{count: capture.savedCount})}</Text></View>
    </View>
    {capture.pendingCount > 0 && <ActionButton secondary disabled={busy} onClick={onRetry}>{strings.text('retry')}</ActionButton>}
    {busy && <Text className='fridge-camera-caption'>{strings.text('loading')}</Text>}
    {errorKey && <Text className='fridge-inline-error'>{strings.text(errorKey)}</Text>}
    <Text className='fridge-camera-caption'>{strings.text('cameraHint')}</Text>
    <View className='fridge-camera-finish'><ActionButton secondary disabled={locked} onClick={onFinish}>{strings.text('done')}</ActionButton></View>
  </FridgePage>
    {permission === 'explain' && <FridgeDialog top><Text className='fridge-dialog-title'>{strings.text('permissionTitle')}</Text>
      <Text className='fridge-consent-body'>{strings.text('permissionBody')}</Text><View className='fridge-dialog-actions'>
        <ActionButton disabled={busy} onClick={onRequest}>{strings.text('continueRequest')}</ActionButton>
        <ActionButton secondary disabled={busy} onClick={onAlbum}>{strings.text('album')}</ActionButton>
        <ActionButton secondary disabled={busy} onClick={onDecline}>{strings.text('notNow')}</ActionButton>
      </View></FridgeDialog>}
  </View>;
}
