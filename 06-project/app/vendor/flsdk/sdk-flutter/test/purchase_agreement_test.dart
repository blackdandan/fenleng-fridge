import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';

void main() {
  test('nullable agreement and explicit confirmation use commerce contract',
      () async {
    final confirmation = {
      'documentId': 'basic',
      'documentVersion': 'v1',
      'contentSha256': 'a' * 64,
      'accepted': true
    };
    final commerce = FlutterCommerceSDK(
        client: FenlengFlutterClient(
            options: FenlengClientOptions(
                baseUrl: 'https://example.com',
                storage: FenlengMemoryStorageAdapter(),
                httpClient: MockClient((r) async {
                  if (r.method == 'GET') {
                    expect(r.url.path,
                        '/api/platform/v1/commerce/prices/price/purchase-agreement');
                    return http.Response('null', 200);
                  }
                  expect(jsonDecode(r.body), {
                    'priceOptionId': 'price',
                    'agreementConfirmation': confirmation
                  });
                  return http.Response('{"id":"order"}', 201);
                }))));
    expect(await commerce.purchaseAgreement('price'), isNull);
    expect(
        (await commerce.createOrder('price', 'purchase-001',
            agreementConfirmation: confirmation))['id'],
        'order');
  });
}
