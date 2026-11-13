import test from 'node:test';
import assert from 'node:assert/strict';
import {requestSubscriptionFromGesture} from '../src/subscription-permission';

test('native dialog is requested synchronously within the same user gesture',async()=>{
  const order:string[]=[];
  const pending=requestSubscriptionFromGesture('template-one',input=>{order.push('native');assert.deepEqual(input.tmplIds,['template-one']);return Promise.resolve({'template-one':'accept'});});
  order.push('after-click');assert.deepEqual(order,['native','after-click']);assert.equal(await pending,'accept');
});
test('reject ban and filter remain observations while cancel and unknown replies never imply acceptance',async()=>{
  for(const result of ['reject','ban','filter'])assert.equal(await requestSubscriptionFromGesture('template-one',async()=>({'template-one':result})),result);
  await assert.rejects(requestSubscriptionFromGesture('template-one',async()=>{throw {errMsg:'requestSubscribeMessage:fail cancel'};}),/MINI_PERMISSION_CANCELLED/);
  await assert.rejects(requestSubscriptionFromGesture('template-one',async()=>({errMsg:'requestSubscribeMessage:ok'})),/MINI_PERMISSION_UNCONFIRMED/);
  await assert.rejects(requestSubscriptionFromGesture('',()=>{throw Error('must not run');}),/MINI_TEMPLATE_INVALID/);
});
