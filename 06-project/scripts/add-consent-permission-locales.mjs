import fs from 'node:fs';
const copy = {
  'zh-CN':'相机和通知权限将在使用对应功能时另行申请。',
  'zh-TW':'相機和通知權限將在使用對應功能時另行申請。',
  en:'Camera and notification permissions are requested separately when you use the corresponding feature.',
  es:'Los permisos de cámara y notificaciones se solicitan por separado al usar la función correspondiente.',
  fr:'Les autorisations de caméra et de notifications sont demandées séparément lorsque vous utilisez la fonction correspondante.',
  de:'Kamera- und Benachrichtigungsberechtigungen werden separat angefragt, wenn du die jeweilige Funktion nutzt.',
  'pt-BR':'As permissões de câmera e notificações são solicitadas separadamente ao usar o recurso correspondente.',
  it:'I permessi per fotocamera e notifiche vengono richiesti separatamente quando usi la relativa funzione.',
  ja:'カメラと通知の権限は、それぞれの機能を使用するときに個別に確認します。',
  ko:'카메라와 알림 권한은 해당 기능을 사용할 때 별도로 요청합니다.',
  ar:'يُطلب إذن الكاميرا والإشعارات كلٌّ على حدة عند استخدام الميزة المعنية.',
  hi:'कैमरा और सूचनाओं की अनुमति संबंधित सुविधा का उपयोग करते समय अलग से मांगी जाती है।',
  id:'Izin kamera dan notifikasi diminta secara terpisah saat Anda menggunakan fitur terkait.',
  ru:'Разрешения на камеру и уведомления запрашиваются отдельно при использовании соответствующей функции.',
  tr:'Kamera ve bildirim izinleri, ilgili özelliği kullandığınızda ayrı ayrı istenir.',
  vi:'Quyền máy ảnh và thông báo được yêu cầu riêng khi bạn sử dụng tính năng tương ứng.',
  th:'ระบบจะขอสิทธิ์กล้องและการแจ้งเตือนแยกกันเมื่อคุณใช้ฟีเจอร์ที่เกี่ยวข้อง',
  nl:'Toestemming voor de camera en meldingen wordt apart gevraagd wanneer je de betreffende functie gebruikt.',
  pl:'Uprawnienia do aparatu i powiadomień są wymagane osobno podczas korzystania z odpowiedniej funkcji.',
  uk:'Дозволи на камеру та сповіщення запитуються окремо під час використання відповідної функції.',
};
const source = new URL('../contracts/locales/messages.json', import.meta.url);
const messages = JSON.parse(fs.readFileSync(source, 'utf8'));
if (Object.keys(copy).length !== Object.keys(messages).length) throw Error('LOCALE_COUNT_INVALID');
for (const [locale, message] of Object.entries(copy)) {
  if (!messages[locale] || !message) throw Error('LOCALE_INVALID:' + locale);
  messages[locale].consentPermissionNotice = message;
}
const text = JSON.stringify(messages, null, 2) + '\n';
for (const target of ['../contracts/locales/messages.json','../app/apps/fridge/assets/i18n/messages.json','../mini-program/apps/miniapp/src/locales/messages.json']) {
  fs.writeFileSync(new URL(target, import.meta.url), text);
}
console.log('Synchronized20 locales with consent permission notice; ' + Object.keys(messages.en).length + ' keys.');
