import Taro from '@tarojs/taro';
import {SnapshotInventoryStorage, type InventoryStorageDriver} from './snapshot-storage';
export type {InventoryStorageDriver} from './snapshot-storage';

const nativeStorage: InventoryStorageDriver = {
  keys: () => Taro.getStorageInfoSync().keys,
  read: async key => (await Taro.getStorage<string>({key})).data,
  write: async (key, data) => {await Taro.setStorage({key, data});},
};
/** Native binding; snapshot and recovery logic is shared with deterministic tests. */
export class WeappInventoryStorage extends SnapshotInventoryStorage {
  constructor(driver: InventoryStorageDriver = nativeStorage) {super(driver);}
}
