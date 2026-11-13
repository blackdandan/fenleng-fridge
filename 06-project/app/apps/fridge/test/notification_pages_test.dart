import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge_inventory/fridge_inventory.dart';
import 'package:fridge_settings/fridge_settings.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';
import 'support/presentation_fixture.dart';

final checkNow = DateTime(2026, 11, 16, 12);
InventoryState remindersFixture(String phase) {
  var state = InventoryState();
  for (var n = 1; n <= 11; n++) {
    final id = n.toString().padLeft(3, '0');
    state = InventoryRules.add(
      state,
      id: id,
      photoPath: '$id.jpg',
      zone: StorageZone.cold,
      now: DateTime(2026, 11, 1),
    );
    state = InventoryRules.edit(state, id, dueAt: DateTime(2026, 11, 15, 10));
  }
  state = InventoryRules.collectDue(state, checkNow);
  if (phase == 'partial') {
    state = InventoryRules.organize(state, {'001': Remaining.half}, checkNow);
  }
  if (phase == 'handled') {
    state = InventoryRules.organize(state, {
      for (final food in state.active) food.id: Remaining.gone,
    }, checkNow);
  }
  return phase == 'empty' ? InventoryState() : state;
}

void main() {
  testWidgets(
    'reminder original counts survive partial/full handling; complete and empty have no organize action',
    (tester) async {
      pageSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = FridgeStrings.fromJson(
        await pageMessages(tester),
        'zh-CN',
      );
      for (final phase in ['pending', 'partial', 'handled', 'empty']) {
        CheckReminder? opened;
        final state = remindersFixture(phase);
        await tester.pumpWidget(
          pageHost(
            strings,
            RemindersScreen(
              key: ValueKey(phase),
              state: state,
              strings: strings,
              now: checkNow,
              onOpen: (r) => opened = r,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(FridgePage),
          matchesGoldenFile('goldens/reminders-$phase-430.png'),
        );
        if (phase == 'empty') {
          expect(find.text(strings.text('notificationEmpty')), findsOneWidget);
        } else {
          expect(
            find.text(strings.format('notificationBody', {'count': 11})),
            findsOneWidget,
          );
          expect(
            find.text(
              strings.format('pendingCount', {
                'count': phase == 'pending'
                    ? 11
                    : phase == 'partial'
                    ? 10
                    : 0,
              }),
            ),
            findsOneWidget,
          );
          expect(
            tester
                .getSize(find.byKey(const ValueKey('reminder-2026-11-15')))
                .width,
            382,
          );
        }
        if (phase == 'pending' || phase == 'partial') {
          await tester.tap(
            find.byKey(const ValueKey('open-reminder-2026-11-15')),
          );
          expect(opened?.originalCount, 11);
          if (phase == 'partial') {
            expect(find.text(strings.text('partiallyHandled')), findsOneWidget);
          }
        } else {
          expect(find.text(strings.text('notificationOpen')), findsNothing);
        }
        if (phase == 'handled') {
          expect(
            find.text(strings.text('notificationHandled')),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'notification preferences show real denied/busy states and keep system recovery discoverable',
    (tester) async {
      pageSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = FridgeStrings.fromJson(
        await pageMessages(tester),
        'zh-CN',
      );
      var enabled = 0, settings = 0;
      await tester.pumpWidget(
        pageHost(
          strings,
          NotificationSettingsScreen(
            strings: strings,
            enabled: false,
            authorized: false,
            requested: true,
            busy: false,
            limited: true,
            timingKey: 'notificationTimingIOS',
            onEnable: () => enabled++,
            onDisable: () {},
            onSettings: () => settings++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(strings.text('notificationDenied')), findsOneWidget);
      expect(
        find.text(strings.text('notificationQueueLimited')),
        findsOneWidget,
      );
      expect(find.text(strings.text('notificationTimingIOS')), findsOneWidget);
      await tester.tap(find.text(strings.text('openSettings')));
      expect(settings, 1);
      await tester.tap(find.byKey(const ValueKey('notifications-enable')));
      expect(enabled, 1);
      await tester.pumpWidget(
        pageHost(
          strings,
          NotificationSettingsScreen(
            key: const ValueKey('busy'),
            strings: strings,
            enabled: true,
            authorized: true,
            requested: true,
            busy: true,
            onEnable: () => enabled++,
            onDisable: () {},
            onSettings: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final action = find.descendant(
        of: find.byKey(const ValueKey('notifications-disable')),
        matching: find.byType(TextButton),
      );
      expect(tester.widget<TextButton>(action).onPressed, isNull);
    },
  );
  testWidgets(
    'reminder4 states and notification preferences fit20 languages two themes at320 and text2',
    (tester) async {
      pageSize(tester, width: 320, height: 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final messages = await pageMessages(tester);
      for (final locale in messages.keys) {
        final strings = FridgeStrings.fromJson(messages, locale);
        for (final dark in [false, true]) {
          for (final phase in [
            'pending',
            'partial',
            'handled',
            'empty',
            'settings',
            'permission',
          ]) {
            final key = ValueKey('$locale-$dark-$phase');
            final page = phase == 'permission'
                ? NotificationPermissionDialog(
                    key: key,
                    strings: strings,
                    onContinue: () {},
                    onLater: () {},
                  )
                : phase == 'settings'
                ? NotificationSettingsScreen(
                    key: key,
                    strings: strings,
                    enabled: true,
                    authorized: false,
                    requested: true,
                    busy: false,
                    errorKey: 'notificationUnavailable',
                    limited: true,
                    timingKey: 'notificationTimingIOS',
                    onEnable: () {},
                    onDisable: () {},
                    onSettings: () {},
                  )
                : RemindersScreen(
                    key: key,
                    state: remindersFixture(phase),
                    strings: strings,
                    now: checkNow,
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
            if (phase == 'permission') {
              await tester.ensureVisible(
                find.text(strings.text('notificationLater')),
              );
            } else {
              await tester.drag(find.byType(ListView), const Offset(0, -1200));
            }
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$locale $dark $phase',
            );
          }
        }
      }
    },
  );
}
