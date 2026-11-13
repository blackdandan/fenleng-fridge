import fs from 'node:fs';
const file = new URL('../contracts/locales/messages.json', import.meta.url);
const messages = JSON.parse(fs.readFileSync(file, 'utf8'));
const keys = ['organizeZone','reviewHint','detail','lastOrganizedCaption','neverOrganized','emptyReview','undoExpired'];
const rows = {
'zh-CN':['整理{zone}食材','只确认你看过的食材。前三项会重新安排这条记录的下次检查；「没了」移入历史。','详情','上次整理 {date}','尚未整理','没有需要整理的食材','记录已发生变化，无法撤销此操作'],
'zh-TW':['整理{zone}食材','只確認你看過的食材。前三項會重新安排這筆記錄的下次檢查；「沒了」移入歷史。','詳情','上次整理 {date}','尚未整理','沒有需要整理的食材','記錄已變更，無法撤銷此操作'],
en:['Organize {zone}','Confirm only items you checked. The first three choices schedule the next check; Gone moves the record to history.','Details','Last checked {date}','Not checked yet','No ingredients to organize','Records have changed. This action can no longer be undone.'],
es:['Organizar {zone}','Confirma solo lo que hayas revisado. Las tres primeras opciones programan la próxima revisión; No queda mueve el registro al historial.','Detalles','Última revisión: {date}','Sin revisar','No hay alimentos que organizar','Los registros han cambiado. Ya no se puede deshacer esta acción.'],
fr:['Ranger : {zone}','Confirmez uniquement les aliments vérifiés. Les trois premiers choix planifient la prochaine vérification ; Plus rien déplace la fiche dans l’historique.','Détails','Dernière vérification : {date}','Pas encore vérifié','Aucun aliment à ranger','Les fiches ont changé. Cette action ne peut plus être annulée.'],
de:['{zone} ordnen','Bestätige nur geprüfte Zutaten. Die ersten drei Optionen planen die nächste Prüfung; Aufgebraucht verschiebt den Eintrag in den Verlauf.','Details','Zuletzt geprüft: {date}','Noch nicht geprüft','Keine Zutaten zum Ordnen','Die Einträge wurden geändert. Diese Aktion lässt sich nicht mehr rückgängig machen.'],
'pt-BR':['Organizar {zone}','Confirme apenas os itens verificados. As três primeiras opções agendam a próxima verificação; Acabou move o registro para o histórico.','Detalhes','Última verificação: {date}','Ainda não verificado','Nenhum alimento para organizar','Os registros mudaram. Não é mais possível desfazer esta ação.'],
it:['Riordina {zone}','Conferma solo gli alimenti controllati. Le prime tre opzioni programmano il prossimo controllo; Finito sposta la voce nella cronologia.','Dettagli','Ultimo controllo: {date}','Non ancora controllato','Nessun alimento da riordinare','Le voci sono cambiate. Questa azione non può più essere annullata.'],
ja:['{zone}の食材を整理','確認した食材だけ選んでください。最初の3項目は次の確認を設定し、「なし」は履歴へ移します。','詳細','前回の確認 {date}','未確認','整理する食材はありません','記録が変更されたため、この操作は元に戻せません。'],
ko:['{zone} 식재료 정리','확인한 식재료만 선택하세요. 앞의 세 항목은 다음 확인을 예약하고, 없음은 기록을 내역으로 옮깁니다.','상세','마지막 확인 {date}','아직 확인하지 않음','정리할 식재료가 없습니다','기록이 변경되어 이 작업을 취소할 수 없습니다.'],
ar:['ترتيب {zone}','أكّد المكونات التي فحصتها فقط. تحدد الخيارات الثلاثة الأولى موعد الفحص التالي؛ وينقل خيار نفد السجل إلى المحفوظات.','التفاصيل','آخر فحص {date}','لم يُفحص بعد','لا توجد مكونات لترتيبها','تغيّرت السجلات. لم يعد بالإمكان التراجع عن هذا الإجراء.'],
hi:['{zone} व्यवस्थित करें','केवल जाँची गई सामग्री की पुष्टि करें। पहले तीन विकल्प अगली जाँच तय करते हैं; खत्म विकल्प रिकॉर्ड को इतिहास में ले जाता है।','विवरण','पिछली जाँच {date}','अभी जाँचा नहीं गया','व्यवस्थित करने के लिए कोई सामग्री नहीं','रिकॉर्ड बदल गए हैं। अब यह कार्रवाई वापस नहीं ली जा सकती।'],
id:['Atur {zone}','Konfirmasikan hanya bahan yang sudah diperiksa. Tiga pilihan pertama menjadwalkan pemeriksaan berikutnya; Habis memindahkan catatan ke riwayat.','Detail','Terakhir diperiksa {date}','Belum diperiksa','Tidak ada bahan untuk diatur','Catatan telah berubah. Tindakan ini tidak dapat dibatalkan lagi.'],
ru:['Разобрать: {zone}','Подтверждайте только проверенные продукты. Первые три варианта назначают следующую проверку; «Закончилось» переносит запись в историю.','Подробнее','Последняя проверка: {date}','Ещё не проверено','Нет продуктов для разбора','Записи изменились. Это действие больше нельзя отменить.'],
tr:['{zone} düzenle','Yalnızca kontrol ettiğiniz malzemeleri onaylayın. İlk üç seçenek sonraki kontrolü planlar; Bitti kaydı geçmişe taşır.','Ayrıntılar','Son kontrol: {date}','Henüz kontrol edilmedi','Düzenlenecek malzeme yok','Kayıtlar değişti. Bu işlem artık geri alınamaz.'],
vi:['Sắp xếp {zone}','Chỉ xác nhận thực phẩm đã kiểm tra. Ba lựa chọn đầu lên lịch kiểm tra tiếp theo; Hết chuyển bản ghi vào lịch sử.','Chi tiết','Kiểm tra lần cuối {date}','Chưa kiểm tra','Không có thực phẩm cần sắp xếp','Bản ghi đã thay đổi. Không thể hoàn tác thao tác này nữa.'],
th:['จัดระเบียบ {zone}','ยืนยันเฉพาะวัตถุดิบที่ตรวจแล้ว สามตัวเลือกแรกจะนัดตรวจครั้งถัดไป ส่วนหมดแล้วจะย้ายรายการไปยังประวัติ','รายละเอียด','ตรวจล่าสุด {date}','ยังไม่ได้ตรวจ','ไม่มีวัตถุดิบให้จัดระเบียบ','รายการมีการเปลี่ยนแปลง ไม่สามารถเลิกทำการดำเนินการนี้ได้แล้ว'],
nl:['{zone} ordenen','Bevestig alleen gecontroleerde ingrediënten. De eerste drie keuzes plannen de volgende controle; Op verplaatst het item naar de geschiedenis.','Details','Laatst gecontroleerd: {date}','Nog niet gecontroleerd','Geen ingrediënten om te ordenen','De items zijn gewijzigd. Deze actie kan niet meer ongedaan worden gemaakt.'],
pl:['Uporządkuj: {zone}','Potwierdzaj tylko sprawdzone produkty. Pierwsze trzy opcje planują kolejną kontrolę; Brak przenosi wpis do historii.','Szczegóły','Ostatnia kontrola: {date}','Jeszcze nie sprawdzono','Brak produktów do uporządkowania','Wpisy uległy zmianie. Nie można już cofnąć tej czynności.'],
uk:['Упорядкувати: {zone}','Підтверджуйте лише перевірені продукти. Перші три варіанти планують наступну перевірку; «Закінчилося» переносить запис до історії.','Докладніше','Остання перевірка: {date}','Ще не перевірено','Немає продуктів для впорядкування','Записи змінилися. Цю дію більше не можна скасувати.'],
};
for (const [locale, values] of Object.entries(rows)) {
 if (values.length !== keys.length || !messages[locale]) throw new Error(locale);
 keys.forEach((key, i) => {messages[locale][key] = values[i];});
}
fs.writeFileSync(file, JSON.stringify(messages, null, 2) + '\n');
