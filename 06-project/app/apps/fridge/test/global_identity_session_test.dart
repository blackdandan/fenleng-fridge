import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';
import 'package:fridge/application/account_deletion.dart';
import 'package:fridge/application/identity_session.dart';
import 'package:fridge/infrastructure/platform_deletion.dart';
import 'package:fridge/infrastructure/platform_identity.dart';
import 'package:fridge/infrastructure/global_firebase_identity.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'global_firebase_identity_test.dart' show Native, configured;
import 'support/deletion_fixture.dart' show DeletionJournal;

void main() {
  late Native native;
  late GlobalFirebaseIdentity flow;
  late IdentitySession session;
  late PlatformIdentityBackend backend;
  late FenlengMemoryStorageAdapter storage;
  late List<http.Request> requests;
  const config = PlatformIdentityConfig(
    releaseChannel: 'global',
    clientId: 'fenleng-fridge-global-android',
  );
  setUp(() {
    native = Native();
    requests = [];
    storage = FenlengMemoryStorageAdapter();
    flow = GlobalFirebaseIdentity(
      config: configured,
      native: native,
      consent: () => true,
      platform: 'android',
    );
    final client = FenlengFlutterClient(
      options: FenlengClientOptions(
        baseUrl: 'https://platform.example.test',
        storage: storage,
        httpClient: MockClient((request) async {
          requests.add(request);
          final path = request.url.path;
          final data = path.endsWith('/login')
              ? {
                  'accessToken': 'platform-access',
                  'refreshToken': 'platform-refresh',
                }
              : path.endsWith('/me')
              ? {'id': 'human-one', 'kind': 'HUMAN', 'status': 'ACTIVE'}
              : path.endsWith('/challenges')
              ? {
                  'challengeId': 'fdc-global',
                  'provider': 'FIREBASE',
                  'expiresAt': '2030-01-01T00:05:00Z',
                }
              : path.endsWith('/confirm')
              ? {
                  'confirmationId': 'fdc-global',
                  'deletionIdempotencyKey': 'delete-global-intent',
                  'expiresAt': '2030-01-01T00:05:00Z',
                }
              : path.endsWith('/data-requests')
              ? {
                  'id': 'request-global',
                  'userId': 'human-one',
                  'type': 'DELETE',
                  'status': 'PENDING',
                  'requestedAt': '2030-01-01T00:00:00Z',
                  'nextAttemptAt': '2030-01-08T00:00:00Z',
                }
              : path.endsWith('/logout')
              ? <String, dynamic>{}
              : throw StateError('Unexpected SDK request');
          return http.Response(jsonEncode(data), 200);
        }),
      ),
    );
    backend = PlatformIdentityBackend(
      Directory.systemTemp,
      config,
      client: client,
    );
    session = IdentitySession(
      backend: backend,
      authorization: PlatformAuthorization(
        config,
        firebase: flow,
        consent: () => true,
      ),
      consent: () => true,
      configured: true,
    );
  });
  tearDown(() async {
    await session.close();
    session.dispose();
    await flow.close();
  });
  test('compiled channel requires its own registered client namespace', () {
    expect(
      const PlatformIdentityConfig(
        enabled: true,
        releaseChannel: 'global',
        baseUrl: 'https://platform.example.test',
        clientId: 'fenleng-fridge-android',
      ).ready,
      isFalse,
    );
    expect(
      const PlatformIdentityConfig(
        enabled: true,
        releaseChannel: 'global',
        baseUrl: 'https://platform.example.test',
        clientId: 'fenleng-fridge-global-android',
      ).ready,
      isTrue,
    );
    expect(
      const PlatformIdentityConfig(
        enabled: true,
        releaseChannel: 'china',
        baseUrl: 'https://platform.example.test',
        clientId: 'fenleng-fridge-global-android',
      ).ready,
      isFalse,
    );
  });
  test(
    'global Google proof exchanges only through official Firebase platform login',
    () async {
      await session.login(IdentityProvider.google);
      expect(session.signedIn, isTrue);
      expect(session.errorKey, isNull);
      expect(
        requests.single.url.path,
        '/api/platform/v1/auth/federated/firebase/login',
      );
      expect(jsonDecode(requests.single.body), {
        'applicationCode': 'fenleng-fridge',
        'clientId': 'fenleng-fridge-global-android',
        'idToken': 'fresh-provider-token',
      });
      expect(await storage.getItem('fl_session_token'), 'platform-access');
      expect(native.signIns, 1);
      expect(native.reauths, 0);
    },
  );
  test(
    'opposite-channel providers cannot fall through to a different login endpoint',
    () async {
      await session.login(IdentityProvider.wechat);
      expect(session.errorKey, 'loginNotConfigured');
      expect(requests, isEmpty);
      expect(native.initializes, 0);
      final china = PlatformAuthorization(
        const PlatformIdentityConfig(releaseChannel: 'china'),
        firebase: flow,
        consent: () => true,
      );
      await expectLater(
        china.authorize(IdentityProvider.google),
        throwsA(isA<IdentityFailure>()),
      );
      expect(native.initializes, 0);
    },
  );
  test(
    'global Apple proof also uses Firebase exchange rather than China Apple direct verification',
    () async {
      final ios = GlobalFirebaseIdentity(
        config: const GlobalFirebaseConfig(
          enabled: true,
          channel: 'global',
          projectId: 'fenleng-fridge-global',
          appId: '1:123:ios:abc123',
          apiKey: 'AIza000000000000000000000000000000000',
          senderId: '123',
          googleServerClientId: 'fridge-web.apps.googleusercontent.com',
          googleIosClientId: 'fridge-ios.apps.googleusercontent.com',
        ),
        native: native,
        consent: () => true,
        platform: 'ios',
      );
      final authorization = PlatformAuthorization(
        config,
        firebase: ios,
        consent: () => true,
      );
      try {
        await backend.exchange(
          IdentityProvider.apple,
          await authorization.authorize(IdentityProvider.apple),
        );
        expect(
          requests.single.url.path,
          '/api/platform/v1/auth/federated/firebase/login',
        );
        expect(native.signIns, 1);
        expect(native.uid, 'firebase-one');
      } finally {
        await ios.close();
      }
    },
  );
  test(
    'global deletion reauthenticates existing provider and persists ACK before clearing both sessions',
    () async {
      await session.login(IdentityProvider.google);
      final journal = DeletionJournal();
      final model = AccountDeletionSession(
        storage: journal,
        gateway: PlatformDeletionGateway(
          auth: backend.auth,
          identity: () => session,
          provider: () => IdentityProvider.google,
          consent: () => true,
          configured: true,
          firebase: true,
          clock: () => DateTime.utc(2030),
        ),
        consent: () => true,
        nextKey: () => 'delete-global-intent',
      );
      try {
        await model.submit(() async => true);
        expect(model.entry?.phase, DeletionPhase.accepted);
        expect(model.cleanupPending, isFalse);
        expect(native.signIns, 1);
        expect(native.reauths, 1);
        expect(native.uid, isNull);
        expect(journal.entries.single.phase, DeletionPhase.accepted);
        expect(requests.where((r) => r.url.path.endsWith('/login')).length, 1);
        expect(
          jsonDecode(
            requests.firstWhere((r) => r.url.path.endsWith('/challenges')).body,
          )['provider'],
          'FIREBASE',
        );
        final deletion = requests.firstWhere(
          (r) => r.url.path.endsWith('/data-requests'),
        );
        expect(deletion.headers['X-Action-Confirmation'], 'fdc-global');
        expect(deletion.headers['Idempotency-Key'], 'delete-global-intent');
        expect(await storage.getItem('fl_session_token'), isNull);
        expect(requests.any((r) => r.url.path.endsWith('/logout')), isFalse);
      } finally {
        await model.close();
        model.dispose();
      }
    },
  );
  test('provider cleanup failure retries only local receipt cleanup', () async {
    await session.login(IdentityProvider.google);
    native.failClear = true;
    final model = AccountDeletionSession(
      storage: DeletionJournal(),
      gateway: PlatformDeletionGateway(
        auth: backend.auth,
        identity: () => session,
        provider: () => IdentityProvider.google,
        consent: () => true,
        configured: true,
        firebase: true,
        clock: () => DateTime.utc(2030),
      ),
      consent: () => true,
      nextKey: () => 'delete-global-intent',
    );
    try {
      await model.submit(() async => true);
      expect(model.cleanupPending, isTrue);
      expect(model.errorKey, 'deletionCleanupFailed');
      await model.retryReceipt();
      expect(model.cleanupPending, isFalse);
      expect(native.uid, isNull);
      expect(
        requests.where((r) => r.url.path.endsWith('/data-requests')).length,
        1,
      );
    } finally {
      await model.close();
      model.dispose();
    }
  });
  test(
    'ordinary app close preserves settled provider cache for a new reauth controller',
    () async {
      await session.login(IdentityProvider.google);
      await session.close();
      expect(native.uid, 'firebase-one');
      final next = GlobalFirebaseIdentity(
        config: configured,
        native: native,
        consent: () => true,
        platform: 'android',
      );
      try {
        expect(
          await next.authorize(FirebaseProvider.google, reauthenticate: true),
          'fresh-provider-token',
        );
        await expectLater(
          flow.authorize(FirebaseProvider.google),
          throwsA(isA<IdentityFailure>()),
        );
        expect(native.uid, 'firebase-one');
      } finally {
        await next.close();
      }
    },
  );
  test(
    'explicit logout clears Provider and platform identity without deleting local inventory',
    () async {
      await session.login(IdentityProvider.google);
      await session.logout();
      expect(session.signedIn, isFalse);
      expect(native.uid, isNull);
      expect(await storage.getItem('fl_session_token'), isNull);
      expect(requests.last.url.path, '/api/platform/v1/auth/logout');
    },
  );
}
