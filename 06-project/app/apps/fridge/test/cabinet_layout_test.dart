import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge_inventory/fridge_inventory.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';

final pixel = MemoryImage(
  Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
    ),
  ),
);
InventoryState fixture({DateTime? now}) {
  var state = InventoryState();
  for (var number = 1; number <= 14; number++) {
    state = InventoryRules.add(
      state,
      id: number.toString().padLeft(3, '0'),
      photoPath: '$number.jpg',
      zone: number <= 8
          ? StorageZone.cold
          : number <= 11
          ? StorageZone.frozen
          : StorageZone.pantry,
      now: now ?? DateTime.now(),
    );
  }
  return state;
}

Future<Map<String, dynamic>> messages(WidgetTester tester) async =>
    jsonDecode(
          (await tester.runAsync(
            () => rootBundle.loadString('assets/i18n/messages.json'),
          ))!,
        )
        as Map<String, dynamic>;
Widget screen(
  FridgeStrings strings,
  InventoryState state, {
  double width = 430,
  double scale = 1,
  bool dark = false,
  VoidCallback? review,
}) => MaterialApp(
  theme: fridgeTheme(dark: dark),
  home: MediaQuery(
    data: MediaQueryData(
      size: Size(width, 850),
      textScaler: TextScaler.linear(scale),
    ),
    child: Directionality(
      textDirection: strings.direction,
      child: CabinetScreen(
        state: state,
        strings: strings,
        photo: (_) => pixel,
        onOpenZone: (_) {},
        onSettings: () {},
        onReminders: () {},
        onReview: review ?? () {},
      ),
    ),
  ),
);
void configure(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 850);
  tester.view.devicePixelRatio = 1;
}

void main() {
  testWidgets(
    'home uses the reference cabinet/photo geometry and overflow slot',
    (tester) async {
      configure(tester, 430);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = FridgeStrings.fromJson(await messages(tester), 'zh-CN');
      await tester.pumpWidget(screen(strings, fixture()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const ValueKey('home-photo-001'))).width,
        closeTo(66, .1),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('door-cold'))).height,
        closeTo(271, .5),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('cabinet'))).height,
        closeTo(455, 1),
      );
      expect(find.byType(FridgeFoodPhoto), findsNWidgets(11));
      expect(find.text('+3'), findsOneWidget);
      expect(find.text('#008'), findsNothing);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
      await expectLater(
        find.byType(CabinetScreen),
        matchesGoldenFile('goldens/home-430.png'),
      );
    },
  );
  testWidgets(
    'home stays readable at 320 and large text for all locales and themes',
    (tester) async {
      configure(tester, 320);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final resources = await messages(tester);
      for (final locale in resources.keys) {
        final strings = FridgeStrings.fromJson(resources, locale);
        for (final dark in [false, true]) {
          await tester.pumpWidget(
            screen(strings, fixture(), width: 320, scale: 2, dark: dark),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$locale dark=$dark');
          for (final icon in tester.widgetList<FridgeHeaderIcon>(
            find.byType(FridgeHeaderIcon),
          )) {
            expect(
              tester.getSize(find.byWidget(icon)).width,
              greaterThanOrEqualTo(44),
            );
            expect(
              tester.getSize(find.byWidget(icon)).height,
              greaterThanOrEqualTo(44),
            );
          }
          final size = tester.getSize(
            find.byKey(const ValueKey('home-photo-001')),
          );
          expect(size.width, closeTo(66 * 320 / 430, .1));
        }
      }
    },
  );
  testWidgets(
    'wide portrait and landscape keep the full page centered within 600',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = FridgeStrings.fromJson(await messages(tester), 'zh-CN');
      for (final size in [const Size(800, 1100), const Size(1100, 600)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(screen(strings, fixture(), width: size.width));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.getCenter(find.byKey(const ValueKey('cabinet'))).dx,
          closeTo(size.width / 2, .1),
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('home-photo-001'))).width,
          closeTo(66 * 600 / 430, .1),
        );
      }
    },
  );
  testWidgets(
    'empty fridge has no review hint and due hint opens all-inventory review',
    (tester) async {
      configure(tester, 430);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = FridgeStrings.fromJson(await messages(tester), 'zh-CN');
      await tester.pumpWidget(screen(strings, InventoryState()));
      await tester.pumpAndSettle();
      expect(find.text(strings.text('goOrganize')), findsNothing);
      var calls = 0;
      await tester.pumpWidget(
        screen(strings, fixture(now: DateTime(2020)), review: () => calls++),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(strings.text('goOrganize')),
        250,
      );
      await tester.tap(find.text(strings.text('goOrganize')));
      await tester.pump();
      expect(calls, 1);
      expect(find.text(strings.text('dueHint')), findsOneWidget);
    },
  );
}
