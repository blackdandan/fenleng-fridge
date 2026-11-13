"""Keep the approved public preview's actual artifact kind visible in20 languages."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COPY = {
    'zh-CN': 'Debug APK · 未加固 · 仅供开发预览',
    'zh-TW': 'Debug APK · 未加固 · 僅供開發預覽',
    'en': 'Debug APK · not hardened · development preview only',
    'ja': 'デバッグAPK・未保護・開発プレビュー専用',
    'ko': '디버그 APK · 앱 강화 미적용 · 개발 미리보기 전용',
    'fr': 'APK de débogage · non renforcé · aperçu de développement',
    'de': 'Debug-APK · nicht gehärtet · nur Entwicklungsvorschau',
    'es': 'APK de depuración · sin protección adicional · vista previa',
    'pt-BR': 'APK de depuração · sem proteção adicional · prévia de desenvolvimento',
    'it': 'APK di debug · non protetto · anteprima di sviluppo',
    'ru': 'Отладочный APK · без усиленной защиты · предпросмотр разработки',
    'ar': 'ملف APK للتصحيح · غير محصّن · معاينة تطوير فقط',
    'hi': 'डीबग APK · सुरक्षा हार्डनिंग नहीं · केवल विकास पूर्वावलोकन',
    'id': 'APK debug · belum diperkuat · hanya pratinjau pengembangan',
    'th': 'APK ดีบัก · ยังไม่เสริมการป้องกัน · ตัวอย่างสำหรับการพัฒนาเท่านั้น',
    'vi': 'APK gỡ lỗi · chưa gia cố · chỉ xem trước phát triển',
    'tr': 'Hata ayıklama APK’sı · güçlendirilmemiş · geliştirme önizlemesi',
    'nl': 'Debug-APK · niet gehard · alleen ontwikkelvoorbeeld',
    'pl': 'APK debugowania · bez wzmocnionej ochrony · podgląd deweloperski',
    'uk': 'Налагоджувальний APK · без посиленого захисту · попередній перегляд',
}

if __name__ == '__main__':
    seen = set()
    for path in (ROOT / '06-project/web/src/locales').glob('*.json'):
        data = json.loads(path.read_text(encoding='utf-8'))
        for locale, values in data.items():
            values['androidPreviewKind'] = COPY[locale]
            seen.add(locale)
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    assert seen == set(COPY)
    print('Updated20 preview artifact labels')
