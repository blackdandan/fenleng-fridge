import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';
import {createRequire} from 'node:module';import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const {chromium}=createRequire(path.join(root,'.fenleng/web-qa/package.json'))('playwright');
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
const core=JSON.parse(fs.readFileSync(path.join(root,'06-project/contracts/locales/messages.json'),'utf8'));
const out=path.join(root,'02-engineering/evidence/website');
const report={completed:false,scope:'Local Chromium bridge contract with mocked WeChat JS SDK; not real WeChat WebView/native message delivery',locales:[],guards:[],screenshots:[]};
try {
 const page=await browser.newPage({viewport:{width:320,height:740}});let sdkRequests=0,mode='success';
 await page.route('https://res.wx.qq.com/**',route=>{sdkRequests++;if(mode==='sdk-error')return route.abort();return route.fulfill({contentType:'application/javascript',body:`window.bridgeCalls=[];window.wx={miniProgram:{getEnv:f=>f({miniprogram:${mode==='success'}}),postMessage:p=>bridgeCalls.push(p),navigateBack:p=>bridgeCalls.push({back:p.delta})}};`});});
 const errors=[];page.on('pageerror',error=>errors.push(error.message));
 for(const locale of Object.keys(core)) {
  await page.goto(`http://127.0.0.1:4817/privacy/?mini=1&withdraw=1&nonce=legal-local-contract&locale=${encodeURIComponent(locale)}`);
  const button=page.locator('.mini-withdraw');await button.waitFor();await page.waitForFunction(()=>!document.querySelector('.mini-withdraw').disabled);
  assert.equal(await button.textContent(),core[locale].privacyWithdrawLink);
  await button.scrollIntoViewIfNeeded();const bounds=await button.boundingBox();assert(bounds.x>=0 && bounds.x+bounds.width<=321 && bounds.height>=44);
  if(['zh-CN','ar'].includes(locale)) {const name=`mini-privacy-bridge-${locale}-320.png`;await page.screenshot({path:path.join(out,name)});report.screenshots.push(name);}
  await button.click();assert.deepEqual(await page.evaluate(()=>window.bridgeCalls),[{data:{action:'withdraw-privacy',nonce:'legal-local-contract'}},{back:1}]);
  report.locales.push(locale);
 }
 for(const url of ['privacy/','privacy/?mini=1&withdraw=0&nonce=legal-local-contract','terms/?mini=1&withdraw=1&nonce=legal-local-contract','privacy/?mini=1&withdraw=1&nonce=bad']) {
  const before=sdkRequests;await page.goto('http://127.0.0.1:4817/'+url);assert.equal(await page.locator('.mini-withdraw').count(),0);assert.equal(sdkRequests,before);report.guards.push(url);
 }
 for(const failure of ['sdk-error','outside-mini']) {
  mode=failure;await page.goto('http://127.0.0.1:4817/privacy/?mini=1&withdraw=1&nonce=legal-local-contract&locale=ar');
  await page.locator('[role=alert]').filter({hasText:core.ar.error}).waitFor();
  assert(await page.locator('.mini-withdraw').isDisabled());report.guards.push(failure+'-disabled-with-translated-error');
 }
 assert.deepEqual(errors,[]);report.completed=true;
 fs.writeFileSync(path.join(out,'mini-legal-bridge-results.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
} finally {await browser.close();}
