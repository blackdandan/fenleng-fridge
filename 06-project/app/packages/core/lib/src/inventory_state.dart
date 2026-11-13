import 'check_schedule.dart';
import 'food_record.dart';

class CycleReference {
  final String foodId;
  final int cycle;
  const CycleReference(this.foodId, this.cycle);
  bool matches(FoodRecord food) => foodId == food.id && cycle == food.cycle;
  Map<String, dynamic> toJson() => {'foodId': foodId, 'cycle': cycle};
  factory CycleReference.fromJson(Map<String, dynamic> json) =>
      CycleReference(json['foodId'] as String, json['cycle'] as int);
}

class CheckReminder {
  final String day;
  final List<CycleReference> references;
  CheckReminder(this.day, Iterable<CycleReference> references)
    : references = List.unmodifiable(references);

  int get originalCount => references.length;

  List<FoodRecord> pending(InventoryState state, DateTime now) => [
    for (final ref in references)
      if (state.foods[ref.foodId] case final food?)
        if (food.active && ref.matches(food) && !food.dueAt.isAfter(now)) food,
  ];

  Map<String, dynamic> toJson() => {
    'day': day,
    'references': references.map((e) => e.toJson()).toList(),
  };
  factory CheckReminder.fromJson(Map<String, dynamic> json) => CheckReminder(
    json['day'] as String,
    (json['references'] as List).map(
      (e) => CycleReference.fromJson(Map<String, dynamic>.from(e as Map)),
    ),
  );
}

class InventoryState {
  final Map<String, FoodRecord> foods;
  final List<CheckReminder> reminders;
  final Map<StorageZone, int> defaults;
  final DateTime? lastOrganizedAt;
  final int reminderHour;
  final int reminderMinute;
  final int nextNumber;

  InventoryState({
    Map<String, FoodRecord> foods = const {},
    Iterable<CheckReminder> reminders = const [],
    Map<StorageZone, int> defaults = const {
      StorageZone.cold: 3,
      StorageZone.frozen: 14,
      StorageZone.pantry: 3,
    },
    this.lastOrganizedAt,
    this.reminderHour = 17,
    this.reminderMinute = 30,
    this.nextNumber = 1,
  }) : foods = Map.unmodifiable(foods),
       reminders = List.unmodifiable(reminders),
       defaults = Map.unmodifiable(defaults);

  List<FoodRecord> get active => foods.values.where((e) => e.active).toList();
  List<FoodRecord> get history => foods.values.where((e) => !e.active).toList();
  bool hasPending(DateTime now) =>
      reminders.any((r) => r.pending(this, now).isNotEmpty);
  bool shouldShowInactivity(DateTime now) {
    if (active.isEmpty || active.any((food) => !food.dueAt.isAfter(now)))
      return false;
    final origin =
        lastOrganizedAt ??
        active.map((f) => f.addedAt).reduce((a, b) => a.isBefore(b) ? a : b);
    return now.difference(origin) > const Duration(days: 2);
  }

  InventoryState copyWith({
    Map<String, FoodRecord>? foods,
    Iterable<CheckReminder>? reminders,
    Map<StorageZone, int>? defaults,
    DateTime? lastOrganizedAt,
    int? reminderHour,
    int? reminderMinute,
    int? nextNumber,
  }) => InventoryState(
    foods: foods ?? this.foods,
    reminders: reminders ?? this.reminders,
    defaults: defaults ?? this.defaults,
    lastOrganizedAt: lastOrganizedAt ?? this.lastOrganizedAt,
    reminderHour: reminderHour ?? this.reminderHour,
    reminderMinute: reminderMinute ?? this.reminderMinute,
    nextNumber: nextNumber ?? this.nextNumber,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'nextNumber': nextNumber,
    'foods': foods.values.map((e) => e.toJson()).toList(),
    'reminders': reminders.map((e) => e.toJson()).toList(),
    'defaults': {
      for (final entry in defaults.entries) entry.key.name: entry.value,
    },
    'lastOrganizedAt': lastOrganizedAt?.toIso8601String(),
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
  };

  factory InventoryState.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1)
      throw const FormatException('INVENTORY_SCHEMA_UNSUPPORTED');
    final records = (json['foods'] as List)
        .map((e) => FoodRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (records.map((e) => e.id).toSet().length != records.length)
      throw const FormatException('INVENTORY_DUPLICATE_ID');
    final defaults = {
      for (final entry in (json['defaults'] as Map).entries)
        StorageZone.values.byName(entry.key as String): entry.value as int,
    };
    final hour = json['reminderHour'] as int;
    final minute = json['reminderMinute'] as int;
    final nextNumber =
        json['nextNumber'] as int? ??
        records.fold<int>(1, (next, food) {
          final number = int.tryParse(food.id);
          return number != null && number >= next ? number + 1 : next;
        });
    if (defaults.length != StorageZone.values.length ||
        defaults.values.any((d) => d < 1 || d > 3650) ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59 ||
        nextNumber < 1)
      throw const FormatException('INVENTORY_DEFAULTS_INVALID');
    return InventoryState(
      foods: {for (final f in records) f.id: f},
      reminders: (json['reminders'] as List).map(
        (e) => CheckReminder.fromJson(Map<String, dynamic>.from(e as Map)),
      ),
      defaults: defaults,
      lastOrganizedAt: json['lastOrganizedAt'] == null
          ? null
          : DateTime.parse(json['lastOrganizedAt'] as String),
      reminderHour: hour,
      reminderMinute: minute,
      nextNumber: nextNumber,
    );
  }
}
