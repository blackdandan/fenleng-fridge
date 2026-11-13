import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/main.dart';
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';
import 'support/presentation_fixture.dart';
import 'support/runtime_fixture.dart';

void main() {
  testWidgets(
    'actual App edits history, restores a new cycle and permanently deletes only the chosen record',
    (tester) async {
      pageSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = FridgeStrings.fromJson(
        await pageMessages(tester),
        'zh-CN',
      );
      final now = DateTime.now();
      final overdue = InventoryRules.edit(
        pageInventory(count: 2),
        '001',
        dueAt: now.subtract(const Duration(days: 1)),
      );
      final state = InventoryRules.organize(overdue, {
        '002': Remaining.gone,
      }, now);
      final repository = InventoryRepository(
        MemoryStorage(state),
        clock: () => now,
      );
      await repository.open();
      final original = repository.state.foods['002']!;
      final bootstrap = ReadyBootstrap(repository, strings);
      try {
        await tester.pumpWidget(
          FridgeApp(bootstrap: bootstrap, photoLoader: (_) => testPhoto),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(strings.text('settings')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(strings.text('history')));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('#002'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('record-zone')));
        await tester.tap(find.byKey(const ValueKey('record-zone')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(strings.text('frozen')).last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('record-interval')),
          '١٤',
        );
        await tester.ensureVisible(find.text(strings.text('saveChanges')));
        await tester.tap(find.text(strings.text('saveChanges')));
        await tester.pumpAndSettle();
        var updated = repository.state.foods['002']!;
        expect(updated.zone, StorageZone.frozen);
        expect(updated.intervalDays, 14);
        expect(updated.dueAt, original.dueAt);
        expect(updated.cycle, original.cycle);
        expect(updated.addedAt, original.addedAt);
        expect(updated.active, false);
        expect(
          repository.state.foods['001']!.toJson(),
          state.foods['001']!.toJson(),
        );
        await tester.tap(find.text(strings.text('restore')));
        await tester.pumpAndSettle();
        updated = repository.state.foods['002']!;
        expect(updated.active, true);
        expect(updated.cycle, original.cycle + 1);
        expect(updated.remaining, Remaining.full);
        expect(updated.dueAt.isAfter(now), true);
        expect(
          repository.state.hasPending(now),
          true,
        ); // Only the untouched 001 is overdue.
        expect(
          repository.state.reminders
              .expand((r) => r.pending(repository.state, now))
              .map((f) => f.id)
              .toSet(),
          {'001'},
        );
        expect(find.text(strings.text('emptyHistory')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('active-tab')));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('#001'));
        await tester.pumpAndSettle();
        final delete = find.text(strings.text('deleteRecordAction'));
        await tester.ensureVisible(delete);
        await tester.tap(delete);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(strings.text('cancel')),
          ),
        );
        await tester.pumpAndSettle();
        expect(repository.state.foods.containsKey('001'), true);
        await tester.tap(delete);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(strings.text('delete')),
          ),
        );
        await tester.pumpAndSettle();
        expect(repository.state.foods.keys, ['002']);
        expect(repository.state.foods['002']!.toJson(), updated.toJson());
        expect(repository.state.hasPending(now), false);
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
