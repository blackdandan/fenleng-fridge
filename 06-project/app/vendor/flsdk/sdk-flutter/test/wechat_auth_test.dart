import 'dart:convert';

import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('WeChat code is exchanged only by Shared Platform', () async {
    final storage = FenlengMemoryStorageAdapter();
    late http.Request sent;
    final client = FenlengFlutterClient(
      options: FenlengClientOptions(
        baseUrl: 'http://localhost:8080',
        storage: storage,
        httpClient: MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode({'accessToken': 'access', 'refreshToken': 'refresh'}),
            200,
          );
        }),
      ),
    );
    final auth = FlutterAuthSDK(
      client: client,
      applicationCode: 'promptmanager',
      clientId: 'promptmanager-android',
    );

    await auth.loginWithWechatCode('temporary-code');

    expect(sent.url.path, '/api/platform/v1/auth/wechat/login');
    expect(sent.body, isNot(contains('secret')));
    expect(await storage.getItem(client.options.tokenKey), 'access');
    auth.dispose();
  });
}
