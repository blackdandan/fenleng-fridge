import Taro from '@tarojs/taro';
import {MiniProductTelemetry,type MiniIdentityOwner} from '@fridge/api-client';
import type {FridgeController} from '@fridge/application';
import {FridgeStrings} from '@fridge/ui-kit';
import messages from './locales/messages.json';
import catalog from './config/telemetry-events.json';
import {identityConfig} from './config/identity';

declare const FRIDGE_TELEMETRY_ENABLED:boolean;
export function createProductTelemetry(controller:FridgeController,sessions:MiniIdentityOwner,systemLanguage:string,active:()=>boolean) {
  return new MiniProductTelemetry({enabled:FRIDGE_TELEMETRY_ENABLED && identityConfig.enabled,
    consent:()=>active() && controller.snapshot().stage==='ready',identity:()=>sessions.identity,ready:()=>sessions.ready(),
    catalog,
    context:()=>({platform:'mini-program',appVersion:'0.1.0',buildNumber:'1',releaseChannel:'china',
      locale:FridgeStrings.resolve(Object.keys(messages),systemLanguage,controller.snapshot().locale)}),
    nextKey:async()=>{
      const bytes=new Uint8Array((await Taro.getRandomValues({length:32})).randomValues);
      if(bytes.length!==32)throw new Error('TELEMETRY_KEY_UNAVAILABLE');
      return `fridge-mini-telemetry-${Date.now()}-${Array.from(bytes,value=>value.toString(16).padStart(2,'0')).join('')}`;
    },
  });
}
