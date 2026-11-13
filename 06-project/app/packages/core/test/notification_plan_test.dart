import 'dart:convert';
import 'package:test/test.dart';
import 'package:fridge_core/fridge_core.dart';

void main() {
  test(
    'notification plan uses local wall time and unique cycle keys without photos or content',
    () {
      var state = InventoryState();
      for (final id in ['002', '001']) {
        state = InventoryRules.add(
          state,
          id: id,
          photoPath: 'PRIVATE_PHOTO',
          zone: StorageZone.cold,
          now: DateTime(2026, 11, 13),
        );
      }
      state = InventoryRules.edit(
        state,
        '002',
        dueAt: DateTime(2026, 11, 14, 9, 15, 30, 123, 500),
      );
      final plan = notificationPlan(state);
      expect(plan.first, {
        'key': jsonEncode(['002', 1]),
        'day': '2026-11-14',
        'hour': 9,
        'minute': 15,
        'second': 30,
        'millisecond': 124,
      });
      expect(plan.last['key'], jsonEncode(['001', 0]));
      expect(jsonEncode(plan), isNot(contains('PRIVATE_PHOTO')));
      expect(notificationPlan(InventoryState.fromJson(state.toJson())), plan);
    },
  );
  test(
    'move and interval preserve schedule; handling, retime and restore replace cycle identity; gone excluded',
    () {
      final now = DateTime(2026, 11, 13, 10);
      var state = InventoryRules.add(
        InventoryState(),
        id: '001',
        photoPath: 'a',
        zone: StorageZone.cold,
        now: now,
      );
      final original = notificationPlan(state).single;
      state = InventoryRules.edit(
        state,
        '001',
        zone: StorageZone.frozen,
        intervalDays: 7,
      );
      expect(notificationPlan(state).single, original);
      state = InventoryRules.organize(state, {'001': Remaining.half}, now);
      expect(notificationPlan(state).single['key'], jsonEncode(['001', 1]));
      state = InventoryRules.edit(
        state,
        '001',
        dueAt: DateTime(2026, 11, 13, 12),
      );
      expect(notificationPlan(state).single['key'], jsonEncode(['001', 2]));
      state = InventoryRules.organize(state, {'001': Remaining.gone}, now);
      expect(notificationPlan(state), isEmpty);
      state = InventoryRules.restore(state, '001', now);
      expect(notificationPlan(state).single['key'], jsonEncode(['001', 4]));
      state = InventoryRules.delete(state, '001');
      expect(notificationPlan(state), isEmpty);
    },
  );
}
