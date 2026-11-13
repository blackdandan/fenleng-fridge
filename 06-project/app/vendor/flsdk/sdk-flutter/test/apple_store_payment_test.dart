import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';

class StoreBridge implements AppleStoreBridge {
  final finished = <String>[];
  int calls = 0;
  String? failureCode;
  bool productsUnavailable = false;
  List<Map<String, dynamic>> pending = [];
  List<Map<String, dynamic>> restored = [];
  Stream<Map<String, dynamic>> eventStream = const Stream.empty();

  Map<String, dynamic> outcome = {
    'outcome': 'PURCHASED',
    'purchaseToken': '123'
  };
  @override
  Future<Map<String, dynamic>> invoke(
      String provider, Map<String, String> payload) async {
    calls++;
    if (failureCode != null)
      throw FenlengSdkException(failureCode!, 'Native operation stopped');
    return outcome;
  }

  @override
  Future<List<Map<String, dynamic>>> products(List<String> ids) async =>
      productsUnavailable
          ? []
          : [
              {
                'productId': 'basic.monthly',
                'amountMinor': 990,
                'currency': 'CNY',
                'displayPrice': '¥9.90',
                'subscriptionPeriodUnit': 'month',
                'subscriptionPeriodValue': 1
              }
            ];
  @override
  Future<List<Map<String, dynamic>>> unfinished() async => pending;
  @override
  Future<List<Map<String, dynamic>>> restore() async => restored;
  @override
  Stream<Map<String, dynamic>> get transactions => eventStream;
  @override
  Future<void> finish(String transactionId) async {
    finished.add(transactionId);
  }

  @override
  Future<void> manageSubscriptions() async {}
}

