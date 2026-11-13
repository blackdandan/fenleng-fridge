import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/application/notification_session.dart';
import 'package:fridge_core/fridge_core.dart';
import 'support/runtime_fixture.dart';
import 'support/notification_fixture.dart';

void main() {
  late InventoryRepository repository;
  late FakeNotifications platform;
  late NotificationSession model;
  var consent = false;
  var now = DateTime(2026, 11, 13, 10);
  setUp(() async {
    consent = false;
    now = DateTime(2026, 11, 13, 10);
    repository = InventoryRepository(
      MemoryStorage(InventoryState()),
      clock: () => now,
    );
    await repository.open();
    platform = FakeNotifications();
    model = NotificationSession(
      repository: repository,
      platform: platform,
      consent: () => consent,
      clock: () => now,
      copy: () => {
        'title': 'Check',
        'body': 'Due: {count}',
        'channel': 'Checks',
        'locale': 'en',
      },
    );
  });
  tearDown(() async {
    await model.close();
    await repository.close();
  });
  test(
    'no consent makes no platform calls; starting restores without asking notification permission',
    () async {
      await model.start();
      expect(platform.reads + platform.requests + platform.syncs, 0);
      consent = true;
      await model.start();
      expect(platform.requests, 0);
      expect(platform.syncs, 1);
      expect(model.status.enabled, false);
      expect(model.errorKey, isNull);
    },
  );
  test(
    'cancel and repeated enable taps request at most once; refusal preserves in-app inventory',
    () async {
      consent = true;
      await model.start();
      var explanations = 0;
      await model.enable(() async {
        explanations++;
        return false;
      });
      expect(platform.requests, 0);
      final choice = Completer<bool>();
      final first = model.enable(() {
        explanations++;
        return choice.future;
      });
      await model.enable(() async {
        throw StateError('duplicate');
      });
      choice.complete(true);
      await first;
      expect(explanations, 2);
      expect(platform.requests, 1);
      expect(model.status.enabled, true);
      await model.disable();
      expect(model.status.enabled, false);
      platform.current = const NotificationStatus();
      platform.grant = false;
      await model.enable(() async => true);
      expect(model.status.authorized, false);
      expect(model.status.enabled, false);
      expect(repository.state.foods, isEmpty);
    },
  );
  test(
    'successful sync refreshes native capacity status and can clear it',
    () async {
      consent = true;
      var limited = true;
      platform.onSync = () {
        platform.current = NotificationStatus(limited: limited);
      };
      await model.start();
      expect(model.status.limited, true);
      limited = false;
      await model.synchronize();
      expect(model.status.limited, false);
    },
  );
  test(
    'native failure ends busy, uses stable error and permits retry',
    () async {
      consent = true;
      platform.fail = true;
      await model.enable(() async => true);
      expect(model.busy, false);
      expect(model.errorKey, 'notificationUnavailable');
      expect(model.status.enabled, false);
      platform.fail = false;
      await model.enable(() async => true);
      expect(model.errorKey, isNull);
      expect(model.status.enabled, true);
    },
  );
  test(
    'queued synchronization uses the latest committed inventory and foreground refresh collects due',
    () async {
      consent = true;
      platform.gate = Completer<void>();
      final starting = model.start();
      await repository.update(
        (s) => InventoryRules.add(
          s,
          id: '001',
          photoPath: 'private',
          zone: StorageZone.cold,
          now: now,
        ),
      );
      platform.gate!.complete();
      await starting;
      await model.synchronize();
      expect(platform.plan.single['key'], '["001",0]');
      now = DateTime(2026, 11, 20, 10);
      await model.refresh();
      expect(repository.state.hasPending(now), true);
      await repository.update(
        (s) => InventoryRules.organize(s, {'001': Remaining.gone}, now),
      );
      await model.synchronize();
      expect(platform.plan, isEmpty);
    },
  );
  test(
    'cold and live taps are consumed once; invalid/withdrawn callbacks cannot open records',
    () async {
      consent = true;
      platform.launch = '2026-11-13';
      await model.start();
      expect(model.takeTap(), '2026-11-13');
      expect(model.takeTap(), isNull);
      await model.refresh();
      expect(model.pendingDay, isNull);
      platform.events.add('bad');
      expect(model.pendingDay, isNull);
      platform.events.add('2026-11-12');
      expect(model.takeTap(), '2026-11-12');
      consent = false;
      platform.events.add('2026-11-11');
      expect(model.pendingDay, isNull);
    },
  );
  test(
    'closing during explanation prevents a late OS permission request',
    () async {
      consent = true;
      final choice = Completer<bool>();
      final enable = model.enable(() => choice.future);
      await Future<void>.delayed(Duration.zero);
      final closing = model.close();
      choice.complete(true);
      await Future.wait([enable, closing]);
      expect(platform.requests, 0);
      expect(platform.current.enabled, false);
    },
  );
}
