import 'package:fridge_core/fridge_core.dart';
import 'package:test/test.dart';

class MemoryStorage implements InventoryStorage {
  InventoryState? saved;
  bool fail = false;
  @override
  Future<InventoryState?> load() async => saved;
  @override
  Future<void> save(InventoryState state) async {
    if (fail) throw StateError('DISK_FULL');
    saved = state;
  }
}

void main() {
  final now = DateTime(2026, 11, 4, 18);
  test(
    'serialized concurrent capture never loses a record; failed write is retryable',
    () async {
      final storage = MemoryStorage();
      final repository = InventoryRepository(storage, clock: () => now);
      await repository.open();
      Future<void> add(String id) => repository.update(
        (s) => InventoryRules.add(
          s,
          id: id,
          photoPath: '$id.jpg',
          zone: StorageZone.cold,
          now: now,
        ),
      );
      await Future.wait([add('a'), add('b')]);
      expect(repository.state.active, hasLength(2));
      storage.fail = true;
      await expectLater(add('c'), throwsStateError);
      expect(repository.state.foods.containsKey('c'), isFalse);
      expect(storage.saved!.foods.containsKey('c'), isFalse);
      storage.fail = false;
      await add('c');
      expect(repository.state.active, hasLength(3));
      await repository.close();
    },
  );

  test(
    'undo restores prior cycle and recalculates red dot; failure retains undo',
    () async {
      final storage = MemoryStorage();
      storage.saved = InventoryRules.add(
        InventoryState(),
        id: 'a',
        photoPath: 'a.jpg',
        zone: StorageZone.cold,
        now: DateTime(2026, 11, 1),
      );
      final repository = InventoryRepository(storage, clock: () => now);
      await repository.open();
      expect(repository.state.hasPending(now), isTrue);
      await repository.update(
        (s) => InventoryRules.organize(s, {'a': Remaining.gone}, now),
      );
      expect(repository.state.hasPending(now), isFalse);
      storage.fail = true;
      await expectLater(repository.undo(), throwsStateError);
      expect(repository.canUndo, isTrue);
      storage.fail = false;
      await repository.undo();
      expect(repository.state.hasPending(now), isTrue);
      expect(repository.canUndo, isFalse);
      await repository.close();
    },
  );

  test(
    'stale undo cannot erase a newer capture; numbers stay monotonic',
    () async {
      final repository = InventoryRepository(MemoryStorage(), clock: () => now);
      await repository.open();
      Future<void> add(String id) => repository.update(
        (state) => InventoryRules.add(
          state,
          id: id,
          photoPath: '$id.jpg',
          zone: StorageZone.cold,
          now: now,
        ),
      );
      await add('001');
      final oldTicket = repository.revision;
      await repository.refreshDue();
      expect(repository.revision, oldTicket);
      await add('002');
      await expectLater(
        repository.undo(expectedRevision: oldTicket),
        throwsStateError,
      );
      expect(repository.state.foods.keys, ['001', '002']);
      await repository.undo(expectedRevision: repository.revision);
      expect(repository.state.foods.keys, ['001']);
      expect(repository.state.nextNumber, 3);
      await repository.close();
    },
  );
}
