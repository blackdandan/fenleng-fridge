import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FailingKindStorage extends FenlengMemoryStorageAdapter {
  @override
  Future<void> setItem(String key, String value) async {
    if (key.endsWith(':kind')) throw StateError('Disk full');
    await super.setItem(key, value);
  }
}

void main() {
  late FenlengMemoryStorageAdapter storage;
  late FlutterAuthSDK auth;
  late FenlengFlutterClient client;
  late Future<http.Response> Function(http.Request) respond;
  setUp(() {
    storage = FenlengMemoryStorageAdapter();
    respond = (_) async => http.Response(
        jsonEncode({
          'accessToken': 'access',
          'refreshToken': 'refresh',
          'tokenType': 'Bearer',
          'expiresIn': 300,
          'applicationId': 'app-fridge',
          'sessionId': 'session-guest',
        }),
        200);
    client = FenlengFlutterClient(
        options: FenlengClientOptions(
      baseUrl: 'http://localhost:8080',
      storage: storage,
      httpClient: MockClient((request) => respond(request)),
    ));
    auth = FlutterAuthSDK(
        client: client,
        applicationCode: 'fenleng-fridge',
        clientId: 'fenleng-fridge-android');
  });
  tearDown(() {
    auth.dispose();
    client.options.httpClient.close();
  });

  test('concurrent guest calls make one ordinary POST without identifiers',
      () async {
    final gate = Completer<http.Response>();
    var requests = 0;
    respond = (request) async {
      requests++;
      expect(request.url.path, '/api/platform/v1/auth/guest/login');
      expect(request.method, 'POST');
      expect(request.headers.keys.map((key) => key.toLowerCase()),
          isNot(contains('idempotency-key')));
      expect(jsonDecode(request.body), {
        'applicationCode': 'fenleng-fridge',
        'clientId': 'fenleng-fridge-android',
      });
      return gate.future;
    };
    final first = auth.loginAsGuest(), second = auth.loginAsGuest();
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
    gate.complete(http.Response('{"accessToken":"a","refreshToken":"r"}', 200));
    await Future.wait([first, second]);
    expect(await auth.isGuestSession(), true);
  });

  test('guest kind survives reconstruction and token rotation', () async {
    await auth.loginAsGuest();
    final reopened =
        FlutterAuthSDK(client: client, applicationCode: 'fenleng-fridge');
    try {
      expect(
          await reopened.restoreSession(), FlutterSessionStatus.authenticated);
      expect(await reopened.isGuestSession(), true);
      await reopened.loginWithWechatCode('one-time-code');
      expect(await reopened.isGuestSession(), false);
    } finally {
      reopened.dispose();
    }
  });

  test('unknown network result is not replayed until a new controlled call',
      () async {
    var requests = 0;
    respond = (_) async {
      requests++;
      throw http.ClientException('offline');
    };
    await expectLater(auth.loginAsGuest(), throwsA(isA<FenlengSdkException>()));
    expect(requests, 1);
    expect(await storage.getItem(client.options.tokenKey), null);
    await expectLater(auth.loginAsGuest(), throwsA(isA<FenlengSdkException>()));
    expect(requests, 2);
  });

  test('offline restore preserves guest tokens and can recover later',
      () async {
    await auth.loginAsGuest();
    final success = respond;
    respond = (_) async => http.Response('{"code":"UNAVAILABLE"}', 503);
    await expectLater(
        auth.restoreSession(), throwsA(isA<FenlengSdkException>()));
    expect(await storage.getItem(client.options.tokenKey), 'access');
    expect(await auth.isGuestSession(), true);
    respond = success;
    expect(await auth.restoreSession(), FlutterSessionStatus.authenticated);
  });

  test('refresh recovers missing access token; expired refresh clears kind',
      () async {
    await auth.loginAsGuest();
    await storage.removeItem(client.options.tokenKey);
    expect(await auth.restoreSession(), FlutterSessionStatus.authenticated);
    expect(await auth.isGuestSession(), true);
    respond = (_) async => http.Response('{"code":"UNAUTHORIZED"}', 401);
    expect(await auth.restoreSession(), FlutterSessionStatus.sessionExpired);
    expect(await storage.getItem(client.options.tokenKey), null);
    expect(await auth.isGuestSession(), false);
  });

  test('logout clears guest tokens even if remote logout fails', () async {
    await auth.loginAsGuest();
    respond = (_) async => http.Response('{"code":"UNAVAILABLE"}', 503);
    await expectLater(auth.logout(), throwsA(isA<FenlengSdkException>()));
    expect(await storage.getItem(client.options.tokenKey), null);
    expect(await storage.getItem('${client.options.tokenKey}:refresh'), null);
    expect(await auth.isGuestSession(), false);
  });

  test('kind persistence failure removes the whole token pair', () async {
    final failing = FailingKindStorage();
    final failingClient = FenlengFlutterClient(
        options: FenlengClientOptions(
      baseUrl: 'http://localhost:8080',
      storage: failing,
      httpClient: MockClient((request) => respond(request)),
    ));
    final failingAuth = FlutterAuthSDK(
        client: failingClient, applicationCode: 'fenleng-fridge');
    try {
      await expectLater(failingAuth.loginAsGuest(), throwsStateError);
      expect(await failing.getItem(failingClient.options.tokenKey), null);
      expect(await failing.getItem('${failingClient.options.tokenKey}:refresh'),
          null);
      expect(await failingAuth.isGuestSession(), false);
    } finally {
      failingAuth.dispose();
      failingClient.options.httpClient.close();
    }
  });
}
