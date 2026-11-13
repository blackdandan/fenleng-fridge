import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/application/bootstrap.dart';
import 'package:fridge/application/identity_session.dart';
import 'package:fridge/infrastructure/identity_storage.dart';
import 'identity_session_test.dart' show Backend, Authorization;

class LocalBackend extends Backend implements LocalIdentityBackend {
  int seals = 0;
  @override
  Future<void> sealForWithdrawal() async {
    seals++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('fenleng.fridge/bootstrap');
  late Directory directory;
  late Map<String, Object?> record;
  late List<String> calls;
  var failFinish = false;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fridge-withdrawal-');
    record = {
      'policyVersion': 'V0.4',
      'releaseChannel': 'china',
      'acceptedAt': '2026-11-13T00:00:00Z',
      'locale': 'zh-CN',
      'appearance': 'dark',
    };
    calls = [];
    failFinish = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(native, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'privacy.read':
              return record;
            case 'plugins.initialize':
              return true;
            case 'data.directory':
              return directory.path;
            case 'legal.open':
              return 'withdraw';
            case 'privacy.accept':
              record.addAll(Map<String, Object?>.from(call.arguments as Map));
              return true;
            case 'privacy.revoke':
              record.remove('policyVersion');
              record.remove('releaseChannel');
              record.remove('acceptedAt');
              record['withdrawalPending'] = true;
              return true;
            case 'privacy.directory':
              if (record['withdrawalPending'] != true) {
                throw PlatformException(code: 'CONSENT_REQUIRED');
              }
              return directory.path;
            case 'privacy.finishRevoke':
              if (failFinish) return false;
              final file = File('${directory.path}/platform-session.json');
              if (await file.exists()) expect(await file.readAsString(), '{}');
              record.remove('withdrawalPending');
              return true;
          }
          throw PlatformException(code: 'UNEXPECTED_METHOD');
        });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(native, null);
    await directory.delete(recursive: true);
  });
  test(
    'durable withdrawal keeps inventory and photos, clears active tokens and returns to consent',
    () async {
      final bootstrap = FridgeBootstrap();
      await bootstrap.initialize();
      final inventory = File('${directory.path}/inventory-sentinel');
      await inventory.writeAsString('unchanged-inventory');
      final photo = File('${directory.path}/photo-sentinel');
      await photo.writeAsBytes([1, 2, 3]);
      await IdentityStorage(directory).setItem('test-token', 'private-token');
      final first = bootstrap.withdrawPrivacy(),
          second = bootstrap.withdrawPrivacy();
      expect(identical(first, second), true);
      await first;
      expect(bootstrap.stage, BootstrapStage.consent);
      expect(bootstrap.onlineConsent, false);
      expect(bootstrap.identity, null);
      expect(bootstrap.telemetry, null);
      expect(bootstrap.feedback, null);
      expect(
        await File('${directory.path}/platform-session.json').readAsString(),
        '{}',
      );
      expect(await inventory.readAsString(), 'unchanged-inventory');
      expect(await photo.readAsBytes(), [1, 2, 3]);
      expect(record, {'locale': 'zh-CN', 'appearance': 'dark'});
      expect(calls.where((call) => call == 'privacy.revoke').length, 1);
      await bootstrap.accept();
      expect(bootstrap.stage, BootstrapStage.ready);
      expect(bootstrap.onlineConsent, true);
      expect(bootstrap.inventory, isNotNull);
      expect(await inventory.readAsString(), 'unchanged-inventory');
      expect(await photo.readAsBytes(), [1, 2, 3]);
      await bootstrap.localReminders?.close();
      await bootstrap.inventory?.close();
      bootstrap.dispose();
    },
  );
  test(
    'cleanup failure stays blocked; restart recovers pending intent before opening business data',
    () async {
      record = {'locale': 'zh-CN', 'withdrawalPending': true};
      final stock = File('${directory.path}/inventory.json');
      await stock.writeAsString('not-even-read-before-consent');
      await File(
        '${directory.path}/platform-session.json',
      ).writeAsString('{"old":"private"}');
      failFinish = true;
      var bootstrap = FridgeBootstrap();
      await bootstrap.initialize();
      expect(bootstrap.stage, BootstrapStage.withdrawalError);
      expect(record['withdrawalPending'], true);
      expect(calls, isNot(contains('plugins.initialize')));
      expect(calls, isNot(contains('data.directory')));
      bootstrap.dispose();
      calls.clear();
      failFinish = false;
      bootstrap = FridgeBootstrap();
      await bootstrap.initialize();
      expect(bootstrap.stage, BootstrapStage.consent);
      expect(record['withdrawalPending'], null);
      expect(await stock.readAsString(), 'not-even-read-before-consent');
      expect(bootstrap.identity, null);
      expect(calls, isNot(contains('plugins.initialize')));
      bootstrap.dispose();
    },
  );
  test(
    'sealed storage cannot restore credentials through late SDK writes',
    () async {
      final storage = IdentityStorage(directory);
      await storage.setItem('access', 'private-token');
      await storage.sealForWithdrawal();
      await IdentityStorage.clearRevokedSession(directory);
      await expectLater(
        storage.setItem('access', 'late-token'),
        throwsStateError,
      );
      expect(await storage.getItem('access'), null);
      expect(await IdentityStorage(directory).getItem('access'), null);
      final fresh = IdentityStorage(directory);
      await fresh.setItem('access', 'new-consented-session');
      await storage.removeItem('access');
      expect(await fresh.getItem('access'), 'new-consented-session');
    },
  );
  test(
    'withdrawal fences late native authorization without waiting or sending logout HTTP',
    () async {
      final backend = LocalBackend(),
          authorization = Authorization()..gate = Completer<String>();
      final model = IdentitySession(
        backend: backend,
        authorization: authorization,
        consent: () => true,
        configured: true,
      );
      final login = model.login(IdentityProvider.wechat);
      await Future<void>.delayed(Duration.zero);
      await model.stopForWithdrawal();
      expect(backend.seals, 1);
      expect(backend.exchanges, 0);
      expect(backend.closed, false);
      authorization.gate!.complete('one-time-code');
      await login;
      await model.close();
      expect(backend.exchanges, 0);
      expect(backend.logouts, 0);
      expect(backend.closed, true);
      expect(model.signedIn, false);
    },
  );
}
