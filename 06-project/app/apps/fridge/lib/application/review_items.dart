import 'package:fridge_core/fridge_core.dart';

/// A day identifies a live reminder group, never a captured old reference list.
List<FoodRecord> reviewItems(
  InventoryState state,
  DateTime now, {
  StorageZone? zone,
  String? reminderDay,
}) {
  final foods = reminderDay == null
      ? state.active.where((food) => zone == null || food.zone == zone).toList()
      : state.reminders
                .where((reminder) => reminder.day == reminderDay)
                .firstOrNull
                ?.pending(state, now) ??
            <FoodRecord>[];
  return foods..sort((a, b) {
    final due = a.dueAt.compareTo(b.dueAt);
    return due == 0 ? a.id.compareTo(b.id) : due;
  });
}
