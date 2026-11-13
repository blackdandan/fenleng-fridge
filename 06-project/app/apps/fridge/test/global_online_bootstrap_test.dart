import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/application/bootstrap.dart';
import 'package:fridge/application/identity_session.dart';
import 'package:fridge/infrastructure/global_firebase_identity.dart';
import 'package:fridge/infrastructure/platform_identity.dart';
import 'package:fridge/infrastructure/identity_storage.dart';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'global_firebase_identity_test.dart' show Native, configured;
import 'support/deletion_fixture.dart' show DeletionHarness;
import 'global_online_consent_test.dart' show DeferredGlobalBootstrap;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('fenleng.fridge/bootstrap');
  const notifications = MethodChannel('fenleng.fridge/notifications');
  late Directory directory;
  late DeferredGlobalBootstrap bootstrap;
  late Map<String, Object?> record;
  late List<String> calls;
  final global = FridgeBootstrap.channel == 'global';
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'fridge-global-bootstrap-',
    );
    record = {'locale': 'en'};
    calls = [];
    bootstrap = DeferredGlobalBootstrap();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          notifications,
          (call) async => switch (call.method) {
            'status' => {'enabled': false, 'authorized': false},
            'sync' => true,
            'consumeTap' => null,
            _ => throw PlatformException(code: 'UNEXPECTED_NOTIFICATION_CALL'),
          },
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(native, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'privacy.read':
              return record;
            case 'plugins.initialize':
              return true;
            case 'data.directory':
            case 'privacy.directory':
              return directory.path;
            case 'privacy.accept':
              record.addAll(Map<String, Object?>.from(call.arguments as Map));
              return true;
            case 'privacy.revoke':
              record.remove('policyVersion');
              record.remove('releaseChannel');
              record.remove('acceptedAt');
              record['withdrawalPending'] = true;
              return true;
            case 'privacy.finishRevoke':
              record.remove('withdrawalPending');
              return true;
          }
          throw PlatformException(code: 'UNEXPECTED_NATIVE_CALL');
        });
  });
  tearDown(() async {
    await bootstrap.localReminders?.close();
    await bootstrap.inventory?.close();
    await bootstrap.deletion?.close();
    await bootstrap.identity?.close();
    bootstrap.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(native, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, null);
    expect(
      directory.parent.resolveSymbolicLinksSync(),
      Directory.systemTemp.resolveSymbolicLinksSync(),
    );
    expect(
      directory.uri.pathSegments.where((p) => p.isNotEmpty).last,
      startsWith('fridge-global-bootstrap-'),
    );
    await directory.delete(recursive: true);
  });
  test(
    'global accept is serialized and restart restores the same persisted agreement',
    () async {
      await bootstrap.proceed();
      final first = bootstrap.acceptOnline(), second = bootstrap.acceptOnline();
      expect(identical(first, second), isTrue);
      await first;
      expect(calls.where((c) => c == 'privacy.accept').length, 1);
      expect(bootstrap.onlineConsent, isTrue);
      await bootstrap.identity?.close();
      await bootstrap.localReminders?.close();
      await bootstrap.inventory?.close();
      bootstrap.dispose();
      bootstrap = DeferredGlobalBootstrap();
      await bootstrap.proceed();
      expect(bootstrap.stage, BootstrapStage.ready);
      expect(bootstrap.onlineConsent, isTrue);
      expect(bootstrap.identity, isNotNull);
      expect(calls.where((c) => c == 'privacy.accept').length, 1);
    },
    skip: !global,
  );
  test(
    'global withdrawal returns to local home and preserves stock and photos before reconsent',
    () async {
      await bootstrap.proceed();
      await bootstrap.acceptOnline();
      final stock = File('${directory.path}/stock-sentinel');
      await stock.writeAsString('original-stock');
      final photo = File('${directory.path}/photo-sentinel');
      await photo.writeAsBytes([9, 8, 7]);
      await bootstrap.withdrawPrivacy();
      expect(bootstrap.stage, BootstrapStage.ready);
      expect(bootstrap.onlineConsent, isFalse);
      expect(bootstrap.identity, isNull);
      expect(bootstrap.feedback, isNull);
      expect(bootstrap.telemetry, isNull);
      expect(await stock.readAsString(), 'original-stock');
      expect(await photo.readAsBytes(), [9, 8, 7]);
      await bootstrap.acceptOnline();
      expect(bootstrap.onlineConsent, isTrue);
      expect(bootstrap.identity, isNotNull);
    },
    skip: !global,
  );
  test(
    'actual global withdrawal seals SDK files and rejects a late native proof without platform login',
    () async {
      await bootstrap.proceed();
      await bootstrap.acceptOnline();
      await bootstrap.identity!.close();
      bootstrap.identity!.dispose();
      final provider = Native()..pending = Completer<void>();
      final flow = GlobalFirebaseIdentity(
        config: configured,
        native: provider,
        consent: () => bootstrap.onlineConsent,
        platform: 'android',
      );
      final requests = <http.Request>[];
      final backend = PlatformIdentityBackend(
        directory,
        const PlatformIdentityConfig(
          releaseChannel: 'global',
          clientId: 'fenleng-fridge-global-android',
        ),
        client: FenlengFlutterClient(
          options: FenlengClientOptions(
            baseUrl: 'https://platform.example.test',
            storage: IdentityStorage(directory),
            httpClient: MockClient((request) async {
              requests.add(request);
              return http.Response(
                jsonEncode({
                  'accessToken': 'access',
                  'refreshToken': 'refresh',
                }),
                200,
              );
            }),
          ),
        ),
      );
      final identity = IdentitySession(
        backend: backend,
        authorization: PlatformAuthorization(
          backend.config,
          firebase: flow,
          consent: () => bootstrap.onlineConsent,
        ),
        consent: () => bootstrap.onlineConsent,
        configured: true,
      );
      bootstrap.identity = identity;
      final signingIn = identity.login(IdentityProvider.google);
      for (var i = 0; i < 50 && provider.signIns == 0; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(provider.signIns, 1);
      await bootstrap.withdrawPrivacy();
      expect(bootstrap.stage, BootstrapStage.ready);
      expect(bootstrap.onlineConsent, isFalse);
      provider.pending!.complete();
      await signingIn;
      expect(requests, isEmpty);
      expect(provider.uid, isNull);
      expect(identity.signedIn, isFalse);
      expect(
        await IdentityStorage(directory).getItem('fl_session_token'),
        isNull,
      );
      await flow.close();
    },
    skip: !global,
  );
  test(
    'late old deletion cannot replace new feedback or lock a reconsented scope',
    () async {
      await bootstrap.proceed();
      await bootstrap.acceptOnline();
      await bootstrap.deletion?.close();
      bootstrap.deletion?.dispose();
      await bootstrap.identity?.close();
      bootstrap.identity?.dispose();
      final h = DeletionHarness(
        storage: IdentityStorage(directory),
        sessionGate: () => bootstrap.onlineSessionMutable,
      );
      await h.start();
      bootstrap.identity = h.identity;
      bootstrap.deletion = h.model;
      final hold = Completer<void>();
      h.holdDelete = hold;
      final deleting = bootstrap.deleteAccount(() async => true);
      for (var i = 0; i < 60 && h.deletes == 0; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(h.deletes, 1);
      await bootstrap.withdrawPrivacy();
      await bootstrap.acceptOnline();
      final replacement = bootstrap.feedback, identity = bootstrap.identity;
      expect(bootstrap.onlineSessionMutable, isTrue);
      hold.complete();
      await deleting;
      expect(bootstrap.feedback, same(replacement));
      expect(bootstrap.identity, same(identity));
      expect(bootstrap.onlineSessionMutable, isTrue);
      expect(h.journal.entries.single.receipt, isNull);
    },
    skip: !global,
  );
}
