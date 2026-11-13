import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge_inventory/fridge_inventory.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';
import 'support/presentation_fixture.dart';

void main() {
  testWidgets(
    'detail has design geometry, live photo, all fields and failure-safe single save',
    (tester) async {
      pageSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = FridgeStrings.fromJson(
        await pageMessages(tester),
        'zh-CN',
      );
      final food = pageInventory(count: 1).active.single;
      var saves = 0, closed = 0;
      final saving = Completer<void>();
      await tester.pumpWidget(
        pageHost(
          strings,
          Scaffold(
            body: RecordEditor(
              food: food,
              strings: strings,
              photo: testPhoto,
              onSave: (_) {
                saves++;
                return saving.future;
              },
              onReplace: () async {},
              onDelete: () async {},
              onClose: () => closed++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(FridgeFoodPhoto)).width, 120);
      final material = find
          .descendant(of: find.byType(Dialog), matching: find.byType(Material))
          .first;
      expect(tester.getSize(material).width, 398);
      expect(tester.getSize(material).height, 688);
      expect(tester.getTopLeft(material).dx, 16);
      expect(find.text('2026/11/11 00:00'), findsOneWidget);
      expect(find.byKey(const ValueKey('record-zone')), findsOneWidget);
      expect(find.byKey(const ValueKey('record-interval')), findsOneWidget);
      expect(find.byKey(const ValueKey('nextCheck')), findsOneWidget);
      expect(find.byType(FridgeIcon), findsNWidgets(3));
      expect(
        tester
            .getSize(find.byKey(const ValueKey('record-interval-surface')))
            .height,
        44,
      );
      expect(
        tester.getSize(
          find
              .byWidgetPredicate(
                (widget) =>
                    widget is FridgeIcon &&
                    widget.name == FridgeIconName.calendar,
              )
              .first,
        ).width,
        closeTo(11.6667, .0001),
      );
      expect(
        tester.getSize(
          find.byWidgetPredicate(
            (widget) =>
                widget is FridgeIcon &&
                widget.name == FridgeIconName.editorChevron,
          ),
        ),
        const Size(10, 6),
      );
      await expectLater(
        find.byType(Dialog),
        matchesGoldenFile('goldens/detail-430.png'),
      );
      final save = find.text(strings.text('saveChanges'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.tap(save);
      await tester.pump();
      expect(saves, 1);
      expect(closed, 0);
      expect(tester.widget<PopScope>(find.byType(PopScope).last).canPop, false);
      saving.completeError(StateError('private transport details'));
      await tester.pumpAndSettle();
      expect(find.text(strings.text('error')), findsOneWidget);
      expect(find.textContaining('private transport'), findsNothing);
      expect(closed, 0);
      expect(tester.widget<PopScope>(find.byType(PopScope).last).canPop, true);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history tabs, card dates, detail callback, duplicate restore and failure retry',
    (tester) async {
      pageSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = FridgeStrings.fromJson(
        await pageMessages(tester),
        'zh-CN',
      );
      final state = InventoryRules.organize(pageInventory(count: 2), {
        '002': Remaining.gone,
      }, DateTime(2026, 11, 12));
      var calls = 0;
      String? opened;
      var gate = Completer<void>();
      Widget history() => pageHost(
        strings,
        HistoryScreen(
          state: state,
          strings: strings,
          photo: (_) => testPhoto,
          onOpen: (food) => opened = food.id,
          onRestore: (food) {
            expect(food.id, '002');
            calls++;
            return gate.future;
          },
        ),
      );
      await tester.pumpWidget(history());
      await tester.pumpAndSettle();
      expect(find.text('11.10 入库 · 已移出'), findsOneWidget);
      expect(tester.getSize(find.byType(FridgeFoodPhoto)).width, 55);
      await expectLater(
        find.byType(HistoryScreen),
        matchesGoldenFile('goldens/history-430.png'),
      );
      await tester.tap(find.textContaining('#002'));
      expect(opened, '002');
      final restore = find.text(strings.text('restore'));
      await tester.tap(restore);
      await tester.tap(restore);
      await tester.pump();
      expect(calls, 1);
      expect(find.byKey(const ValueKey('history-card-002')), findsOneWidget);
      gate.completeError(StateError('private disk failure'));
      await tester.pumpAndSettle();
      expect(find.text(strings.text('error')), findsOneWidget);
      gate = Completer<void>();
      await tester.tap(restore);
      await tester.pump();
      expect(calls, 2);
      gate.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('active-tab')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('history-card-001')), findsOneWidget);
      expect(find.byKey(const ValueKey('history-card-002')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'detail and history support 20 locales, two themes, 320px large text and empty history',
    (tester) async {
      pageSize(tester, width: 320, height: 740);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final messages = await pageMessages(tester);
      final food = pageInventory(count: 1).active.single;
      for (final locale in messages.keys) {
        final strings = FridgeStrings.fromJson(messages, locale);
        for (final dark in [false, true]) {
          await tester.pumpWidget(
            pageHost(
              strings,
              Scaffold(
                body: RecordEditor(
                  key: ValueKey('$locale-$dark'),
                  food: food,
                  strings: strings,
                  photo: testPhoto,
                  onSave: (_) async {},
                  onReplace: () async {},
                  onDelete: () async {},
                  onClose: () {},
                ),
              ),
              width: 320,
              height: 740,
              scale: 2,
              dark: dark,
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.text(strings.text('deleteRecordAction')),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'detail $locale/$dark',
          );
          final state = InventoryRules.organize(pageInventory(count: 2), {
            '002': Remaining.gone,
          }, DateTime(2026, 11, 12));
          await tester.pumpWidget(
            pageHost(
              strings,
              HistoryScreen(
                key: ValueKey('$locale-$dark-history'),
                state: state,
                strings: strings,
                photo: (_) => testPhoto,
                onOpen: (_) {},
                onRestore: (_) async {},
              ),
              width: 320,
              height: 740,
              scale: 2,
              dark: dark,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'history $locale/$dark',
          );
        }
      }
      final strings = FridgeStrings.fromJson(messages, 'zh-CN');
      await tester.pumpWidget(
        pageHost(
          strings,
          HistoryScreen(
            state: InventoryState(),
            strings: strings,
            photo: (_) => testPhoto,
            onOpen: (_) {},
            onRestore: (_) async {},
          ),
          width: 320,
          height: 740,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(strings.text('emptyHistory')), findsOneWidget);
      expect(find.byType(FridgeFoodPhoto), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
