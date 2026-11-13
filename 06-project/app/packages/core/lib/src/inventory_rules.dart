import 'check_schedule.dart';
import 'food_record.dart';
import 'inventory_state.dart';

/// Pure business operations. No UI, plugins, storage or network calls live here.
class InventoryRules {
  static InventoryState add(
    InventoryState state, {
    required String id,
    required String photoPath,
    required StorageZone zone,
    required DateTime now,
  }) {
    if (id.isEmpty ||
        photoPath.isEmpty ||
        state.foods.containsKey(id) ||
        state.reminders.any(
          (r) => r.references.any((ref) => ref.foodId == id),
        )) {
      throw ArgumentError('INVENTORY_ID_OR_PHOTO_INVALID');
    }
    final days = state.defaults[zone]!;
    final food = FoodRecord(
      id: id,
      photoPath: photoPath,
      zone: zone,
      addedAt: now,
      intervalDays: days,
      dueAt: scheduleCheck(
        now,
        days,
        hour: state.reminderHour,
        minute: state.reminderMinute,
      ),
    );
    return state.copyWith(
      foods: {...state.foods, id: food},
      nextNumber: state.nextNumber + 1,
    );
  }

  static FoodRecord _require(InventoryState state, String id) =>
      state.foods[id] ?? (throw StateError('INVENTORY_RECORD_MISSING'));

  static InventoryState organize(
    InventoryState state,
    Map<String, Remaining> selected,
    DateTime now,
  ) {
    if (selected.isEmpty) return state;
    final foods = {...state.foods};
    for (final entry in selected.entries) {
      final food = _require(state, entry.key);
      if (!food.active) throw StateError('INVENTORY_RECORD_ARCHIVED');
      foods[entry.key] = food.copyWith(
        remaining: entry.value,
        confirmedAt: now,
        cycle: food.cycle + 1,
        dueAt: scheduleCheck(
          now,
          food.intervalDays,
          hour: state.reminderHour,
          minute: state.reminderMinute,
        ),
      );
    }
    return state.copyWith(foods: foods, lastOrganizedAt: now);
  }

  static InventoryState edit(
    InventoryState state,
    String id, {
    StorageZone? zone,
    int? intervalDays,
    DateTime? dueAt,
    DateTime? addedAt,
    String? photoPath,
  }) {
    final food = _require(state, id);
    if (intervalDays != null && (intervalDays < 1 || intervalDays > 3650))
      throw ArgumentError('CHECK_INTERVAL_INVALID');
    if (photoPath != null && photoPath.isEmpty)
      throw ArgumentError('PHOTO_PATH_INVALID');
    // Changing only region or interval never cancels an existing pending cycle.
    return state.copyWith(
      foods: {
        ...state.foods,
        id: food.copyWith(
          zone: zone,
          intervalDays: intervalDays,
          dueAt: dueAt,
          addedAt: addedAt,
          photoPath: photoPath,
          cycle: dueAt == null ? food.cycle : food.cycle + 1,
        ),
      },
    );
  }

  static InventoryState restore(InventoryState state, String id, DateTime now) {
    final food = _require(state, id);
    if (food.active) throw StateError('INVENTORY_RECORD_NOT_ARCHIVED');
    return state.copyWith(
      foods: {
        ...state.foods,
        id: food.copyWith(
          remaining: Remaining.full,
          confirmedAt: now,
          cycle: food.cycle + 1,
          dueAt: scheduleCheck(
            now,
            food.intervalDays,
            hour: state.reminderHour,
            minute: state.reminderMinute,
          ),
        ),
      },
    );
  }

  static InventoryState delete(InventoryState state, String id) {
    _require(state, id);
    return state.copyWith(foods: {...state.foods}..remove(id));
  }

  static InventoryState changeDefaults(
    InventoryState state,
    Map<StorageZone, int> values, {
    int? hour,
    int? minute,
  }) {
    if (values.values.any((e) => e < 1 || e > 3650) ||
        (hour != null && (hour < 0 || hour > 23)) ||
        (minute != null && (minute < 0 || minute > 59))) {
      throw ArgumentError('CHECK_DEFAULTS_INVALID');
    }
    return state.copyWith(
      defaults: {...state.defaults, ...values},
      reminderHour: hour,
      reminderMinute: minute,
    );
  }

  static InventoryState collectDue(InventoryState state, DateTime now) {
    final byDay = {
      for (final r in state.reminders) r.day: [...r.references],
    };
    for (final food in state.active) {
      if (food.dueAt.isAfter(now) ||
          byDay.values.any((refs) => refs.any((ref) => ref.matches(food))))
        continue;
      byDay
          .putIfAbsent(calendarDay(food.dueAt), () => [])
          .add(CycleReference(food.id, food.cycle));
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return state.copyWith(
      reminders: days.map((d) => CheckReminder(d, byDay[d]!)),
    );
  }
}
