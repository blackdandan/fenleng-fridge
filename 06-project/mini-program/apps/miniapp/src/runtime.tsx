import {createContext, useContext, useSyncExternalStore} from 'react';
import Taro from '@tarojs/taro';
import {FridgeController, InventoryRepository} from '@fridge/application';
import {WeappInventoryStorage, WeappMedia, WeappPreferences} from '@fridge/weapp';
import {FridgeStrings, type IconSources} from '@fridge/ui-kit';
import messages from './locales/messages.json';
import {OnlineRuntime} from './online-runtime';
import bell from './assets/icons/bell.svg';
import settings from './assets/icons/settings.svg';
import cold from './assets/icons/cold.svg';
import frozen from './assets/icons/frozen.svg';
import pantry from './assets/icons/pantry.svg';
import back from './assets/icons/back.svg';
import camera from './assets/icons/camera.svg';
import cameraBack from './assets/icons/camera-back.svg';
import album from './assets/icons/album.svg';
import chevronDown from './assets/icons/chevron-down.svg';
import calendar from './assets/icons/calendar.svg';
import editorChevron from './assets/icons/editor-chevron.svg';
import settingsCold from './assets/icons/settings-cold.svg';
import settingsFrozen from './assets/icons/settings-frozen.svg';
import settingsPantry from './assets/icons/settings-pantry.svg';
import clock from './assets/icons/clock.svg';

export const icons: IconSources = {bell, settings, cold, frozen, pantry, back, camera, cameraBack, album, chevronDown,
  calendar, editorChevron, settingsCold, settingsFrozen, settingsPantry, clock};
export interface Runtime {controller: FridgeController; online: OnlineRuntime; language: string; hostTop: number; systemTheme: 'light' | 'dark'; textScale: number;}
export function createRuntime(): Runtime {
  const window = Taro.getWindowInfo();
  const app = Taro.getAppBaseInfo();
  let hostTop = (window.statusBarHeight || 0) + 44;
  try {hostTop = Taro.getMenuButtonBoundingClientRect().bottom + 8;} catch { /* Standard native navbar fallback. */ }
  const controller = new FridgeController(new InventoryRepository(new WeappInventoryStorage()), new WeappPreferences(), new WeappMedia());
  return {controller, online:new OnlineRuntime(controller,app.language),
    language: app.language, hostTop, systemTheme: app.theme === 'dark' ? 'dark' : 'light',
    // This legacy host API supplies only the display font setting; no device
    // identifiers or returned object are retained or sent to analytics.
    textScale: Math.max(430 / window.windowWidth, (Taro.getSystemInfoSync().fontSizeSetting || 16) / 16)};
}
export const RuntimeContext = createContext<Runtime | null>(null);
export function useFridge() {
  const runtime = useContext(RuntimeContext);
  if (!runtime) throw new Error('FRIDGE_RUNTIME_REQUIRED');
  const state = useSyncExternalStore(runtime.controller.subscribe, runtime.controller.snapshot, runtime.controller.snapshot);
  const locale = FridgeStrings.resolve(Object.keys(messages), runtime.language, state.locale);
  return {runtime, controller: runtime.controller, state, strings: new FridgeStrings(messages, locale)};
}
