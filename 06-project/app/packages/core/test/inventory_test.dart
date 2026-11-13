import 'dart:convert';
import 'package:fridge_core/fridge_core.dart';
import 'package:test/test.dart';

void main() {
  final start = DateTime(2026, 11, 1, 10);
  InventoryState add(
    InventoryState state,
    String id, {
    DateTime? time,
    StorageZone zone = StorageZone.cold,
  }) => InventoryRules.add(
    state,
    id: id,
    photoPath: '$id.jpg',
    zone: zone,
    now: time ?? start,
  );

  test(
    'first install has no fictional inventory; defaults preserve calendar schedule',
    () {
      final state = InventoryState();
      expect(state.active, isEmpty);
      expect(state.shouldShowInactivity(start), isFalse);
      final saved = add(state, 'a');
      expect(saved.foods['a']!.dueAt, DateTime(2026, 11, 4, 17, 30));
      final changed = InventoryRules.changeDefaults(saved, {
        StorageZone.cold: 8,
      });
      expect(changed.foods['a']!.intervalDays, 3);
      expect(add(changed, 'b').foods['b']!.intervalDays, 8);
    },
  );

  test(
    'same-day incremental due records merge once; missed days stay separate',
    () {
      var state = add(
        add(InventoryState(), 'a'),
        'b',
        time: start.add(const Duration(hours: 3)),
      );
      state = add(state, 'c', time: start.add(const Duration(days: 1)));
      state = InventoryRules.edit(state, 'b', dueAt: DateTime(2026, 11, 4, 20));
      state = InventoryRules.collectDue(state, DateTime(2026, 11, 4, 18));
      expect(state.reminders.single.originalCount, 1);
      state = InventoryRules.collectDue(state, DateTime(2026, 11, 4, 21));
      expect(state.reminders.single.originalCount, 2);
      state = InventoryRules.collectDue(state, DateTime(2026, 11, 8));
      state = InventoryRules.collectDue(state, DateTime(2026, 11, 8));
      expect(state.reminders.map((r) => r.day), ['2026-11-05', '2026-11-04']);
      expect(state.reminders.last.originalCount, 2);
    },
  );

  test(
    'partial/full resolution updates pending without rewriting original quantity',
    () {
      final now = DateTime(2026, 11, 4, 18);
      var state = InventoryRules.collectDue(
        add(add(InventoryState(), 'a'), 'b'),
        now,
      );
      state = InventoryRules.organize(state, {'a': Remaining.half}, now);
      expect(state.reminders.single.originalCount, 2);
      expect(state.reminders.single.pending(state, now).map((f) => f.id), [
        'b',
      ]);
      expect(state.foods['b']!.confirmedAt, isNull);
      state = InventoryRules.organize(state, {'b': Remaining.gone}, now);
      expect(state.hasPending(now), isFalse);
      expect(state.reminders, hasLength(1));
      expect(state.history.single.id, 'b');
    },
  );

  test(
    'absolute remaining values, movement and interval edits preserve pending cycle',
    () {
      final now = DateTime(2026, 11, 4, 18);
      var state = InventoryRules.collectDue(add(InventoryState(), 'a'), now);
      state = InventoryRules.edit(
        state,
        'a',
        zone: StorageZone.frozen,
        intervalDays: 14,
      );
      expect(state.hasPending(now), isTrue);
      expect(state.foods['a']!.addedAt, start);
      state = InventoryRules.organize(state, {'a': Remaining.half}, now);
      state = InventoryRules.organize(state, {'a': Remaining.half}, now);
      expect(state.foods['a']!.remaining, Remaining.half);
      state = InventoryRules.organize(state, {'a': Remaining.full}, now);
      expect(state.foods['a']!.remaining, Remaining.full);
      expect(state.foods['a']!.dueAt, DateTime(2026, 11, 18, 17, 30));
    },
  );

  test(
    'reschedule terminates old cycle; restore creates new cycle; delete resolves pending',
    () {
      final now = DateTime(2026, 11, 4, 18);
      var state = InventoryRules.collectDue(add(InventoryState(), 'a'), now);
      state = InventoryRules.edit(state, 'a', dueAt: DateTime(2026, 11, 10));
      expect(state.hasPending(now), isFalse);
      state = InventoryRules.organize(state, {'a': Remaining.gone}, now);
      final archivedCycle = state.foods['a']!.cycle;
      state = InventoryRules.restore(state, 'a', now);
      expect(state.foods['a']!.cycle, archivedCycle + 1);
      expect(
        state.reminders.single.pending(state, DateTime(2026, 12)),
        isEmpty,
      );
      state = InventoryRules.collectDue(state, DateTime(2026, 12));
      expect(
        state.reminders.first.pending(state, DateTime(2026, 12)),
        hasLength(1),
      );
      state = InventoryRules.delete(state, 'a');
      expect(state.hasPending(DateTime(2026, 12)), isFalse);
    },
  );

  test(
    'new cycle notifies while old reminder stays completed after restart',
    () {
      final now = DateTime(2026, 11, 4, 18);
      var state = InventoryRules.collectDue(add(InventoryState(), 'a'), now);
      state = InventoryRules.organize(state, {'a': Remaining.small}, now);
      state = InventoryRules.collectDue(state, DateTime(2026, 11, 8));
      final decoded = InventoryState.fromJson(
        jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.reminders, hasLength(2));
      expect(
        decoded.reminders.last.pending(decoded, DateTime(2026, 11, 8)),
        isEmpty,
      );
      expect(
        decoded.reminders.first.pending(decoded, DateTime(2026, 11, 8)),
        hasLength(1),
      );
    },
  );

  test(
    'inactivity priority does not get reset by adding or moving inventory',
    () {
      var state = add(InventoryState(), 'a', zone: StorageZone.frozen);
      final now = DateTime(2026, 11, 4);
      expect(state.shouldShowInactivity(now), isTrue);
      state = add(state, 'b', time: now);
      expect(state.shouldShowInactivity(now), isTrue);
      state = InventoryRules.organize(state, {'a': Remaining.full}, now);
      expect(state.shouldShowInactivity(now), isFalse);
      expect(
        state.shouldShowInactivity(DateTime(2026, 11, 8)),
        isFalse,
      ); // b is due: due card takes priority.
    },
  );

  test('invalid data never silently replaces existing inventory', () {
    final state = add(InventoryState(), 'a');
    expect(() => add(state, 'a'), throwsArgumentError);
    expect(
      () => InventoryRules.changeDefaults(state, {StorageZone.cold: 0}),
      throwsArgumentError,
    );
    expect(
      () => InventoryState.fromJson({...state.toJson(), 'schemaVersion': 9}),
      throwsFormatException,
    );
    expect(() => state.foods.clear(), throwsUnsupportedError);
  });
}