void main() {
  FlutterPaymentCoordinator coordinator(StoreBridge bridge,
      {bool reject = false,
      bool rejectMissingOrder = false,
      List<String>? traffic,
      List<http.Request>? requests,
      bool pendingCheckout = false,
      bool activeSubscription = false}) {
    var abandoned = false;
    final client = FenlengFlutterClient(
        options: FenlengClientOptions(
            baseUrl: 'http://localhost',
            storage: FenlengMemoryStorageAdapter(),
            httpClient: MockClient((request) async {
              requests?.add(request);
              traffic?.add(request.url.path);
              if (activeSubscription &&
                  request.url.path.endsWith('/subscription')) {
                return http.Response(
                    jsonEncode({
                      'provider': 'apple-app-store',
                      'priceOptionId': 'price',
                      'status': 'ACTIVE',
                      'periodEnd': '2099-01-01T00:00:00Z'
                    }),
                    200);
              }
              if (request.url.path.endsWith('/abandon-apple')) {
                abandoned = true;
                return http.Response('{}', 200);
              }
              if (request.url.path.endsWith('/prices'))
                return http.Response(
                    jsonEncode([
                      {
                        'id': 'price',
                        'amountMinor': 1,
                        'currency': 'CNY',
                        'appleProductId': 'basic.monthly',
                        'interval': 'MONTH'
                      }
                    ]),
                    200);
              if (request.url.path.endsWith('/orders') &&
                  request.method == 'POST') {
                final body = jsonDecode(request.body);
                expect(body['appleStoreQuote'],
                    {'amountMinor': 990, 'currency': 'CNY'});
                return http.Response('{"id":"order"}', 200);
              }
              if (request.url.path.endsWith('/payments'))
                return http.Response(
                    '{"paymentAttemptId":"attempt","clientPayload":{"productId":"basic.monthly","appAccountToken":"00112233-4455-6677-8899-aabbccddeeff"}}',
                    200);
              if (request.url.path.endsWith('/verify') ||
                  request.url.path.endsWith('/restore')) {
                if (rejectMissingOrder &&
                    jsonDecode(request.body)['orderId'] == 'missing-order') {
                  return http.Response(
                      '{"code":"RESOURCE_NOT_FOUND","message":"Order"}', 404);
                }
                return reject
                    ? http.Response(
                        '{"code":"PURCHASE_REJECTED","message":"Rejected"}',
                        409)
                    : http.Response('{}', 200);
              }
              return http.Response(
                  jsonEncode({
                    'id': 'order',
                    'status': abandoned
                        ? 'CANCELED'
                        : pendingCheckout ? 'PAYMENT_PROCESSING' : 'PAID'
                  }),
                  200);
            })));
    return FlutterPaymentCoordinator(
        commerce: FlutterCommerceSDK(client: client),
        adapters: [AppleStorePaymentAdapter(bridge)]);
  }

  test('restore attempts every receipt and preserves rejected transactions',
      () async {
    final bridge = StoreBridge()
      ..restored = [
        {'transactionId': 'old', 'appAccountToken': 'missing-order'},
        {'transactionId': 'current', 'appAccountToken': 'cloud-order'},
      ];
    final requests = <http.Request>[];
    final payment =
        coordinator(bridge, rejectMissingOrder: true, requests: requests);
    await expectLater(payment.restoreApplePurchases(isCurrentUser: () => true),
        throwsA(isA<FenlengSdkException>()));
    expect(requests.where((r) => r.url.path.endsWith('/restore')).length, 2);
    expect(bridge.finished, ['current']);
  });

  test('fresh active Apple subscription prevents creating a duplicate order',
      () async {
    final bridge = StoreBridge();
    final traffic = <String>[];
    final result =
        await coordinator(bridge, activeSubscription: true, traffic: traffic)
            .purchase('price', 'apple-app-store', 'active-subscription-check',
                appleStoreQuote: {'amountMinor': 990, 'currency': 'CNY'});
    expect(result['nativeOutcome'], 'RESTORED');
    expect(bridge.calls, 0);
    expect(traffic.where((path) => path.endsWith('/orders')), isEmpty);
    expect(traffic.where((path) => path.endsWith('/payments')), isEmpty);
  });

  test('empty StoreKit products produce retryable failure without purchase',
      () async {
    final bridge = StoreBridge()..productsUnavailable = true;
    await expectLater(
        coordinator(bridge).prices('basic'),
        throwsA(isA<FenlengSdkException>()
            .having(
                (e) => e.code, 'code', 'PAYMENT_PROVIDER_PRODUCT_UNAVAILABLE')
            .having((e) => e.retryable, 'retryable', true)));
    expect(bridge.calls, 0);
  });

  test('store metadata replaces account test price', () async {
    final prices = await coordinator(StoreBridge()).prices('basic');
    expect(prices.single['amountMinor'], 990);
    expect(prices.single['displayPrice'], '¥9.90');
  });

  test('purchase intent requests confirmation without purchase or verification',
      () async {
    final events = StreamController<Map<String, dynamic>>();
    final bridge = StoreBridge()..eventStream = events.stream;
    final traffic = <String>[];
    final intents = <String>[];
    var current = true;
    final payment = coordinator(bridge, traffic: traffic);
    await payment.startAppleUpdates(
      isCurrentUser: () => current,
      onError: (error) => fail('$error'),
      onPurchaseIntent: intents.add,
    );
    events.add({'outcome': 'PURCHASE_INTENT', 'productId': 'basic.monthly'});
    await Future<void>.delayed(Duration.zero);
    expect(intents, ['basic.monthly']);
    expect(traffic, isEmpty);
    expect(bridge.calls, 0);
    expect(bridge.finished, isEmpty);
    current = false;
    events.add({'outcome': 'PURCHASE_INTENT', 'productId': 'basic.monthly'});
    await Future<void>.delayed(Duration.zero);
    expect(intents, ['basic.monthly']);
    await payment.stopAppleUpdates();
    await events.close();
  });
  test('finish follows server verification and confirmed paid order', () async {
    final bridge = StoreBridge()..outcome['signedTransaction'] = 'signed-proof';
    final requests = <http.Request>[];
    await coordinator(bridge, requests: requests).purchase(
        'price', 'apple-app-store', 'apple-test',
        appleStoreQuote: {'amountMinor': 990, 'currency': 'CNY'});
    expect(
        jsonDecode(requests
            .singleWhere((r) => r.url.path.endsWith('/verify'))
            .body)['signedTransaction'],
        'signed-proof');
    expect(bridge.finished, ['123']);
  });
  test('unfinished restore forwards Apple signed proof to server verification',
      () async {
    final bridge = StoreBridge();
    final requests = <http.Request>[];
    await coordinator(bridge, requests: requests).syncAppleTransaction({
      'transactionId': '123',
      'appAccountToken': 'order',
      'signedTransaction': 'restore-proof'
    }, isCurrentUser: () => true);
    expect(
        jsonDecode(requests.single.body)['signedTransaction'], 'restore-proof');
    expect(bridge.finished, ['123']);
  });
  test('server rejection leaves transaction unfinished for recovery', () async {
    final bridge = StoreBridge();
    await expectLater(
        coordinator(bridge, reject: true).purchase(
            'price', 'apple-app-store', 'apple-test',
            appleStoreQuote: {'amountMinor': 990, 'currency': 'CNY'}),
        throwsA(isA<FenlengSdkException>()));
    expect(bridge.finished, isEmpty);
  });
  test('account switch before finish preserves the transaction', () async {
    final bridge = StoreBridge();
    var checks = 0;
    await coordinator(bridge).syncAppleTransaction(
        {'transactionId': '123', 'appAccountToken': 'order'},
        isCurrentUser: () => ++checks == 1);
    expect(bridge.finished, isEmpty);
  });
  test(
      'manual result retry syncs only the selected order without starting payment',
      () async {
    final bridge = StoreBridge()
      ..pending = [
        {'transactionId': '123', 'appAccountToken': 'order'},
        {'transactionId': '456', 'appAccountToken': 'another-account-order'}
      ];
    final traffic = <String>[];
    await coordinator(bridge, traffic: traffic)
        .syncAppleUnfinishedForOrder('order', isCurrentUser: () => true);
    expect(bridge.finished, ['123']);
    expect(bridge.calls, 0);
    expect(traffic.length, 1);
    expect(traffic.single, endsWith('/restore'));
  });
  test(
      'manual result retry preserves unfinished transaction on verification failure',
      () async {
    final bridge = StoreBridge()
      ..pending = [
        {'transactionId': '123', 'appAccountToken': 'order'}
      ];
    await expectLater(
        coordinator(bridge, reject: true)
            .syncAppleUnfinishedForOrder('order', isCurrentUser: () => true),
        throwsA(isA<FenlengSdkException>()));
    expect(bridge.finished, isEmpty);
    expect(bridge.calls, 0);
  });
  test('Apple purchase cannot use an omitted store quote', () async {
    final bridge = StoreBridge();
    await expectLater(
        coordinator(bridge)
            .purchase('price', 'apple-app-store', 'missing-quote'),
        throwsA(isA<FenlengSdkException>()));
    expect(bridge.finished, isEmpty);
    expect(bridge.calls, 0);
  });
  test('resuming a confirmed order never opens another purchase sheet',
      () async {
    final bridge = StoreBridge();
    final result = await coordinator(bridge).resumeApple('order', 'attempt',
        idempotencyKey: 'resume-paid', isCurrentUser: () => true);
    expect(result['status'], 'PAID');
    expect(bridge.calls, 0);
  });
  test(
      'already owned receipt restores its original association and closes the new local attempt',
      () async {
    final bridge = StoreBridge()
      ..outcome = {
        'outcome': 'PURCHASED',
        'purchaseToken': '123',
        'appAccountToken': 'original-order'
      };
    final traffic = <String>[];
    final result = await coordinator(bridge, traffic: traffic).purchase(
        'price', 'apple-app-store', 'owned-receipt',
        appleStoreQuote: {'amountMinor': 990, 'currency': 'CNY'});
    expect(result['nativeOutcome'], 'RESTORED');
    expect(result['status'], 'CANCELED');
    expect(traffic.any((path) => path.endsWith('/restore')), isTrue);
    expect(traffic.any((path) => path.endsWith('/verify')), isFalse);
    expect(bridge.finished, ['123']);
  });
  test('unassociated receipt closes only new checkout and remains unfinished',
      () async {
    final bridge = StoreBridge()
      ..outcome = {
        'outcome': 'PURCHASED',
        'purchaseToken': 'old-transaction',
        'appAccountToken': 'missing-order'
      };
    final traffic = <String>[];
    final payment = coordinator(bridge,
        rejectMissingOrder: true, traffic: traffic);
    final result = await payment.purchase(
        'price', 'apple-app-store', 'unassociated',
        appleStoreQuote: {'amountMinor': 990, 'currency': 'CNY'});
    expect(result['status'], 'CANCELED');
    expect(result['nativeOutcome'], 'ASSOCIATION_REQUIRED');
    expect(result['nativeErrorCode'], 'APPLE_PURCHASE_ASSOCIATION_REQUIRED');
    expect(traffic.where((p) => p.endsWith('/abandon-apple')).length, 1);
    expect(traffic.any((p) => p.endsWith('/verify')), isFalse);
    expect((await payment.readOrder('order'))['status'], 'CANCELED');
    expect(bridge.finished, isEmpty);
  });

  test('rejected receipt verification preserves pending checkout', () async {
    final bridge = StoreBridge()
      ..outcome = {
        'outcome': 'PURCHASED',
        'purchaseToken': 'old-transaction',
        'appAccountToken': 'original-order'
      };
    final traffic = <String>[];
    await expectLater(
        coordinator(bridge, reject: true, traffic: traffic).purchase(
            'price', 'apple-app-store', 'verification-rejected',
            appleStoreQuote: {'amountMinor': 990, 'currency': 'CNY'}),
        throwsA(isA<FenlengSdkException>()
            .having((e) => e.code, 'code', 'PURCHASE_REJECTED')));
    expect(traffic.any((p) => p.endsWith('/abandon-apple')), isFalse);
    expect(bridge.finished, isEmpty);
  });
  test('resuming checkout handles old association without leaving pending',
      () async {
    final bridge = StoreBridge()
      ..outcome = {
        'outcome': 'PURCHASED',
        'purchaseToken': 'old-transaction',
        'appAccountToken': 'missing-order'
      };
    final traffic = <String>[];
    final result = await coordinator(bridge,
            rejectMissingOrder: true, pendingCheckout: true, traffic: traffic)
        .resumeApple('order', 'attempt',
            idempotencyKey: 'resume-orphan', isCurrentUser: () => true);
    expect(result['status'], 'CANCELED');
    expect(result['nativeErrorCode'], 'APPLE_PURCHASE_ASSOCIATION_REQUIRED');
    expect(bridge.calls, 1);
    expect(traffic.where((p) => p.endsWith('/abandon-apple')).length, 1);
    expect(traffic.any((p) => p.endsWith('/verify')), isFalse);
    expect(bridge.finished, isEmpty);
  });
  test(
      'changed store price closes only the uncharged local attempt and never finishes a transaction',
      () async {
    final bridge = StoreBridge()..failureCode = 'PAYMENT_PRICE_CHANGED';
    final traffic = <String>[];
    final result = await coordinator(bridge, traffic: traffic).purchase(
        'price', 'apple-app-store', 'changed-price',
        appleStoreQuote: {'amountMinor': 990, 'currency': 'CNY'});
    expect(result['nativeOutcome'], 'PRICE_CHANGED');
    expect(result['status'], 'CANCELED');
    expect(traffic.any((path) => path.endsWith('/verify')), isFalse);
    expect(bridge.finished, isEmpty);
  });
}
