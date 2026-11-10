#!/usr/bin/env node

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const VAULT_HOST = 'root@121.199.10.6';

function option(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

function fail(message) {
  console.error(`[android-signing-vault] ${message}`);
  process.exit(1);
}

function parseProperties(file) {
  const values = {};
  for (const rawLine of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;
    const index = line.search(/[:=]/);
    if (index > 0) values[line.slice(0, index).trim()] = line.slice(index + 1).trim();
  }
  return values;
}

function ssh(args, options = {}) {
  const result = spawnSync('ssh', ['-o', 'BatchMode=yes', VAULT_HOST, ...args], {
    input: options.input,
    encoding: options.binary ? null : 'utf8',
    maxBuffer: 32 * 1024 * 1024,
  });
  if (result.status !== 0) fail(`SSH command failed for ${options.label ?? 'Vault operation'}`);
  return result.stdout;
}

function normalizedText(buffer) {
  return Buffer.from(buffer).toString('utf8').replace(/[\r\n]+$/, '');
}

function digest(buffer) {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

const projectId = option('--project-id');
const projectRoot = path.resolve(option('--project') ?? '');
const apply = process.argv.includes('--apply');
if (!projectId || !/^[a-z0-9][a-z0-9-]*$/.test(projectId) || !option('--project')) {
  fail('usage: store-flutter-android-signing.mjs --project-id <id> --project <flutter-root> [--apply]');
}

const standardProperties = path.join(projectRoot, 'android', 'signing', 'credentials.properties');
const legacyProperties = path.join(projectRoot, 'android', 'key.properties');
const propertiesFile = fs.existsSync(standardProperties) ? standardProperties : legacyProperties;
if (!fs.existsSync(propertiesFile)) fail('Signing properties file is missing');
const properties = parseProperties(propertiesFile);
for (const key of ['storeFile', 'storePassword', 'keyAlias', 'keyPassword']) {
  if (!properties[key]) fail(`Signing property is missing: ${key}`);
}
const keystorePath = path.resolve(path.join(projectRoot, 'android'), properties.storeFile.replaceAll('\\', path.sep));
if (!fs.existsSync(keystorePath)) fail('Signing keystore is missing');

const entries = new Map([
  [`${projectId}-android-keystore`, fs.readFileSync(keystorePath)],
  [`${projectId}-android-store-password`, Buffer.from(properties.storePassword)],
  [`${projectId}-android-key-alias`, Buffer.from(properties.keyAlias)],
  [`${projectId}-android-key-password`, Buffer.from(properties.keyPassword)],
]);
const listed = new Set(String(ssh(['fl-secret list'])).split(/\r?\n/).filter(Boolean));
const missing = [...entries.keys()].filter((name) => !listed.has(name));

if (!apply) {
  console.log(JSON.stringify({ projectId, mode: 'check', present: [...entries.keys()].filter((name) => listed.has(name)), missing }, null, 2));
  process.exit(missing.length ? 3 : 0);
}

for (const name of missing) {
  const output = String(ssh([`fl-secret set ${name}`], { input: entries.get(name), label: name })).trim();
  if (output !== `STORED ${name}`) fail(`Vault did not acknowledge ${name}`);
  console.log(`stored=${name}`);
}

for (const [name, expected] of entries) {
  const actual = ssh([`fl-secret copy ${name}`], { binary: true, label: name });
  const matches = name.endsWith('-keystore')
    ? digest(actual) === digest(expected)
    : normalizedText(actual) === normalizedText(expected);
  if (!matches) fail(`Post-write verification failed for ${name}`);
  console.log(`verified=${name}`);
}
console.log(`all_match=yes project=${projectId}`);
