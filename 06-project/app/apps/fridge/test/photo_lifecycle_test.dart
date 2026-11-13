import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/application/photo_lifecycle.dart';
import 'package:fridge/infrastructure/food_media.dart';
import 'package:fridge_core/fridge_core.dart';

class PickedPhotos extends ManagedFoodPhotos {
  String? selected;
  PickedPhotos(Directory directory) : super(directory: directory);
  @override
  Future<String?> replacement() async => selected;
}

class FailingStorage implements InventoryStorage {
  InventoryState? state;
  bool fail = false;
  @override
  Future<InventoryState?> load() async => state;
  @override
  Future<void> save(InventoryState value) async {
    if (fail) throw StateError('DISK_FULL');
    state = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PickedPhotos photos;
  Future<File> file(String name) async {
    final folder = Directory('${directory.path}/photos');
    await folder.create(recursive: true);
    return File('${folder.path}/$name').writeAsBytes([1, 2, 3]);
  }

  InventoryState state(String path) => InventoryRules.add(
    InventoryState(),
    id: '001',
    photoPath: path,
    zone: StorageZone.cold,
    now: DateTime(2026, 11, 13),
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'fridge-photo-lifecycle-',
    );
    photos = PickedPhotos(directory);
  });
  tearDown(() async => directory.delete(recursive: true));

  test(
    'replacement keeps undo and backup photos; next startup collects only abandoned private files',
    () async {
      final old = await file('1-a.image'), candidate = await file('2-b.image');
      final abandoned = await file('3-c.pending'),
          unrelated = await file('notes.txt');
      final storage = FileInventoryStorage(directory);
      await storage.save(state(old.path));
      final repository = InventoryRepository(storage);
      await repository.open();
      final lifecycle = PhotoLifecycle(
        repository: repository,
        photos: photos,
        snapshotReferences: storage.photoReferences,
      );
      photos.selected = candidate.path;
      await lifecycle.replace('001');
      expect(repository.state.foods['001']!.photoPath, candidate.path);
      expect(repository.retainedPhotoPaths, contains(old.path));
      await lifecycle.recoverOrphans();
      expect(await old.exists(), true);
      expect(await candidate.exists(), true);
      expect(await abandoned.exists(), false);
      expect(await unrelated.exists(), true);
    await repository.undo();
    expect(repository.state.active.single.photoPath, old.path);
    await lifecycle.replace('001');
    expect(repository.state.active.single.photoPath, candidate.path);
      await repository.close();
      final reopened = InventoryRepository(FileInventoryStorage(directory));
      await reopened.open(); // Rotates backup to the committed replacement.
      await PhotoLifecycle(
        repository: reopened,
        photos: photos,
        snapshotReferences: storage.photoReferences,
      ).recoverOrphans();
      expect(await old.exists(), false);
      expect(await candidate.exists(), true);
      expect(await unrelated.exists(), true);
      expect(
        (await FileInventoryStorage(directory).load())!.active.single.photoPath,
        candidate.path,
      );
      await reopened.close();
    },
  );

  test(
    'failed replacement removes only its candidate; cancel and missing record preserve inventory',
    () async {
      final old = await file('1-a.image'), candidate = await file('2-b.image');
      final storage = FailingStorage()..state = state(old.path);
      final repository = InventoryRepository(storage);
      await repository.open();
      final lifecycle = PhotoLifecycle(
        repository: repository,
        photos: photos,
        snapshotReferences: () async => {},
      );
      photos.selected = candidate.path;
      storage.fail = true;
      await expectLater(lifecycle.replace('001'), throwsStateError);
      expect(await candidate.exists(), false);
      expect(await old.exists(), true);
      expect(repository.state.active.single.photoPath, old.path);
      photos.selected = null;
      await lifecycle.replace('001');
      expect(repository.state.active.single.photoPath, old.path);
      final missing = await file('3-c.image');
      photos.selected = missing.path;
      storage.fail = false;
      await expectLater(lifecycle.replace('missing'), throwsStateError);
      expect(await missing.exists(), false);
      expect(await old.exists(), true);
      await repository.close();
    },
  );

  test(
    'unreadable recovery snapshot stops collection; empty source leaves no partial file',
    () async {
      final old = await file('1-a.image'), candidate = await file('2-b.image');
      final storage = FileInventoryStorage(directory);
      await storage.save(state(old.path));
      final repository = InventoryRepository(storage);
      await repository.open();
      await File(
        '${directory.path}/inventory.backup.json',
      ).writeAsString('{broken');
      expect(
        await PhotoLifecycle(
          repository: repository,
          photos: photos,
          snapshotReferences: storage.photoReferences,
        ).recoverOrphans(),
        false,
      );
      expect(await old.exists(), true);
      expect(await candidate.exists(), true);
      final empty = await File('${directory.path}/empty.jpg').writeAsBytes([]);
      await expectLater(photos.persist(empty.path), throwsStateError);
      expect(
        await Directory(
          '${directory.path}/photos',
        ).list().where((f) => f.path.endsWith('.pending')).length,
        0,
      );
      await repository.close();
    },
  );
}
