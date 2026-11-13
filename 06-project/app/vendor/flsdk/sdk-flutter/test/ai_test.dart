import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';

void main() {
  test('AI SDK consumes Platform SSE events and rejects arbitrary endpoints', () async {
    final client = FenlengFlutterClient(options: FenlengClientOptions(
      baseUrl: 'http://localhost:8080',
      storage: FenlengMemoryStorageAdapter(),
      httpClient: MockClient.streaming((request, _) async {
        expect(request.headers['Accept'], 'text/event-stream');
        return http.StreamedResponse(
          Stream.value(utf8.encode('data: {"type":"delta","text":"ok"}\n\n')),
          200,
        );
      }),
    ));
    final sdk = FlutterAIServiceSDK(client: client);
    expect(await sdk.connectStream('/api/platform/v1/ai/completions', {'prompt': 'hello'}).toList(), [
      {'type': 'delta', 'text': 'ok'},
    ]);
    expect(
      () => sdk.connectStream('/internal/stream', {}).toList(),
      throwsA(isA<FenlengSdkException>()),
    );
  });
}
