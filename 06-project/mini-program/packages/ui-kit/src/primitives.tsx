import {createContext, useContext, useEffect, useState, type PropsWithChildren, type ReactNode} from 'react';
import {Button, Image, Text, View} from '@tarojs/components';
import type {FridgeStrings} from './strings';
import './theme.scss';

export type IconName = 'bell' | 'settings' | 'cold' | 'frozen' | 'pantry' | 'back' | 'camera' | 'cameraBack' | 'album' | 'chevronDown' |
  'calendar' | 'editorChevron' | 'settingsCold' | 'settingsFrozen' | 'settingsPantry' | 'clock';
export type IconSources = Readonly<Record<IconName, string>>;
const AssetContext = createContext<IconSources | null>(null);
export function FridgeAssets({icons, children}: PropsWithChildren<{icons: IconSources}>) {
  return <AssetContext.Provider value={icons}>{children}</AssetContext.Provider>;
}
export function FridgeIcon({name}: {name: IconName}) {
  const sources = useContext(AssetContext);
  if (!sources?.[name]) throw new Error('ICON_ASSET_MISSING:' + name);
  return <Image className={`fridge-icon fridge-icon--${name}`} src={sources[name]} mode='aspectFit' aria-hidden />;
}
export function FridgePage({title, strings, onBack, actions, children, count, backIcon = 'back'}: PropsWithChildren<{
  title: string; strings: FridgeStrings; onBack?: () => void; actions?: ReactNode; count?: string; backIcon?: IconName;
}>) {
  return <View className={`fridge-page ${onBack ? 'fridge-page--back' : ''}`}>
    <View className={`fridge-header ${onBack ? 'fridge-header--back' : ''}`}>
      {onBack && <Button className='fridge-back' aria-label={strings.text('back')} onClick={onBack} hoverClass='fridge-pressed'><FridgeIcon name={backIcon} /></Button>}
      <Text className='fridge-title'>{title}</Text>
      {count && <Text className='fridge-muted fridge-count'>{count}</Text>}
      {actions && <View className='fridge-header-actions'>{actions}</View>}
    </View>
    {children}
  </View>;
}
export function HeaderAction({name, label, onClick, badge = false}: {name: IconName; label: string; onClick: () => void; badge?: boolean}) {
  return <Button className='fridge-header-button' aria-label={label} onClick={onClick} hoverClass='fridge-pressed'>
    <View className='fridge-header-circle'><FridgeIcon name={name} />{badge && <View className='fridge-badge' />}</View>
  </Button>;
}
export function ActionButton({children, onClick, secondary = false, disabled = false, icon}: PropsWithChildren<{
  onClick: () => void; secondary?: boolean; disabled?: boolean; icon?: IconName;
}>) {
  return <Button className={`fridge-action ${secondary ? 'fridge-action--secondary' : ''}`}
    disabled={disabled} onClick={onClick} hoverClass='fridge-pressed'>
    {icon && <FridgeIcon name={icon} />}<Text>{children}</Text>
  </Button>;
}
export function FridgeDialog({children, top = false, className = '', label}: PropsWithChildren<{top?: boolean; className?: string; label?: string}>) {
  return <View className={`fridge-overlay ${top ? 'fridge-overlay--top' : ''}`}>
    <View className={`fridge-dialog ${className}`} role='dialog' aria-label={label}>{children}</View>
  </View>;
}

export function RoundPhoto({src, className = '', errorLabel}: {src: string; className?: string; errorLabel: string}) {
  const [failed, setFailed] = useState(false);
  useEffect(() => {setFailed(false);}, [src]);
  return <View className={`fridge-round-photo ${className}`} aria-label={failed ? errorLabel : undefined}>
    <View className='fridge-square-spacer' />
    {failed ? <View className='fridge-square-content fridge-photo-error'><Text>{errorLabel}</Text></View> :
      <Image className='fridge-square-image' src={src} mode='aspectFill' onError={() => setFailed(true)} />}
  </View>;
}
