import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const mini=path.resolve(import.meta.dirname,'..'),root=path.resolve(mini,'../..');
const canonical=JSON.parse(fs.readFileSync(path.join(root,'06-project/contracts/locales/messages.json'),'utf8'));
for(const relative of ['06-project/app/apps/fridge/assets/i18n/messages.json','06-project/mini-program/apps/miniapp/src/locales/messages.json']) {
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(root,relative),'utf8')),canonical);
}
const keys=Object.keys(canonical.en).sort(),placeholders=text=>[...text.matchAll(/\{(\w+)\}/g)].map(match=>match[1]).sort();
for(const [locale,messages]of Object.entries(canonical)) {
  assert.deepEqual(Object.keys(messages).sort(),keys,locale);
  for(const key of keys){assert.equal(typeof messages[key],'string');assert.ok(messages[key].trim(),`${locale}:${key}`);
    assert.deepEqual(placeholders(messages[key]),placeholders(canonical.en[key]),`${locale}:${key}`);}
}
function scripts(dir) {return fs.readdirSync(dir,{withFileTypes:true}).flatMap(entry=>{
  const file=path.join(dir,entry.name);return entry.isDirectory()?scripts(file):entry.name.endsWith('.js')?[file]:[];
});}
const files=scripts(path.join(mini,'apps/miniapp/dist')),compiled=files.map(file=>fs.readFileSync(file,'utf8')).join('\n');
for(const capability of ['mini-reminders/revoke','requestSubscribeMessage','getRandomValues','reminderDay','miniSubscriptionTitle','miniCancelFailed'])assert.ok(compiled.includes(capability),`compiled capability missing:${capability}`);
const report={status:'passed',scope:'locale equality/placeholders and compiled capability presence only; not native runtime proof',
  locales:Object.keys(canonical).length,keys:keys.length,compiledScripts:files.length};
fs.writeFileSync(path.join(root,'02-engineering/evidence/mini-reminder-compiled-check.json'),JSON.stringify(report,null,2)+'\n');
console.log(`PASS ${report.locales} locales/${report.keys} keys and compiled reminder capabilities; native WeChat not-run`);
