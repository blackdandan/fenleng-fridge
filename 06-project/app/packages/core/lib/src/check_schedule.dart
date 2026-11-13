enum StorageZone { cold, frozen, pantry }

enum Remaining { full, half, small, gone }

DateTime scheduleCheck(
  DateTime from,
  int days, {
  int hour = 17,
  int minute = 30,
}) {
  if (days < 1 ||
      days > 3650 ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    throw ArgumentError('CHECK_SCHEDULE_INVALID');
  }
  final local = from.toLocal();
  // Calendar days, rather than 24-hour durations, preserve the chosen local time.
  return DateTime(local.year, local.month, local.day + days, hour, minute);
}

String calendarDay(DateTime date) {
  final d = date.toLocal();
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
