import 'dart:convert';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
      'current user reads existing authenticated session without login or refresh',
      () async {
    final storage = FenlengMemoryStorageAdapter();
    await storage.setItem('access', 'original-access');
    await storage.setItem('access:refresh', 'original-refresh');
    final requests = <http.Request>[];
    final client = FenlengFlutterClient(
        options: FenlengClientOptions(
            baseUrl: 'http://localhost',
            storage: storage,
            tokenKey: 'access',
            httpClient: MockClient((request) async {
              requests.add(request);
              return http.Response(
                  jsonEncode(
                      {'id': 'human-one', 'kind': 'HUMAN', 'status': 'ACTIVE'}),
                  200);
            })));
    final auth = FlutterAuthSDK(client: client, applicationCode: 'fridge-app');
    final profile = await auth.currentUser();
    expect([profile.id, profile.kind, profile.status],
        ['human-one', 'HUMAN', 'ACTIVE']);
    expect(requests.single.method, 'GET');
    expect(requests.single.url.path, '/api/platform/v1/users/me');
    expect(requests.single.headers['Authorization'], 'Bearer original-access');
    expect(await storage.getItem('access:refresh'), 'original-refresh');
    auth.dispose();
    client.options.httpClient.close();
  });
  test(
      'local-only logout clears identity keys and emits status without an HTTP call',
      () async {
    final storage = FenlengMemoryStorageAdapter();
    for (final key in ['access', 'access:refresh', 'access:kind']) {
      await storage.setItem(key, 'original');
    }
    var calls = 0;
    final client = FenlengFlutterClient(
        options: FenlengClientOptions(
            baseUrl: 'http://localhost',
            storage: storage,
            tokenKey: 'access',
            httpClient: MockClient((_) async {
              calls++;
              throw StateError('no network expected');
            })));
    final auth = FlutterAuthSDK(client: client, applicationCode: 'fridge-app');
    final status = auth.onSessionStatusChanged.first;
    await auth.logout(localOnly: true);
    expect(await status, FlutterSessionStatus.unauthenticated);
    expect(calls, 0);
    for (final key in ['access', 'access:refresh', 'access:kind']) {
      expect(await storage.getItem(key), isNull);
    }
    auth.dispose();
    client.options.httpClient.close();
  });
  test('current user rejects malformed response and keeps existing credentials',
      () async {
    final storage = FenlengMemoryStorageAdapter();
    await storage.setItem('access', 'original');
    final client = FenlengFlutterClient(
        options: FenlengClientOptions(
            baseUrl: 'http://localhost',
            storage: storage,
            tokenKey: 'access',
            httpClient: MockClient(
                (_) async => http.Response('{"id":"human-one"}', 200))));
    final auth = FlutterAuthSDK(client: client, applicationCode: 'fridge-app');
    await expectLater(auth.currentUser(), throwsA(isA<FenlengSdkException>()));
    expect(await storage.getItem('access'), 'original');
    auth.dispose();
    client.options.httpClient.close();
  });
}
