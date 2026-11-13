import 'dart:async';
import 'dart:convert';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late FlutterTelemetrySDK telemetry;
  late List<http.Request> requests;
  late List<Completer<http.Response>> responses;
  setUp(() {
    requests = [];
    responses = [];
    final client = FenlengFlutterClient(
        options: FenlengClientOptions(
            baseUrl: 'http://localhost',
            storage: FenlengMemoryStorageAdapter(),
            httpClient: MockClient((request) {
              requests.add(request);
              final result = Completer<http.Response>();
              responses.add(result);
              return result.future;
            })));
    telemetry = FlutterTelemetrySDK(
        client: client,
        hasConsent: () => true,
        catalog: {'test.event.v1'},
        maxQueueSize: 2,
        batchSize: 2,
        context: () => const FlutterTelemetryContext(
            platform: 'ohos',
            appVersion: '1',
            buildNumber: '1',
            releaseChannel: 'china',
            locale: 'zh-CN'));
  });
  Future<void> waitRequest(int count) async {
    for (var i = 0; i < 100 && requests.length < count; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(requests.length, count);
  }

  void track(String source) =>
      telemetry.track('test.event.v1', {'source': source});
  void complete(int index) => responses[index].complete(http.Response(
      jsonEncode({
        'accepted': (jsonDecode(requests[index].body)['events'] as List).length
      }),
      200));
  test('overflow preserves events added during a flush', () async {
    track('a');
    track('b');
    final sent = telemetry.flush('first');
    await waitRequest(1);
    track('c');
    track('d');
    complete(0);
    expect(await sent, 2);
    expect(telemetry.pendingCount, 2);
    final next = telemetry.flush('next');
    await waitRequest(2);
    final events = (jsonDecode(requests[1].body) as Map)['events'] as List;
    expect(events.map((e) => e['properties']['source']).toList(), ['c', 'd']);
    expect(events.first['context']['platform'], 'ohos');
    complete(1);
    expect(await next, 2);
  });
  test('withdraw and renew do not lose new events on old completion', () async {
    track('old');
    final sent = telemetry.flush('old');
    await waitRequest(1);
    telemetry.withdrawConsent();
    track('new');
    complete(0);
    expect(await sent, 0);
    expect(telemetry.pendingCount, 1);
  });
  test('overlapping flush coalesces and failure leaves retryable events',
      () async {
    track('a');
    final first = telemetry.flush('first');
    final duplicate = telemetry.flush('duplicate');
    expect(identical(first, duplicate), true);
    await waitRequest(1);
    final rejected = expectLater(first, throwsA(isA<FenlengSdkException>()));
    responses[0].complete(
        http.Response('{"code":"UNAVAILABLE","message":"retry"}', 503));
    await rejected;
    expect(telemetry.pendingCount, 1);
    final retry = telemetry.flush('retry');
    await waitRequest(2);
    complete(1);
    expect(await retry, 1);
    expect(telemetry.pendingCount, 0);
  });
  test('retry pins the original payload and key while new events arrive',
      () async {
    track('old');
    final first = telemetry.flush('original-key');
    await waitRequest(1);
    final body = requests[0].body;
    final failure = expectLater(first, throwsA(isA<FenlengSdkException>()));
    responses[0].complete(http.Response('{"code":"UNAVAILABLE"}', 503));
    await failure;
    track('new');
    final retry = telemetry.flush('replacement-key');
    await waitRequest(2);
    expect(requests[1].body, body);
    expect(requests[1].headers['Idempotency-Key'], 'original-key');
    complete(1);
    expect(await retry, 1);
    expect(telemetry.pendingCount, 1);
    final next = telemetry.flush('new-batch-key');
    await waitRequest(3);
    expect(requests[2].headers['Idempotency-Key'], 'new-batch-key');
    complete(2);
    await next;
  });
  test(
      'invalid acknowledgement retains the identical batch until real acceptance',
      () async {
    track('old');
    final first = telemetry.flush('receipt-key');
    await waitRequest(1);
    final failure = expectLater(first, throwsA(isA<FenlengSdkException>()));
    responses[0].complete(http.Response('{"accepted":0}', 200));
    await failure;
    expect(telemetry.pendingCount, 1);
    final retry = telemetry.flush('ignored-new-key');
    await waitRequest(2);
    expect(requests[1].body, requests[0].body);
    expect(requests[1].headers['Idempotency-Key'], 'receipt-key');
    complete(1);
    await retry;
  });
  test('nested caller mutation cannot inject sensitive fields after track',
      () async {
    final properties = <String, dynamic>{
      'nested': <String, dynamic>{'source': 'original'}
    };
    telemetry.track('test.event.v1', properties);
    (properties['nested'] as Map)['accessToken'] = 'must-not-send';
    final sent = telemetry.flush('immutable-key');
    await waitRequest(1);
    expect(requests[0].body, isNot(contains('must-not-send')));
    complete(0);
    await sent;
  });
}
