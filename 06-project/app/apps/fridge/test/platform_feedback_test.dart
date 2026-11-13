import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';
import 'package:fridge/application/feedback_session.dart';
import 'package:fridge/infrastructure/platform_feedback.dart';

class FeedbackTokens implements FenlengStorageAdapter {
  final values = <String, String>{'fl_session_token': 'test-platform-session'};
  @override
  Future<String?> getItem(String key) async => values[key];
  @override
  Future<void> setItem(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem(String key) async {
    values.remove(key);
  }
}

void main() {
  test(
    'official SDK sends authenticated idempotent text-only feedback and decodes the actual receipt contract',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = FenlengFlutterClient(
        options: FenlengClientOptions(
          baseUrl: 'http://127.0.0.1:${server.port}',
          storage: FeedbackTokens(),
        ),
      );
      try {
        var restored = 0;
        final gateway = PlatformFeedbackGateway(
          client: client,
          configured: true,
          ensureSession: () async {
            restored++;
            return true;
          },
        );
        final incoming = server.first;
        final sending = gateway.submit(
          'test feedback',
          'fridge-feedback-test-key',
        );
        final request = await incoming;
        expect(request.method, 'POST');
        expect(request.uri.path, '/api/platform/v1/feedback');
        expect(
          request.headers.value('Authorization'),
          'Bearer test-platform-session',
        );
        expect(
          request.headers.value('Idempotency-Key'),
          'fridge-feedback-test-key',
        );
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        expect(body, {
          'projectId': 'fenleng-fridge',
          'version': '0.1.0+1',
          'traceId': null,
          'message': 'test feedback',
          'attachmentConsent': false,
          'attachments': [],
        });
        request.response.statusCode = 201;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({'id': 'server-receipt-1', 'status': 'RECEIVED'}),
        );
        await request.response.close();
        expect(await sending, 'server-receipt-1');
        expect(restored, 1);
      } finally {
        client.options.httpClient.close();
        await server.close(force: true);
      }
    },
  );
  test(
    'malformed successful server response does not produce a receipt',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = FenlengFlutterClient(
        options: FenlengClientOptions(
          baseUrl: 'http://127.0.0.1:${server.port}',
          storage: FeedbackTokens(),
        ),
      );
      try {
        final gateway = PlatformFeedbackGateway(
          client: client,
          configured: true,
          ensureSession: () async => true,
        );
        final incoming = server.first;
        final sending = gateway.submit('test', 'valid-request-key');
        final rejected = expectLater(sending, throwsA(isA<FeedbackFailure>()));
        final request = await incoming;
        await utf8.decoder.bind(request).join();
        request.response.statusCode = 201;
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"status":"RECEIVED"}');
        await request.response.close();
        await rejected;
      } finally {
        client.options.httpClient.close();
        await server.close(force: true);
      }
    },
  );
  test(
    'missing configuration or session cannot send anonymous fake success',
    () async {
      final client = FenlengFlutterClient(
        options: FenlengClientOptions(
          baseUrl: 'https://unconfigured.invalid',
          storage: FeedbackTokens(),
        ),
      );
      var calls = 0;
      try {
        final disabled = PlatformFeedbackGateway(
          client: client,
          configured: false,
          ensureSession: () async {
            calls++;
            return true;
          },
        );
        await expectLater(
          disabled.submit('test', 'valid-request-key'),
          throwsA(
            isA<FeedbackFailure>().having(
              (f) => f.key,
              'key',
              'feedbackUnavailable',
            ),
          ),
        );
        expect(calls, 0);
        final anonymous = PlatformFeedbackGateway(
          client: client,
          configured: true,
          ensureSession: () async => false,
        );
        await expectLater(
          anonymous.submit('test', 'valid-request-key'),
          throwsA(
            isA<FeedbackFailure>().having(
              (f) => f.key,
              'key',
              'feedbackSessionUnavailable',
            ),
          ),
        );
      } finally {
        client.options.httpClient.close();
      }
    },
  );
}
