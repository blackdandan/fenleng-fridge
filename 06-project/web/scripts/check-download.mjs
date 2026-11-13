import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const base=process.env.FRIDGE_WEB_URL||'http://127.0.0.1:4817/';
const releaseResponse=await fetch(new URL('release.json',base));assert(releaseResponse.ok);
const release=await releaseResponse.json();assert(release.android,'Build with a verified preview APK before download QA');
const response=await fetch(new URL(release.android.url,base));assert.equal(response.status,200);
assert(response.headers.get('content-type').includes('application/vnd.android.package-archive'));
const digest=crypto.createHash('sha256');let bytes=0;
for await(const chunk of response.body){digest.update(chunk);bytes+=chunk.byteLength;}
const sha256=digest.digest('hex');assert.equal(bytes,release.android.bytes);assert.equal(sha256,release.android.sha256);
const report={completed:true,scope:'Full HTTP GET body,not just HEAD/range or a cancelled browser download',bytes,sha256,
 version:release.android.version,build:release.android.build,kind:release.android.kind};
fs.writeFileSync(path.join(root,'02-engineering/evidence/website/download-results.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));
