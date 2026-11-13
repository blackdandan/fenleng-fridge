import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

/** Inspect the recorded artifact before the caller replaces any existing website files. */
export function prepareAndroidDownload({root,args=[],environment=process.env,inspect=execFileSync}) {
  const option=name=>{
    const index=args.indexOf(name);if(index<0)return null;
    assert(args[index+1] && !args[index+1].startsWith('--'),`${name} needs a value`);return args[index+1];
  };
  const explicit=option('--android-apk');
  if(args.includes('--without-android')){assert(!explicit,'Choose an APK or explicitly omit Android, not both');return null;}
  const statusFile=path.join(root,'02-engineering/implementation-status.json');
  const status=fs.existsSync(statusFile)?JSON.parse(fs.readFileSync(statusFile,'utf8')).verified?.androidCurrentDebugBuild:null;
  if(!explicit && status?.status!=='passed')return null;
  assert(status?.status==='passed' && status.apk && status.sha256,'Downloads require a verified APK record');
  const absolute=explicit?path.resolve(explicit):path.resolve(root,status.apk);
  assert(fs.existsSync(absolute),'Recorded APK is missing; build it or explicitly use --without-android');
  const sha256=crypto.createHash('sha256').update(fs.readFileSync(absolute)).digest('hex');
  assert.equal(sha256,status.sha256,'APK differs from the recorded build');
  let aapt=option('--aapt');
  if(!aapt) {
    const sdk=environment.ANDROID_HOME || environment.ANDROID_SDK_ROOT;
    assert(sdk,'Set ANDROID_HOME or pass --aapt to inspect the download');
    const tools=path.join(sdk,'build-tools'),executable=process.platform==='win32'?'aapt.exe':'aapt';
    const versions=fs.readdirSync(tools).filter(version=>fs.existsSync(path.join(tools,version,executable)))
      .sort((a,b)=>b.localeCompare(a,undefined,{numeric:true}));
    assert(versions.length,'Android build-tools aapt is unavailable');aapt=path.join(tools,versions[0],executable);
  }
  const java=option('--java') || (environment.JAVA_HOME?path.join(environment.JAVA_HOME,'bin',process.platform==='win32'?'java.exe':'java'):'java');
  const info=inspect(aapt,['dump','badging',absolute],{encoding:'utf8'});
  const match=info.match(/^package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'/m);
  assert(match,'Missing APK manifest metadata');assert.equal(match[1],'com.fenlengtech.fridge');
  const signature=inspect(java,['-jar',path.join(path.dirname(aapt),'lib/apksigner.jar'),'verify','--print-certs',absolute],{encoding:'utf8'});
  const certificate=signature.match(/Signer #1 certificate SHA-256 digest: (\w+)/)?.[1]?.toLowerCase();
  const registered=JSON.parse(fs.readFileSync(path.join(root,'05-knowledge/signinfo/application-signing-info.json'),'utf8'))
    .android.certificateFingerprintSha256.replaceAll(':','').toLowerCase();
  assert.equal(certificate,registered,'APK fixed signing identity mismatch');
  const artifactFilename=`fridge-${match[3]}-${match[2]}-android-debug.apk`;
  assert.equal(path.basename(artifactFilename),artifactFilename,'APK version cannot form a download filename');
  const filename='fenleng-fridge_latest.apk';
  const architecture=info.match(/^native-code: '([^']+)'\s*$/m)?.[1];
  return {absolute,filename,metadata:{url:'downloads/'+filename,artifactFilename,version:match[3],build:match[2],bytes:fs.statSync(absolute).size,
    sha256,certificateSha256:certificate,kind:'debug-preview',...(architecture?{architecture}:{})}};
}
