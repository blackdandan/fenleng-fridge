import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge/application/capture_flow.dart';

class Storage implements InventoryStorage {
  InventoryState? state;
  bool full = false;
  @override
  Future<InventoryState?> load() async => state;
  @override
  Future<void> save(InventoryState value) async {
    if (full) throw StateError('QUOTA');
    state = value;
  }
}

class Photos implements FoodPhotoSource {
  int captured = 0, persisted = 0;
  @override
  Future<String> capture() async {
    captured++;
    return 'temporary.jpg';
  }

  @override
  Future<List<String>> album() async => ['a.jpg', 'b.jpg'];
  @override
  Future<String> persist(String path) async {
    persisted++;
    return 'managed/$path';
  }

  @override
  Future<void> discardSaved(String path) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'quota retry reuses the photo and original zone; sequential numbers persist',
    () async {
      final storage = Storage();
      final repository = InventoryRepository(storage);
      await repository.open();
      final photos = Photos();
      final flow = CaptureFlow(
        repository: repository,
        source: photos,
        zone: StorageZone.cold,
      );
      storage.full = true;
      await flow.take();
      expect(flow.hasPending, isTrue);
      expect(flow.failed, isTrue);
      expect(flow.savedCount, 0);
      flow.selectZone(StorageZone.frozen);
      storage.full = false;
      await flow.retry();
      expect(photos.captured, 1);
      expect(photos.persisted, 1);
      expect(repository.state.foods['001']!.zone, StorageZone.cold);
      await flow.take();
      expect(repository.state.foods['002']!.zone, StorageZone.frozen);
      expect(flow.savedCount, 2);
      expect(InventoryState.fromJson(repository.state.toJson()).nextNumber, 3);
      flow.dispose();
      await repository.close();
    },
  );
  test('album produces independent records without opening camera', () async {
    final repository = InventoryRepository(Storage());
    await repository.open();
    final photos = Photos();
    final flow = CaptureFlow(
      repository: repository,
      source: photos,
      zone: StorageZone.pantry,
    );
    await flow.chooseAlbum();
    expect(repository.state.active.map((f) => f.photoPath), [
      'managed/a.jpg',
      'managed/b.jpg',
    ]);
    expect(
      repository.state.active.every((f) => f.zone == StorageZone.pantry),
      isTrue,
    );
    expect(photos.captured, 0);
    expect(flow.savedCount, 2);
    flow.dispose();
    await repository.close();
  });
}
