const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {chromium}=require('./web-qa/node_modules/playwright');
(async()=>{
 const release=JSON.parse(fs.readFileSync(path.join(__dirname,'../06-project/web/dist/release.json'),'utf8'));
 if(!release.android)throw Error('APK download missing');
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 try {
  const page=await browser.newPage({acceptDownloads:true,viewport:{width:390,height:844}});
  await page.goto('http://127.0.0.1:4817/#availability');
  const link=page.locator('.android-download');await link.waitFor();await link.scrollIntoViewIfNeeded();
  await page.screenshot({path:path.join(__dirname,'website-restored-download-390.png'),fullPage:false});
  const pending=page.waitForEvent('download');await link.click();const download=await pending;
  const downloaded=await download.path();if(await download.failure())throw Error('Browser download failed');
  const digest=crypto.createHash('sha256');let bytes=0;
  for await(const chunk of fs.createReadStream(downloaded)){bytes+=chunk.length;digest.update(chunk);}
  const sha256=digest.digest('hex');
  if(bytes!==release.android.bytes || sha256!==release.android.sha256)throw Error('Browser artifact mismatch');
  const result={status:'passed',scope:'Actual Chromium download through the current local website; not Android WeChat',bytes,sha256,
   filename:download.suggestedFilename(),url:download.url(),screenshot:'.fenleng/website-restored-download-390.png'};
  fs.writeFileSync(path.join(__dirname,'website-restored-download-browser.json'),JSON.stringify(result,null,2)+'\n');
  console.log(`PASS actual browser APK download: ${bytes} bytes / ${sha256}`);
 }finally {await browser.close();}
})().catch(error=>{console.error(error.message);process.exitCode=1;});
