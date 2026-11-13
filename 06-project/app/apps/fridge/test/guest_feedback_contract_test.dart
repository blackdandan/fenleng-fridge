import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';
import 'package:fridge/application/identity_session.dart';
import 'package:fridge/infrastructure/identity_storage.dart';
import 'package:fridge/infrastructure/platform_identity.dart';
import 'package:fridge/infrastructure/platform_feedback.dart';
import 'package:fridge/infrastructure/product_telemetry.dart';
import 'identity_session_test.dart' show Authorization;

void main() {
  test(
    'real HTTP guest feedback, durable restore, then optional WeChat exchange',
    () async {
      final directory = await Directory.systemTemp.createTemp('fridge-guest-');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = StreamIterator(server);
      const config = PlatformIdentityConfig(clientId: 'fenleng-fridge-android');
      IdentitySession create() => IdentitySession(
        backend: PlatformIdentityBackend(
          directory,
          config,
          client: FenlengFlutterClient(
            options: FenlengClientOptions(
              baseUrl: 'http://127.0.0.1:${server.port}',
              storage: IdentityStorage(directory),
              tokenKey: 'fridge:platform:access',
            ),
          ),
        ),
        authorization: Authorization(),
        configured: true,
        guestEnabled: true,
        consent: () => true,
      );
      Future<HttpRequest> next() async {
        expect(
          await requests.moveNext().timeout(const Duration(seconds: 5)),
          true,
        );
        return requests.current;
      }

      Future<void> reply(HttpRequest request, Map<String, Object> body) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(body));
        await request.response.close();
      }

      final original = File('${directory.path}/inventory-sentinel');
      await original.writeAsString('local inventory unchanged');
      var session = create();
      ProductTelemetry? telemetry;
      try {
        final gateway = PlatformFeedbackGateway(
          client: (session.backend as PlatformIdentityBackend).client,
          configured: true,
          ensureSession: () async {
            await session.ensureSession();
            return session.sessionAvailable && session.errorKey == null;
          },
        );
        final sending = gateway.submit(
          'test feedback',
          'fridge-feedback-guest-test',
        );
        final guest = await next();
        expect(guest.uri.path, '/api/platform/v1/auth/guest/login');
        expect(jsonDecode(await utf8.decoder.bind(guest).join()), {
          'applicationCode': 'fenleng-fridge',
          'clientId': 'fenleng-fridge-android',
        });
        await reply(guest, {
          'accessToken': 'guest-access',
          'refreshToken': 'guest-refresh',
        });
        final feedback = await next();
        expect(feedback.uri.path, '/api/platform/v1/feedback');
        expect(feedback.headers.value('Authorization'), 'Bearer guest-access');
        expect(
          feedback.headers.value('Idempotency-Key'),
          'fridge-feedback-guest-test',
        );
        await feedback.drain<void>();
        await reply(feedback, {'id': 'feedback-guest-1', 'status': 'RECEIVED'});
        await sending;
        expect(session.signedIn, false);
        expect(session.guestReady, true);
        await session.close();

        session = create();
        final restoring = session.ensureSession();
        final refresh = await next();
        expect(refresh.uri.path, '/api/platform/v1/auth/refresh');
        expect(jsonDecode(await utf8.decoder.bind(refresh).join()), {
          'refreshToken': 'guest-refresh',
        });
        await reply(refresh, {
          'accessToken': 'rotated-guest',
          'refreshToken': 'rotated-refresh',
        });
        await restoring;
        expect(session.guestReady, true);
        expect(session.signedIn, false);

        final login = session.login(IdentityProvider.wechat);
        final wechat = await next();
        expect(wechat.uri.path, '/api/platform/v1/auth/wechat/login');
        expect(
          (jsonDecode(await utf8.decoder.bind(wechat).join()) as Map)['code'],
          'one-time-code',
        );
        await reply(wechat, {
          'accessToken': 'account-access',
          'refreshToken': 'account-refresh',
        });
        await login;
        expect(session.signedIn, true);
        expect(session.guestReady, false);
        telemetry = ProductTelemetry(
          client: (session.backend as PlatformIdentityBackend).client,
          catalog:
              jsonDecode(
                    await File('assets/telemetry-events.json').readAsString(),
                  )
                  as Map<String, dynamic>,
          enabled: true,
          consent: () => true,
          ensureSession: () async => session.sessionAvailable,
          debounce: const Duration(days: 1),
          context: () => const FlutterTelemetryContext(
            platform: 'android',
            appVersion: '0.1.0',
            buildNumber: '1',
            releaseChannel: 'china',
            locale: 'zh-CN',
          ),
        );
        telemetry.record('fridge.home.viewed.v1');
        final flushing = telemetry.flush();
        final event = await next();
        expect(event.uri.path, '/api/platform/v1/telemetry/events');
        expect(event.headers.value('Authorization'), 'Bearer account-access');
        expect(
          event.headers.value('Idempotency-Key'),
          startsWith('fridge-telemetry-'),
        );
        final envelope =
            jsonDecode(await utf8.decoder.bind(event).join()) as Map;
        expect(envelope.keys, ['events']);
        final payload = (envelope['events'] as List).single as Map;
        expect(payload['event'], 'fridge.home.viewed.v1');
        expect(payload['properties'], isEmpty);
        expect(payload['context'], {
          'platform': 'android',
          'appVersion': '0.1.0',
          'buildNumber': '1',
          'releaseChannel': 'china',
          'locale': 'zh-CN',
        });
        await reply(event, {'accepted': 1});
        expect(await flushing, 1);
        expect(await original.readAsString(), 'local inventory unchanged');
      } finally {
        telemetry?.close();
        await session.close();
        await requests.cancel();
        await server.close(force: true);
        await directory.delete(recursive: true);
      }
    },
  );
}
