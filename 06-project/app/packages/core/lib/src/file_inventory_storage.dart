import 'dart:convert';
import 'dart:io';
import 'inventory.dart';
import 'inventory_repository.dart';

/// Construct only after privacy consent and native data-directory resolution.
/// Backup recovery must never resurrect a permanently removed record.
class FileInventoryStorage implements InventoryStorage {
  final Directory directory;
  bool recoveredFromBackup = false;
  FileInventoryStorage(this.directory);

  File get _main => File('${directory.path}/inventory.json');
  File get _backup => File('${directory.path}/inventory.backup.json');
  File get _temporary => File('${directory.path}/inventory.pending.json');
  File get _backupTemporary =>
      File('${directory.path}/inventory.backup.pending.json');

  Future<InventoryState> _decode(File file) async => InventoryState.fromJson(
    jsonDecode(await file.readAsString()) as Map<String, dynamic>,
  );

  /// Cleanup must retain both committed snapshots; malformed references abort it.
  Future<Set<String>> photoReferences() async {
    final paths = <String>{};
    for (final file in [_main, _backup]) {
      if (await file.exists()) {
        paths.addAll(
          (await _decode(file)).foods.values.map((f) => f.photoPath),
        );
      }
    }
    return paths;
  }

  @override
  Future<InventoryState?> load() async {
    if (await _main.exists()) {
      try {
        return await _decode(_main);
      } on FormatException {
        return _recover();
      } on TypeError {
        return _recover();
      } on ArgumentError {
        return _recover();
      }
    }
    if (await _backup.exists()) return _recover();
    return null;
  }

  Future<InventoryState> _recover() async {
    if (!await _backup.exists())
      throw const FormatException('INVENTORY_RECOVERY_REQUIRED');
    final saved = await _decode(_backup);
    recoveredFromBackup = true;
    return saved;
  }

  @override
  Future<void> save(InventoryState state) async {
    await directory.create(recursive: true);
    await _temporary.writeAsString(jsonEncode(state.toJson()), flush: true);
    final previousFile = recoveredFromBackup ? _backup : _main;
    if (await previousFile.exists()) {
      final previous = await _decode(previousFile);
      final recoverable = previous.copyWith(
        foods: {
          for (final entry in previous.foods.entries)
            if (state.foods.containsKey(entry.key)) entry.key: entry.value,
        },
        nextNumber: previous.nextNumber > state.nextNumber
            ? previous.nextNumber
            : state.nextNumber,
      );
      await _backupTemporary.writeAsString(
        jsonEncode(recoverable.toJson()),
        flush: true,
      );
      await _backupTemporary.rename(_backup.path);
    }
    // Preserve evidence without moving away the last main snapshot before commit.
    if (recoveredFromBackup) {
      if (await _main.exists()) {
        await _main.copy(
          '${directory.path}/inventory.corrupt.${DateTime.now().microsecondsSinceEpoch}.json',
        );
      }
    }
    try {
      await _temporary.rename(_main.path);
      recoveredFromBackup = false;
    } on FileSystemException {
      if (!await _main.exists() && await _backup.exists())
        await _backup.copy(_main.path);
      rethrow;
    }
  }
}
