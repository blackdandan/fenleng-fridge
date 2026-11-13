import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/application/account_deletion.dart';

const receipt = DeletionReceipt(
  'request-1',
  '2030-01-01T00:00:00.123456789Z',
  '2030-01-08T00:00:00.123456789Z',
);

class Journal implements DeletionStorage {
  List<DeletionEntry> values = [];
  bool failAccepted = false;
  final writes = <DeletionPhase>[];
  @override
  Future<List<DeletionEntry>> load() async => values;
  @override
  Future<void> save(List<DeletionEntry> entries) async {
    if (failAccepted && entries.last.phase == DeletionPhase.accepted) {
      throw StateError('synthetic quota');
    }
    values = List.of(entries);
    writes.add(entries.last.phase);
  }
}

class Driver implements DeletionGateway, DeletionContext {
  final Journal journal;
  Driver(this.journal);
  @override
  String owner = 'environment/client/user-one';
  @override
  bool current = true;
  int challenges = 0, proofs = 0, deletes = 0, cleanups = 0, stops = 0;
  bool failSubmit = false, failCleanup = false;
  Completer<DeletionReceipt>? heldSubmit;
  Completer<String>? heldProof;
  final keys = <String>[];
  @override
  Future<DeletionContext> open() async {
    current = true;
    return this;
  }

  @override
  Future<String> challenge(String key) async {
    challenges++;
    return 'challenge';
  }

  @override
  Future<String> authorize() async {
    proofs++;
    return heldProof?.future ?? Future.value('fresh-proof');
  }

  @override
  Future<String> confirm(String challenge, String proof, String key) async =>
      'confirmation';
  @override
  Future<void> stopReminders() async {
    stops++;
  }

  @override
  Future<DeletionReceipt> submit(String key, String confirmation) async {
    deletes++;
    keys.add(key);
    expect(journal.values.last.phase, DeletionPhase.submitting);
    if (failSubmit) throw StateError('unknown transport outcome');
    return heldSubmit?.future ?? Future.value(receipt);
  }

  @override
  Future<void> finish() async {
    cleanups++;
    expect(journal.values.last.phase, DeletionPhase.accepted);
    if (failCleanup) throw StateError('local cleanup failed');
  }

  @override
  void cancel() {
    current = false;
  }
}

