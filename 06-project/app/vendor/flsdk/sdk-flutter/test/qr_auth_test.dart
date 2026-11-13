import 'dart:convert';

import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const capability = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test('QR login never sends poll capability to scan or confirm', () async {
    final storage = FenlengMemoryStorageAdapter();
    final requests = <http.Request>[];
    final client = FenlengFlutterClient(
      options: FenlengClientOptions(
        baseUrl: 'http://localhost:8080',
        storage: storage,
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/status')) {
            return http.Response(
                jsonEncode({
                  'status': 'CONFIRMED',
                  'expiresAt': null,
                  'tokens': {
                    'accessToken': 'access',
                    'refreshToken': 'refresh',
                  },
                }),
                200);
          }
          return http.Response(jsonEncode({'status': 'CONFIRMED'}), 200);
        }),
      ),
    );
    final auth = FlutterAuthSDK(
      client: client,
      applicationCode: 'prompt-manager',
      clientId: 'flutter-android',
    );

    await auth.scanQrLoginChallenge(capability);
    await auth.confirmQrLoginChallenge(capability);
    await auth.claimQrLoginChallenge(
      challengeToken: capability,
      pollToken: capability,
    );

    expect(requests[0].body, isNot(contains('pollToken')));
    expect(requests[1].body, isNot(contains('pollToken')));
    expect(requests[2].body, contains('pollToken'));
    expect(await storage.getItem(client.options.tokenKey), 'access');
    auth.dispose();
  });

  test('generated QR challenge rejects malformed capabilities', () {
    expect(
      () => GeneratedQrLoginChallenge.fromJson({
        'challengeToken': 'short',
        'pollToken': capability,
        'qrUri': 'promptmanager://app/login?challenge=$capability',
        'expiresAt': '2026-08-11T00:00:00Z',
      }),
      throwsA(isA<FenlengSdkException>()),
    );
  });
}
