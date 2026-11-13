import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
const web=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');const root=path.resolve(web,'../..');
const {chromium}=createRequire(path.join(root,'.fenleng/web-qa/package.json'))('playwright');
const browserPath=process.argv[process.argv.indexOf('--browser')+1];assert(browserPath&&fs.existsSync(browserPath),'Pass --browser with an installed Chromium browser');
const url=process.env.FRIDGE_WEB_URL||'http://127.0.0.1:4817/';
const out=path.join(root,'02-engineering/evidence/website');fs.mkdirSync(out,{recursive:true});
const browser=await chromium.launch({headless:true,executablePath:browserPath});
const report={completed:false,scope:'Isolated desktop Chromium local static-site QA, not Android/iOS/WeChat installation or deployed-domain evidence',matrix:[],errors:[],screenshots:[]};
try{
 const context=await browser.newContext({locale:'en-US',viewport:{width:390,height:844},acceptDownloads:true});
 const page=await context.newPage();page.on('pageerror',e=>report.errors.push(e.message));
 await page.goto(url);await page.waitForFunction(()=>document.documentElement.lang==='en');
 await page.emulateMedia({reducedMotion:'reduce'});
 await page.keyboard.press('Tab');assert(await page.locator('.skip').evaluate(el=>el===document.activeElement));
 assert((await page.locator('.skip').boundingBox()).y>=0);
 assert.equal(await page.locator('#language option').count(),21);
 const locales=await page.locator('#language option').evaluateAll(options=>options.map(o=>o.value).filter(v=>v!=='system'));
 for(const width of [320,390,1440]){
  await page.setViewportSize({width,height:width>1000?1000:844});
  for(const locale of locales){
   await page.selectOption('#language',locale);
   const dimensions=await page.evaluate(()=>({width:innerWidth,body:document.documentElement.scrollWidth,dir:document.documentElement.dir,
    empty:[...document.querySelectorAll('[data-i18n],[data-core],[data-format]')].filter(e=>!e.textContent.trim()||e.textContent==='undefined').length,
    background:getComputedStyle(document.querySelector('.food')).backgroundImage}));
   assert(dimensions.body<=width+1,`${locale}@${width}: horizontal overflow ${dimensions.body}`);
   assert.equal(dimensions.empty,0);assert.equal(dimensions.dir,locale==='ar'?'rtl':'ltr');
   assert(dimensions.background.includes('food-photos.png'));
   report.matrix.push({locale,width,overflow:dimensions.body-width,dir:dimensions.dir});
  }
 }
 await page.setViewportSize({width:390,height:844});await page.selectOption('#language','de');await page.reload();
 assert.equal(await page.locator('html').getAttribute('lang'),'de');
 await page.selectOption('#language','system');assert.equal(await page.locator('html').getAttribute('lang'),'en');
 await page.selectOption('#language','zh-CN');await page.locator('a[href="#availability"]').first().click();
 assert(await page.locator('#availability').isVisible());
 const release=await (await context.request.get(new URL('release.json',url).href)).json();
 if(release.android){
  const downloadUrl=new URL(release.android.url,url).href;
  const head=await context.request.head(downloadUrl);assert.equal(head.status(),200);
  assert.equal(Number(head.headers()['content-length']),release.android.bytes);
  assert(head.headers()['content-type'].includes('application/vnd.android.package-archive'));
  const range=await context.request.get(downloadUrl,{headers:{Range:'bytes=0-3'}});assert.equal(range.status(),206);
  assert.deepEqual([...await range.body()],[80,75,3,4]);
  const invalid=await context.request.get(downloadUrl,{headers:{Range:`bytes=${release.android.bytes}-`}});assert.equal(invalid.status(),416);
  const [download]=await Promise.all([page.waitForEvent('download'),page.locator('.android-download').click()]);
  assert.equal(download.suggestedFilename(),path.basename(release.android.url));await download.cancel();
  report.androidDownload={actualBrowserDownloadEvent:true,headAndRange:true,sha256:release.android.sha256,bytes:release.android.bytes};
 }
 for(const route of ['terms/','privacy/','app/']){
  await page.goto(new URL(route,url).href);assert.equal(await page.locator('h1').count(),1);
  await page.selectOption('#language','ar');
  if(route!=='app/'){
   assert.equal(await page.locator('.legal-document').getAttribute('lang'),'zh-CN');
   assert.equal(await page.locator('.legal-document').getAttribute('dir'),'ltr');
   assert((await page.locator('.legal-document').innerText()).includes('fenlengtech@163.com'));
  }
  assert((await page.evaluate(()=>document.documentElement.scrollWidth))<=391);
 }
 for(const [name,width,locale]of [['home390',390,'zh-CN'],['home1440',1440,'zh-CN'],['home320-ar',320,'ar']]){
  await page.setViewportSize({width,height:width>1000?1000:844});await page.goto(url);await page.selectOption('#language',locale);
  await page.screenshot({path:path.join(out,name+'.png'),fullPage:true});report.screenshots.push(name+'.png');
 }
 await page.setViewportSize({width:320,height:844});await page.goto(new URL('privacy/',url).href);
 await page.selectOption('#language','en');await page.screenshot({path:path.join(out,'privacy320.png'),fullPage:true});report.screenshots.push('privacy320.png');
 await page.goto(url);await page.selectOption('#language','en');
 await page.addStyleTag({content:'html{font-size:200%!important}'});
 for(const locale of locales){
  await page.selectOption('#language',locale);
  const overflow=await page.evaluate(()=>document.documentElement.scrollWidth-innerWidth);
  assert(overflow<=1,`${locale}:200% text overflow ${overflow}`);
  report.matrix.push({locale,width:320,textScale:2,overflow});
 }
 await page.selectOption('#language','en');
 for(const link of await page.locator('.operator a').all())assert((await link.boundingBox()).height>=44);
 await page.screenshot({path:path.join(out,'home320-text2.png'),fullPage:true});report.screenshots.push('home320-text2.png');
 const privateContext=await browser.newContext({locale:'fr-FR'});await privateContext.addInitScript(()=>{Object.defineProperty(window,'localStorage',{get(){throw new Error('Unavailable');}});});
 const privatePage=await privateContext.newPage();await privatePage.goto(url);assert.equal(await privatePage.locator('html').getAttribute('lang'),'fr');await privateContext.close();
 await context.close();assert.deepEqual(report.errors,[]);report.completed=true;
}finally{await browser.close();fs.writeFileSync(path.join(out,'browser-results.json'),JSON.stringify(report,null,2)+'\n');}
console.log(JSON.stringify({completed:report.completed,matrixStates:report.matrix.length,download:report.androidDownload,screenshots:report.screenshots,errors:report.errors},null,2));