void main() {
  late Journal journal;
  late Driver driver;
  late AccountDeletionSession session;
  var consent = true, key = 0;
  setUp(() {
    consent = true;
    key = 0;
    journal = Journal();
    driver = Driver(journal);
    session = AccountDeletionSession(
      storage: journal,
      gateway: driver,
      consent: () => consent,
      nextKey: () => 'delete-key-${++key}',
    );
  });
  tearDown(() async {
    await session.close();
    session.dispose();
  });
  Future<void> accept() => session.submit(() async => true);
  Future<void> until(bool Function() condition) async {
    for (var attempt = 0; attempt < 50 && !condition(); attempt++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(condition(), isTrue);
  }

  test(
    'cancel has no persisted intent, proof, reminder stop or DELETE',
    () async {
      await session.submit(() async => false);
      expect(journal.values, isEmpty);
      expect(
        [driver.challenges, driver.proofs, driver.stops, driver.deletes],
        [0, 0, 0, 0],
      );
    },
  );
  test('genuine receipt is durable before local cleanup', () async {
    await accept();
    expect(journal.writes, [
      DeletionPhase.prepared,
      DeletionPhase.submitting,
      DeletionPhase.accepted,
    ]);
    expect(session.entry?.receipt, same(receipt));
    expect(session.receiptIncomplete, isFalse);
    expect([driver.deletes, driver.cleanups], [1, 1]);
  });
  test(
    'known ACK storage failure retains memory and retries locally only',
    () async {
      journal.failAccepted = true;
      await accept();
      expect(session.entry?.phase, DeletionPhase.accepted);
      expect(session.durable, isFalse);
      expect(session.cleanupPending, isTrue);
      expect(driver.cleanups, 0);
      journal.failAccepted = false;
      await session.retryReceipt();
      expect([driver.deletes, driver.cleanups], [1, 1]);
      expect(session.receiptIncomplete, isFalse);
    },
  );
  test('local cleanup failure does not resend DELETE', () async {
    driver.failCleanup = true;
    await accept();
    expect(session.errorKey, 'deletionCleanupFailed');
    expect(session.durable, isTrue);
    expect(session.cleanupPending, isTrue);
    driver.failCleanup = false;
    await session.retryReceipt();
    expect([driver.deletes, driver.cleanups], [1, 2]);
    expect(session.cleanupPending, isFalse);
  });
  test('unknown transport retries original persisted key', () async {
    driver.failSubmit = true;
    await accept();
    expect(session.entry?.phase, DeletionPhase.unknown);
    expect(driver.cleanups, 0);
    driver.failSubmit = false;
    await accept();
    expect(driver.keys, ['delete-key-1', 'delete-key-1']);
  });
  test(
    'explicit new login retires unknown intent and creates a new key',
    () async {
      driver.failSubmit = true;
      await accept();
      await session.refreshOwner();
      expect(session.entry?.phase, DeletionPhase.unknown);
      await session.refreshOwner(afterLogin: true);
      expect(session.entry?.phase, DeletionPhase.cancelled);
      driver.failSubmit = false;
      await accept();
      expect(driver.keys, ['delete-key-1', 'delete-key-2']);
    },
  );
  test('restart after submitting never silently retries or logs in', () async {
    journal.values = [
      const DeletionEntry(
        'old-owner',
        'delete-key-1',
        DeletionPhase.submitting,
      ),
    ];
    await session.start();
    expect(session.entry?.phase, DeletionPhase.unknown);
    expect(driver.deletes, 0);
    expect(driver.proofs, 0);
  });
  test('different owner never overwrites previous owner receipt', () async {
    await accept();
    driver.owner = 'environment/client/user-two';
    await session.refreshOwner();
    expect(session.entry, isNull);
    await accept();
    expect(journal.values.length, 2);
    expect(journal.values.first.owner, 'environment/client/user-one');
  });
  test('page freeze before native proof returns prevents DELETE', () async {
    driver.heldProof = Completer<String>();
    final pending = accept();
    await until(() => driver.proofs == 1);
    session.freeze();
    driver.heldProof!.complete('late-proof');
    await pending;
    expect(driver.deletes, 0);
    expect(session.errorKey, 'deletionCancelled');
  });
  test(
    'withdrawal during DELETE preserves durable submitting marker',
    () async {
      driver.heldSubmit = Completer<DeletionReceipt>();
      final pending = accept();
      await until(() => driver.deletes == 1);
      consent = false;
      session.freeze();
      driver.heldSubmit!.complete(receipt);
      await pending;
      expect(journal.values.last.phase, DeletionPhase.submitting);
      expect(driver.cleanups, 0);
    },
  );
  test(
    'concurrent session invalidation does not discard genuine ACK',
    () async {
      driver.heldSubmit = Completer<DeletionReceipt>();
      final pending = accept();
      await until(() => driver.deletes == 1);
      driver.current = false;
      driver.heldSubmit!.complete(receipt);
      await pending;
      expect(session.entry?.phase, DeletionPhase.accepted);
      expect(driver.cleanups, 1);
    },
  );
  test(
    'duplicate submit shares operation and only calls provider once',
    () async {
      driver.heldProof = Completer<String>();
      final first = accept();
      final second = accept();
      expect(identical(first, second), isTrue);
      await until(() => driver.proofs == 1);
      driver.heldProof!.complete('proof');
      await Future.wait([first, second]);
      expect(driver.deletes, 1);
    },
  );
  test(
    'timestamps reject normalization and require genuine seven-day window',
    () {
      expect(receipt.valid, isTrue);
      expect(deletionInstant('2030-02-30T00:00:00Z'), isNull);
      expect(deletionInstant('2030-01-01T24:00:00Z'), isNull);
      expect(deletionInstant('2030-01-01T00:00:00+00:00'), isNull);
      expect(
        const DeletionReceipt(
          'id',
          '2030-01-01T00:00:00Z',
          '2030-01-07T23:59:59Z',
        ).valid,
        isFalse,
      );
    },
  );
}
