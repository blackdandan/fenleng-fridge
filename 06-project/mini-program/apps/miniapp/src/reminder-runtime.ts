import Taro from '@tarojs/taro';
import {MiniReminderSession,type FridgeController} from '@fridge/application';
import {miniReminderCalendar} from '@fridge/domain';
import {cancelWeappReminders,createWeappReminders} from '@fridge/weapp';
import type {MiniIdentityOwner} from '@fridge/api-client';
import {identityConfig} from './config/identity';

export function createReminderSession(controller:FridgeController,sessions:MiniIdentityOwner,systemLanguage:string) {
  const consent=()=>controller.snapshot().stage==='ready';
  return new MiniReminderSession({
    events:controller.recordEvent,
    consent,available:()=>identityConfig.enabled,
    accountReady:async()=>{
      const identity=await sessions.ready(),snapshot=identity?.session.snapshot();
      return snapshot?.status==='authenticated' && snapshot.identityKind!=='guest';
    },
    calendar:()=>{
      const timezone=Intl.DateTimeFormat().resolvedOptions().timeZone;
      if(!timezone)throw new Error('MINI_TIMEZONE_UNAVAILABLE');
      const state=controller.snapshot();return miniReminderCalendar(state.inventory,new Date(),timezone,state.locale || systemLanguage);
    },
    readEnabled:async()=>{
      const value=Taro.getStorageSync('fridge.reminders.enabled.v1');
      if(value===true || value===false)return value;
      if(value==='' || value===undefined || value===null)return false;
      throw new Error('MINI_PREF_INVALID');
    },
    writeEnabled:async enabled=>{await Taro.setStorage({key:'fridge.reminders.enabled.v1',data:enabled});},
    create:()=>{
      const {sdk,plan,requestPermission}=createWeappReminders(identityConfig,consent);
      return {configuration:()=>sdk.configuration(),sync:calendar=>plan.sync(calendar),
        retryObservations:()=>plan.retryObservations(),observe:(template,result)=>plan.observe(template,result),
        requestPermission,revoke:()=>plan.revoke()};
    },
    cancelStored:()=>cancelWeappReminders(identityConfig),
  });
}
