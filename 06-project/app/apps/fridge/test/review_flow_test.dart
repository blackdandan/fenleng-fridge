import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/main.dart';
import 'package:fridge/application/review_items.dart';
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';
import 'support/presentation_fixture.dart';
import 'support/runtime_fixture.dart';

void main() {
  test(
    'reminder review resolves the live day group after same-day arrivals and sorts by due time',
    () {
      final morning = DateTime(2026, 11, 6, 10);
      final noon = DateTime(2026, 11, 6, 12);
      var state = InventoryState();
      for (final id in ['002', '001']) {
        state = InventoryRules.add(
          state,
          id: id,
          photoPath: '$id.jpg',
          zone: StorageZone.cold,
          now: morning,
        );
        state = InventoryRules.edit(
          state,
          id,
          dueAt: DateTime(2026, 11, 6, id == '001' ? 8 : 11),
        );
      }
      state = InventoryRules.collectDue(state, morning);
      final day = state.reminders.single.day;
      expect(
        reviewItems(state, morning, reminderDay: day).map((food) => food.id),
        ['001'],
      );
      state = InventoryRules.collectDue(state, noon);
      state = InventoryState.fromJson(state.toJson());
      expect(
        reviewItems(state, noon, reminderDay: day).map((food) => food.id),
        ['001', '002'],
      );
      state = InventoryRules.organize(state, {'001': Remaining.half}, noon);
      expect(
        reviewItems(state, noon, reminderDay: day).map((food) => food.id),
        ['002'],
      );
      expect(state.reminders.single.originalCount, 2);
    },
  );
  testWidgets(
    'actual App routes close reminder review and undo without resetting other records',
    (tester) async {
      pageSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = FridgeStrings.fromJson(
        await pageMessages(tester),
        'zh-CN',
      );
      var state = InventoryState();
      final now = DateTime.now();
      for (final entry in {
        '001': StorageZone.cold,
        '002': StorageZone.pantry,
      }.entries) {
        state = InventoryRules.add(
          state,
          id: entry.key,
          photoPath: entry.key,
          zone: entry.value,
          now: now.subtract(const Duration(days: 10)),
        );
      }
      final repository = InventoryRepository(
        MemoryStorage(state),
        clock: () => now,
      );
      await repository.open();
      final bootstrap = ReadyBootstrap(repository, strings);
      try {
        await tester.pumpWidget(
          FridgeApp(bootstrap: bootstrap, photoLoader: (_) => testPhoto),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, true);
        await tester.tap(find.byTooltip(strings.text('notifications')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(strings.text('notificationOpen')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('review-001-gone')));
        await tester.pumpAndSettle();
        expect(repository.state.history.map((food) => food.id), ['001']);
        expect(repository.state.foods['002']!.cycle, 0);
        expect(
          repository.state.reminders.single.pending(repository.state, now),
          hasLength(1),
        );
        await tester.tap(find.text(strings.text('undo')));
        await tester.pumpAndSettle();
        expect(repository.state.foods['001']!.active, true);
        expect(
          repository.state.reminders.single.pending(repository.state, now),
          hasLength(2),
        );
        await tester.tap(find.byKey(const ValueKey('review-001-half')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('review-002-gone')));
        await tester.pumpAndSettle();
        expect(find.text(strings.text('allHandled')), findsOneWidget);
        expect(repository.state.foods['001']!.remaining, Remaining.half);
        expect(repository.state.reminders.single.originalCount, 2);
        expect(repository.state.hasPending(now), false);
        await tester.tap(find.text(strings.text('back')));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(strings.text('back')));
        await tester.pumpAndSettle();
        expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, false);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        final closing = repository.close();
        await tester.pump();
        await closing;
        bootstrap.dispose();
      }
    },
  );
}
