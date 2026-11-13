import {useState,type ReactNode} from 'react';
import {Button, Input, Picker, Text, View} from '@tarojs/components';
import {zones, type InventoryState, type StorageZone} from '@fridge/domain';
import {ActionButton, FridgeIcon, FridgePage, type IconName} from './primitives';
import type {FridgeStrings} from './strings';
import './settings.scss';

function SettingsLink({title, value, hint, disabled, onClick}: {
  title: string; value?: string; hint?: string; disabled: boolean; onClick: () => void;
}) {
  return <Button className='fridge-settings-link' disabled={disabled} onClick={onClick}>
    <View className='fridge-settings-link-title'><Text>{title}</Text>{hint && <Text className='fridge-settings-row-hint'>{hint}</Text>}</View>
    {value && <Text className='fridge-settings-value'>{value}</Text>}<Text className='fridge-settings-arrow' aria-hidden>↗︎</Text>
  </Button>;
}
export function SettingsView({inventory, strings, busy, errorKey, language, appearance, filing,subscription,
  onBack, onSave, onHistory, onAccount, onLanguage, onAppearance, onLegal, onFeedback, onFiling}: {
  inventory: InventoryState; strings: FridgeStrings; busy: boolean; errorKey: string | null;
  subscription?:ReactNode;
  language: string; appearance: string; filing: string; onBack: () => void;
  onSave: (raw: Record<StorageZone, string>, time: string) => Promise<string>;
  onHistory: () => void; onAccount: () => void; onLanguage: () => void; onAppearance: () => void;
  onLegal: (document: 'terms' | 'privacy') => void; onFeedback: () => void; onFiling: () => void;
}) {
  const [values, setValues] = useState(() => Object.fromEntries(zones.map(z => [z, String(inventory.defaults[z])])) as Record<StorageZone, string>);
  const [time, setTime] = useState(`${String(inventory.reminderHour).padStart(2,'0')}:${String(inventory.reminderMinute).padStart(2,'0')}`);
  const [status, setStatus] = useState<string | null>(null);
  const icon: Record<StorageZone, IconName> = {cold: 'settingsCold', frozen: 'settingsFrozen', pantry: 'settingsPantry'};
  return <FridgePage title={strings.text('settings')} strings={strings} onBack={onBack}>
    <Text className='fridge-settings-section'>{strings.text('settingsDefaultsTitle')}</Text>
    <View className='fridge-settings-card'>
      {zones.map(zone => <View className='fridge-settings-default' key={zone}>
        <View className='fridge-settings-zone'><FridgeIcon name={icon[zone]} /><Text>{strings.text(zone)}</Text></View>
        <View className='fridge-settings-number-wrap'><Input type='number' className='fridge-settings-number' disabled={busy}
          value={values[zone]} cursorSpacing={24} aria-label={`${strings.text(zone)} · ${strings.text('interval')}`}
          onInput={e => {setValues({...values, [zone]: e.detail.value}); setStatus(null);}} /><Text>{strings.text('daysUnit')}</Text></View>
      </View>)}
      <View className='fridge-settings-time-row'>
        <View className='fridge-settings-link-title'><Text>{strings.text('reminderTime')}</Text><Text className='fridge-settings-row-hint'>{strings.text('reminderRule')}</Text></View>
        <Picker mode='time' value={time} disabled={busy} onChange={e => {setTime(e.detail.value); setStatus(null);}}>
          <View className='fridge-settings-time' aria-label={strings.text('reminderTime')}><Text>{time}</Text><FridgeIcon name='clock' /></View>
        </Picker>
      </View>
    </View>
    <Text className='fridge-settings-hint'>{strings.text('defaultsHint')}</Text>
    <View className='fridge-settings-save'><ActionButton disabled={busy} onClick={() => {void onSave(values,time).then(setStatus).catch(() => setStatus('error'));}}>{strings.text(busy ? 'loading' : 'saveDefaults')}</ActionButton></View>
    <View className={`fridge-settings-status ${status === 'saved' ? 'fridge-settings-status--saved' : ''}`} role='alert'>
      {(status || errorKey) && <Text>{strings.text(status || errorKey!)}</Text>}
    </View>
    {subscription}
    <Text className='fridge-settings-section'>{strings.text('localRecordsTitle')}</Text>
    <View className='fridge-settings-card'>
      <SettingsLink title={strings.text('history')} hint={strings.text('historyDescription')} disabled={busy} onClick={onHistory} />
      <SettingsLink title={strings.text('account')} disabled={busy} onClick={onAccount} />
    </View>
    <Text className='fridge-settings-hint'>{strings.text('localOnly')}</Text>
    <Text className='fridge-settings-section'>{strings.text('displaySettingsTitle')}</Text>
    <View className='fridge-settings-card'>
      <SettingsLink title={strings.text('language')} value={language} disabled={busy} onClick={onLanguage} />
      <SettingsLink title={strings.text('appearance')} value={appearance} disabled={busy} onClick={onAppearance} />
    </View>
    <Text className='fridge-settings-section'>{strings.text('agreementsHelp')}</Text>
    <View className='fridge-settings-card fridge-settings-legal'>
      <SettingsLink title={strings.text('terms')} disabled={busy} onClick={() => onLegal('terms')} />
      <SettingsLink title={strings.text('privacy')} disabled={busy} onClick={() => onLegal('privacy')} />
      <SettingsLink title={strings.text('feedback')} disabled={busy} onClick={onFeedback} />
    </View>
    <Button className='fridge-settings-filing' disabled={busy} onClick={onFiling}>{filing}</Button>
  </FridgePage>;
}
export function SettingsChoices({title, values, selected, busy, errorKey, strings, onBack, onSelect}: {
  title: string; values: readonly {id: string; label: string}[]; selected: string; busy: boolean;
  errorKey: string | null; strings: FridgeStrings; onBack: () => void; onSelect: (id: string) => void;
}) {
  return <FridgePage title={title} strings={strings} onBack={onBack}>
    {errorKey && <View role='alert'><Text>{strings.text(errorKey)}</Text></View>}
    <View className='fridge-settings-card fridge-settings-choices'>{values.map(value => <Button className='fridge-settings-link'
      key={value.id} disabled={busy} aria-pressed={selected === value.id} onClick={() => onSelect(value.id)}>
      <Text>{value.label}</Text>{selected === value.id && <Text aria-hidden>✓</Text>}
    </Button>)}</View>
  </FridgePage>;
}
