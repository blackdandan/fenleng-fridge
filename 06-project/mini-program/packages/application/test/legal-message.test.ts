import test from 'node:test';import assert from 'node:assert/strict';
import {isPrivacyWithdrawalMessage} from '../src/legal-message';
test('reader messages require a current nonce and exact action; malformed/stale payloads do nothing',()=>{
  const nonce='legal-current-reader';
  for(const data of [null,{},[{action:'withdraw-privacy',nonce:'legal-other-reader'}],[{action:'accept',nonce}],[null,'withdraw-privacy'],[{action:'withdraw-privacy'}]]) assert.equal(isPrivacyWithdrawalMessage(data,nonce),false);
  assert.equal(isPrivacyWithdrawalMessage([{action:'withdraw-privacy',nonce}],nonce),true);
  assert.equal(isPrivacyWithdrawalMessage([{action:'withdraw-privacy',nonce:''}],''),false);
});
