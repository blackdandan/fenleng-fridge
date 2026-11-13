import {TaroMiniReminderSDK,TaroMiniReminderPlan,TaroPlatformClient,TaroStorageAdapter} from '@fenleng/sdk-taro';
import type {IdentityConfig} from './identity';
import type {TaroNativeRequest,TaroStorageDriver} from '@fenleng/sdk-taro';

export interface MiniReminderDriver extends TaroStorageDriver {
  request(input:TaroNativeRequest):unknown;
  randomBytes(length:number):Promise<Uint8Array|ArrayBuffer>;
}
export type {TaroMiniReminderSnapshot,TaroMiniReminderReceipt,TaroMiniReminderConfiguration,TaroMiniReminderStatus,TaroMiniObservation} from '@fenleng/sdk-taro';

/** Construct once after consent. Uses the existing identity tokens, never creates a login. */
export function createMiniReminderClient(config:IdentityConfig,driver:MiniReminderDriver) {
  if(!config.enabled || !config.clientId.startsWith('fenleng-fridge-') || !/^https:\/\/[^/\s]+/.test(config.baseUrl)) {
    throw new Error('loginNotConfigured');
  }
  const client=new TaroPlatformClient({baseUrl:config.baseUrl,
    storage:new TaroStorageAdapter(driver,{prefix:'fridge.platform.v1:'}),request:input=>driver.request(input)});
  const sdk=new TaroMiniReminderSDK(client);
  const plan=new TaroMiniReminderPlan(sdk,{storage:new TaroStorageAdapter(driver,{prefix:'fridge.reminders.v1:'}),
    storageKey:'plan',randomBytes:length=>driver.randomBytes(length)});
  return {sdk,plan};
}

/** Cleanup can run before reconsent. Missing config must not prevent a no-capability local cleanup. */
export function cancelStoredMiniReminders(config:Pick<IdentityConfig,'baseUrl'>,driver:MiniReminderDriver):Promise<{revoked:true}> {
  const storage=new TaroStorageAdapter(driver,{prefix:'fridge.platform.v1:'});
  const sdk=new TaroMiniReminderSDK({storage,tokenKey:'fl_session_token',request:(endpoint,method,body,options)=>
    new TaroPlatformClient({baseUrl:config.baseUrl,storage,request:input=>driver.request(input)}).request(endpoint,method,body,options)});
  return new TaroMiniReminderPlan(sdk,{storage:new TaroStorageAdapter(driver,{prefix:'fridge.reminders.v1:'}),
    storageKey:'plan',randomBytes:length=>driver.randomBytes(length)}).revoke();
}
