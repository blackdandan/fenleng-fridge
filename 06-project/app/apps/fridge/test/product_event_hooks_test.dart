import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/application/bootstrap.dart';
import 'package:fridge/application/capture_flow.dart';
import 'package:fridge/application/feedback_session.dart';
import 'package:fridge/application/identity_session.dart';
import 'package:fridge/application/notification_session.dart';
import 'package:fridge_core/fridge_core.dart';
import 'capture_flow_test.dart' show Storage, Photos;
import 'identity_session_test.dart' show Backend, Authorization;
import 'support/feedback_fixture.dart';
import 'support/notification_fixture.dart';

typedef Event = ({String name, Map<String, String> properties});

class EventBootstrap extends FridgeBootstrap {
  final events = <Event>[];
  @override
  void recordEvent(String name, Map<String, String> properties) {
    events.add((name: name, properties: properties));
  }
}

class FailedPhotos extends Photos {
  @override
  Future<String> capture() async => throw StateError('private-photo-path');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Event> events;
  void record(String name, Map<String, String> properties) =>
      events.add((name: name, properties: properties));
  setUp(() {
    events = [];
  });

  test(
    'capture retry records one durable success with original source/zone and no identifiers',
    () async {
      final storage = Storage();
      // Use the same failing writer as the actual repository.
      final actual = InventoryRepository(storage);
      await actual.open();
      final flow = CaptureFlow(
        repository: actual,
        source: Photos(),
        zone: StorageZone.cold,
        onEvent: record,
      );
      storage.full = true;
      await flow.take();
      flow.selectZone(StorageZone.frozen);
      storage.full = false;
      await flow.retry();
      expect(events.map((event) => event.name), [
        'fridge.capture.started.v1',
        'fridge.inventory.added.v1',
        'fridge.inventory.added.v1',
      ]);
      expect(events.map((event) => event.properties['result']), [
        null,
        'save_failed',
        'success',
      ]);
      expect(events.last.properties, {
        'source': 'camera',
        'zone': 'cold',
        'result': 'success',
      });
      expect(actual.state.active.length, 1);
      flow.dispose();
      await actual.close();
    },
  );
  test(
    'read failure is an enum and a broken analytics sink cannot fail a commit',
    () async {
      final repository = InventoryRepository(Storage());
      await repository.open();
      final failed = CaptureFlow(
        repository: repository,
        source: FailedPhotos(),
        zone: StorageZone.pantry,
        onEvent: record,
      );
      await failed.take();
      expect(events.last.properties, {
        'source': 'camera',
        'zone': 'pantry',
        'result': 'read_failed',
      });
      expect(events.toString(), isNot(contains('private-photo-path')));
      failed.dispose();
      final valid = CaptureFlow(
        repository: repository,
        source: Photos(),
        zone: StorageZone.cold,
        onEvent: (_, _) => throw StateError('analytics'),
      );
      await valid.take();
      expect(valid.failed, false);
      expect(repository.state.active.length, 1);
      valid.dispose();
      await repository.close();
    },
  );
  test('review reports only a successful committed update', () async {
    final storage = Storage();
    final actual = InventoryRepository(storage);
    await actual.open();
    await actual.update(
      (state) => InventoryRules.add(
        state,
        id: '001',
        photoPath: 'local-only',
        zone: StorageZone.cold,
        now: DateTime(2026, 11, 13),
      ),
    );
    final bootstrap = EventBootstrap()..inventory = actual;
    storage.full = true;
    await expectLater(
      bootstrap.organize(actual.state.foods['001']!, Remaining.half),
      throwsStateError,
    );
    expect(bootstrap.events, isEmpty);
    storage.full = false;
    await bootstrap.organize(actual.state.foods['001']!, Remaining.half);
    expect(bootstrap.events.single.properties, {
      'state': 'half',
      'zone': 'cold',
    });
    bootstrap.dispose();
    await actual.close();
  });
  test(
    'notification explanation cancel and real request outcomes emit once; existing grant does not',
    () async {
      final repository = InventoryRepository(Storage());
      await repository.open();
      final platform = FakeNotifications();
      final model = NotificationSession(
        repository: repository,
        platform: platform,
        consent: () => true,
        copy: () => {},
        onEvent: record,
      );
      await model.enable(() async => false);
      expect(events.single.properties['result'], 'cancelled');
      expect(platform.requests, 0);
      platform.grant = false;
      await model.enable(() async => true);
      expect(events.last.properties['result'], 'denied');
      platform.grant = true;
      await model.enable(() async => true);
      expect(events.last.properties['result'], 'granted');
      await model.enable(
        () async => throw StateError('must not explain existing grant'),
      );
      expect(events.length, 3);
      expect(platform.requests, 2);
      await model.close();
      await repository.close();
    },
  );
  test(
    'feedback receipt storage failure cannot emit success; retry and duplicate submit emit once',
    () async {
      final storage = DraftMemory(), sender = FeedbackSender();
      final model = FeedbackSession(
        storage: storage,
        gateway: sender,
        consent: () => true,
        onEvent: record,
      );
      await model.start();
      await model.edit('private-feedback');
      sender.send = (_, _) async {
        storage.failWrite = true;
        return 'receipt-1';
      };
      await model.submit();
      expect(events.single.properties, {'result': 'storage_failed'});
      storage.failWrite = false;
      sender.send = (_, _) async => 'receipt-1';
      final first = model.submit(), duplicate = model.submit();
      await Future.wait([first, duplicate]);
      expect(events.length, 2);
      expect(events.last.properties, {'result': 'success'});
      expect(events.toString(), isNot(contains('private-feedback')));
      await model.close();
    },
  );
  test(
    'withdrawal during feedback does not collect a late successful result',
    () async {
      var consent = true;
      final storage = DraftMemory(),
          sender = FeedbackSender(),
          gate = Completer<String>();
      sender.send = (_, _) => gate.future;
      final model = FeedbackSession(
        storage: storage,
        gateway: sender,
        consent: () => consent,
        onEvent: record,
      );
      await model.start();
      await model.edit('private-feedback');
      final sending = model.submit();
      await Future<void>.delayed(Duration.zero);
      consent = false;
      gate.complete('receipt-1');
      await sending;
      expect(events, isEmpty);
      expect(model.receipt, null);
      await model.close();
    },
  );
  test(
    'account login and logout reset analytics without touching inventory ownership',
    () async {
      var resets = 0;
      final backend = Backend();
      final model = IdentitySession(
        backend: backend,
        authorization: Authorization(),
        consent: () => true,
        configured: true,
        onSessionReset: () => resets++,
      );
      await model.login(IdentityProvider.wechat);
      expect(resets, 1);
      await model.logout();
      expect(resets, 2);
      expect(model.signedIn, false);
      await model.close();
    },
  );
}
