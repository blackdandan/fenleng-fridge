import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
const web=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');const root=path.resolve(web,'../..');const dist=path.join(web,'dist');
const pages=['index.html','terms/index.html','privacy/index.html','app/index.html'];
const context={window:{}};vm.runInNewContext(fs.readFileSync(path.join(dist,'site-data.js'),'utf8'),context);
const locales=context.window.FRIDGE_SITE.locales;assert.equal(Object.keys(locales).length,20);
for(const page of pages){
 const file=path.join(dist,page);const html=fs.readFileSync(file,'utf8');assert(html.includes('name="viewport"'));
 for(const [,url]of html.matchAll(/(?:src|href)="([^"]+)"/g)){
  if(/^(?:https?:|mailto:|tel:|#)/.test(url))continue;
  const target=path.resolve(path.dirname(file),url);assert(fs.existsSync(target),`${page}: missing ${url}`);
 }
 for(const [,key]of html.matchAll(/data-(?:i18n|core|label|format)="([^"]+)"/g)){
  for(const [locale,values]of Object.entries(locales))assert(typeof values[key]==='string'&&values[key].length,`${page}:${locale}:${key}`);
 }
 assert(!html.includes('prototype/'),'Prototype runtime must not ship as a web business client');
 assert(html.includes('fenlengtech@163.com'));assert(!html.includes('href="#"'));
}
new vm.Script(fs.readFileSync(path.join(dist,'site.js'),'utf8'));
const release=JSON.parse(fs.readFileSync(path.join(dist,'release.json'),'utf8'));
assert.equal(release.legalVersion,'V0.4');
const verified=JSON.parse(fs.readFileSync(path.join(root,'02-engineering/implementation-status.json'),'utf8')).verified.androidCurrentDebugBuild;
if(verified?.status==='passed' && !process.argv.includes('--without-android')) {
 assert.ok(release.android,'The verified APK download disappeared; use --without-android only for an intentional source-only preview');
 assert.equal(release.android.sha256,verified.sha256,'Download differs from the recorded APK');
}
if(release.android){
 assert.equal(release.android.url,'downloads/fenleng-fridge_latest.apk','Download URL must remain stable across versions');
 assert.equal(release.android.artifactFilename,`fridge-${release.android.version}-${release.android.build}-android-debug.apk`);
 const file=path.join(dist,release.android.url);assert.equal(fs.statSync(file).size,release.android.bytes);
 assert.equal(crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'),release.android.sha256);
 assert.equal(release.android.kind,'debug-preview');
}
for(const key of ['ios','harmonyos','wechat'])assert.equal(release[key].status,'unreleased');
const sourceImage=fs.readFileSync(path.join(root,'06-project/prototype/mvp/assets/food-photos.png'));
assert(sourceImage.equals(fs.readFileSync(path.join(dist,'assets/food-photos.png'))));
for(const key of ['terms','privacy']){
 const html=fs.readFileSync(path.join(dist,key,'index.html'),'utf8');
 const original=fs.readFileSync(path.join(root,'06-project/app/apps/fridge/assets/legal',key+'.html'),'utf8').match(/<main>([\s\S]*)<\/main>/)[1].replace(/^<h1>[\s\S]*?<\/h1>/,'');
 assert(html.includes(original));assert(html.includes('lang="zh-CN" dir="ltr"'));
}
console.log('PASS20-language page bindings/local links,legal V0.4 exact source,unchanged approved photo asset,release states; '+
 (release.android?'full APK bytes/SHA256 verified':'no APK supplied; download NOT verified'));
