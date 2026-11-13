const fs=require('node:fs'),path=require('node:path'),{createRequire}=require('node:module');
let pw;
for(const entry of [process.env.PREVIEW_PLAYWRIGHT_PACKAGE,'C:/Program Files/WindowsApps/OpenAI.Codex_26.1106.6628.0_x64__2p2nqsd0c76g0/app/resources/cua_node/bin/node_modules/playwright/package.json','/Users/xixi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json'].filter(Boolean)){
  if(fs.existsSync(entry)){try{pw=createRequire(entry)('playwright');break;}catch{}}
}
if(!pw)pw=require('playwright');
const chrome=process.env.PREVIEW_CHROME||['C:/Program Files/Google/Chrome/Application/chrome.exe','/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'].find(p=>fs.existsSync(p));
module.exports={pw,launch:()=>pw.chromium.launch({headless:true,...(chrome?{executablePath:chrome}:{})}),url:'file://'+path.join(__dirname,'index.html')};
