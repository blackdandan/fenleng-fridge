// Actual React/Taro page, controller, runtime, application and official SDK with explicit
// browser DOM/native-driver adapters. Not a WeChat-host or production-provider test.
import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';import {createRequire} from 'node:module';import {createServer} from 'node:http';import {fileURLToPath} from 'node:url';
const mini=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),root=path.resolve(mini,'../..');
const require=createRequire(import.meta.url),{build}=createRequire(require.resolve('tsx'))('esbuild'),sass=require('sass');
const {chromium}=createRequire(path.join(root,'.fenleng/web-qa/package.json'))('playwright');
const out=path.join(root,'.fenleng/mini-account-deletion-ui');fs.mkdirSync(out,{recursive:true});
const target=relative=>JSON.stringify(path.join(mini,relative).replaceAll('\\','/'));
const adapter=`import React,{useEffect,useRef} from 'react';
const hooks={show:new Set(),hide:new Set()};window.hostHooks=hooks;
export function useDidShow(fn){const ref=useRef(fn);ref.current=fn;useEffect(()=>{const handler=()=>ref.current();hooks.show.add(handler);handler();return()=>hooks.show.delete(handler);},[]);}
export function useDidHide(fn){const ref=useRef(fn);ref.current=fn;useEffect(()=>{const handler=()=>ref.current();hooks.hide.add(handler);return()=>hooks.hide.delete(handler);},[]);}
const host={env:{USER_DATA_PATH:'/qa'},getStorageSync:k=>window.mock.values.get(k)??'',setStorageSync:(k,v)=>{
 if(k==='fridge.account-deletion.v1' && window.mock.failReceipt && JSON.parse(v).entries.at(-1)?.phase==='accepted'){window.mock.failReceipt--;throw Error('synthetic quota');}window.mock.values.set(k,v);},
 removeStorageSync:k=>window.mock.values.delete(k),getStorageInfoSync:()=>({keys:[...window.mock.values.keys()]}),
 getStorage:async({key})=>{if(!window.mock.values.has(key))throw Error('missing');return{data:window.mock.values.get(key)};},
 setStorage:async({key,data})=>{host.setStorageSync(key,data);},removeStorage:async({key})=>{host.removeStorageSync(key);},
 getWindowInfo:()=>({windowWidth:innerWidth,statusBarHeight:20}),getMenuButtonBoundingClientRect:()=>({bottom:36}),
 getAppBaseInfo:()=>({language:window.mock.locale,theme:window.mock.systemTheme}),getSystemInfoSync:()=>({fontSizeSetting:16*window.mock.scale}),
 getRandomValues:async({length})=>({randomValues:crypto.getRandomValues(new Uint8Array(length)).buffer}),
 getFileSystemManager:()=>({accessSync(){throw Error('no native files');},readdirSync(){return[];}}),
 onThemeChange:()=>{},offThemeChange:()=>{},setNavigationBarColor:async()=>{},
 login:async()=>{window.mock.nativeLogins++;return{code:'qa-code-'+window.mock.nativeLogins};},
 navigateBack:async()=>{window.hostHooks.hide.forEach(fn=>fn());},
 request:input=>{const m=window.mock,p=new URL(input.url).pathname,body=input.data||{};m.calls.push({path:p,method:input.method,body,
  hasAuthorization:!!input.header.Authorization,confirmation:input.header['X-Action-Confirmation']||null,key:input.header['Idempotency-Key']||null});
  const ok=data=>input.success({statusCode:200,data}),denied=()=>input.success({statusCode:401,data:{code:'AUTHENTICATION_REQUIRED'}});
  queueMicrotask(()=>{
   if(p.endsWith('/guest/login'))ok({accessToken:'qa-guest-access',refreshToken:'qa-guest-refresh'});
   else if(p.endsWith('/wechat/login')){m.pending=false;ok({accessToken:'qa-account-access',refreshToken:'qa-account-refresh'});}
   else if(p.endsWith('/auth/refresh')){if(m.pending && body.refreshToken==='qa-account-refresh')denied();else ok({accessToken:body.refreshToken==='qa-account-refresh'?'qa-account-access':'qa-guest-access',refreshToken:body.refreshToken});}
   else if(p.endsWith('/auth/logout'))ok({});
   else if(p.endsWith('/users/me')){if(m.pending)denied();else ok({id:'qa-user',kind:'HUMAN',status:'ACTIVE'});}
   else if(p.endsWith('/challenges')){m.intent=body.deletionIdempotencyKey;ok({challengeId:'fdc-once',provider:'WECHAT',nonce:'qa-nonce',expiresAt:'2030-01-01T00:05:00.123456789Z'});}
   else if(p.endsWith('/confirm'))ok({confirmationId:'fdc-once',deletionIdempotencyKey:m.intent,expiresAt:'2030-01-01T00:05:00.123456789Z'});
   else if(p.endsWith('/data-requests')){m.pending=true;const receipt={id:'qa-request',userId:'qa-user',type:'DELETE',status:'PENDING',requestedAt:'2030-01-01T00:00:00.123456789Z',nextAttemptAt:'2030-01-08T00:00:00.123456789Z'};
    if(m.mode==='unknown'){input.fail({errMsg:'synthetic timeout'});}else if(m.mode==='hold')m.held=()=>ok(receipt);else ok(receipt);}
   else input.fail({errMsg:'unexpected fake API route'});
  });return{abort:()=>{m.aborts++;}};},
};export default host;`;
const components=`import React from 'react';
function style(v){if(typeof v!=='string')return v;return Object.fromEntries(v.split(';').filter(Boolean).map(x=>{const i=x.indexOf(':');return[x.slice(0,i),x.slice(i+1)];}));}
const make=tag=>({children,hoverClass,mode,scrollY,selectable,placeholderClass,catchMove,onInput,...p})=>React.createElement(tag,{...p,style:style(p.style),...(onInput?{onInput:e=>onInput({detail:{value:e.target.value}})}:{})},children);
export const View=make('div'),Text=make('span'),Button=make('button'),Image=make('img'),Textarea=make('textarea'),Input=make('input'),Picker=make('div'),ScrollView=make('div'),Camera=make('div'),Switch=make('input'),Checkbox=make('input'),RichText=make('div');`;
const entry=`import React from 'react';import{createRoot}from'react-dom/client';import{flushSync}from'react-dom';
import AccountPage from ${target('apps/miniapp/src/pages/account/index.tsx')};
import{RuntimeContext,createRuntime,icons}from ${target('apps/miniapp/src/runtime.tsx')};
import{AccountDeletionView,FridgeStrings,FridgeAssets,FridgePage}from ${target('packages/ui-kit/src/index.ts')};
import messages from ${target('apps/miniapp/src/locales/messages.json')};import ${target('apps/miniapp/src/app.scss')};
let runtime=null;const react=createRoot(document.getElementById('root'));window.uiErrors=[];
addEventListener('unhandledrejection',e=>window.uiErrors.push(String(e.reason?.message||e.reason)));addEventListener('error',e=>window.uiErrors.push(e.message));
async function dispose(){flushSync(()=>react.render(null));if(runtime){await runtime.online.close();runtime.controller.close();runtime=null;}}
const frame=()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
window.qa={async boot(options={}){await dispose();const previous=window.mock;window.mock={values:options.keepStorage?previous.values:new Map(),calls:[],nativeLogins:0,aborts:0,locale:options.locale||'zh-CN',scale:options.scale||1,systemTheme:options.systemTheme||'light',mode:'normal',pending:options.keepStorage?previous.pending:false,failReceipt:0,held:null};
 window.mock.values.set('fridge.display.v1',{locale:window.mock.locale,theme:options.theme||'light'});runtime=createRuntime();await runtime.controller.initialize();if(options.consent!==false)await runtime.controller.accept();await runtime.online.ready();
 flushSync(()=>react.render(<RuntimeContext.Provider value={runtime}><AccountPage/></RuntimeContext.Provider>));window.scrollTo(0,0);await frame();},
 info(){const d=runtime.online.deletion.snapshot();return{stage:runtime.controller.snapshot().stage,deletion:d,nativeLogins:window.mock.nativeLogins,
  calls:window.mock.calls.map(c=>({path:c.path,method:c.method,key:c.key,confirmation:c.confirmation,hasAuthorization:c.hasAuthorization})),held:!!window.mock.held,token:!!window.mock.values.get('fridge.platform.v1:fl_session_token'),journal:window.mock.values.get('fridge.account-deletion.v1')||'',errors:window.uiErrors};},
 mode(value){window.mock.mode=value;},failReceipt(){window.mock.failReceipt=1;},hide(){window.hostHooks.hide.forEach(fn=>fn());runtime.online.suspend();},show(){runtime.online.resume();window.hostHooks.show.forEach(fn=>fn());},
 withdraw(){return runtime.controller.withdraw();},release(){window.mock.held?.();window.mock.held=null;},
 async layout({locale,theme,scale,kind}){if(runtime)await dispose();const strings=new FridgeStrings(messages,locale);
 const receipt={id:'qa-request',requestedAt:'2030-01-01T00:00:00.123456789Z',eligibleAt:'2030-01-08T00:00:00.123456789Z'};
 let state={loading:false,initialized:true,busy:false,entry:null,durable:true,errorKey:null},signedIn=true;
 if(['accepted','unsaved','cleanup','restored'].includes(kind))state.entry={owner:'qa',key:'qa-key',phase:kind==='restored'?'cancelled':'accepted',receipt};
 if(kind==='unknown')state.entry={owner:'qa',key:'qa-key',phase:'unknown',receipt:null};
 if(kind==='busy')state={...state,busy:true,entry:{owner:'qa',key:'qa-key',phase:'submitting',receipt:null}};
 if(kind==='unsaved')state={...state,durable:false,errorKey:'deletionStorageFailed'};
 if(kind==='cleanup')state.errorKey='deletionCleanupFailed';if(kind==='storage')state={...state,initialized:false,errorKey:'deletionStorageFailed'};
 if(kind==='guest')signedIn=false;if(kind==='accepted'||kind==='cleanup')signedIn=false;
 if(kind==='confirm')state.busy=true;
 flushSync(()=>react.render(<FridgeAssets icons={icons}><div className={'fridge-theme fridge-theme--'+theme+' fridge-app'} style={{'--fridge-text-scale':scale,'--fridge-host-top':'44px',direction:strings.rtl?'rtl':'ltr'}}>
 <FridgePage title={strings.text('account')} strings={strings}><div className='account-content'><AccountDeletionView strings={strings} state={state} signedIn={signedIn} confirming={kind==='confirm'} onSubmit={()=>{}} onRetryReceipt={()=>{}} onReload={()=>{}} onConfirm={()=>{}} onCancel={()=>{}}/></div></FridgePage></div></FridgeAssets>));window.scrollTo(0,0);await frame();},dispose};`;
