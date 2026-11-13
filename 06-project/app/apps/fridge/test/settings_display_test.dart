import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/application/bootstrap.dart';
import 'package:fridge_core/fridge_core.dart';
import 'support/runtime_fixture.dart';
import 'support/presentation_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('fenleng.fridge/bootstrap');
  var record = <String, Object?>{};
  var fail = false;
  final writes = <String>[];
  Completer<void>? gate;
  setUp(() {
    record = {'locale': 'ja', 'appearance': 'dark'};
    fail = false;
    writes.clear();
    gate = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(native, (call) async {
          if (call.method == 'privacy.read') return record;
          if (call.method == 'display.locale' ||
              call.method == 'display.theme') {
            final key = call.method == 'display.locale'
                ? 'locale'
                : 'appearance';
            final value = (call.arguments as Map)[key];
            writes.add('$key:$value');
            await gate?.future;
            if (fail) return false;
            record[key] = value;
            return true;
          }
          if (call.method == 'filing.open') return !fail;
          throw PlatformException(code: 'UNEXPECTED_METHOD');
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(native, null),
  );
  test(
    'display choices restore before consent and a failed write never changes visible preferences',
    () async {
      final bootstrap = FridgeBootstrap();
      await bootstrap.initialize();
      expect(bootstrap.stage, BootstrapStage.consent);
      expect(bootstrap.appearance, DisplayAppearance.dark);
      expect(bootstrap.localePreference, 'ja');
      expect(bootstrap.strings!.locale, 'ja');
      fail = true;
      await expectLater(
        bootstrap.changeAppearance(DisplayAppearance.light),
        throwsStateError,
      );
      await expectLater(bootstrap.changeLocale('en'), throwsStateError);
      expect(bootstrap.appearance, DisplayAppearance.dark);
      expect(bootstrap.strings!.locale, 'ja');
      fail = false;
      await bootstrap.changeLocale(null);
      expect(bootstrap.localePreference, isNull);
      final reopened = FridgeBootstrap();
      await reopened.initialize();
      expect(reopened.localePreference, isNull);
      expect(reopened.appearance, DisplayAppearance.dark);
      reopened.dispose();
      bootstrap.dispose();
    },
  );
  test(
    'queued appearance writes preserve order and unsupported locales never write',
    () async {
      final bootstrap = FridgeBootstrap();
      await bootstrap.initialize();
      gate = Completer<void>();
      final first = bootstrap.changeAppearance(DisplayAppearance.light);
      final second = bootstrap.changeAppearance(DisplayAppearance.dark);
      await Future<void>.delayed(Duration.zero);
      expect(writes, ['appearance:light']);
      gate!.complete();
      await Future.wait([first, second]);
      expect(writes, ['appearance:light', 'appearance:dark']);
      expect(record['appearance'], 'dark');
      await expectLater(
        bootstrap.changeLocale('unsupported-tag'),
        throwsArgumentError,
      );
      expect(writes, hasLength(2));
      bootstrap.dispose();
    },
  );
  test('filing launch failure propagates for a translated UI error', () async {
    final bootstrap = FridgeBootstrap();
    fail = true;
    await expectLater(bootstrap.openFiling(), throwsStateError);
    bootstrap.dispose();
  });
  testWidgets(
    'default settings persist without editing existing records and apply to the next record',
    (tester) async {
      final strings = await pageMessages(tester);
      final store = MemoryStorage(pageInventory(count: 2));
      final repo = InventoryRepository(store);
      await repo.open();
      final original = repo.state.foods.map(
        (key, value) => MapEntry(key, value.toJson()),
      );
      final bootstrap = FridgeBootstrap()..inventory = repo;
      try {
        await bootstrap.changeDefaults(
          {StorageZone.cold: 7, StorageZone.frozen: 21, StorageZone.pantry: 5},
          9,
          15,
        );
        expect(
          repo.state.foods.map((key, value) => MapEntry(key, value.toJson())),
          original,
        );
        expect(repo.state.reminderHour, 9);
        expect(repo.state.reminderMinute, 15);
        expect(repo.canUndo, false);
        final next = InventoryRules.add(
          repo.state,
          id: '003',
          photoPath: 'new.jpg',
          zone: StorageZone.cold,
          now: DateTime(2026, 11, 13, 10),
        );
        expect(next.foods['003']!.intervalDays, 7);
        expect(next.foods['003']!.dueAt, DateTime(2026, 11, 20, 9, 15));
        expect(strings, isNotEmpty);
      } finally {
        final closing = repo.close();
        await tester.pump();
        await closing;
        bootstrap.dispose();
      }
    },
  );
}
