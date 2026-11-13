import fs from 'node:fs';import path from 'node:path';
const dir=path.resolve(import.meta.dirname,'../src/locales');
const keys=['websitePrivacyTitle','websitePrivacyBody','websitePrivacyChoices'];
const copy={
 'zh-CN':['网站协议与隐私','同意本网站用户协议和隐私政策后，可记录匿名的应用入口使用情况。统计不携带登录凭据或 Cookie。暂不同意仍可浏览和下载。','网站协议与隐私选择'],
 'zh-TW':['網站協議與隱私','同意本網站使用者協議和隱私政策後，可記錄匿名的應用入口使用情況。統計不攜帶登入憑證或 Cookie。暫不同意仍可瀏覽和下載。','網站協議與隱私選擇'],
 en:['Website terms and privacy','Accept this website’s terms and privacy policy to allow anonymous counts of app entry actions. Statistics send no sign-in credentials or cookies. You can still browse and download without accepting.','Website terms and privacy choices'],
 es:['Acuerdo y privacidad del sitio','Al aceptar el acuerdo y la política de privacidad, se pueden contar anónimamente los accesos a la aplicación. Las estadísticas no envían credenciales ni cookies. Puedes navegar y descargar sin aceptar.','Opciones de acuerdo y privacidad del sitio'],
 fr:['Conditions et confidentialité du site','Accepter les conditions et la politique permet de compter anonymement les accès à l’application. Les statistiques n’envoient ni identifiants de connexion ni cookies. La navigation et le téléchargement restent possibles sans accepter.','Choix des conditions et de confidentialité'],
 de:['Website-Bedingungen und Datenschutz','Mit Zustimmung zu Bedingungen und Datenschutz können App-Aufrufe anonym gezählt werden. Die Statistik sendet keine Anmeldedaten oder Cookies. Ohne Zustimmung kannst du weiter surfen und herunterladen.','Website-Bedingungen und Datenschutzauswahl'],
 'pt-BR':['Termos e privacidade do site','Ao aceitar os termos e a política, os acessos ao aplicativo podem ser contados anonimamente. As estatísticas não enviam credenciais nem cookies. Você pode navegar e baixar sem aceitar.','Escolhas de termos e privacidade do site'],
 it:['Termini e privacy del sito','Accettando termini e informativa si possono contare in forma anonima gli accessi all’app. Le statistiche non inviano credenziali o cookie. Puoi navigare e scaricare anche senza accettare.','Scelte per termini e privacy del sito'],
 ja:['サイトの規約とプライバシー','本サイトの規約とプライバシーポリシーに同意すると、アプリへのアクセスを匿名で集計できます。ログイン情報やCookieは統計に送信しません。同意しなくても閲覧とダウンロードができます。','サイトの規約とプライバシーの選択'],
 ko:['사이트 약관 및 개인정보','사이트 약관과 개인정보 처리방침에 동의하면 앱 접근을 익명으로 집계할 수 있습니다. 통계에는 로그인 정보나 쿠키를 보내지 않습니다. 동의하지 않아도 탐색과 다운로드를 할 수 있습니다.','사이트 약관 및 개인정보 선택'],
 ar:['شروط الموقع والخصوصية','تتيح الموافقة على شروط الموقع وسياسة الخصوصية إحصاء فتح التطبيق بصورة مجهولة. لا ترسل الإحصاءات بيانات الدخول أو ملفات تعريف الارتباط. يمكنك التصفح والتنزيل دون الموافقة.','خيارات شروط الموقع والخصوصية'],
 hi:['वेबसाइट की शर्तें और गोपनीयता','शर्तों और गोपनीयता नीति से सहमत होने पर ऐप खोलने की गुमनाम गिनती की जा सकती है। आँकड़ों में लॉगिन जानकारी या कुकी नहीं भेजी जाती। असहमत होने पर भी आप ब्राउज़ और डाउनलोड कर सकते हैं।','वेबसाइट की शर्तों और गोपनीयता के विकल्प'],
 id:['Ketentuan dan privasi situs','Persetujuan atas ketentuan dan kebijakan memungkinkan penghitungan akses aplikasi secara anonim. Statistik tidak mengirim kredensial masuk atau cookie. Anda tetap dapat menjelajah dan mengunduh tanpa menyetujui.','Pilihan ketentuan dan privasi situs'],
 ru:['Условия сайта и конфиденциальность','Согласие с условиями и политикой позволяет анонимно считать переходы к приложению. Статистика не передаёт данные входа и файлы cookie. Просмотр и загрузка доступны без согласия.','Выбор условий сайта и конфиденциальности'],
 tr:['Site koşulları ve gizlilik','Koşullar ve gizlilik politikası kabul edildiğinde uygulama girişleri anonim olarak sayılabilir. İstatistikler giriş bilgisi veya çerez göndermez. Kabul etmeden de gezinebilir ve indirebilirsiniz.','Site koşulları ve gizlilik tercihleri'],
 vi:['Điều khoản và quyền riêng tư của trang','Đồng ý điều khoản và chính sách cho phép đếm lượt vào ứng dụng ẩn danh. Thống kê không gửi thông tin đăng nhập hay cookie. Bạn vẫn có thể xem và tải xuống khi chưa đồng ý.','Lựa chọn điều khoản và quyền riêng tư'],
 th:['ข้อกำหนดและความเป็นส่วนตัวของเว็บไซต์','เมื่อยอมรับข้อกำหนดและนโยบาย สามารถนับการเข้าแอปโดยไม่ระบุตัวตนได้ สถิติไม่ส่งข้อมูลเข้าสู่ระบบหรือคุกกี้ คุณยังดูเว็บไซต์และดาวน์โหลดได้โดยไม่ยอมรับ','ตัวเลือกข้อกำหนดและความเป็นส่วนตัว'],
 nl:['Websitevoorwaarden en privacy','Na akkoord met de voorwaarden en privacyverklaring kunnen appbezoeken anoniem worden geteld. Statistieken sturen geen inloggegevens of cookies mee. Je kunt zonder akkoord blijven surfen en downloaden.','Keuzes voor websitevoorwaarden en privacy'],
 pl:['Warunki strony i prywatność','Akceptacja warunków i polityki pozwala anonimowo zliczać przejścia do aplikacji. Statystyki nie wysyłają danych logowania ani plików cookie. Bez zgody nadal można przeglądać i pobierać.','Wybór warunków strony i prywatności'],
 uk:['Умови сайту та конфіденційність','Згода з умовами й політикою дозволяє анонімно рахувати переходи до застосунку. Статистика не передає дані входу чи файли cookie. Перегляд і завантаження доступні без згоди.','Вибір умов сайту та конфіденційності'],
};
let count=0;
for(const name of fs.readdirSync(dir).filter(name=>name.endsWith('.json'))) {
 const file=path.join(dir,name),data=JSON.parse(fs.readFileSync(file,'utf8'));
 for(const [locale,values]of Object.entries(data)){if(!copy[locale] || copy[locale].length!==keys.length)throw Error('Website locale missing');
  keys.forEach((key,index)=>{values[key]=copy[locale][index];});count++;}
 fs.writeFileSync(file,JSON.stringify(data,null,2)+'\n');
}
if(count!==20)throw Error('Website locale count invalid');console.log('Added unified website privacy copy in20 languages');
