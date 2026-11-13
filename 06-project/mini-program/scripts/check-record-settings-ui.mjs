import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const mini=path.join(root,'06-project/mini-program');
const files=['apps/miniapp/src/presentation/record-editor.scss','packages/ui-kit/src/settings.scss','packages/ui-kit/src/history.scss','packages/ui-kit/src/feedback.scss'];
const definitions=fs.readFileSync(path.join(mini,'packages/ui-kit/src/tokens.scss'),'utf8')+fs.readFileSync(path.join(mini,'packages/ui-kit/src/theme.scss'),'utf8');
const defined=new Set([...definitions.matchAll(/(--fridge-[\w-]+)\s*:/g)].map(m=>m[1]));
for(const name of ['--fridge-text-scale','--fridge-host-top'])defined.add(name);
for(const file of files){
 const text=fs.readFileSync(path.join(mini,file),'utf8');
 for(const [,name]of text.matchAll(/var\((--fridge-[\w-]+)/g))assert(defined.has(name),`${file}: unresolved ${name}`);
 assert(!/#[0-9a-fA-F]{3,8}\b|rgba?\(/.test(text),`${file}: hardcoded color`);
}
const assets=[['calendar','54:4'],['editor-chevron','53:22'],['settings-cold','30:52'],['settings-frozen','30:61'],['settings-pantry','30:70'],['clock','41:14']].map(([name,node])=>{
 const file=`${name}.svg`;const local=fs.readFileSync(path.join(mini,'apps/miniapp/src/assets/icons',file));
 const original=fs.readFileSync(path.join(root,'06-project/app/packages/ui_kit/assets/icons',file));
 assert(local.length>0&&local.equals(original),file+' must reuse exact original Figma export');
 const svg=local.toString('utf8').match(/<svg\b[^>]*>/)?.[0];assert(svg,file);
 return {asset:file,sourceNode:node,sourceMode:'exact-existing-Figma-export-reuse',
  sha256:crypto.createHash('sha256').update(local).digest('hex'),
  rootWidth:svg.match(/\bwidth="([^"]+)"/)?.[1],rootHeight:svg.match(/\bheight="([^"]+)"/)?.[1]};
});
const locales=JSON.parse(fs.readFileSync(path.join(root,'06-project/contracts/locales/messages.json'),'utf8'));
const keys=Object.keys(locales['zh-CN']).sort();assert.equal(keys.length,159);assert.equal(Object.keys(locales).length,20);
for(const [locale,messages]of Object.entries(locales)){
 assert.deepEqual(Object.keys(messages).sort(),keys,locale);
 for(const key of keys)assert.deepEqual(messages[key].match(/\{\w+\}/g)||[],locales['zh-CN'][key].match(/\{\w+\}/g)||[],`${locale}:${key}`);
}
for(const target of ['06-project/app/apps/fridge/assets/i18n/messages.json','06-project/mini-program/apps/miniapp/src/locales/messages.json']){
 assert.deepEqual(JSON.parse(fs.readFileSync(path.join(root,target),'utf8')),locales);
}
const dist=path.join(mini,'apps/miniapp/dist');assert(fs.existsSync(path.join(dist,'app.json')),'build required before artifact checks');
const app=JSON.parse(fs.readFileSync(path.join(dist,'app.json'),'utf8'));
assert.deepEqual(app.pages,['pages/index/index','pages/account/index','pages/legal/index']);
const out=path.join(root,'02-engineering/evidence/mini-program');fs.mkdirSync(out,{recursive:true});
const report={scope:'Source token/asset/locale contracts and compiled route inventory only; no WeChat runtime, native screenshot, golden or Figma pixel proof',
 figmaFile:'b34I8tzPpU7tv1sHHdWLkq',nodes:['2:149','2:172','2:227'],sourceContracts:'pass',assets,
 locales:20,keys:159,compiledPages:app.pages,developerTools:'not-run-not-installed',physicalDevice:'not-run',nativeFidelity:'not-run'};
fs.writeFileSync(path.join(out,'record-settings-source-results.json'),JSON.stringify(report,null,2)+'\n');
console.log('PASS new UI token references/colors,6 exact original SVGs,20-language159-key copies/placeholders,compiled route inventory; native fidelity not-run');
