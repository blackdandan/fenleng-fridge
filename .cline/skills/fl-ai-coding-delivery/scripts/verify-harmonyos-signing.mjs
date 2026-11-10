#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { X509Certificate, createHash } from 'node:crypto';
import { prepareSigning } from './package-flutter-harmonyos.mjs';
import { fileURLToPath } from 'node:url';

export function verifySigning(appRoot, mode, run = spawnSync) {
  const signing = prepareSigning(appRoot, mode).material;
  let repository = path.resolve(appRoot);
  while (!fs.existsSync(path.join(repository, '05-knowledge/signinfo/application-signing-info.json'))) {
    const parent = path.dirname(repository);
    if (parent === repository) throw new Error('Identity register missing');
    repository = parent;
  }
  const register = JSON.parse(fs.readFileSync(path.join(repository, '05-knowledge/signinfo/application-signing-info.json'))).harmonyos;
  const bundle = JSON.parse(fs.readFileSync(path.join(appRoot, 'ohos/AppScope/app.json5'))).app.bundleName;
  if (!register?.appIdentifier || register.bundleName !== bundle) throw new Error('Registered identity missing or drifted');
  const env = { ...process.env, FL_HMOS_PASSWORD: signing.storePassword };
  const key = run('keytool', ['-exportcert', '-rfc', '-keystore', signing.storeFile, '-storepass:env', 'FL_HMOS_PASSWORD', '-alias', signing.keyAlias], { encoding: 'utf8', env });
  if (key.status !== 0) throw new Error('Key unavailable');
  const publicKey = new X509Certificate(key.stdout).publicKey.export({ type: 'spki', format: 'der' });
  const publicKeySha256 = createHash('sha256').update(publicKey).digest('hex');
  if (register.publicKeySha256 && register.publicKeySha256 !== publicKeySha256) throw new Error('Registered public key drift');
  const certBytes = fs.readFileSync(signing.certpath);
  const pemChain = certBytes.toString().match(/-----BEGIN CERTIFICATE-----[\s\S]+?-----END CERTIFICATE-----/g);
  const certificates = pemChain ? pemChain.map(pem => new X509Certificate(pem)) : [new X509Certificate(certBytes)];
  const cert = certificates.find(value => !value.ca && publicKey.equals(value.publicKey.export({ type: 'spki', format: 'der' })));
  if (!cert) throw new Error('Certificate key drift');
  if (register[mode]?.certificateFingerprintSha256 && register[mode].certificateFingerprintSha256 !== cert.fingerprint256) throw new Error('Registered certificate drift');
  if (!publicKey.equals(cert.publicKey.export({ type: 'spki', format: 'der' }))) throw new Error('Certificate key drift');
  if (Date.parse(cert.validFrom) > Date.now() || Date.parse(cert.validTo) <= Date.now()) throw new Error('Certificate expired');
  // CMS signature verification checks the container signature, while Huawei trust is
  // provided by obtaining the Profile from the authenticated official console.
  const profile = run('openssl', ['cms', '-verify', '-inform', 'DER', '-in', signing.profile, '-noverify'], { encoding: 'utf8' });
  if (profile.status !== 0) throw new Error('Profile signature invalid');
  const data = JSON.parse(profile.stdout);
  if (data.type !== mode || data['bundle-info']?.['bundle-name'] !== bundle || String(data['bundle-info']?.['app-identifier']) !== String(register.appIdentifier)) throw new Error('Profile identity/type drift');
  const embedded = data['bundle-info'][mode === 'debug' ? 'development-certificate' : 'distribution-certificate'];
  const profileCert = new X509Certificate(embedded.includes('BEGIN CERTIFICATE') ? embedded : Buffer.from(embedded, 'base64'));
  if (!cert.raw.equals(profileCert.raw)) throw new Error('Profile certificate drift');
  if (!data.validity || !Number.isFinite(data.validity['not-after']) || data.validity['not-after'] * 1000 <= Date.now() || !Number.isFinite(data.validity['not-before']) || data.validity['not-before'] * 1000 > Date.now()) throw new Error('Profile validity unavailable or expired');
  return { bundleName: bundle, appIdentifier: register.appIdentifier, mode, certificateFingerprint: cert.fingerprint256, publicKeySha256 };
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { console.log(JSON.stringify(verifySigning(path.resolve(process.argv[2] ?? '.'), process.argv[3] ?? 'debug'))); }
  catch { console.error('[harmonyos-signing] Missing, invalid, expired or mismatched signing identity.'); process.exitCode = 1; }
}
