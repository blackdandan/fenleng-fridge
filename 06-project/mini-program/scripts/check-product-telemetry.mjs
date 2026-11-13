import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
const mini=path.resolve(import.meta.dirname,'..'),root=path.resolve(mini,'../..'),sha=data=>crypto.createHash('sha256').update(data).digest('hex');
const canonical=JSON.parse(fs.readFileSync(path.join(root,'01-product/mvp/telemetry-events.json'),'utf8'));
assert.deepEqual(JSON.parse(fs.readFileSync(path.join(mini,'apps/miniapp/src/config/telemetry-events.json'),'utf8')),canonical);
assert.equal(canonical.separateAnalyticsToggle,false);assert.equal(canonical.consentSource,'unified-privacy-v0.4');
const provenance=JSON.parse(fs.readFileSync(path.join(mini,'vendor/provenance.json'),'utf8'));
const taro=path.join(mini,'packages/api-client/node_modules/@fenleng/sdk-taro');
const core=path.dirname(createRequire(fs.realpathSync(path.join(taro,'index.js'))).resolve('@fenleng/sdk-core'));
for(const [candidate,installed]of [[provenance.candidate,taro],[provenance.coreCandidate,core]]) {
  assert.equal(candidate.published,false);assert.equal(candidate.sourceMode,'local-worktree-candidate');
  assert.equal(sha(fs.readFileSync(path.join(mini,'vendor',candidate.archive))),candidate.sha256);
  for(const [name,hash]of Object.entries(candidate.sourceFiles))assert.equal(sha(fs.readFileSync(path.join(installed,name))),hash,name);
}
function scripts(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(entry=>entry.isDirectory()?scripts(path.join(dir,entry.name)):entry.name.endsWith('.js')?[path.join(dir,entry.name)]:[]);}
const compiled=scripts(path.join(mini,'apps/miniapp/dist')).map(file=>fs.readFileSync(file,'utf8')).join('\n');
for(const event of canonical.events.filter(event=>!event.name.includes('website')))assert.ok(compiled.includes(event.name),event.name);
assert.ok(compiled.includes('/api/platform/v1/telemetry/events'));
console.log('PASS canonical event catalog, both installed candidate archives and compiled7-event presence; not production analytics proof');
