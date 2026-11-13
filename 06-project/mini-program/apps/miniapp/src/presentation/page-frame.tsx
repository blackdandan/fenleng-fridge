import {useEffect, useState, type PropsWithChildren} from 'react';
import Taro from '@tarojs/taro';
import {Text, View} from '@tarojs/components';
import {ActionButton, ConsentView, FridgeAssets, FridgePage, fridgeTokens} from '@fridge/ui-kit';
import {icons, useFridge} from '../runtime';
import {LegalPage} from './legal-page';
import {PrivacyWithdrawalError} from './privacy-withdrawal';

export function PageFrame({children,contentOnly=false}: PropsWithChildren<{contentOnly?:boolean}>) {
  const {runtime, controller, state, strings} = useFridge();
  const [systemTheme, setSystemTheme] = useState(runtime.systemTheme);
  const theme = state.theme === 'system' ? systemTheme : state.theme;
  const camera = state.stage === 'ready' && state.route.name === 'camera';
  useEffect(() => {
    const handler: Taro.onThemeChange.Callback = result => setSystemTheme(result.theme);
    Taro.onThemeChange(handler);
    return () => Taro.offThemeChange(handler);
  }, []);
  useEffect(() => {
    const palette = theme === 'dark' ? fridgeTokens.darkColors : fridgeTokens.colors;
    void Taro.setNavigationBarColor({frontColor: camera || theme === 'dark' ? '#ffffff' : '#000000',
      backgroundColor: camera ? fridgeTokens.colors.camera : palette.page});
  }, [camera, theme]);
  const style = `--fridge-host-top:${runtime.hostTop}px;--fridge-text-scale:${runtime.textScale};direction:${strings.rtl ? 'rtl' : 'ltr'}`;
  let content = children;
  if (contentOnly) content=children;
  else if (state.route.name === 'legal') content = <LegalPage />;
  else if (state.stage === 'consent' || state.stage === 'declined') content = <ConsentView strings={strings} declined={state.stage === 'declined'}
    busy={state.busy} errorKey={state.errorKey} onAccept={controller.accept} onDecline={controller.decline} onReconsider={controller.reconsider}
    onDocument={key => controller.navigate({name: 'legal', document: key})} />;
  else if (state.stage === 'withdrawal-error') content = <PrivacyWithdrawalError />;
  else if (state.stage !== 'ready') content = <FridgePage title={strings.text('home')} strings={strings}><View className='fridge-initial-state'>
    <Text>{strings.text(state.stage === 'loading' || state.stage === 'withdrawing' ? 'loading' : 'error')}</Text>
    {state.stage === 'error' && <ActionButton onClick={() => void controller.initialize()}>{strings.text('retry')}</ActionButton>}
  </View></FridgePage>;
  return <FridgeAssets icons={icons}><View className={`fridge-theme fridge-theme--${theme} fridge-app ${camera ? 'fridge-app--camera' : ''}`}
    style={style} data-rtl={strings.rtl}>{content}</View></FridgeAssets>;
}
