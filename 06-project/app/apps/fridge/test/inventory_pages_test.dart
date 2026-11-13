import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge_inventory/fridge_inventory.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';
import 'support/presentation_fixture.dart';

void main() {
  testWidgets(
    'zone keeps three columns, equal actions, dates, icon and every record',
    (tester) async {
      pageSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = FridgeStrings.fromJson(
        await pageMessages(tester),
        'zh-CN',
      );
      final foods = pageInventory().active;
      var added = 0, organized = 0;
      String? opened;
      await tester.pumpWidget(
        pageHost(
          strings,
          RecordsScreen(
            title: strings.text('coldZone'),
            foods: foods,
            strings: strings,
            photo: (_) => testPhoto,
            onAdd: () => added++,
            onOrganize: () => organized++,
            onOpen: (food) => opened = food.id,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text(strings.format('recordCount', {'count': 8})),
        findsOneWidget,
      );
      final add = find.byKey(const ValueKey('zone-add'));
      final review = find.byKey(const ValueKey('zone-review'));
      expect(tester.getSize(add), tester.getSize(review));
      expect(tester.getSize(add).height, closeTo(46, .1));
      expect(
        tester
            .getSize(find.descendant(of: add, matching: find.byType(Material)))
            .height,
        closeTo(46, .1),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('zone-photo-001'))).width,
        closeTo(118, .1),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('zone-photo-001'))).dy,
        tester.getTopLeft(find.byKey(const ValueKey('zone-photo-003'))).dy,
      );
      expect(find.byKey(const ValueKey('zone-photo-008')), findsOneWidget);
      expect(find.text('11.11 入库'), findsNWidgets(2));
      expect(
        tester.widget<Text>(find.text('11.11 入库').first).style!.letterSpacing,
        0,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is FridgeIcon && widget.name == FridgeIconName.camera,
        ),
        findsOneWidget,
      );
      await expectLater(
        find.byType(RecordsScreen),
        matchesGoldenFile('goldens/zone-430.png'),
      );
      await tester.tap(add);
      await tester.tap(review);
      await tester.tap(find.byKey(const ValueKey('zone-photo-008')));
      expect(added, 1);
      expect(organized, 1);
      final backIcon = find.byWidgetPredicate(
        (widget) => widget is FridgeIcon && widget.name == FridgeIconName.back,
      );
      expect(tester.getSize(backIcon), const Size(20, 20));
      expect(opened, '008');
    },
  );
  testWidgets(
    'review baseline covers saved confirmation metadata and two selected states',
    (tester) async {
      pageSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = FridgeStrings.fromJson(
        await pageMessages(tester),
        'zh-CN',
      );
      var state = pageInventory(count: 2);
      state = InventoryRules.organize(state, {
        '002': Remaining.half,
      }, DateTime(2026, 11, 11, 10));
      state = InventoryRules.organize(state, {
        '001': Remaining.full,
      }, DateTime(2026, 11, 12, 10));
      await tester.pumpWidget(
        pageHost(
          strings,
          ReviewScreen(
            title: strings.format('organizeZone', {
              'zone': strings.text('cold'),
            }),
            foods: state.active,
            strings: strings,
            photo: (_) => testPhoto,
            onConfirm: (_, _) async {},
            onOpen: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('上次整理 11.12 10:00'), findsOneWidget);
      expect(find.text('上次整理 11.11 10:00'), findsOneWidget);
      for (final key in ['review-001-full', 'review-002-half']) {
        expect(
          tester.widget<FridgeChoice>(find.byKey(ValueKey(key))).selected,
          true,
        );
      }
      await expectLater(
        find.byType(ReviewScreen),
        matchesGoldenFile('goldens/review-430.png'),
      );
    },
  );
  testWidgets(
    'zone and review fit all locales in both themes with large text at 320',
    (tester) async {
      pageSize(tester, width: 320, height: 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final resources = await pageMessages(tester);
      final foods = pageInventory().active;
      for (final locale in resources.keys) {
        final strings = FridgeStrings.fromJson(resources, locale);
        for (final dark in [false, true]) {
          for (final review in [false, true]) {
            final page = review
                ? ReviewScreen(
                    title: strings.format('organizeZone', {
                      'zone': strings.text('cold'),
                    }),
                    foods: foods,
                    strings: strings,
                    photo: (_) => testPhoto,
                    onConfirm: (_, _) async {},
                    onOpen: (_) {},
                  )
                : RecordsScreen(
                    title: strings.text('coldZone'),
                    foods: foods,
                    strings: strings,
                    photo: (_) => testPhoto,
                    onAdd: () {},
                    onOrganize: () {},
                    onOpen: (_) {},
                  );
            await tester.pumpWidget(
              pageHost(
                strings,
                page,
                width: 320,
                height: 800,
                scale: 2,
                dark: dark,
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$locale dark=$dark review=$review',
            );
          }
        }
      }
    },
  );
  testWidgets(
    'review locks duplicate taps, exposes details and recovers from a failed save',
    (tester) async {
      pageSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = FridgeStrings.fromJson(
        await pageMessages(tester),
        'zh-CN',
      );
      final foods = pageInventory(count: 1).active;
      var calls = 0;
      String? detail;
      var gate = Completer<void>();
      await tester.pumpWidget(
        pageHost(
          strings,
          ReviewScreen(
            foods: foods,
            strings: strings,
            photo: (_) => testPhoto,
            onConfirm: (_, _) {
              calls++;
              return gate.future;
            },
            onOpen: (food) => detail = food.id,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('review-photo-001'))).width,
        66,
      );
      await tester.tap(find.byKey(const ValueKey('review-detail-001')));
      expect(detail, '001');
      final half = find.byKey(const ValueKey('review-001-half'));
      await tester.tap(half);
      await tester.tap(half);
      expect(calls, 1);
      gate.completeError(StateError('PRIVATE_FAILURE_DETAIL'));
      await tester.pumpAndSettle();
      expect(find.text(strings.text('error')), findsOneWidget);
      expect(find.text('PRIVATE_FAILURE_DETAIL'), findsNothing);
      expect(foods.single.remaining, Remaining.full);
      gate = Completer<void>();
      await tester.tap(half);
      expect(calls, 2);
      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
