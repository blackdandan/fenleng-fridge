import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';

class Bridge implements NativePaymentBridge {
  @override
  Future<Map<String, dynamic>> invoke(
          String provider, Map<String, String> payload) async =>
      {};
}

class CancelBridge implements NativePaymentBridge {
  @override
  Future<Map<String, dynamic>> invoke(
          String provider, Map<String, String> payload) async =>
      provider == 'wechat-pay'
          ? {'outcome': 'CANCELLED'}
          : {'resultStatus': '6001'};
}

void main() {
  test(
      'current access refreshes forbidden stale scope once and restores active subscription',
      () async {
    var refreshes = 0;
    final coordinator = FlutterPaymentCoordinator(
        commerce: FlutterCommerceSDK(
            client: FenlengFlutterClient(
                options: FenlengClientOptions(
                    baseUrl: 'http://localhost',
                    storage: FenlengMemoryStorageAdapter(),
                    httpClient: MockClient((r) async {
                      if (r.url.path.endsWith('/subscription'))
                        return http.Response(
                            jsonEncode({
                              'status': 'ACTIVE',
                              'periodEnd': '2099-12-10T00:00:00Z'
                            }),
                            200);
                      if (refreshes == 0)
                        return http.Response(
                            jsonEncode({'code': 'PERMISSION_DENIED'}), 403);
                      return http.Response(
                          jsonEncode({
                            'items': [
                              {
                                'entitlements': {'subscription.basic': true}
                              }
                            ]
                          }),
                          200);
                    })))),
        adapters: [],
        refreshSession: () async {
          refreshes++;
        });
    final result = await coordinator.currentAccess('app');
    expect(refreshes, 1);
    expect(result['subscription']['status'], 'ACTIVE');
    expect(result['entitlements']['items'], isNotEmpty);
  });
  test('no current subscription is a valid nullable response', () async {
    final commerce = FlutterCommerceSDK(
        client: FenlengFlutterClient(
            options: FenlengClientOptions(
                baseUrl: 'http://localhost',
                storage: FenlengMemoryStorageAdapter(),
                httpClient:
                    MockClient((r) async => http.Response('null', 200)))));
    expect(await commerce.subscription(), isEmpty);
  });

  for (final provider in ['alipay', 'wechat-pay']) {
    test('$provider resume uses original channel and never creates a new order',
        () async {
      var sessions = 0;
      final coordinator = FlutterPaymentCoordinator(
          commerce: FlutterCommerceSDK(
              client: FenlengFlutterClient(
                  options: FenlengClientOptions(
                      baseUrl: 'http://localhost',
                      storage: FenlengMemoryStorageAdapter(),
                      httpClient: MockClient((r) async {
                        if (r.method == 'POST' &&
                            r.url.path.endsWith('/orders'))
                          fail('must not create order');
                        if (r.method == 'GET' &&
                            r.url.path.endsWith('/payments/old-attempt'))
                          return http.Response(
                              jsonEncode({
                                'id': 'old-attempt',
                                'orderId': 'old-order',
                                'provider': provider,
                              }),
                              200);
                        if (r.method == 'POST' &&
                            r.url.path.endsWith('/payments')) {
                          final body = jsonDecode(r.body) as Map;
                          expect(body['orderId'], 'old-order');
                          expect(body['resumeAttemptId'], 'old-attempt');
                          expect(body['provider'], provider);
                          expect(body['presentation'], 'NATIVE_APP');
                          sessions++;
                          return http.Response(
                              jsonEncode({
                                'paymentAttemptId': 'old-attempt',
                                'clientPayload': {'orderString': 'signed'}
                              }),
                              200);
                        }
                        return http.Response(
                            jsonEncode({
                              'id': 'old-order',
                              'status': 'PAYMENT_PROCESSING',
                              'amountMinor': 990
                            }),
                            200);
                      })))),
          adapters: [
            AlipayPaymentAdapter(CancelBridge()),
            WechatPaymentAdapter(CancelBridge())
          ]);
      final result = await coordinator.resume('old-order', 'old-attempt',
          idempotencyKey: 'resume-key');
      expect(sessions, 1);
      expect(result['id'], 'old-order');
      expect(result['amountMinor'], 990);
      expect(result['nativeOutcome'], 'USER_CANCELED');
    });
  }

  test('manual pending query reconciles once without polling delay', () async {
    var reconciles = 0;
    final coordinator = FlutterPaymentCoordinator(
        commerce: FlutterCommerceSDK(
            client: FenlengFlutterClient(
                options: FenlengClientOptions(
                    baseUrl: 'http://localhost',
                    storage: FenlengMemoryStorageAdapter(),
                    httpClient: MockClient((r) async {
                      if (r.url.path.endsWith('/reconcile')) {
                        reconciles++;
                        return http.Response('{}', 200);
                      }
                      return http.Response(
                          jsonEncode(
                              {'id': 'order', 'status': 'PAYMENT_PROCESSING'}),
                          200);
                    })))),
        adapters: [],
        confirmationInterval: const Duration(days: 1));
    final results = await Future.wait([
      coordinator.queryOnce('order', paymentAttemptId: 'attempt'),
      coordinator.queryOnce('order', paymentAttemptId: 'attempt')
    ]);
    expect(reconciles, 1);
    expect(results.first['status'], 'PAYMENT_PROCESSING');
    await coordinator.queryOnce('order', paymentAttemptId: 'attempt');
    expect(reconciles, 2);
  });

  test('forbidden digital channel is blocked before creating an order',
      () async {
    var requests = 0;
    final commerce = FlutterCommerceSDK(
        client: FenlengFlutterClient(
            options: FenlengClientOptions(
                baseUrl: 'http://localhost',
                storage: FenlengMemoryStorageAdapter(),
                httpClient: MockClient((r) async {
                  requests++;
                  return http.Response('{}', 200);
                }))));
    for (final combination in [
      ('china', 'ios'),
      ('global', 'ios'),
      ('global', 'android')
    ]) {
      final coordinator = FlutterPaymentCoordinator(
          commerce: commerce,
          adapters: [AlipayPaymentAdapter(Bridge())],
          policy: DigitalSubscriptionPaymentPolicy(
              channel: combination.$1, platform: combination.$2));
      await expectLater(
          coordinator.purchase('price', 'alipay', 'key'),
          throwsA(isA<FenlengSdkException>()
              .having((e) => e.code, 'code', 'PAYMENT_CHANNEL_FORBIDDEN')));
    }
    expect(requests, 0);
    expect(
        DigitalSubscriptionPaymentPolicy(channel: 'china', platform: 'iOS')
            .allowedProviders,
        {'apple-app-store'});
    expect(
        DigitalSubscriptionPaymentPolicy(channel: 'china', platform: 'android')
            .allowedProviders,
        {'alipay', 'wechat-pay'});
  });
  test(
      'HarmonyOS China permits configured wallets and global stays unavailable',
      () {
    expect(
        DigitalSubscriptionPaymentPolicy(channel: 'china', platform: 'ohos')
            .allowedProviders,
        {'alipay', 'wechat-pay'});
    expect(
        DigitalSubscriptionPaymentPolicy(channel: 'global', platform: 'ohos')
            .allowedProviders,
        isEmpty);
  });
  test('expired payment session refreshes once and retries authoritative reads',
      () async {
    var refreshed = false;
    var refreshes = 0;
    final gate = Completer<void>();
    final commerce = FlutterCommerceSDK(
        client: FenlengFlutterClient(
            options: FenlengClientOptions(
                baseUrl: 'http://localhost',
                storage: FenlengMemoryStorageAdapter(),
                httpClient: MockClient((r) async => refreshed
                    ? http.Response(
                        jsonEncode(
                            {'id': 'order', 'status': 'PAYMENT_PROCESSING'}),
                        200)
                    : http.Response(
                        jsonEncode(
                            {'code': 'UNAUTHENTICATED', 'message': 'Expired'}),
                        401)))));
    final coordinator = FlutterPaymentCoordinator(
        commerce: commerce,
        adapters: [],
        refreshSession: () async {
          refreshes++;
          await gate.future;
          refreshed = true;
        });
    final a = coordinator.readOrder('a');
    final b = coordinator.readOrder('b');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    gate.complete();
    expect(
        (await Future.wait([a, b]))
            .every((r) => r['status'] == 'PAYMENT_PROCESSING'),
        isTrue);
    expect(refreshes, 1);
  });
  test(
      'native user cancellation keeps the unpaid authoritative order recoverable',
      () async {
    var reconciliations = 0;
    final commerce = FlutterCommerceSDK(
        client: FenlengFlutterClient(
            options: FenlengClientOptions(
                baseUrl: 'http://localhost',
                storage: FenlengMemoryStorageAdapter(),
                httpClient: MockClient((r) async {
                  if (r.url.path.endsWith('/orders') && r.method == 'POST')
                    return http.Response('{"id":"order"}', 200);
                  if (r.url.path.endsWith('/payments'))
                    return http.Response(
                        '{"paymentAttemptId":"attempt","clientPayload":{}}',
                        200);
                  if (r.url.path.endsWith('/verify'))
                    fail('Native cancellation is not a purchase receipt');
                  if (r.url.path.endsWith('/reconcile')) {
                    reconciliations++;
                    return http.Response('{}', 200);
                  }
                  return http.Response(
                      '{"id":"order","status":"PAYMENT_PROCESSING"}', 200);
                }))));
    final coordinator = FlutterPaymentCoordinator(
        commerce: commerce,
        adapters: [AlipayPaymentAdapter(CancelBridge())],
        confirmationAttempts: 1);
    final result = await coordinator.purchase('price', 'alipay', 'payment-key');
    expect(result['nativeOutcome'], 'USER_CANCELED');
    expect(result['status'], 'PAYMENT_PROCESSING');
    expect(reconciliations, 1);
  });
  test('parallel recovery shares a bounded provider query', () async {
    var queries = 0;
    final gate = Completer<void>();
    final commerce = FlutterCommerceSDK(
        client: FenlengFlutterClient(
            options: FenlengClientOptions(
                baseUrl: 'http://localhost',
                storage: FenlengMemoryStorageAdapter(),
                httpClient: MockClient((r) async {
                  if (r.url.path.endsWith('/reconcile')) {
                    queries++;
                    await gate.future;
                    return http.Response('{}', 200);
                  }
                  return http.Response(
                      jsonEncode(
                          {'id': 'order', 'status': 'PAYMENT_PROCESSING'}),
                      200);
                }))));
    final coordinator = FlutterPaymentCoordinator(
        commerce: commerce, adapters: [], confirmationAttempts: 1);
    final first = coordinator.recover('order', paymentAttemptId: 'attempt');
    final second = coordinator.recover('order', paymentAttemptId: 'attempt');
    gate.complete();
    final results = await Future.wait([first, second]);
    expect(queries, 1);
    expect(results.every((r) => r['status'] == 'PAYMENT_PROCESSING'), isTrue);
  });
}
