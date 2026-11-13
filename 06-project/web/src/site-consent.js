import {WebsitePrivacy,WEBSITE_PRIVACY_KEY} from './site-privacy.js';

function bootstrap() {
  const data=window.FRIDGE_SITE,config=data?.analytics;
  if(!config?.enabled || new URLSearchParams(location.search).get('mini')==='1')return;
  const text=key=>data.locales[document.documentElement.lang]?.[key] || data.locales['zh-CN'][key];
  const panel=document.createElement('aside');panel.className='website-privacy';panel.setAttribute('role','region');panel.setAttribute('aria-labelledby','website-privacy-title');
  const title=document.createElement('h2');title.id='website-privacy-title';
  const body=document.createElement('p'),links=document.createElement('p'),error=document.createElement('p'),actions=document.createElement('div');
  error.setAttribute('role','status');actions.className='website-privacy-actions';
  const terms=document.createElement('a'),policy=document.createElement('a');terms.href='/terms/';policy.href='/privacy/';
  links.append(terms,document.createTextNode(' · '),policy);
  panel.append(title,body,links,error,actions);document.body.append(panel);
  const choices=document.createElement('button');choices.type='button';choices.className='website-privacy-choice';
  document.querySelector('.footer-links')?.append(choices);
  let privacy;
  privacy=new WebsitePrivacy({storage:{getItem:key=>localStorage.getItem(key),setItem:(key,value)=>localStorage.setItem(key,value),removeItem:key=>localStorage.removeItem(key)},version:config.policyVersion,loadCollector:async()=>{
    const {createAnonymousCollector}=await import('./anonymous-analytics.js');
    if(!privacy.hasConsent())return null;
    return createAnonymousCollector(config,{consent:privacy.hasConsent,locale:()=>document.documentElement.lang});
  }});
  function button(key,action,secondary=false){
    const button=document.createElement('button');button.type='button';button.className='button'+(secondary?' website-privacy-secondary':'');
    button.textContent=text(key);button.addEventListener('click',action);return button;
  }
  function render(){
    const state=privacy.snapshot();panel.hidden=!state.show;
    title.textContent=text('websitePrivacyTitle');body.textContent=text('websitePrivacyBody');terms.textContent=text('terms');policy.textContent=text('privacy');
    choices.textContent=text('websitePrivacyChoices');error.textContent=state.error?text(state.error):'';error.hidden=!state.error;
    actions.replaceChildren();
    if(state.error==='privacyWithdrawFailed')actions.append(button('retry',()=>privacy.withdraw()));
    else if(state.choice==='accepted')actions.append(button('privacyWithdrawLink',()=>privacy.withdraw()),button('back',()=>privacy.hideChoices(),true));
    else actions.append(button('agree',()=>privacy.accept()),button('decline',()=>privacy.decline(),true));
  }
  privacy.subscribe(render);render();
  choices.addEventListener('click',()=>{privacy.showChoices();title.tabIndex=-1;title.focus();});
  document.addEventListener('fridge:locale',render);
  window.addEventListener('storage',event=>{if(event.key===WEBSITE_PRIVACY_KEY || event.key===null)void privacy.refresh();});
  document.addEventListener('click',event=>{
    const link=event.target.closest?.('a.android-download');
    if(link && !event.defaultPrevented && event.button===0)void privacy.appEntry();
  });
  window.addEventListener('pagehide',()=>privacy.suspend());window.addEventListener('pageshow',()=>privacy.resume());
  const consentOnEntry=privacy.read().choice==='accepted';
  void privacy.start().then(()=>{if(consentOnEntry && /\/app\/(?:index\.html)?$/.test(location.pathname))void privacy.appEntry();});
}
if(document.readyState==='loading' || !window.FRIDGE_SITE)document.addEventListener('DOMContentLoaded',bootstrap,{once:true});else bootstrap();
