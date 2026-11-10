#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { inspectProject } from './check-flutter-oh.mjs';

export function prepareSigning(appRoot, mode) {
  if (!['debug', 'release'].includes(mode)) throw new Error('Mode must be debug or release');
  const directory = path.join(appRoot, 'ohos/signing');
  const config = JSON.parse(fs.readFileSync(path.join(directory, 'credentials.json'), 'utf8'));
  const selected = config[mode];
  if (!config.keyAlias || !config.storePassword || !config.keyPassword || !selected) {
    throw new Error('Signing configuration incomplete');
  }
  const resolve = value => {
    if (typeof value !== 'string' || path.basename(value) !== value) throw new Error('Signing files must use stable local filenames');
    const file = path.join(directory, value);
    if (!fs.existsSync(file) || !fs.statSync(file).isFile() || fs.lstatSync(file).isSymbolicLink()) throw new Error(`Signing asset missing or invalid: ${value}`);
    return file;
  };
  return {
    name: 'fixed', type: 'HarmonyOS', material: {
      storeFile: resolve(config.storeFile), storePassword: config.storePassword,
      keyAlias: config.keyAlias, keyPassword: config.keyPassword,
      certpath: resolve(selected.certpath), profile: resolve(selected.profile),
      signAlg: 'SHA256withECDSA'
    }
  };
}

export function withSigningProfile(appRoot, signing, action) {
  const profile = path.join(appRoot, 'ohos/build-profile.json5');
  const original = fs.readFileSync(profile);
  const originalMode = fs.statSync(profile).mode & 0o777;
  // The generated Flutter template is JSON with trailing commas; never evaluate it as code.
  const value = JSON.parse(original.toString().replace(/,\s*([}\]])/g, '$1'));
  if (!Array.isArray(value.app?.products) || !value.app.products.length) throw new Error('HarmonyOS products missing');
  value.app.signingConfigs = [signing];
  for (const product of value.app.products) product.signingConfig = 'fixed';
  try {
    fs.writeFileSync(profile, JSON.stringify(value, null, 2) + '\n', { mode: 0o600 });
    fs.chmodSync(profile, 0o600);
    return action();
  } finally {
    fs.writeFileSync(profile, original);
    fs.chmodSync(profile, originalMode);
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const appRoot = path.resolve(process.argv[2] ?? '.');
    const mode = process.argv[3] ?? 'debug';
    const baseline = inspectProject(appRoot);
    if (baseline.length) throw new Error('Fixed Flutter-OH baseline check failed');
    const signing = prepareSigning(appRoot, mode);
    const buildProfile = JSON.parse(fs.readFileSync(path.join(appRoot, 'ohos/build-profile.json5'), 'utf8').replace(/,\s*([}\]])/g, '$1'));
    const product = buildProfile.app?.products?.find(value => value.name === 'default');
    const version = product?.compatibleSdkVersion;
    const compatibleVersion = typeof version === 'number' ? String(version) : String(version ?? '').match(/\((\d+)\)$/)?.[1] ?? (/^\d+$/.test(String(version)) ? String(version) : undefined);
    if (!compatibleVersion) throw new Error('Compatible API version unavailable');
    // Check signed profile identity and certificate public key before compiling.
    const check = spawnSync('node', [fileURLToPath(new URL('./verify-harmonyos-signing.mjs', import.meta.url)), appRoot, mode], { stdio: 'inherit' });
    if (check.status !== 0) throw new Error('Signing identity verification failed');
    // Hvigor requires IDE-specific encrypted passwords. Use the official SDK signer
    // after Flutter compilation, so credentials never enter build-profile.json5.
    const result = spawnSync('fvm', ['flutter', 'build', 'hap', `--${mode}`, '--no-codesign'], { cwd: appRoot, stdio: 'inherit' });
    if (result.status !== 0) throw new Error('HAP compilation failed');
    const sdk = process.env.DEVECO_SDK_HOME;
    if (!sdk) throw new Error('HarmonyOS SDK unavailable');
    const jar = path.join(sdk, 'default/openharmony/toolchains/lib/hap-sign-tool.jar');
    const input = path.join(appRoot, 'build/ohos/hap/entry-default-unsigned.hap');
    const output = path.join(appRoot, `build/ohos/hap/entry-default-${mode}-signed.hap`);
    const signed = spawnSync('java', ['-jar', jar, 'sign-app', '-mode', 'localSign',
      '-keyAlias', signing.material.keyAlias, '-appCertFile', signing.material.certpath,
      '-profileFile', signing.material.profile, '-inFile', input, '-signAlg', signing.material.signAlg,
      '-keystoreFile', signing.material.storeFile, '-keystorePwd', signing.material.storePassword,
      '-keyPwd', signing.material.keyPassword, '-outFile', output, '-compatibleVersion', compatibleVersion], { encoding: 'utf8' });
    if (signed.status !== 0) throw new Error('Official HAP signer failed');
    const verified = spawnSync('java', ['-jar', jar, 'verify-app', '-inFile', output,
      '-outCertChain', path.join(appRoot, 'build/ohos/hap/verified-cert-chain.cer'),
      '-outProfile', path.join(appRoot, 'build/ohos/hap/verified-profile.p7b')], { encoding: 'utf8' });
    if (verified.status !== 0) throw new Error('Signed HAP verification failed');
    console.log(`[harmonyos-signing] Verified signed HAP: ${output}`);
  } catch {
    // Credentials and external tool errors may contain secrets. Only print a stable failure.
    console.error('[harmonyos-signing] Build unavailable: check fixed assets, registered identity and matching certificate/Profile.');
    process.exitCode = 1;
  }
}
