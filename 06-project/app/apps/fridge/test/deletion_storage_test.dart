import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/application/account_deletion.dart';
import 'package:fridge/infrastructure/deletion_storage.dart';

void main() {
  late Directory directory;
  late FileDeletionStorage storage;
  late File journal;
  final owner = jsonEncode([
    'https://platform.example.test',
    'fridge-mobile',
    'user-one',
  ]);
  final receipt = const DeletionReceipt(
    'request-1',
    '2030-01-01T00:00:00Z',
    '2030-01-08T00:00:00Z',
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fridge-deletion-test-');
    storage = FileDeletionStorage(directory);
    journal = File('${directory.path}/account-deletion.json');
  });
  tearDown(() async {
    expect(
      directory.parent.resolveSymbolicLinksSync(),
      Directory.systemTemp.resolveSymbolicLinksSync(),
    );
    expect(
      directory.uri.pathSegments.where((p) => p.isNotEmpty).last,
      startsWith('fridge-deletion-test-'),
    );
    await directory.delete(recursive: true);
  });
  test(
    'exact server receipt survives new storage instance; no unrelated file changes',
    () async {
      final inventory = File('${directory.path}/inventory.json');
      await inventory.writeAsString('original inventory');
      final entry = DeletionEntry(
        owner,
        'delete-key-1',
        DeletionPhase.accepted,
        receipt,
      );
      await storage.save([entry]);
      final recovered = await FileDeletionStorage(directory).load();
      expect(recovered.single.owner, owner);
      expect(recovered.single.receipt?.eligibleAt, receipt.eligibleAt);
      expect(await inventory.readAsString(), 'original inventory');
      expect(
        (jsonDecode(await journal.readAsString()) as Map).keys,
        unorderedEquals(['version', 'entries']),
      );
    },
  );
  test(
    'corrupt existing journal is preserved even when saving new state',
    () async {
      await journal.writeAsString('{broken');
      await expectLater(storage.load(), throwsFormatException);
      await expectLater(
        storage.save([
          DeletionEntry(owner, 'delete-key-1', DeletionPhase.prepared),
        ]),
        throwsFormatException,
      );
      expect(await journal.readAsString(), '{broken');
    },
  );
  test(
    'duplicate owner and invalid accepted receipt never replace committed journal',
    () async {
      final entry = DeletionEntry(
        owner,
        'delete-key-1',
        DeletionPhase.prepared,
      );
      await storage.save([entry]);
      final original = await journal.readAsBytes();
      expect(() => storage.save([entry, entry]), throwsFormatException);
      expect(
        () => storage.save([
          DeletionEntry(owner, 'delete-key-1', DeletionPhase.accepted),
        ]),
        throwsFormatException,
      );
      expect(await journal.readAsBytes(), original);
    },
  );
  test(
    'unfinished pending file cannot replace the last committed intent',
    () async {
      await storage.save([
        DeletionEntry(owner, 'delete-key-1', DeletionPhase.submitting),
      ]);
      await File('${journal.path}.pending').writeAsString('{interrupted');
      final values = await storage.load();
      expect(values.single.phase, DeletionPhase.submitting);
      await storage.save([values.single.withPhase(DeletionPhase.unknown)]);
      expect((await storage.load()).single.phase, DeletionPhase.unknown);
    },
  );
}
