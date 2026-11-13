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
  test(
      'Apple native credential uses existing platform route and atomic SDK session',
      () async {
    final storage = FenlengMemoryStorageAdapter();
    late http.Request sent;
    final client = FenlengFlutterClient(
        options: FenlengClientOptions(
      baseUrl: 'http://localhost:8080',
      storage: storage,
      httpClient: MockClient((request) async {
        sent = request;
        return http.Response(
            jsonEncode({
              'accessToken': 'fixture-access',
              'refreshToken': 'fixture-refresh'
            }),
            200);
      }),
    ));
    final auth = FlutterAuthSDK(
        client: client,
        applicationCode: 'fenleng-patent',
        clientId: 'fenleng-patent-ios');
    await auth.loginWithAppleIdentityToken('fixture.apple.token',
        displayName: '测试用户');
    expect(sent.url.path, '/api/platform/v1/auth/federated/apple/login');
    expect(jsonDecode(sent.body), {
      'applicationCode': 'fenleng-patent',
      'clientId': 'fenleng-patent-ios',
      'identityToken': 'fixture.apple.token',
      'displayName': '测试用户',
    });
    expect(await storage.getItem(client.options.tokenKey), 'fixture-access');
    expect(await storage.getItem('${client.options.tokenKey}:refresh'),
        'fixture-refresh');
    auth.dispose();
  });
  test('invalid Apple credential never makes a request or changes a session',
      () async {
    var requests = 0;
    final storage = FenlengMemoryStorageAdapter();
    final client = FenlengFlutterClient(
        options: FenlengClientOptions(
      baseUrl: 'http://localhost:8080',
      storage: storage,
      httpClient: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
    ));
    final auth =
        FlutterAuthSDK(client: client, applicationCode: 'fenleng-patent');
    for (final token in ['', ' ', 'bad\rcredential', 'bad\ncredential']) {
      await expectLater(auth.loginWithAppleIdentityToken(token),
          throwsA(isA<FenlengSdkException>()));
    }
    expect(requests, 0);
    expect(await storage.getItem(client.options.tokenKey), isNull);
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
