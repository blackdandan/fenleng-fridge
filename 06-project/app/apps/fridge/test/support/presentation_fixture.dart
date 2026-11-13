import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';

final testPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
);
final testPhoto = MemoryImage(Uint8List.fromList(testPng));
Future<Map<String, dynamic>> pageMessages(WidgetTester tester) async =>
    jsonDecode(
          (await tester.runAsync(
            () => rootBundle.loadString('assets/i18n/messages.json'),
          ))!,
        )
        as Map<String, dynamic>;
InventoryState pageInventory({int count = 8}) {
  var state = InventoryState();
  for (var n = 1; n <= count; n++) {
    state = InventoryRules.add(
      state,
      id: n.toString().padLeft(3, '0'),
      photoPath: '$n.jpg',
      zone: StorageZone.cold,
      now: DateTime(2026, 11, 11 - (n - 1) % 4),
    );
  }
  return state;
}

Widget pageHost(
  FridgeStrings strings,
  Widget child, {
  double width = 430,
  double height = 940,
  double scale = 1,
  bool dark = false,
}) {
  final parts = strings.locale.split('-');
  return MaterialApp(
    key: ValueKey((strings.locale, dark, child.runtimeType, child.key)),
    theme: fridgeTheme(dark: dark),
    locale: Locale(parts.first, parts.length > 1 ? parts.last : null),
    supportedLocales: strings.messages.keys.map((locale) {
      final p = locale.split('-');
      return Locale(p.first, p.length > 1 ? p.last : null);
    }),
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: const Scaffold(),
    initialRoute: '/fixture',
    routes: {
      '/fixture': (_) => MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          textScaler: TextScaler.linear(scale),
        ),
        child: Directionality(textDirection: strings.direction, child: child),
      ),
    },
  );
}

void pageSize(WidgetTester tester, {double width = 430, double height = 940}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
}
