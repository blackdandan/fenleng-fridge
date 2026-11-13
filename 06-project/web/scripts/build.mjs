import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {prepareAndroidDownload} from './android-download.mjs';
import {websiteAnalyticsConfig} from './analytics-config.mjs';
import {buildSync} from 'esbuild';
import {fileURLToPath} from 'node:url';
const web=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const root=path.resolve(web,'../..');const src=path.join(web,'src');const dist=path.join(web,'dist');
const args=process.argv.slice(2);
const read=p=>fs.readFileSync(p,'utf8');const json=p=>JSON.parse(read(p));
const escape=value=>String(value).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
const androidArtifact=prepareAndroidDownload({root,args});
const analytics=websiteAnalyticsConfig(process.env,json(path.join(web,'package.json')).version);
if(fs.existsSync(dist)){
 const actual=fs.realpathSync(dist);
 assert.equal(path.dirname(actual),fs.realpathSync(web));assert.equal(path.basename(actual),'dist');
 fs.rmSync(actual,{recursive:true});
}
fs.mkdirSync(path.join(dist,'assets'),{recursive:true});
for(const name of ['styles.css','controls.css','text-layout.css','header-layout.css','accessibility.css','site.js','mini-legal.js','site-consent.js','site-consent.css','site-privacy.js'])fs.copyFileSync(path.join(src,name),path.join(dist,name));
buildSync({entryPoints:[path.join(src,'anonymous-collector.js')],outfile:path.join(dist,'anonymous-analytics.js'),bundle:true,format:'esm',platform:'browser',target:'es2020',minify:true});
fs.copyFileSync(path.join(src,'assets/food-photos.png'),path.join(dist,'assets/food-photos.png'));
const core=json(path.join(root,'06-project/contracts/locales/messages.json'));
fs.writeFileSync(path.join(dist,'mini-legal-data.js'),'window.FRIDGE_MINI_LEGAL = '+JSON.stringify(Object.fromEntries(Object.entries(core).map(([locale,values]) => [locale,{withdraw:values.privacyWithdrawLink,error:values.error}])) )+';\n');
const webCopy={};
for(const name of fs.readdirSync(path.join(src,'locales')).filter(x=>x.endsWith('.json'))){
 for(const [locale,values]of Object.entries(json(path.join(src,'locales',name)))){
  assert(!webCopy[locale],`Duplicate locale ${locale}`);webCopy[locale]=values;
 }
}
assert.equal(Object.keys(webCopy).length,20);
const keys=Object.keys(webCopy['zh-CN']).sort();
for(const locale of Object.keys(core))assert.deepEqual(Object.keys(webCopy[locale]||{}).sort(),keys,locale);
const template=read(path.join(src,'index.html'));
const coreKeys=[...new Set(['_localeName','system','language','terms','privacy','filingPending','agree','decline','back','retry','error','privacyWithdrawLink','privacyWithdrawFailed',
 ...[...template.matchAll(/data-(?:core|format)="([^"]+)"/g)].map(m=>m[1])])];
const locales={};
for(const locale of Object.keys(core)){
 for(const key of keys)assert.equal(typeof webCopy[locale][key],'string');
 locales[locale]={...Object.fromEntries(coreKeys.map(k=>{assert(core[locale][k],`${locale}:${k}`);return[k,core[locale][k]];})),...webCopy[locale]};
}
fs.writeFileSync(path.join(dist,'site-data.js'),'window.FRIDGE_SITE = '+JSON.stringify({locales,analytics})+';\n');
const android=androidArtifact?.metadata ?? null;
if(androidArtifact){
 fs.mkdirSync(path.join(dist,'downloads'),{recursive:true});fs.copyFileSync(androidArtifact.absolute,path.join(dist,'downloads',androidArtifact.filename));
}
const publicMetadata={releaseStatus:'development',android,ios:{status:'unreleased'},harmonyos:{status:'unreleased'},wechat:{status:'unreleased'},legalVersion:'V0.4'};
fs.writeFileSync(path.join(dist,'release.json'),JSON.stringify(publicMetadata,null,2)+'\n');
function cards(prefix=''){
 const androidCard=android?`<a class="button android-download" data-i18n="androidDownload" href="${prefix}${android.url}" download>下载 Android 开发预览</a><div class="artifact-meta"><p>Android ${escape(android.version)} (${escape(android.build)}) · ${(android.bytes/1048576).toFixed(1)} MiB</p><p data-i18n="androidPreviewKind">Debug APK · 未加固 · 仅供开发预览</p><span class="hash-label">SHA-256</span><code dir="ltr">${android.sha256}</code><p data-i18n="preview">开发预览，尚未正式发布</p></div>`:`<div class="channel"><strong>Android</strong><span data-i18n="unreleased">尚未发布</span></div>`;
 return androidCard+['iPhone / iPad','HarmonyOS NEXT','WeChat Mini Program'].map(name=>`<div class="channel"><strong>${name}</strong><span data-i18n="unreleased">尚未发布</span></div>`).join('');
}
function footer(prefix=''){
 return `<footer><div class="footer-top"><div><a class="wordmark" href="${prefix||'./'}" data-i18n="name">冰箱库存管理</a><p data-core="localOnly">照片与库存仅存本机</p></div><div class="footer-links"><a href="${prefix}terms/" data-core="terms">用户协议</a><a href="${prefix}privacy/" data-core="privacy">隐私政策</a><a href="mailto:fenlengtech@163.com" data-i18n="contact">联系我们</a></div></div><div class="operator"><p><span data-i18n="operator">运营主体</span>：杭州临安芬棱软件设计工作室（个体工商户）</p><p><a href="mailto:fenlengtech@163.com">fenlengtech@163.com</a>　<a href="tel:18234132630">18234132630</a></p></div><div class="footer-bottom"><span data-i18n="preview">开发预览，尚未正式发布</span><a href="https://beian.miit.gov.cn" target="_blank" rel="noopener"><span data-i18n="websiteFiling">网站备案号待登记</span> · <span data-core="filingPending">APP 备案号待登记</span></a></div></footer>`;
}
fs.writeFileSync(path.join(dist,'index.html'),template.replace('<!-- RELEASE_CARDS -->',cards()).replace('<!-- FOOTER -->',footer()).replace('href="controls.css">','href="controls.css"><link rel="stylesheet" href="text-layout.css"><link rel="stylesheet" href="header-layout.css"><link rel="stylesheet" href="accessibility.css">'));
function shell(body,title,legal=''){
 return `<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light"><title>${title} · 冰箱库存管理</title><link rel="stylesheet" href="../styles.css"><link rel="stylesheet" href="../controls.css"><link rel="stylesheet" href="../text-layout.css"><link rel="stylesheet" href="../header-layout.css"><script defer src="../site-data.js"></script><script defer src="../site.js"></script></head><body${legal?` data-legal="${legal}"`:''}><a class="skip" href="#main" data-i18n="skip">跳到正文</a><header class="site-header"><a class="wordmark" href="../" data-i18n="name">冰箱库存管理</a><label class="language-control"><span data-core="language">语言</span><select id="language" aria-label="语言"></select></label></header><main id="main" class="legal-main"><a class="home-link" href="../"><span aria-hidden="true">←</span><span data-i18n="backSite">返回官网</span></a>${body}</main>${footer('../')}</body></html>`;
}
for(const [key,filename]of [['terms','user-agreement.md'],['privacy','privacy-policy.md']]){
 const source=read(path.join(root,'01-product/mvp',filename));
 assert.equal(read(path.join(root,'06-project/app/apps/fridge/assets/legal',`${key}.md`)),source,'Legal assets are stale; regenerate shared legal content');
 assert(source.includes('/ V0.4'),'Legal version mismatch');
 const html=read(path.join(root,'06-project/app/apps/fridge/assets/legal',`${key}.html`));
 const body=html.match(/<main>([\s\S]*)<\/main>/)?.[1];assert(body,'Missing offline legal body');
 const content=`<h1 data-core="${key}">${escape(core['zh-CN'][key])}</h1><p class="legal-notice" data-i18n="legalNotice">${escape(webCopy['zh-CN'].legalNotice)}</p><p class="legal-meta">V0.4</p><article class="legal-document" lang="zh-CN" dir="ltr">${body.replace(/^<h1>[\s\S]*?<\/h1>/,'')}</article>`;
 fs.mkdirSync(path.join(dist,key),{recursive:true});fs.writeFileSync(path.join(dist,key,'index.html'),shell(content,core['zh-CN'][key],key).replace('</head>','<script defer src="../mini-legal-data.js"></script><script defer src="../mini-legal.js"></script></head>'));
}
fs.mkdirSync(path.join(dist,'app'),{recursive:true});
fs.writeFileSync(path.join(dist,'app/index.html'),shell(`<h1 data-i18n="availabilityTitle">${escape(webCopy['zh-CN'].availabilityTitle)}</h1><p data-i18n="availabilityBody">${escape(webCopy['zh-CN'].availabilityBody)}</p><div class="download-options">${cards('../')}</div>`,webCopy['zh-CN'].download));
// The shared shell uses the same accessibility rules as the landing page.
for(const page of ['terms/index.html','privacy/index.html','app/index.html']){
 const file=path.join(dist,page);fs.writeFileSync(file,read(file).replace('href="../header-layout.css">','href="../header-layout.css"><link rel="stylesheet" href="../accessibility.css">'));
}
for(const page of ['index.html','terms/index.html','privacy/index.html','app/index.html']) {
 const prefix=page==='index.html'?'':'../',file=path.join(dist,page);
 fs.writeFileSync(file,read(file).replace('</head>',`<link rel="stylesheet" href="${prefix}site-consent.css"><script type="module" src="${prefix}site-consent.js"></script></head>`));
}
console.log(JSON.stringify({status:'built-local-not-deployed',directory:dist,languages:20,websiteKeys:keys.length,legalVersion:'V0.4',android},null,2));
