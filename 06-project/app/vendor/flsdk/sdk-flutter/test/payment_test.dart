import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';

class Bridge implements NativePaymentBridge {
  int calls = 0;
  @override
  Future<Map<String, dynamic>> invoke(
      String provider, Map<String, String> payload) async {
    calls++;
    return {'purchaseToken': 'receipt'};
  }
}

void main() {
  test(
      'duplicate purchase taps invoke native provider once and return server order',
      () async {
    var orders = 0;
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/orders') && request.method == 'POST') {
        orders++;
        return http.Response(jsonEncode({'id': 'order-1'}), 200);
      }
      if (request.url.path.endsWith('/payments'))
        return http.Response(
            jsonEncode({
              'paymentAttemptId': 'attempt-1',
              'clientPayload': <String, String>{}
            }),
            200);
      if (request.url.path.endsWith('/verify')) return http.Response('{}', 200);
      return http.Response(
          jsonEncode({'id': 'order-1', 'status': 'PAID'}), 200);
    });
    final client = FenlengFlutterClient(
        options: FenlengClientOptions(
            baseUrl: 'http://localhost',
            storage: FenlengMemoryStorageAdapter(),
            httpClient: httpClient));
    final bridge = Bridge();
    final sdk = FlutterPaymentCoordinator(
        commerce: FlutterCommerceSDK(client: client),
        adapters: [AppleStorePaymentAdapter(bridge)]);
    final result = await Future.wait([
      sdk.purchase('price', 'apple-app-store', 'idem-123',
          appleStoreQuote: {'amountMinor': 990, 'currency': 'CNY'}),
      sdk.purchase('price', 'apple-app-store', 'idem-123',
          appleStoreQuote: {'amountMinor': 990, 'currency': 'CNY'})
    ]);
    expect(orders, 1);
    expect(bridge.calls, 1);
    expect(result.first['status'], 'PAID');
  });
}
