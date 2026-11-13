import fs from 'node:fs';
const file = new URL('../contracts/locales/messages.json', import.meta.url);
const messages = JSON.parse(fs.readFileSync(file, 'utf8'));
const keys = ['more','recordCount','recordsHint','dueHint','inactivityHint','goOrganize'];
const rows = {
  'zh-CN': ['更多','{count} 条记录','一张照片，一条记录。整理时再确认当前状态。','放太久了，这些食材还新鲜吗？','这两天没做饭吗，冰箱的食材还能吃吗？','去整理'],
  'zh-TW': ['更多','{count} 筆記錄','一張照片，一筆記錄。整理時再確認目前狀態。','放太久了，這些食材還新鮮嗎？','這兩天沒煮飯嗎，冰箱的食材還能吃嗎？','去整理'],
  en: ['More','Records: {count}','One photo, one record. Confirm what remains when you organize.','It has been a while. Are these ingredients still fresh?','Haven’t cooked in a couple of days? Check what’s in the fridge.','Organize'],
  es: ['Más','Registros: {count}','Una foto, un registro. Confirma lo que queda al organizar.','Ha pasado un tiempo. ¿Siguen frescos estos alimentos?','¿Llevas un par de días sin cocinar? Revisa la nevera.','Organizar'],
  fr: ['Plus','Fiches : {count}','Une photo, une fiche. Confirmez ce qui reste au rangement.','Cela fait un moment. Ces aliments sont-ils encore frais ?','Vous n’avez pas cuisiné depuis deux jours ? Vérifiez le réfrigérateur.','Ranger'],
  de: ['Mehr','Einträge: {count}','Ein Foto, ein Eintrag. Bestätige beim Ordnen, was noch da ist.','Es ist eine Weile her. Sind diese Zutaten noch frisch?','Seit ein paar Tagen nicht gekocht? Schau in den Kühlschrank.','Ordnen'],
  'pt-BR': ['Mais','Registros: {count}','Uma foto, um registro. Confirme o que resta ao organizar.','Já faz algum tempo. Estes alimentos ainda estão frescos?','Faz alguns dias que não cozinha? Confira a geladeira.','Organizar'],
  it: ['Altro','Voci: {count}','Una foto, una voce. Conferma cosa rimane quando riordini.','È passato un po’ di tempo. Questi alimenti sono ancora freschi?','Non cucini da un paio di giorni? Controlla il frigorifero.','Riordina'],
  ja: ['もっと見る','記録：{count}件','写真1枚で記録1件。整理するときに残量を確認します。','しばらく経ちました。この食材はまだ新鮮ですか？','ここ2日ほど料理していませんか？冷蔵庫の中を確認しましょう。','整理する'],
  ko: ['더 보기','기록: {count}개','사진 한 장이 기록 하나입니다. 정리할 때 남은 양을 확인하세요.','시간이 좀 지났네요. 이 식재료는 아직 신선한가요?','며칠 동안 요리하지 않으셨나요? 냉장고를 확인해 보세요.','정리하기'],
  ar: ['المزيد','السجلات: {count}','صورة واحدة لكل سجل. أكّد الكمية المتبقية عند الترتيب.','مر بعض الوقت. هل لا تزال هذه المكونات طازجة؟','لم تطبخ منذ يومين؟ تحقّق مما في الثلاجة.','ترتيب'],
  hi: ['और देखें','रिकॉर्ड: {count}','एक फ़ोटो, एक रिकॉर्ड। व्यवस्थित करते समय बची मात्रा की पुष्टि करें।','काफ़ी समय हो गया। क्या ये सामग्री अभी भी ताज़ा हैं?','कुछ दिनों से खाना नहीं बनाया? फ़्रिज में रखी चीज़ें जाँचें।','व्यवस्थित करें'],
  id: ['Lainnya','Catatan: {count}','Satu foto, satu catatan. Konfirmasikan sisa bahan saat merapikan.','Sudah cukup lama. Apakah bahan-bahan ini masih segar?','Sudah beberapa hari tidak memasak? Periksa isi kulkas.','Rapikan'],
  ru: ['Ещё','Записи: {count}','Одно фото — одна запись. Уточняйте остаток при проверке.','Прошло немало времени. Эти продукты ещё свежие?','Пару дней не готовили? Проверьте продукты в холодильнике.','Проверить'],
  tr: ['Diğer','Kayıtlar: {count}','Bir fotoğraf, bir kayıt. Düzenlerken kalan miktarı doğrulayın.','Biraz zaman geçti. Bu malzemeler hâlâ taze mi?','Birkaç gündür yemek yapmadınız mı? Buzdolabını kontrol edin.','Düzenle'],
  vi: ['Thêm','Bản ghi: {count}','Một ảnh, một bản ghi. Xác nhận lượng còn lại khi sắp xếp.','Đã khá lâu rồi. Những thực phẩm này còn tươi không?','Vài ngày chưa nấu ăn? Hãy kiểm tra thực phẩm trong tủ lạnh.','Sắp xếp'],
  th: ['เพิ่มเติม','รายการ: {count}','หนึ่งภาพ หนึ่งรายการ ยืนยันปริมาณที่เหลือเมื่อจัดระเบียบ','ผ่านมาสักพักแล้ว วัตถุดิบเหล่านี้ยังสดอยู่ไหม?','ไม่ได้ทำอาหารมาสองสามวันแล้วหรือ? ลองตรวจดูในตู้เย็น','จัดระเบียบ'],
  nl: ['Meer','Registraties: {count}','Eén foto, één registratie. Bevestig bij het ordenen wat er over is.','Het is al een tijdje geleden. Zijn deze ingrediënten nog vers?','Al een paar dagen niet gekookt? Controleer de koelkast.','Ordenen'],
  pl: ['Więcej','Liczba wpisów: {count}','Jedno zdjęcie, jeden wpis. Podczas porządkowania potwierdź, ile zostało.','Minęło już trochę czasu. Czy te produkty są nadal świeże?','Nie gotowano od kilku dni? Sprawdź zawartość lodówki.','Uporządkuj'],
  uk: ['Більше','Записи: {count}','Одне фото — один запис. Під час упорядкування підтвердьте залишок.','Минуло чимало часу. Ці продукти ще свіжі?','Кілька днів не готували? Перевірте продукти в холодильнику.','Упорядкувати'],
};
for (const [locale, row] of Object.entries(rows)) {
  if (row.length !== keys.length) throw new Error(`Invalid locale: ${locale}`);
  keys.forEach((key, index) => messages[locale][key] = row[index]);
}
fs.writeFileSync(file, JSON.stringify(messages, null, 2) + '\n');
