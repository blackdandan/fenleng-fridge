import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';

class AlipayBridge implements NativePaymentBridge {
  final String resultStatus;
  int calls = 0;
  AlipayBridge(this.resultStatus);
  @override
  Future<Map<String, dynamic>> invoke(
      String provider, Map<String, String> payload) async {
    calls++;
    expect(provider, 'alipay');
    expect(payload['orderString'], 'server-signed-order');
    if (resultStatus == 'throw') throw Exception('native connection lost');
    return {
      'resultStatus': resultStatus,
      'purchaseToken': 'untrusted-client-value'
    };
  }
}

void main() {
  test('agreement lookup failure never changes confirmed paid result',
      () async {
    final transport = MockClient((request) async {
      if (request.url.path.endsWith('/payments/attempt-1')) {
        return http.Response(
            '{"code":"SERVICE_UNAVAILABLE","message":"Try later"}', 503);
      }
      return http.Response('{"id":"order-1","status":"PAID"}', 200);
    });
    final coordinator = FlutterPaymentCoordinator(
      commerce: FlutterCommerceSDK(
          client: FenlengFlutterClient(
              options: FenlengClientOptions(
                  baseUrl: 'http://localhost',
                  storage: FenlengMemoryStorageAdapter(),
                  httpClient: transport))),
      adapters: [],
    );
    final result =
        await coordinator.recover('order-1', paymentAttemptId: 'attempt-1');
    expect(result['status'], 'PAID');
    expect(result['renewalAgreementStatus'], 'UNKNOWN');
  });

  test('cancel does not override an already confirmed paid order', () async {
    var canceled = false;
    final transport = MockClient((request) async {
      if (request.url.path.endsWith('/cancel')) {
        canceled = true;
        return http.Response('{"status":"SUCCEEDED"}', 200);
      }
      expect(canceled, isTrue);
      return http.Response('{"id":"order-1","status":"PAID"}', 200);
    });
    final coordinator = FlutterPaymentCoordinator(
      commerce: FlutterCommerceSDK(
          client: FenlengFlutterClient(
              options: FenlengClientOptions(
                  baseUrl: 'http://localhost',
                  storage: FenlengMemoryStorageAdapter(),
                  httpClient: transport))),
      adapters: [],
    );
    final result = await coordinator.cancelAndRecover('order-1', 'attempt-1');
    expect(result['status'], 'PAID');
  });

  test(
      'Alipay 9000 is confirmed by platform reconciliation and refreshes entitlements',
      () async {
    var reconciled = false;
    var entitlementReads = 0;
    final bridge = AlipayBridge('9000');
    final transport = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/orders') && request.method == 'POST') {
        return http.Response('{"id":"order-1"}', 200);
      }
      if (path.endsWith('/payments')) {
        expect(jsonDecode(request.body)['presentation'], 'NATIVE_APP');
        return http.Response(
            '{"paymentAttemptId":"attempt-1","clientPayload":{"orderString":"server-signed-order"}}',
            200);
      }
      if (path.endsWith('/reconcile')) {
        expect(request.method, 'POST');
        reconciled = true;
        return http.Response('{"status":"SUCCEEDED"}', 200);
      }
      if (path.endsWith('/payments/attempt-1')) {
        return http.Response(
            jsonEncode({
              'id': 'attempt-1',
              'status': 'SUCCEEDED',
              'renewalAgreementStatus': 'FAILED',
              'renewalAgreementFailureCode':
                  'PAYMENT_PROVIDER_CAPABILITY_UNSUPPORTED',
            }),
            200);
      }
      if (path.endsWith('/entitlements/me')) {
        entitlementReads++;
        return http.Response('{"items":[{"code":"feature.export"}]}', 200);
      }
      if (path.endsWith('/verify'))
        fail(
            'Alipay interaction result must not be sent as a purchase receipt');
      return http.Response(
          jsonEncode({
            'id': 'order-1',
            'status': reconciled ? 'PAID' : 'PAYMENT_PROCESSING'
          }),
          200);
    });
    final coordinator = FlutterPaymentCoordinator(
        commerce: FlutterCommerceSDK(
            client: FenlengFlutterClient(
                options: FenlengClientOptions(
                    baseUrl: 'http://localhost',
                    storage: FenlengMemoryStorageAdapter(),
                    httpClient: transport))),
        adapters: [AlipayPaymentAdapter(bridge)],
        confirmationInterval: Duration.zero);
    String? savedOrder;
    String? savedAttempt;
    final result = await coordinator
        .purchase('price-1', 'alipay', 'idem-alipay-1', applicationId: 'app-1',
            onSessionCreated: (order, attempt) {
      savedOrder = order;
      savedAttempt = attempt;
    });
    expect(savedOrder, 'order-1');
    expect(savedAttempt, 'attempt-1');
    expect(result['status'], 'PAID');
    expect(result['renewalAgreementStatus'], 'FAILED');
    expect(result['renewalAgreementFailureCode'],
        'PAYMENT_PROVIDER_CAPABILITY_UNSUPPORTED');
    expect(result['entitlements']['items'], isNotEmpty);
    expect(entitlementReads, 1);
    expect(bridge.calls, 1);
  });

  test('native exception still reconciles after durable session save',
      () async {
    var saved = false;
    var reconciled = false;
    final transport = MockClient((request) async {
      if (request.url.path.endsWith('/orders') && request.method == 'POST') {
        return http.Response('{"id":"order-1"}', 200);
      }
      if (request.url.path.endsWith('/payments')) {
        return http.Response(
            '{"paymentAttemptId":"attempt-1","clientPayload":{"orderString":"server-signed-order"}}',
            200);
      }
      if (request.url.path.endsWith('/reconcile')) {
        expect(saved, isTrue);
        reconciled = true;
        return http.Response('{}', 200);
      }
      return http.Response(
          jsonEncode({
            'id': 'order-1',
            'status': reconciled ? 'PAID' : 'PAYMENT_PROCESSING'
          }),
          200);
    });
    final coordinator = FlutterPaymentCoordinator(
      commerce: FlutterCommerceSDK(
          client: FenlengFlutterClient(
              options: FenlengClientOptions(
                  baseUrl: 'http://localhost',
                  storage: FenlengMemoryStorageAdapter(),
                  httpClient: transport))),
      adapters: [AlipayPaymentAdapter(AlipayBridge('throw'))],
      confirmationAttempts: 1,
    );
    final result = await coordinator.purchase('price', 'alipay', 'key',
        onSessionCreated: (order, attempt) async {
      saved = true;
    });
    expect(result['status'], 'PAID');
    expect(reconciled, isTrue);
    expect(result['nativeErrorCode'], 'PAYMENT_NATIVE_FAILED');
  });

  test('SDK success cannot turn a still pending server order into paid',
      () async {
    var polls = 0;
    final bridge = AlipayBridge('9000');
    final transport = MockClient((request) async {
      if (request.url.path.endsWith('/orders') && request.method == 'POST')
        return http.Response('{"id":"order-1"}', 200);
      if (request.url.path.endsWith('/payments'))
        return http.Response(
            '{"paymentAttemptId":"attempt-1","clientPayload":{"orderString":"server-signed-order"}}',
            200);
      if (request.url.path.endsWith('/reconcile'))
        return http.Response('{"status":"PENDING_PROVIDER"}', 200);
      polls++;
      return http.Response(
          '{"id":"order-1","status":"PAYMENT_PROCESSING"}', 200);
    });
    final coordinator = FlutterPaymentCoordinator(
        commerce: FlutterCommerceSDK(
            client: FenlengFlutterClient(
                options: FenlengClientOptions(
                    baseUrl: 'http://localhost',
                    storage: FenlengMemoryStorageAdapter(),
                    httpClient: transport))),
        adapters: [AlipayPaymentAdapter(bridge)],
        confirmationAttempts: 2,
        confirmationInterval: Duration.zero);
    final result =
        await coordinator.purchase('price-1', 'alipay', 'idem-alipay-2');
    expect(result['status'], 'PAYMENT_PROCESSING');
    expect(polls, 5);
    expect(result.containsKey('entitlements'), false);
  });
}
