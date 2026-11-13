import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const source = path.join(root, '06-project/contracts/locales/messages.json');
for (const relative of ['06-project/app/apps/fridge/assets/i18n/messages.json','06-project/mini-program/apps/miniapp/src/locales/messages.json']) {
  const target = path.join(root, relative);
  fs.mkdirSync(path.dirname(target), {recursive:true});
  fs.copyFileSync(source, target);
}
console.log('Synchronized canonical localization resources.');
