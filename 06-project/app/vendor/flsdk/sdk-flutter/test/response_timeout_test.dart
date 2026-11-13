import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('response body timeout ends the request and cancels the stalled body',
      () async {
    var cancelled = false;
    final body = StreamController<List<int>>(onCancel: () {
      cancelled = true;
    });
    final client = FenlengFlutterClient(
        options: FenlengClientOptions(
      baseUrl: 'http://localhost',
      storage: FenlengMemoryStorageAdapter(),
      timeout: const Duration(milliseconds: 20),
      httpClient: MockClient.streaming(
          (request, stream) async => http.StreamedResponse(body.stream, 200)),
    ));
    try {
      await expectLater(
          client
              .request('/api/platform/v1/telemetry/events')
              .timeout(const Duration(milliseconds: 200)),
          throwsA(isA<FenlengSdkException>()
              .having((error) => error.code, 'code', 'REQUEST_TIMEOUT')));
      expect(cancelled, true);
    } finally {
      await body.close();
      client.options.httpClient.close();
    }
  });
}
