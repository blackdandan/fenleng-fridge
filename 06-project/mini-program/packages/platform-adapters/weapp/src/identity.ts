import Taro from '@tarojs/taro';
import { MiniIdentity } from '@fridge/api-client';
import type { IdentityConfig, IdentityDriver } from '@fridge/api-client';

export function createWeappIdentity(config: IdentityConfig, consent: boolean): MiniIdentity {
  if (!consent) throw new Error('loginCancelled');
  const driver: IdentityDriver = {
    getStorageSync: key => Taro.getStorageSync(key),
    setStorageSync: (key, value) => Taro.setStorageSync(key, value),
    removeStorageSync: key => Taro.removeStorageSync(key),
    request: input => Taro.request(input as Parameters<typeof Taro.request>[0]),
    // wx.login obtains a temporary code; it requests no profile/phone permissions.
    login: () => Taro.login({timeout: 10000}),
  };
  return new MiniIdentity(config, driver);
}