const bundled=await build({stdin:{contents:entry,loader:'tsx',resolveDir:mini},bundle:true,write:false,outdir:out,format:'iife',platform:'browser',target:'es2020',jsx:'automatic',tsconfig:path.join(mini,'tsconfig.json'),nodePaths:[path.join(mini,'apps/miniapp/node_modules')],
 define:{'process.env.NODE_ENV':'"production"',FRIDGE_IDENTITY_CONFIG:JSON.stringify({enabled:true,guestEnabled:true,baseUrl:'https://platform.test',clientId:'fenleng-fridge-miniapp'}),FRIDGE_TELEMETRY_ENABLED:'false',FRIDGE_LEGAL_WEB_ENABLED:'false'},loader:{'.svg':'dataurl'},
 plugins:[{name:'explicit-native-adapters',setup(b){b.onResolve({filter:/^@tarojs\/taro$/},()=>({path:'taro',namespace:'qa'}));b.onResolve({filter:/^@tarojs\/components$/},()=>({path:'components',namespace:'qa'}));
 b.onLoad({filter:/.*/,namespace:'qa'},args=>({contents:args.path==='taro'?adapter:components,loader:'jsx',resolveDir:mini}));
 b.onLoad({filter:/\.scss$/},args=>({contents:sass.compile(args.path,{style:'expanded'}).css,loader:'css'}));}}]});
