import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/application/account_deletion.dart';
import 'package:fridge/application/identity_session.dart';
import 'package:fridge/infrastructure/platform_deletion.dart';
import 'package:fridge/infrastructure/platform_identity.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class Proof implements IdentityAuthorization {
  final providers = <IdentityProvider>[];
  Completer<String>? pending;
  @override
  Future<String> authorize(IdentityProvider provider) async {
    providers.add(provider);
    return pending?.future ?? Future.value('fresh-native-proof');
  }
}

class Tokens extends FenlengMemoryStorageAdapter {
  bool fail = false;
  @override
  Future<void> removeItem(String key) async {
    if (fail) {
      fail = false;
      throw StateError('synthetic local quota');
    }
    return super.removeItem(key);
  }
}

void main() {
  late Tokens tokens;
  late PlatformIdentityBackend backend;
  late IdentitySession session;
  late Proof proof;
  late PlatformDeletionGateway gateway;
  late List<http.Request> requests;
  late DateTime now;
  var consent = true,
      kind = 'HUMAN',
      status = 'ACTIVE',
      responseUser = 'user-one';
  var selected = IdentityProvider.wechat;
  const expiry = '2030-01-01T00:05:00Z';
  Future<http.Response> response(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    final data = switch (path) {
      '/api/platform/v1/users/me' => {
        'id': 'user-one',
        'kind': kind,
        'status': status,
      },
      '/api/platform/v1/auth/step-up/self-deletion/challenges' => {
        'challengeId': 'fdc-test',
        'provider': jsonDecode(request.body)['provider'],
        'expiresAt': expiry,
      },
      '/api/platform/v1/auth/step-up/self-deletion/challenges/fdc-test/confirm' =>
        {
          'confirmationId': 'fdc-test',
          'deletionIdempotencyKey': 'delete-intent',
          'expiresAt': expiry,
        },
      '/api/platform/v1/users/me/data-requests' => {
        'id': 'request-one',
        'userId': responseUser,
        'type': 'DELETE',
        'status': 'PENDING',
        'requestedAt': '2030-01-01T00:00:00Z',
        'nextAttemptAt': '2030-01-08T00:00:00Z',
      },
      '/api/platform/v1/auth/wechat/login' => {
        'accessToken': 'replacement-access',
        'refreshToken': 'replacement-refresh',
      },
      _ => throw StateError('Unexpected SDK call'),
    };
    return http.Response(jsonEncode(data), 200);
  }

  setUp(() async {
    requests = [];
    tokens = Tokens();
    consent = true;
    kind = 'HUMAN';
    status = 'ACTIVE';
    responseUser = 'user-one';
    selected = IdentityProvider.wechat;
    now = DateTime.utc(2030);
    await tokens.setItem('access', 'original-access');
    await tokens.setItem('access:refresh', 'original-refresh');
    final client = FenlengFlutterClient(
      options: FenlengClientOptions(
        baseUrl: 'https://platform.example.test',
        storage: tokens,
        tokenKey: 'access',
        httpClient: MockClient(response),
      ),
    );
    backend = PlatformIdentityBackend(
      Directory.systemTemp,
      const PlatformIdentityConfig(clientId: 'fenleng-fridge-android'),
      client: client,
    );
    proof = Proof();
    session = IdentitySession(
      backend: backend,
      authorization: proof,
      consent: () => consent,
      configured: true,
    );
    session.signedIn = true;
    gateway = PlatformDeletionGateway(
      auth: backend.auth,
      identity: () => session,
      provider: () => selected,
      consent: () => consent,
      configured: true,
      clock: () => now,
    );
  });
  tearDown(() async {
    await session.close();
    session.dispose();
  });
  Future<DeletionContext> verified() async {
    final context = await gateway.open();
    final id = await context.challenge('delete-intent');
    final native = await context.authorize();
    await context.confirm(id, native, 'delete-intent');
    return context;
  }

  test(
    'SDK challenge proof confirmation and DELETE preserve credentials until local-only cleanup',
    () async {
      final context = await verified();
      expect(jsonDecode(context.owner), [
        'https://platform.example.test',
        'fenleng-fridge-android',
        'user-one',
      ]);
      expect(await tokens.getItem('access'), 'original-access');
      final result = await context.submit('delete-intent', 'fdc-test');
      expect(result.valid, isTrue);
      final sent = requests.last;
      expect(sent.headers['X-Action-Confirmation'], 'fdc-test');
      expect(sent.headers['Idempotency-Key'], 'delete-intent');
      expect(sent.headers['Authorization'], 'Bearer original-access');
      expect(jsonDecode(sent.body), {'type': 'DELETE'});
      expect(proof.providers, [IdentityProvider.wechat]);
      expect(jsonDecode(requests[2].body), {
        'identityToken': 'fresh-native-proof',
      });
      expect(await tokens.getItem('access:refresh'), 'original-refresh');
      await context.finish();
      expect(await tokens.getItem('access'), isNull);
      expect(session.signedIn, isFalse);
      expect(requests.length, 4); // no login, refresh or HTTP logout
    },
  );
  test(
    'signed-out guest busy and disabled contexts never call profile or provider',
    () async {
      for (final state in ['signedOut', 'guest', 'busy']) {
        session.signedIn = state != 'signedOut';
        session.guestReady = state == 'guest';
        session.busy = state == 'busy';
        await expectLater(gateway.open(), throwsA(isA<DeletionFailure>()));
      }
      session.busy = false;
      consent = false;
      await expectLater(gateway.open(), throwsA(isA<DeletionFailure>()));
      expect(requests, isEmpty);
      expect(proof.providers, isEmpty);
    },
  );
  test('server non-human or pending profile cannot create challenge', () async {
    kind = 'GUEST';
    await expectLater(gateway.open(), throwsA(isA<DeletionFailure>()));
    kind = 'HUMAN';
    status = 'DELETION_PENDING';
    await expectLater(gateway.open(), throwsA(isA<DeletionFailure>()));
    expect(requests.length, 2);
    expect(proof.providers, isEmpty);
  });
  test(
    'Apple proof follows selected channel without opening Apple login session',
    () async {
      selected = IdentityProvider.apple;
      await verified();
      expect(jsonDecode(requests[1].body)['provider'], 'APPLE');
      expect(proof.providers, [IdentityProvider.apple]);
      expect(requests.length, 3);
      expect(await tokens.getItem('access'), 'original-access');
    },
  );
  test('expired challenge cannot ask native provider for proof', () async {
    final context = await gateway.open();
    await context.challenge('delete-intent');
    now = DateTime.utc(2030, 1, 1, 0, 5);
    await expectLater(context.authorize(), throwsA(isA<DeletionFailure>()));
    expect(proof.providers, isEmpty);
    expect(requests.length, 2);
  });
  test('mismatched confirmation key cannot submit DELETE', () async {
    final context = await verified();
    await expectLater(
      context.submit('different-key', 'fdc-test'),
      throwsA(isA<DeletionFailure>()),
    );
    expect(requests.length, 3);
  });
  test(
    'cancel during native proof prevents confirmation and preserves session',
    () async {
      final context = await gateway.open();
      await context.challenge('delete-intent');
      proof.pending = Completer<String>();
      final pending = context.authorize();
      final failure = expectLater(pending, throwsA(isA<DeletionFailure>()));
      context.cancel();
      proof.pending!.complete('late-native-proof');
      await failure;
      expect(requests.length, 2);
      expect(await tokens.getItem('access'), 'original-access');
    },
  );
  test(
    'old context cleanup never removes a newer successful identity',
    () async {
      final context = await verified();
      await context.submit('delete-intent', 'fdc-test');
      await session.login(IdentityProvider.wechat);
      await context.finish();
      expect(session.signedIn, isTrue);
      expect(await tokens.getItem('access'), 'replacement-access');
      expect(requests.length, 5);
    },
  );
  test(
    'local cleanup failure retries its own revision without another DELETE',
    () async {
      final context = await verified();
      await context.submit('delete-intent', 'fdc-test');
      tokens.fail = true;
      await expectLater(context.finish(), throwsStateError);
      await context.finish();
      expect(await tokens.getItem('access:refresh'), isNull);
      expect(requests.length, 4);
    },
  );
  test('foreign user ACK cannot be presented as a deletion receipt', () async {
    final context = await verified();
    responseUser = 'other-user';
    await expectLater(
      context.submit('delete-intent', 'fdc-test'),
      throwsA(isA<DeletionFailure>()),
    );
    expect(await tokens.getItem('access'), 'original-access');
  });
}
