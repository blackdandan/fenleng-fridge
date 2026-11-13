import fs from 'node:fs';
const file=new URL('../contracts/locales/messages.json',import.meta.url);
const messages=JSON.parse(fs.readFileSync(file,'utf8'));
const values={
 'zh-CN':'整理待检查食材','zh-TW':'整理待檢查食材',en:'Review pending food',es:'Revisar alimentos pendientes',
 fr:'Vérifier les aliments en attente',de:'Fällige Lebensmittel prüfen','pt-BR':'Conferir alimentos pendentes',it:'Controlla gli alimenti in attesa',
 ja:'確認待ちの食材を整理',ko:'확인할 식재료 정리',ar:'مراجعة الطعام بانتظار الفحص',hi:'जाँच के लिए लंबित खाद्य पदार्थ देखें',
 id:'Periksa makanan yang tertunda',ru:'Проверить ожидающие продукты',tr:'Bekleyen yiyecekleri kontrol et',vi:'Kiểm tra thực phẩm đang chờ',
 th:'จัดการอาหารที่รอตรวจ',nl:'Open te controleren eten',pl:'Sprawdź oczekującą żywność',uk:'Перевірити продукти в очікуванні',
};
for(const [locale,value]of Object.entries(values))messages[locale].notificationOpen=value;
for(const output of ['../contracts/locales/messages.json','../app/apps/fridge/assets/i18n/messages.json','../mini-program/apps/miniapp/src/locales/messages.json'])fs.writeFileSync(new URL(output,import.meta.url),JSON.stringify(messages,null,2)+'\n');
