import Taro from '@tarojs/taro';
import {AccountDeletionSession,type FridgeController} from '@fridge/application';
import {MiniDeletionGateway,type MiniIdentityOwner} from '@fridge/api-client';
import {SnapshotDeletionStorage} from '@fridge/weapp';

export function createDeletionSession(controller:FridgeController,sessions:MiniIdentityOwner,cancelReminders:()=>Promise<void>){
  const consent=()=>controller.snapshot().stage==='ready';
  return new AccountDeletionSession(new SnapshotDeletionStorage({get:key=>Taro.getStorageSync(key),set:(key,value)=>Taro.setStorageSync(key,value)}),
    new MiniDeletionGateway(()=>sessions.identity,consent,cancelReminders),consent,async()=>{
      const bytes=new Uint8Array((await Taro.getRandomValues({length:32})).randomValues);
      if(bytes.length!==32)throw new Error('DELETION_KEY_UNAVAILABLE');
      return 'fridge-delete-'+Array.from(bytes,value=>value.toString(16).padStart(2,'0')).join('');
    });
}
