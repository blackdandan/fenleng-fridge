import fs from 'node:fs';
const file = new URL('../contracts/locales/messages.json', import.meta.url);
const messages = JSON.parse(fs.readFileSync(file, 'utf8'));
const values = {
  'zh-CN':'放入{zone}', 'zh-TW':'放入{zone}', en:'Store in {zone}',
  es:'Guardar en {zone}', fr:'Ranger dans {zone}', de:'In {zone} lagern',
  'pt-BR':'Guardar em {zone}', it:'Conserva in {zone}', ja:'{zone}に保存',
  ko:'{zone}에 보관', ar:'الحفظ في {zone}', hi:'{zone} में रखें',
  id:'Simpan di {zone}', ru:'Хранить в: {zone}', tr:'Saklama yeri: {zone}',
  vi:'Lưu vào {zone}', th:'เก็บใน{zone}', nl:'Bewaren in {zone}',
  pl:'Przechowuj w: {zone}', uk:'Зберігати у: {zone}',
};
for (const [locale, value] of Object.entries(values)) messages[locale].putInto = value;
fs.writeFileSync(file, JSON.stringify(messages, null, 2) + '\n');
for (const output of ['../app/apps/fridge/assets/i18n/messages.json','../mini-program/apps/miniapp/src/locales/messages.json']) {
  fs.writeFileSync(new URL(output, import.meta.url), JSON.stringify(messages,null,2)+'\n');
}
