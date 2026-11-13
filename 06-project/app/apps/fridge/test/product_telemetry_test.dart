import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fridge/infrastructure/product_telemetry.dart';

void main() {
  late ProductTelemetry model;
  late FenlengFlutterClient client;
  late List<http.Request> sent;
  late bool consent, sessionReady;
  late int restores;
  late Future<http.Response> Function(http.Request) respond;
  late Map<String, dynamic> catalog;
  ProductTelemetry create({bool enabled = true}) => ProductTelemetry(
    client: client,
    catalog: catalog,
    enabled: enabled,
    consent: () => consent,
    ensureSession: () async {
      restores++;
      return sessionReady;
    },
    debounce: const Duration(days: 1),
    retryDelay: Duration.zero,
    context: () => const FlutterTelemetryContext(
      platform: 'android',
      appVersion: '0.1.0',
      buildNumber: '1',
      releaseChannel: 'china',
      locale: 'zh-CN',
    ),
  );
  setUp(() async {
    catalog =
        jsonDecode(await File('assets/telemetry-events.json').readAsString())
            as Map<String, dynamic>;
    consent = false;
    sessionReady = true;
    restores = 0;
    sent = [];
    respond = (request) async => http.Response(
      jsonEncode({
        'accepted': (jsonDecode(request.body)['events'] as List).length,
      }),
      200,
    );
    client = FenlengFlutterClient(
      options: FenlengClientOptions(
        baseUrl: 'http://localhost',
        storage: FenlengMemoryStorageAdapter(),
        httpClient: MockClient((request) async {
          sent.add(request);
          return respond(request);
        }),
      ),
    );
    model = create();
  });
  tearDown(() {
    model.close();
    client.options.httpClient.close();
  });

  test('no consent does not collect, initialize a session, or send', () async {
    expect(model.record('fridge.home.viewed.v1'), false);
    expect(await model.flush(), 0);
    expect(model.pendingCount, 0);
    expect(restores, 0);
    expect(sent, isEmpty);
  });
  test(
    'strict catalog rejects unknown names, missing props, private keys and free text',
    () async {
      consent = true;
      for (final entry in [
        ('unknown.v1', <String, String>{}),
        ('fridge.capture.started.v1', <String, String>{'source': 'camera'}),
        ('fridge.home.viewed.v1', <String, String>{'message': 'private'}),
        (
          'fridge.capture.started.v1',
          <String, String>{'source': 'camera', 'zone': 'private-food-name'},
        ),
      ]) {
        expect(model.record(entry.$1, entry.$2), false);
      }
      expect(model.pendingCount, 0);
      expect(sent, isEmpty);
    },
  );
  test(
    'official SDK sends controlled context and success/failure enums without product IDs',
    () async {
      consent = true;
      expect(
        model.record('fridge.inventory.added.v1', {
          'source': 'camera',
          'zone': 'cold',
          'result': 'success',
        }),
        true,
      );
      expect(
        model.record('fridge.feedback.submitted.v1', {
          'result': 'submit_failed',
        }),
        true,
      );
      expect(await model.flush(), 2);
      final body = jsonDecode(sent.single.body) as Map;
      expect(body.keys, ['events']);
      final events = body['events'] as List;
      expect(events.first['context'], {
        'platform': 'android',
        'appVersion': '0.1.0',
        'buildNumber': '1',
        'releaseChannel': 'china',
        'locale': 'zh-CN',
      });
      expect(events.last['properties'], {'result': 'submit_failed'});
      expect(model.pendingCount, 0);
    },
  );
  test(
    'retry is bounded to three and keeps original body/key as new events arrive',
    () async {
      consent = true;
      model.record('fridge.home.viewed.v1');
      respond = (request) async {
        if (sent.length == 1) {
          model.record('fridge.reminder.opened.v1', {'source': 'home'});
        }
        return http.Response('{"code":"UNAVAILABLE"}', 503);
      };
      expect(await model.flush(), 0);
      expect(sent.length, 3);
      expect(model.pendingCount, 2);
      expect(sent.map((request) => request.body).toSet().length, 1);
      expect(
        sent
            .map((request) => request.headers['Idempotency-Key'])
            .toSet()
            .length,
        1,
      );
    },
  );
  test(
    'queue caps at100 and acknowledgements remove at most50 per batch',
    () async {
      consent = true;
      for (var i = 0; i < 105; i++) {
        model.record('fridge.home.viewed.v1');
      }
      expect(model.pendingCount, 100);
      expect(await model.flush(), 50);
      expect(model.pendingCount, 50);
      expect(await model.flush(), 50);
      expect(model.pendingCount, 0);
    },
  );
  test(
    'missing session and disabled deployment never send but stay bounded locally',
    () async {
      consent = true;
      sessionReady = false;
      model.record('fridge.home.viewed.v1');
      expect(await model.flush(), 0);
      expect(sent, isEmpty);
      expect(model.pendingCount, 1);
      model.close();
      model = create(enabled: false);
      model.record('fridge.home.viewed.v1');
      final before = restores;
      expect(await model.flush(), 0);
      expect(restores, before);
      expect(sent, isEmpty);
    },
  );
  test(
    'withdrawal clears retry snapshot and late ACK cannot remove renewed events',
    () async {
      consent = true;
      model.record('fridge.home.viewed.v1');
      final gate = Completer<http.Response>();
      respond = (_) => gate.future;
      final sending = model.flush();
      await Future<void>.delayed(Duration.zero);
      model.withdraw();
      expect(model.pendingCount, 0);
      model.record('fridge.reminder.opened.v1', {'source': 'home'});
      gate.complete(http.Response('{"accepted":1}', 200));
      expect(await sending, 0);
      expect(model.pendingCount, 1);
    },
  );
  test(
    'catalog copy exactly matches the product source and unified consent version',
    () async {
      final product = await File(
        '../../../../01-product/mvp/telemetry-events.json',
      ).readAsString();
      expect(jsonDecode(product), catalog);
      expect(catalog['consentSource'], 'unified-privacy-v0.4');
      expect(catalog['separateAnalyticsToggle'], false);
    },
  );
}
