import 'dart:convert';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FailingRefreshStorage extends FenlengMemoryStorageAdapter {
  @override
  Future<void> setItem(String key, String value) async {
    if (key.endsWith(':refresh')) throw StateError('Disk full');
    await super.setItem(key, value);
  }
}

void main() {
  test('native Apple proof uses platform verifier and shared session storage',
      () async {
    final storage = FenlengMemoryStorageAdapter();
    var requests = 0;
    final client = FenlengFlutterClient(
        options: FenlengClientOptions(
      baseUrl: 'http://localhost:8080',
      storage: storage,
      httpClient: MockClient((request) async {
        requests++;
        expect(request.url.path, '/api/platform/v1/auth/federated/apple/login');
        expect(jsonDecode(request.body), {
          'applicationCode': 'fenleng-fridge',
          'clientId': 'fenleng-fridge-ios',
          'identityToken': 'signed-apple-proof',
        });
        return http.Response(
            jsonEncode({
              'accessToken': 'session-access',
              'refreshToken': 'session-refresh'
            }),
            200);
      }),
    ));
    final auth = FlutterAuthSDK(
        client: client,
        applicationCode: 'fenleng-fridge',
        clientId: 'fenleng-fridge-ios');
    await expectLater(auth.loginWithAppleIdentityToken(''),
        throwsA(isA<FenlengSdkException>()));
    expect(requests, 0);
    await auth.loginWithAppleIdentityToken('signed-apple-proof');
    expect(await storage.getItem(client.options.tokenKey), 'session-access');
    expect(await storage.getItem('${client.options.tokenKey}:refresh'),
        'session-refresh');
    auth.dispose();
  });

  test('partial token persistence cannot leave an authenticated access token',
      () async {
    final storage = FailingRefreshStorage();
    final client = FenlengFlutterClient(
        options: FenlengClientOptions(
      baseUrl: 'http://localhost:8080',
      storage: storage,
      httpClient: MockClient((_) async => http.Response(
          jsonEncode({
            'accessToken': 'platform-access',
            'refreshToken': 'platform-refresh',
          }),
          200)),
    ));
    final auth =
        FlutterAuthSDK(client: client, applicationCode: 'fenleng-fridge');
    await expectLater(
        auth.loginWithWechatCode('temporary-code'), throwsStateError);
    expect(await storage.getItem(client.options.tokenKey), null);
    expect(await storage.getItem('${client.options.tokenKey}:refresh'), null);
    auth.dispose();
  });

  test('malformed successful response does not become an authenticated session',
      () async {
    final storage = FenlengMemoryStorageAdapter();
    final client = FenlengFlutterClient(
        options: FenlengClientOptions(
      baseUrl: 'http://localhost:8080',
      storage: storage,
      httpClient: MockClient((_) async =>
          http.Response('{"accessToken":"","refreshToken":""}', 200)),
    ));
    final auth =
        FlutterAuthSDK(client: client, applicationCode: 'fenleng-fridge');
    await expectLater(auth.loginWithWechatCode('temporary-code'),
        throwsA(isA<FenlengSdkException>()));
    expect(await storage.getItem(client.options.tokenKey), null);
    auth.dispose();
  });
}
