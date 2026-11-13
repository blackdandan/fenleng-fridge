import 'dart:convert';
import 'inventory.dart';

/// All active cycles are supplied, including overdue ones. Delivery history is
/// independent of inventory history and belongs to the OS adapter.
List<Map<String, Object>> notificationPlan(InventoryState state) {
  final foods = [...state.active]
    ..sort((a, b) {
      final date = a.dueAt.compareTo(b.dueAt);
      return date == 0 ? a.id.compareTo(b.id) : date;
    });
  return [
    for (final food in foods)
      {
        'key': jsonEncode([food.id, food.cycle]),
        'day': calendarDay(food.dueAt),
        'hour': food.dueAt.toLocal().hour,
        'minute': food.dueAt.toLocal().minute,
        'second': food.dueAt.toLocal().second,
        'millisecond':
            food.dueAt.toLocal().millisecond +
            (food.dueAt.microsecond > 0 ? 1 : 0),
      },
  ];
}
