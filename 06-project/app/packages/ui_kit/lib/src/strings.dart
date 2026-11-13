import 'package:flutter/widgets.dart';

int? parseLocalizedInt(String input) {
  const ranges = [0x0660, 0x06f0, 0x0966, 0x0e50];
  final normalized = input.runes.map((code) {
    for (final start in ranges) {
      if (code >= start && code < start + 10)
        return String.fromCharCode(48 + code - start);
    }
    return String.fromCharCode(code);
  }).join();
  return int.tryParse(normalized.trim());
}

class FridgeStrings {
  final Map<String, Map<String, String>> messages;
  final String locale;
  const FridgeStrings(this.messages, this.locale);

  factory FridgeStrings.fromJson(Map<String, dynamic> json, String locale) =>
      FridgeStrings(
        json.map(
          (key, value) => MapEntry(key, Map<String, String>.from(value as Map)),
        ),
        locale,
      );

  static String resolve(
    Iterable<String> supported,
    String deviceLocale, {
    String? preference,
  }) {
    if (preference != null && supported.contains(preference)) return preference;
    final normalized = deviceLocale.replaceAll('_', '-');
    if (supported.contains(normalized)) return normalized;
    if (normalized.startsWith('zh')) {
      return normalized.contains('TW') ||
              normalized.contains('HK') ||
              normalized.contains('Hant')
          ? 'zh-TW'
          : 'zh-CN';
    }
    final language = normalized.split('-').first;
    return supported.firstWhere(
      (s) => s.split('-').first == language,
      orElse: () => 'zh-CN',
    );
  }

  String text(String key) {
    final value = messages[locale]?[key] ?? messages['zh-CN']?[key];
    if (value == null) throw ArgumentError('LOCALIZATION_KEY_UNKNOWN: $key');
    return value;
  }

  String format(String key, Map<String, Object> values) =>
      text(key).replaceAllMapped(RegExp(r'\{([a-zA-Z][\w]*)\}'), (match) {
        final value = values[match[1]];
        if (value == null)
          throw ArgumentError('LOCALIZATION_PARAMETER_MISSING');
        return value.toString();
      });

  bool get rtl => locale == 'ar';
  TextDirection get direction => rtl ? TextDirection.rtl : TextDirection.ltr;
  FridgeStrings withLocale(String value) => FridgeStrings(messages, value);
}
