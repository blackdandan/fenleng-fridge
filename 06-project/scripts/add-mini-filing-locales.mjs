import fs from 'node:fs';
const file=new URL('../contracts/locales/messages.json',import.meta.url);
const messages=JSON.parse(fs.readFileSync(file,'utf8'));
const values={'zh-CN':'小程序备案号待登记','zh-TW':'小程式備案號待登記',en:'Mini program filing number pending',
 es:'Número de registro del miniprograma pendiente',fr:'Numéro d’enregistrement du mini-programme en attente',de:'Registrierungsnummer des Mini-Programms ausstehend',
 'pt-BR':'Número de registro do miniprograma pendente',it:'Numero di registrazione del mini programma in attesa',ja:'ミニプログラムの届出番号は登録待ちです',ko:'미니프로그램 등록 번호 대기 중',
 ar:'رقم تسجيل البرنامج المصغر قيد الانتظار',hi:'मिनी प्रोग्राम की पंजीकरण संख्या लंबित है',id:'Nomor pendaftaran program mini belum tersedia',ru:'Регистрационный номер мини-программы ожидается',
 tr:'Mini program kayıt numarası bekleniyor',vi:'Đang chờ số đăng ký chương trình nhỏ',th:'รอหมายเลขจดทะเบียนมินิโปรแกรม',nl:'Registratienummer van het miniprogramma volgt nog',
 pl:'Numer rejestracyjny miniprogramu oczekuje',uk:'Очікується реєстраційний номер мініпрограми'};
for(const [locale,value]of Object.entries(values))messages[locale].miniFilingPending=value;
for(const output of ['../contracts/locales/messages.json','../app/apps/fridge/assets/i18n/messages.json','../mini-program/apps/miniapp/src/locales/messages.json'])fs.writeFileSync(new URL(output,import.meta.url),JSON.stringify(messages,null,2)+'\n');