for(const file of bundled.outputFiles)fs.writeFileSync(file.path,file.contents);
const server=createServer((req,res)=>{const file=req.url==='/stdin.js'?'stdin.js':req.url==='/stdin.css'?'stdin.css':null;
 if(file){res.setHeader('Content-Type',file.endsWith('.css')?'text/css':'text/javascript');res.end(fs.readFileSync(path.join(out,file)));}
 else res.end('<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>*{box-sizing:border-box}body{margin:0}span{white-space:normal}</style><link rel="stylesheet" href="/stdin.css"><div id="root"></div><script src="/stdin.js"></script>');});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const browser=await chromium.launch({channel:'chrome',headless:true});const report={scope:'Actual account page/runtime/application/SDK with browser DOM and fake native APIs; not WeChat-host or production',flows:[],layouts:[]};
const page=await browser.newPage({viewport:{width:430,height:960},timezoneId:'Asia/Shanghai'});
const messages=JSON.parse(fs.readFileSync(path.join(mini,'apps/miniapp/src/locales/messages.json'),'utf8')),zh=messages['zh-CN'];
const click=async key=>{await page.getByRole('button',{name:zh[key],exact:true}).click();};
const wait=async expression=>page.waitForFunction(expression,null,{timeout:10000});
const boot=async(options={})=>{await page.evaluate(options=>window.qa.boot(options),options);};
const info=()=>page.evaluate(()=>window.qa.info());
const login=async()=>{await click('wechatLogin');await wait(()=>window.qa.info().nativeLogins>0 && !window.qa.info().deletion.busy);await page.getByRole('button',{name:zh.logout,exact:true}).waitFor();};
const request=async()=>{await click('deletionTitle');await page.getByRole('dialog',{name:zh.deletionTitle,exact:true}).waitFor();};
try {
 await page.goto(`http://127.0.0.1:${server.address().port}`);await wait(()=>!!window.qa);
 await boot({consent:false});assert.equal((await info()).calls.length,0);report.flows.push('before consent: no platform call');
 await boot();await login();await request();await click('cancel');await wait(()=>!window.qa.info().deletion.busy);
 assert.equal((await info()).nativeLogins,1);assert.equal((await info()).calls.some(c=>c.path.endsWith('/challenges')),false);report.flows.push('cancel: no proof/challenge/DELETE');
 await request();await click('deletionConfirmAction');await wait(()=>window.qa.info().deletion.entry?.phase==='accepted'&&!window.qa.info().deletion.busy);
 let data=await info();assert.equal(data.nativeLogins,2);assert.equal(data.token,false);assert.equal(data.calls.filter(c=>c.path.endsWith('/data-requests')).length,1);
 assert.equal(data.calls.find(c=>c.path.endsWith('/data-requests')).confirmation,'fdc-once');assert.ok(await page.getByText(zh.deletionPending,{exact:true}).isVisible());
 assert.ok((await page.locator('.fridge-deletion-time').first().innerText()).includes('2030'));await page.screenshot({path:path.join(out,'accepted-zh.png'),fullPage:true});report.flows.push('accept: real SDK ACK and journal before local-only logout; year and date shown');
 await boot({keepStorage:true});await login();await wait(()=>window.qa.info().deletion.entry?.phase==='cancelled');assert.equal((await info()).calls.some(c=>c.path.endsWith('/data-requests')),false);report.flows.push('restart receipt and explicit login cancellation: no duplicate DELETE');
 await boot();await login();await page.evaluate(()=>window.qa.failReceipt());await request();await click('deletionConfirmAction');await wait(()=>window.qa.info().deletion.entry?.phase==='accepted'&&!window.qa.info().deletion.durable&&!window.qa.info().deletion.busy);
 assert.equal((await info()).token,true);await page.screenshot({path:path.join(out,'unsaved-zh.png'),fullPage:true});await click('deletionRetryReceipt');await wait(()=>window.qa.info().deletion.durable&&!window.qa.info().deletion.busy&&!window.qa.info().token);
 assert.equal((await info()).calls.filter(c=>c.path.endsWith('/data-requests')).length,1);report.flows.push('receipt storage failure: local retry only, one DELETE');
 await boot();await login();await page.evaluate(()=>window.qa.mode('unknown'));await request();await click('deletionConfirmAction');await wait(()=>window.qa.info().deletion.entry?.phase==='unknown'&&!window.qa.info().deletion.busy);
 const oldKey=(await info()).calls.find(c=>c.path.endsWith('/data-requests')).key;await page.getByRole('button',{name:zh.wechatLogin,exact:true}).waitFor();await page.screenshot({path:path.join(out,'unknown-zh.png'),fullPage:true});await login();await wait(()=>window.qa.info().deletion.entry?.phase==='cancelled');
 await page.evaluate(()=>window.qa.mode('normal'));await request();await click('deletionConfirmAction');await wait(()=>window.qa.info().deletion.entry?.phase==='accepted'&&!window.qa.info().deletion.busy);
 const writes=(await info()).calls.filter(c=>c.path.endsWith('/data-requests'));assert.equal(writes.length,2);assert.notEqual(writes[1].key,oldKey);report.flows.push('unknown accepted result + explicit new login: old intent retired, new request uses new key');
 await boot();await login();await request();await page.evaluate(()=>window.qa.hide());await wait(()=>!window.qa.info().deletion.busy);await page.evaluate(()=>window.qa.show());await wait(()=>!document.querySelector('[role=dialog]'));
 assert.equal((await info()).calls.some(c=>c.path.endsWith('/challenges')),false);await request();await click('cancel');report.flows.push('page hide resolves confirmation and returns usable controls without stale dialog');
 await boot();await login();await page.evaluate(()=>window.qa.mode('hold'));await request();await click('deletionConfirmAction');await wait(()=>window.qa.info().held);
 await page.evaluate(()=>window.qa.withdraw());await page.evaluate(()=>window.qa.release());await wait(()=>window.qa.info().stage==='consent');
 data=await info();assert.equal(JSON.parse(data.journal).entries.at(-1).phase,'submitting');assert.equal(data.token,false);report.flows.push('withdrawal during DELETE: late ACK fenced, durable unknown marker retained');
 await boot({theme:'system',systemTheme:'dark'});assert.equal(await page.locator('.fridge-theme--dark').count(),1);report.flows.push('system dark theme respected');
 assert.deepEqual((await info()).errors,[]);
 await page.setViewportSize({width:320,height:960});
 const kinds=['guest','ready','confirm','busy','accepted','unsaved','cleanup','unknown','restored','storage'];
 for(const locale of Object.keys(messages))for(const theme of ['light','dark'])for(const scale of [1,2])for(const kind of kinds){
  await page.evaluate(options=>window.qa.layout(options),{locale,theme,scale,kind});
  const metrics=await page.evaluate(()=>({horizontal:document.documentElement.scrollWidth>innerWidth,
   dialog:(()=>{const el=document.querySelector('[role=dialog]');if(!el)return null;const b=el.getBoundingClientRect();return{left:b.left,right:b.right,top:b.top,bottom:b.bottom};})(),
   buttons:[...document.querySelectorAll('button')].map(el=>el.getBoundingClientRect().height),unresolved:/\{time\}|UI_TRANSLATION_MISSING/.test(document.body.innerText)}));
  assert.equal(metrics.horizontal,false,`${locale}/${theme}/${scale}/${kind} horizontal`);assert.equal(metrics.unresolved,false);
  assert.ok(metrics.buttons.every(height=>height>=44));if(metrics.dialog){assert.ok(metrics.dialog.left>=15.9 && metrics.dialog.right<=304.1);assert.ok(metrics.dialog.top>=59.9 && metrics.dialog.bottom<=944.1);}
  if(locale==='ar'&&theme==='dark'&&scale===2&&kind==='confirm')await page.screenshot({path:path.join(out,'confirm-ar-dark-2.png')});
  if(locale==='zh-CN'&&theme==='light'&&scale===1&&kind==='confirm')await page.screenshot({path:path.join(out,'confirm-zh-light.png')});
  report.layouts.push({locale,theme,scale,kind,...metrics});
 }
 report.status='passed';fs.writeFileSync(path.join(out,'results.json'),JSON.stringify(report,null,2)+'\n');console.log(`PASS${report.flows.length}actual-page lifecycle cases and${report.layouts.length}component layout cases; native APIs substituted`);
}finally{await page.evaluate(()=>window.qa.dispose()).catch(()=>{});await browser.close();await new Promise(resolve=>server.close(resolve));}
