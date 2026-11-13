import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';

void main() {
  test(
      'channel capability error is preserved and is not retryable network failure',
      () async {
    final sdk = FlutterCommerceSDK(
        client: FenlengFlutterClient(
            options: FenlengClientOptions(
      baseUrl: 'http://localhost',
      storage: FenlengMemoryStorageAdapter(),
      httpClient: MockClient((request) async => http.Response(
          '{"code":"PAYMENT_PROVIDER_CAPABILITY_UNSUPPORTED","message":"Provider alipay does not support RECURRING","requestId":"request-test"}',
          409)),
    )));
    await expectLater(
        sdk.startPayment('order', 'alipay', idempotencyKey: 'key'),
        throwsA(isA<FenlengSdkException>()
            .having((e) => e.code, 'code',
                'PAYMENT_PROVIDER_CAPABILITY_UNSUPPORTED')
            .having((e) => e.retryable, 'retryable', false)));
  });

  test('non-object error responses retain their HTTP classification', () async {
    final sdk = FlutterCommerceSDK(
      client: FenlengFlutterClient(
        options: FenlengClientOptions(
          baseUrl: 'http://localhost',
          storage: FenlengMemoryStorageAdapter(),
          httpClient: MockClient(
            (_) async => http.Response('["maintenance"]', 503),
          ),
        ),
      ),
    );
    await expectLater(
      sdk.order('order'),
      throwsA(
        isA<FenlengSdkException>()
            .having((e) => e.code, 'code', 'HTTP_503')
            .having((e) => e.retryable, 'retryable', true),
      ),
    );
  });

  test('platform prices retain recurring mode rather than silently downgrade',
      () async {
    final sdk = FlutterCommerceSDK(
        client: FenlengFlutterClient(
            options: FenlengClientOptions(
      baseUrl: 'http://localhost',
      storage: FenlengMemoryStorageAdapter(),
      httpClient: MockClient((request) async {
        expect(
            request.url.path, '/api/platform/v1/commerce/plans/basic/prices');
        return http.Response(
            '[{"id":"price-basic","amountMinor":990,"currency":"CNY","interval":"MONTH","billingMode":"SUBSCRIPTION"}]',
            200);
      }),
    )));
    final price = (await sdk.prices('basic')).single;
    expect(price['amountMinor'], 990);
    expect(price['billingMode'], 'SUBSCRIPTION');
  });

  test('order history consumes platform array and retains authentication',
      () async {
    final storage = FenlengMemoryStorageAdapter();
    await storage.setItem('fl_session_token', 'test-token');
    final sdk = FlutterCommerceSDK(
        client: FenlengFlutterClient(
            options: FenlengClientOptions(
      baseUrl: 'http://localhost',
      storage: storage,
      httpClient: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(request.url.queryParameters['limit'], '10');
        return http.Response('[{"id":"order-1","status":"PAID"}]', 200);
      }),
    )));
    expect((await sdk.orders(limit: 10)).single['id'], 'order-1');
    expect(() => sdk.orders(limit: 101), throwsArgumentError);
  });
}
