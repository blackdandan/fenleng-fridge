import 'dart:convert';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
      'WeChat deletion handshake and request preserve the original session and exact confirmation',
      () async {
    final calls = <http.Request>[];
    final storage = FenlengMemoryStorageAdapter();
    final client = FenlengFlutterClient(
        options: FenlengClientOptions(
      baseUrl: 'http://localhost',
      storage: storage,
      httpClient: MockClient((request) async {
        calls.add(request);
        return http.Response(
            jsonEncode({
              'id': 'request-one',
              'challengeId': 'fdc-once',
              'confirmationId': 'fdc-once'
            }),
            200);
      }),
    ));
    await storage.setItem(client.options.tokenKey, 'original-access');
    await storage.setItem(
        '${client.options.tokenKey}:refresh', 'original-refresh');
    final auth = FlutterAuthSDK(
        client: client,
        applicationCode: 'fenleng-fridge',
        clientId: 'fenleng-fridge-mobile');
    await auth.createFederatedDeletionChallenge('WECHAT', 'delete-intent');
    await auth.confirmFederatedDeletionReauthentication(
        'fdc-once', 'fresh-wechat-code');
    await auth.requestData('DELETE', 'delete-intent',
        actionConfirmationId: 'fdc-once');
    await auth.dataRequests();
    expect(
        calls.map((r) => r.method).toList(), ['POST', 'POST', 'POST', 'GET']);
    expect(jsonDecode(calls[0].body),
        {'provider': 'WECHAT', 'deletionIdempotencyKey': 'delete-intent'});
    expect(jsonDecode(calls[1].body), {'identityToken': 'fresh-wechat-code'});
    expect(jsonDecode(calls[2].body), {'type': 'DELETE'});
    expect(calls[2].headers['Idempotency-Key'], 'delete-intent');
    expect(calls[2].headers['X-Action-Confirmation'], 'fdc-once');
    expect(
        calls.every(
            (r) => r.headers['Authorization'] == 'Bearer original-access'),
        true);
    expect(await storage.getItem(client.options.tokenKey), 'original-access');
    expect(await storage.getItem('${client.options.tokenKey}:refresh'),
        'original-refresh');
    auth.dispose();
  });
}
