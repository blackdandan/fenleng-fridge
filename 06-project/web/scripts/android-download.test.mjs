import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import {prepareAndroidDownload} from './android-download.mjs';

function fixture(t) {
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'fridge-website-artifact-'));
  t.after(()=>{
    const actual=fs.realpathSync(root),parent=fs.realpathSync(os.tmpdir());
    assert.equal(path.dirname(actual),parent);assert.ok(path.basename(actual).startsWith('fridge-website-artifact-'));fs.rmSync(actual,{recursive:true});
  });
  const write=(file,value)=>{fs.mkdirSync(path.dirname(path.join(root,file)),{recursive:true});fs.writeFileSync(path.join(root,file),value);};
  const bytes=Buffer.from('synthetic APK content'),sha256=crypto.createHash('sha256').update(bytes).digest('hex'),certificate='a'.repeat(64);
  write('app.apk',bytes);write('02-engineering/implementation-status.json',JSON.stringify({verified:{androidCurrentDebugBuild:{status:'passed',apk:'app.apk',sha256}}}));
  write('05-knowledge/signinfo/application-signing-info.json',JSON.stringify({android:{certificateFingerprintSha256:certificate}}));
  const executable=process.platform==='win32'?'aapt.exe':'aapt';
  write('sdk/build-tools/35.0.0/'+executable,'');write('sdk/build-tools/36.0.0/'+executable,'');
  const calls=[];
  const f={root,sha256,certificate,calls,write,environment:{ANDROID_HOME:path.join(root,'sdk'),JAVA_HOME:path.join(root,'jdk')},
    inspect:(executable,args)=>{calls.push({executable,args});return args[0]==='dump'?
      "package: name='com.fenlengtech.fridge' versionCode='1' versionName='0.1.0'":`Signer #1 certificate SHA-256 digest: ${f.signer || certificate}`;}};
  return f;
}
test('ordinary build defaults to the verified artifact and inspects version and fixed signature',t=>{
  const f=fixture(t),result=prepareAndroidDownload(f);
  assert.equal(result.absolute,path.join(f.root,'app.apk'));
  assert.deepEqual(result.metadata,{url:'downloads/fenleng-fridge_latest.apk',artifactFilename:'fridge-0.1.0-1-android-debug.apk',version:'0.1.0',build:'1',bytes:21,
    sha256:f.sha256,certificateSha256:f.certificate,kind:'debug-preview'});
  assert.ok(f.calls[0].executable.includes('36.0.0'));assert.equal(f.calls[1].args[0],'-jar');
});
test('mismatched or missing recorded artifact fails before inspecting or replacing website output',t=>{
  const f=fixture(t);f.write('app.apk','changed bytes');
  assert.throws(()=>prepareAndroidDownload(f),/differs from the recorded build/);assert.equal(f.calls.length,0);
  fs.unlinkSync(path.join(f.root,'app.apk'));
  assert.throws(()=>prepareAndroidDownload(f),/Recorded APK is missing/);assert.equal(f.calls.length,0);
});
test('intentional source-only preview is explicit and cannot be combined with an APK override',t=>{
  const f=fixture(t);fs.unlinkSync(path.join(f.root,'app.apk'));
  assert.equal(prepareAndroidDownload({...f,args:['--without-android']}),null);assert.equal(f.calls.length,0);
  assert.throws(()=>prepareAndroidDownload({...f,args:['--without-android','--android-apk','app.apk']}),/not both/);
  assert.throws(()=>prepareAndroidDownload({...f,args:['--android-apk']}),/needs a value/);
});
test('a different signing identity is not published under the recorded download identity',t=>{
  const f=fixture(t);f.signer='b'.repeat(64);assert.throws(()=>prepareAndroidDownload(f),/fixed signing identity mismatch/);
});
test('projects without a verified APK still produce a no-download plan without toolchain probes',t=>{
  const f=fixture(t);f.write('02-engineering/implementation-status.json','{"verified":{}}');
  assert.equal(prepareAndroidDownload(f),null);assert.equal(f.calls.length,0);
});
