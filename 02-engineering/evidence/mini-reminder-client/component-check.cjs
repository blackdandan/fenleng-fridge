const fs=require('node:fs'),path=require('node:path'),{pathToFileURL}=require('node:url');
const {chromium}=require('../web-qa/node_modules/playwright');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const page=await browser.newPage({viewport:{width:320,height:1000}}),errors=[];
 page.on('pageerror',error=>errors.push(error.message));
 await page.goto(pathToFileURL(path.join(__dirname,'index.html')).href);
 const locales=await page.evaluate(()=>window.fixtureLocales);
 const states={off:{enabled:false,phase:'off'},ready:{enabled:true,phase:'ready',messageKey:'miniReady'},
  granted:{enabled:true,phase:'ready',messageKey:'miniGranted',observedAcceptances:1},
  login:{enabled:true,phase:'needs-login',messageKey:'miniNeedsLogin'},unconfigured:{enabled:true,phase:'unconfigured',messageKey:'miniUnconfigured'},
  permission:{enabled:true,phase:'permission'},cancelling:{enabled:false,phase:'cancelling'},
  syncError:{enabled:true,phase:'error',errorKey:'miniSyncFailed'},cancelError:{enabled:false,phase:'error',errorKey:'miniCancelFailed'}};
 const results=[];
 try {
  for(const locale of locales)for(const theme of ['light','dark'])for(const scale of [1,2])for(const [stateName,state]of Object.entries(states)) {
   await page.evaluate(spec=>window.renderFixture(spec),{locale,theme,scale,state});
   const metrics=await page.evaluate(()=>{
    const width=document.documentElement.clientWidth,buttons=[...document.querySelectorAll('button')];
    const overflowing=[...document.querySelectorAll('.fridge-subscription-card span')].filter(span=>[...span.getClientRects()].some(rect=>rect.left<-.5 || rect.right>width+.5)).map(span=>span.textContent);
    return {width,scrollWidth:document.documentElement.scrollWidth,overflowing,buttons:buttons.map(button=>({height:button.getBoundingClientRect().height,disabled:button.disabled}))};
   });
   const result={locale,theme,scale,state:stateName,...metrics};results.push(result);
   if(metrics.scrollWidth>320 || metrics.overflowing.length || metrics.buttons.some(button=>button.height<43.5))throw Error('Layout failed '+JSON.stringify(result));
   if(['permission','cancelling'].includes(stateName) && !metrics.buttons[0].disabled)throw Error('Busy button was enabled');
   if(theme==='light' && scale===1 && locale==='zh-CN' && ['off','ready','unconfigured'].includes(stateName) ||
      theme==='dark' && scale===2 && (locale==='ar' && stateName==='cancelError' || locale==='de' && stateName==='granted')) {
    await page.screenshot({path:path.join(__dirname,`${locale}-${theme}-${scale}-${stateName}.png`),fullPage:true});
   }
  }
  if(errors.length)throw Error(errors.join('\n'));
  fs.writeFileSync(path.join(__dirname,'results.json'),JSON.stringify({status:'passed',scope:'Actual React component and SCSS with DOM host shims; no native WeChat visual claims',cases:results.length,results},null,2)+'\n');
  console.log(`PASS ${results.length} component layout/state cases; native WeChat remains not-run`);
 }finally {await browser.close();}
})().catch(error=>{console.error(error.message);process.exitCode=1;});
