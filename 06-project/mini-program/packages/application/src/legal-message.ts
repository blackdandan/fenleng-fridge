/** Only a matching current reader can request a confirmation, never revoke. */
export function isPrivacyWithdrawalMessage(data:unknown,nonce:string):boolean {
  return Array.isArray(data) && data.some(value => value && typeof value==='object' &&
    value.action==='withdraw-privacy' && value.nonce===nonce && /^legal-[a-z0-9-]{5,100}$/.test(nonce));
}
