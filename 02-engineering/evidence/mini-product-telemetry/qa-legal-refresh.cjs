const fs=require('node:fs'),path=require('node:path'),{chromium}=require('./web-qa/node_modules/playwright');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const results=[];try {
  for(const width of [320,430])for(const colorScheme of ['light','dark']) {
   const page=await browser.newPage({viewport:{width,height:960},colorScheme});
   await page.goto('http://127.0.0.1:4817/privacy/');
   await page.getByRole('heading',{name:'8. 草案与功能开放状态',exact:true}).waitFor();
   const text=await page.locator('body').innerText();
   if(text.includes('当前预览中的游客身份、反馈回执和分析记录均为本地模拟') || !text.includes('取消尚未完成') || !text.includes('fenlengtech@163.com'))throw Error('Privacy truth mismatch');
   const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);
   if(overflow)throw Error('Privacy document horizontal page overflow');
   await page.getByRole('heading',{name:'8. 草案与功能开放状态',exact:true}).scrollIntoViewIfNeeded();
   const screenshot=path.join(__dirname,`legal-refresh-${width}-${colorScheme}.png`);await page.screenshot({path:screenshot,fullPage:false});
   results.push({width,colorScheme,status:'passed',screenshot});await page.close();
  }
  fs.writeFileSync(path.join(__dirname,'legal-refresh-results.json'),JSON.stringify({status:'passed',scope:'Local privacy web page refreshed text and viewport; not native App WebView or formal publication',results},null,2)+'\n');
  console.log('PASS4 local privacy viewport/theme checks');
 }finally {await browser.close();}
})().catch(error=>{console.error(error.message);process.exitCode=1;});
