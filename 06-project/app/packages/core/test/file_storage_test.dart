import 'dart:io';
import 'package:fridge_core/fridge_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fridge-storage-test-');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'real disk snapshots reload and keep a recoverable previous commit',
    () async {
      final storage = FileInventoryStorage(directory);
      expect(await storage.load(), isNull);
      var state = InventoryState();
      await storage.save(state);
      state = InventoryRules.add(
        state,
        id: 'a',
        photoPath: 'a.jpg',
        zone: StorageZone.cold,
        now: DateTime(2026, 11, 1),
      );
      await storage.save(state);
      expect(
        (await FileInventoryStorage(directory).load())!.active.single.id,
        'a',
      );
      expect(
        await File('${directory.path}/inventory.backup.json').exists(),
        isTrue,
      );
      expect(
        await File('${directory.path}/inventory.pending.json').exists(),
        isFalse,
      );
    },
  );

  test(
    'corrupt latest commit recovers backup and preserves corrupt evidence',
    () async {
      final storage = FileInventoryStorage(directory);
      await storage.save(InventoryState());
      final state = InventoryRules.add(
        InventoryState(),
        id: 'a',
        photoPath: 'a.jpg',
        zone: StorageZone.cold,
        now: DateTime(2026, 11, 1),
      );
      await storage.save(state);
      await File('${directory.path}/inventory.json').writeAsString('{broken');
      final recovery = FileInventoryStorage(directory);
      final recovered = await recovery.load();
      expect(recovery.recoveredFromBackup, isTrue);
      expect(recovered!.active, isEmpty);
      await recovery.save(recovered);
      expect(
        directory.listSync().where(
          (f) => f.path.contains('inventory.corrupt.'),
        ),
        hasLength(1),
      );
      expect((await FileInventoryStorage(directory).load())!.active, isEmpty);
    },
  );

  test(
    'no usable backup fails without replacing corrupt data with an empty fridge',
    () async {
      final file = File('${directory.path}/inventory.json');
      await file.writeAsString('broken');
      await expectLater(
        FileInventoryStorage(directory).load(),
        throwsFormatException,
      );
      expect(await file.readAsString(), 'broken');
    },
  );

  test('corrupt main cannot resurrect a permanently deleted record', () async {
    final storage = FileInventoryStorage(directory);
    var state = InventoryState();
    for (final id in ['001', '002']) {
      state = InventoryRules.add(
        state,
        id: id,
        photoPath: '$id.jpg',
        zone: StorageZone.cold,
        now: DateTime(2026, 11, 1),
      );
    }
    await storage.save(state);
    state = InventoryRules.delete(state, '001');
    await storage.save(state);
    await File('${directory.path}/inventory.json').writeAsString('{broken');
    final recovered = (await FileInventoryStorage(directory).load())!;
    expect(recovered.foods.keys, ['002']);
    expect(recovered.nextNumber, greaterThan(2));
  });
}
