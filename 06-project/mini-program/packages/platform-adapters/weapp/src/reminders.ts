import Taro from '@tarojs/taro';
import {createMiniReminderClient,cancelStoredMiniReminders,type IdentityConfig,type MiniReminderDriver} from '@fridge/api-client';
import {requestSubscriptionFromGesture} from './subscription-permission';

function driver(consent:()=>boolean):MiniReminderDriver {return {
    getStorageSync:key=>Taro.getStorageSync(key),
    setStorageSync:(key,value)=>Taro.setStorageSync(key,value),
    removeStorageSync:key=>Taro.removeStorageSync(key),
    request:input=>{
      if(!consent() && !(input.method==='POST' && input.url.endsWith('/api/platform/v1/mini-reminders/revoke'))) {
        input.fail({errMsg:'consent required'});return;
      }
      return Taro.request(input as Parameters<typeof Taro.request>[0]);
    },
    randomBytes:async length=>new Uint8Array((await Taro.getRandomValues({length})).randomValues),
  };}
export function cancelWeappReminders(config:Pick<IdentityConfig,'baseUrl'>) {return cancelStoredMiniReminders(config,driver(()=>false));}
export function createWeappReminders(config:IdentityConfig,consent:boolean|(()=>boolean)) {
  const allowed=typeof consent==='function'?consent:()=>consent;
  if(!allowed())throw new Error('loginCancelled');
  const clients=createMiniReminderClient(config,driver(allowed));
  // Taro4.3.2's cross-platform type also requires Alipay entityIds; WeChat sends tmplIds only.
  return {...clients,requestPermission:(templateId:string)=>{
    if(!allowed())return Promise.reject(new Error('loginCancelled'));
    return requestSubscriptionFromGesture(templateId,input=>Taro.requestSubscribeMessage(input as Parameters<typeof Taro.requestSubscribeMessage>[0]));
  }};
}
