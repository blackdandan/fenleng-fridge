import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/main.dart';
import 'package:fridge/application/bootstrap.dart';
import 'package:fridge/application/notification_session.dart';
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge_inventory/fridge_inventory.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';
import 'support/notification_fixture.dart';
import 'support/presentation_fixture.dart';
import 'support/runtime_fixture.dart';

void main() {
  testWidgets(
    'cold and warm notification taps route to current day pending items and consumed taps do not reopen',
    (tester) async {
      pageSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = FridgeStrings.fromJson(
        await pageMessages(tester),
        'zh-CN',
      );
      final now = DateTime.now();
      var state = InventoryState();
      for (final id in ['001', '002']) {
        state = InventoryRules.add(
          state,
          id: id,
          photoPath: id,
          zone: StorageZone.cold,
          now: now.subtract(const Duration(days: 10)),
        );
      }
      final repository = InventoryRepository(MemoryStorage(state));
      await repository.open();
      final day = repository.state.reminders.single.day;
      final bootstrap = ReadyBootstrap(repository, strings);
      final platform = FakeNotifications()..launch = day;
      final model = NotificationSession(
        repository: repository,
        platform: platform,
        consent: () => bootstrap.stage == BootstrapStage.ready,
        copy: () => {
          'title': 'Check',
          'body': '{count}',
          'channel': 'Checks',
          'locale': 'en',
        },
      );
      bootstrap.localReminders = model;
      await model.start();
      try {
        await tester.pumpWidget(
          FridgeApp(bootstrap: bootstrap, photoLoader: (_) => testPhoto),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ReviewScreen), findsOneWidget);
        expect(model.pendingDay, isNull);
        expect(platform.launch, isNull);
        await tester.tap(find.byKey(const ValueKey('review-001-gone')));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(strings.text('back')));
        await tester.pumpAndSettle();
        platform.events.add(day);
        platform.events.add(day);
        await tester.pumpAndSettle();
        expect(find.byType(ReviewScreen), findsOneWidget);
        expect(find.byKey(const ValueKey('review-001-gone')), findsNothing);
        expect(find.byKey(const ValueKey('review-002-gone')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('review-002-gone')));
        await tester.pumpAndSettle();
        expect(find.text(strings.text('allHandled')), findsOneWidget);
        await tester.tap(find.text(strings.text('back')));
        await tester.pumpAndSettle();
        expect(find.byType(ReviewScreen), findsNothing);
        await model.refresh();
        await tester.pumpAndSettle();
        expect(find.byType(ReviewScreen), findsNothing);
        platform.events.add(day);
        await tester.pumpAndSettle();
        expect(find.text(strings.text('allHandled')), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await flushClose(tester, model.close());
        await flushClose(tester, repository.close());
        bootstrap.dispose();
      }
    },
  );
  testWidgets(
    'real settings entry explains before permission, cancel stays off and retry enables',
    (tester) async {
      pageSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = FridgeStrings.fromJson(
        await pageMessages(tester),
        'zh-CN',
      );
      final repository = InventoryRepository(MemoryStorage(InventoryState()));
      await repository.open();
      final bootstrap = ReadyBootstrap(repository, strings);
      final platform = FakeNotifications();
      final model = NotificationSession(
        repository: repository,
        platform: platform,
        consent: () => true,
        copy: () => {
          'title': 'Check',
          'body': '{count}',
          'channel': 'Checks',
          'locale': 'en',
        },
      );
      bootstrap.localReminders = model;
      await model.start();
      try {
        await tester.pumpWidget(FridgeApp(bootstrap: bootstrap));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(strings.text('settings')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('settings-notificationSettings')),
        );
        await tester.tap(
          find.byKey(const ValueKey('settings-notificationSettings')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('notifications-enable')));
        await tester.pumpAndSettle();
        expect(
          find.text(strings.text('notificationPermissionTitle')),
          findsOneWidget,
        );
        final material = find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Material),
            )
            .first;
        expect(tester.getTopLeft(material).dx, 16);
        expect(tester.getTopLeft(material).dy, 16);
        expect(platform.requests, 0);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(strings.text('notificationLater')));
        await tester.pumpAndSettle();
        expect(platform.requests, 0);
        expect(model.status.enabled, false);
        await tester.tap(find.byKey(const ValueKey('notifications-enable')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(strings.text('continueRequest')));
        await tester.pumpAndSettle();
        expect(platform.requests, 1);
        expect(model.status.enabled, true);
        expect(find.text(strings.text('notificationEnabled')), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await flushClose(tester, model.close());
        await flushClose(tester, repository.close());
        bootstrap.dispose();
      }
    },
  );
}

Future<void> flushClose(WidgetTester tester, Future<void> closing) async {
  // Broadcast cancellation can cross the real event loop and the widget's fake
  // clock; drain both rather than awaiting a future while one queue is paused.
  var complete = false;
  closing.whenComplete(() => complete = true);
  for (var n = 0; n < 20 && !complete; n++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
  }
  expect(
    complete,
    true,
    reason: 'Resource cleanup must finish after queued stream events drain',
  );
  await closing;
}
