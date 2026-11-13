import 'check_schedule.dart';

class FoodRecord {
  final String id;
  final String photoPath;
  final StorageZone zone;
  final Remaining remaining;
  final DateTime addedAt;
  final DateTime? confirmedAt;
  final DateTime dueAt;
  final int intervalDays;
  final int cycle;

  const FoodRecord({
    required this.id,
    required this.photoPath,
    required this.zone,
    required this.addedAt,
    required this.dueAt,
    required this.intervalDays,
    this.remaining = Remaining.full,
    this.confirmedAt,
    this.cycle = 0,
  });

  bool get active => remaining != Remaining.gone;

  FoodRecord copyWith({
    String? photoPath,
    StorageZone? zone,
    Remaining? remaining,
    DateTime? addedAt,
    DateTime? confirmedAt,
    DateTime? dueAt,
    int? intervalDays,
    int? cycle,
  }) => FoodRecord(
    id: id,
    photoPath: photoPath ?? this.photoPath,
    zone: zone ?? this.zone,
    remaining: remaining ?? this.remaining,
    addedAt: addedAt ?? this.addedAt,
    confirmedAt: confirmedAt ?? this.confirmedAt,
    dueAt: dueAt ?? this.dueAt,
    intervalDays: intervalDays ?? this.intervalDays,
    cycle: cycle ?? this.cycle,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'photoPath': photoPath,
    'zone': zone.name,
    'remaining': remaining.name,
    'addedAt': addedAt.toIso8601String(),
    'confirmedAt': confirmedAt?.toIso8601String(),
    'dueAt': dueAt.toIso8601String(),
    'intervalDays': intervalDays,
    'cycle': cycle,
  };

  factory FoodRecord.fromJson(Map<String, dynamic> json) {
    final record = FoodRecord(
      id: json['id'] as String,
      photoPath: json['photoPath'] as String,
      zone: StorageZone.values.byName(json['zone'] as String),
      remaining: Remaining.values.byName(json['remaining'] as String),
      addedAt: DateTime.parse(json['addedAt'] as String),
      confirmedAt: json['confirmedAt'] == null
          ? null
          : DateTime.parse(json['confirmedAt'] as String),
      dueAt: DateTime.parse(json['dueAt'] as String),
      intervalDays: json['intervalDays'] as int,
      cycle: json['cycle'] as int,
    );
    if (record.id.isEmpty ||
        record.photoPath.isEmpty ||
        record.cycle < 0 ||
        record.intervalDays < 1 ||
        record.intervalDays > 3650) {
      throw const FormatException('INVENTORY_RECORD_INVALID');
    }
    return record;
  }
}
