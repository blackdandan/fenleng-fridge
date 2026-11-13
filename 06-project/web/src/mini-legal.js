/* Legal reader bridge only. No identity, inventory, telemetry or consent write. */
(() => {
  const query=new URLSearchParams(location.search);
  const nonce=query.get('nonce') || '';
  if (query.get('mini')!=='1' || query.get('withdraw')!=='1' || document.body.dataset.legal!=='privacy' || !/^legal-[a-z0-9-]{5,100}$/.test(nonce)) return;
  const locale=query.get('locale');
  const labels=window.FRIDGE_MINI_LEGAL[locale] || window.FRIDGE_MINI_LEGAL['zh-CN'];
  const footer=document.createElement('div'),button=document.createElement('button'),status=document.createElement('p');
  button.type='button';button.textContent=labels.withdraw;button.disabled=true;button.className='mini-withdraw';
  footer.lang=locale in window.FRIDGE_MINI_LEGAL ? locale : 'zh-CN';footer.dir=footer.lang==='ar' ? 'rtl':'ltr';
  status.setAttribute('role','alert');footer.append(button,status);document.querySelector('main').append(footer);
  const fail=() => {status.textContent=labels.error;button.disabled=false;};
  button.addEventListener('click',() => {
    if (!window.wx?.miniProgram) {fail();return;}
    button.disabled=true;
    try {
      window.wx.miniProgram.postMessage({data:{action:'withdraw-privacy',nonce}});
      window.wx.miniProgram.navigateBack({delta:1,fail});
    } catch {fail();}
  });
  const script=document.createElement('script');script.src='https://res.wx.qq.com/open/js/jweixin-1.6.0.js';
  script.onload=() => {
    if (!window.wx?.miniProgram) {status.textContent=labels.error;return;}
    window.wx.miniProgram.getEnv(result => {
      if (result.miniprogram) button.disabled=false;
      else status.textContent=labels.error;
    });
  };
  script.onerror=() => {status.textContent=labels.error;};document.head.append(script);
})();
