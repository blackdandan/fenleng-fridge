import Taro from '@tarojs/taro';
import {SnapshotPreferences, type PreferencesDriver} from './snapshot-preferences';

const native: PreferencesDriver = {
  keys: () => Taro.getStorageInfoSync().keys,
  read: key => Taro.getStorageSync(key),
  write: async (key,data) => {await Taro.setStorage({key,data});},
  remove: async key => {await Taro.removeStorage({key});},
};
export class WeappPreferences extends SnapshotPreferences {
  constructor(driver: PreferencesDriver = native) {super(driver);}
}
