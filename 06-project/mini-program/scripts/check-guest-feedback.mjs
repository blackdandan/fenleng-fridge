import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const mini=path.join(root,'06-project/mini-program');
const provenance=JSON.parse(fs.readFileSync(path.join(mini,'vendor/provenance.json'),'utf8'));
const candidate=provenance.candidate;
const sha=data=>crypto.createHash('sha256').update(data).digest('hex');
assert.equal(candidate.published,false);assert.equal(candidate.sourceMode,'local-worktree-candidate');
assert.equal(sha(fs.readFileSync(path.join(mini,'vendor',candidate.archive))),candidate.sha256);
for(const [name,hash]of Object.entries(candidate.sourceFiles)){
 const installed=path.join(mini,'packages/api-client/node_modules/@fenleng/sdk-taro',name);
 assert.equal(sha(fs.readFileSync(installed)),hash,'installed SDK source differs: '+name);
}
const view=fs.readFileSync(path.join(mini,'packages/ui-kit/src/feedback-view.tsx'),'utf8');
const locales=JSON.parse(fs.readFileSync(path.join(mini,'apps/miniapp/src/locales/messages.json'),'utf8'));
const used=[...view.matchAll(/(?:text|format)\('([^']+)'/g)].map(match=>match[1]);
for(const [locale,messages]of Object.entries(locales))for(const key of used)assert(messages[key],locale+':'+key);
assert.match(view,/maxlength=\{4000\}/);assert.match(view,/aria-label=/);
function scripts(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(entry=>entry.isDirectory()?scripts(path.join(dir,entry.name)):/\.js$/.test(entry.name)?[fs.readFileSync(path.join(dir,entry.name),'utf8')]:[]);}
const compiled=scripts(path.join(mini,'apps/miniapp/dist')).join('\n');
for(const text of ['/api/platform/v1/auth/guest/login','fridge.feedback.v1','feedbackAccepted','attachmentConsent'])assert(compiled.includes(text),'compiled feature missing: '+text);
const report={status:'passed',scope:'SDK archive and installed source integrity, UI source/locale/compiled-feature contracts only',
 sdk:candidate.archive,sdkSha256:candidate.sha256,sdkPublished:false,sdkBaseline:candidate.baselineCommit,
 installedSdkFiles:Object.keys(candidate.sourceFiles).length,locales:Object.keys(locales).length,
 nodes:['2:289','2:303','2:317'],nativeVisual:'not-run-no-WeChat-developer-tools',productionProvider:'not-run'};
const out=path.join(root,'02-engineering/evidence/mini-program/guest-feedback-source-results.json');
fs.writeFileSync(out,JSON.stringify(report,null,2)+'\n');
console.log('PASS candidate archive/installed SDK integrity, feedback source/locale/compiled contracts; native visual not-run');
