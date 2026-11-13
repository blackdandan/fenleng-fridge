import Taro from '@tarojs/taro';
import {zones, type StorageZone} from '@fridge/domain';
import {intervalFromText} from '@fridge/application';
import {SettingsChoices, SettingsView} from '@fridge/ui-kit';
import {useFridge} from '../runtime';
import {SubscriptionSettings} from './subscription-settings';

declare const FRIDGE_MINI_FILING: string;
export function SettingsPage() {
  const {state, controller, strings} = useFridge();
  async function save(raw: Record<StorageZone,string>, time: string): Promise<string> {
    const values: Partial<Record<StorageZone,number>> = {};
    for (const zone of zones) {const days = intervalFromText(raw[zone]); if (days === null) return 'invalidInterval'; values[zone] = days;}
    if (!/^([01][0-9]|2[0-3]):[0-5][0-9]$/.test(time)) return 'error';
    const [hour, minute] = time.split(':').map(Number);
    await controller.defaults(values,hour,minute);
    return controller.snapshot().errorKey || 'saved';
  }
  return <>
    <SettingsView inventory={state.inventory} strings={strings} busy={state.busy} errorKey={state.errorKey} subscription={<SubscriptionSettings />}
      language={state.locale ? strings.messages[state.locale]?.['_localeName'] || strings.locale : strings.text('system')}
      appearance={strings.text(state.theme)} filing={FRIDGE_MINI_FILING || strings.text('miniFilingPending')}
      onBack={controller.back} onSave={save} onHistory={() => controller.navigate({name:'history'})}
      onAccount={() => {void Taro.navigateTo({url:'/pages/account/index'});}}
      onLanguage={() => controller.navigate({name:'language'})} onAppearance={() => controller.navigate({name:'appearance'})}
      onLegal={document => controller.navigate({name:'legal',document})} onFeedback={() => controller.navigate({name:'feedback'})}
      onFiling={() => {void Taro.setClipboardData({data:'https://beian.miit.gov.cn'});}} />
  </>;
}
export function DisplayChoicesPage({appearance}: {appearance: boolean}) {
  const {state, controller, strings} = useFridge();
  const values = appearance ? ['system','light','dark'].map(id => ({id,label:strings.text(id)})) :
    [{id:'system',label:strings.text('system')},...Object.entries(strings.messages).map(([id,m]) => ({id,label:m['_localeName']}))];
  async function choose(id: string) {
    if (appearance) await controller.display(state.locale,id as 'system'|'light'|'dark');
    else await controller.display(id === 'system' ? null : id);
    if (!controller.snapshot().errorKey) controller.back();
  }
  return <SettingsChoices title={strings.text(appearance ? 'appearance' : 'language')} strings={strings}
    values={values} selected={appearance ? state.theme : state.locale || 'system'} busy={state.busy}
    errorKey={state.errorKey} onBack={controller.back} onSelect={id => {void choose(id);}} />;
}
