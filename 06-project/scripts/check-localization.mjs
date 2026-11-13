import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const files = [
  '06-project/contracts/locales/messages.json',
  '06-project/app/apps/fridge/assets/i18n/messages.json',
  '06-project/mini-program/apps/miniapp/src/locales/messages.json',
];
const required = ['zh-CN','zh-TW','en','es','fr','de','pt-BR','it','ja','ko','ar','hi','id','ru','tr','vi','th','nl','pl','uk'];
const messages = JSON.parse(fs.readFileSync(path.join(root, files[0]), 'utf8'));
assert.deepEqual(Object.keys(messages).sort(), [...required].sort());
const keys = Object.keys(messages['zh-CN']).sort();
for (const locale of required) {
  assert.deepEqual(Object.keys(messages[locale]).sort(), keys, `${locale} key coverage`);
  for (const key of keys) {
    assert.ok(typeof messages[locale][key] === 'string' && messages[locale][key].trim(), `${locale}.${key} actual translation`);
    const parameters = value => [...value.matchAll(/\{([a-zA-Z][\w]*)\}/g)].map(m => m[1]).sort();
    assert.deepEqual(parameters(messages[locale][key]), parameters(messages['zh-CN'][key]), `${locale}.${key} variables`);
  }
}
for (const file of files.slice(1)) assert.deepEqual(JSON.parse(fs.readFileSync(path.join(root, file), 'utf8')), messages, `${file} canonical source parity`);
console.log(`PASS ${required.length} locales, ${keys.length} core UI keys, variable parity and two client bundles`);
