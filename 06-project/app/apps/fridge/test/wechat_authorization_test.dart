import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/application/identity_session.dart';
import 'package:fridge/infrastructure/platform_identity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.fenleng.sdk/native_identity');
  late List<MethodCall> calls;
  bool available = true;
  String? failure;
  PlatformAuthorization authorization({String appId = 'wx0123456789abcdef'}) =>
      PlatformAuthorization(PlatformIdentityConfig(wechatAppId: appId));
  setUp(() {
    calls = [];
    available = true;
    failure = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'configureWechat':
              return null;
            case 'isAvailable':
              return available;
            case 'authorize':
              if (failure != null) throw PlatformException(code: failure!);
              return 'one-time-wechat-proof';
          }
          throw PlatformException(code: 'UNEXPECTED_METHOD');
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test(
    'official SDK configures before availability and obtains one-time code',
    () async {
      expect(
        await authorization().authorize(IdentityProvider.wechat),
        'one-time-wechat-proof',
      );
      expect(calls.map((c) => c.method), [
        'configureWechat',
        'isAvailable',
        'authorize',
      ]);
      expect((calls.first.arguments as Map)['scope'], 'snsapi_userinfo');
      expect((calls.last.arguments as Map)['provider'], 'wechat');
    },
  );
  test('invalid configuration never invokes native authorization', () async {
    await expectLater(
      authorization(appId: '').authorize(IdentityProvider.wechat),
      throwsA(
        isA<IdentityFailure>().having(
          (e) => e.key,
          'key',
          'loginNotConfigured',
        ),
      ),
    );
    expect(calls, isEmpty);
  });
  test('missing WeChat does not launch an authorization request', () async {
    available = false;
    await expectLater(
      authorization().authorize(IdentityProvider.wechat),
      throwsA(
        isA<IdentityFailure>().having(
          (e) => e.key,
          'key',
          'wechatNotInstalled',
        ),
      ),
    );
    expect(calls.map((c) => c.method), ['configureWechat', 'isAvailable']);
  });
  test(
    'cancel, denial and timeout use translated errors and allow a new attempt',
    () async {
      for (final entry in {
        'WECHAT_AUTH_CANCELLED': 'loginCancelled',
        'WECHAT_AUTH_DENIED': 'loginDenied',
        'WECHAT_AUTH_TIMEOUT': 'loginTimeout',
      }.entries) {
        failure = entry.key;
        await expectLater(
          authorization().authorize(IdentityProvider.wechat),
          throwsA(
            isA<IdentityFailure>().having((e) => e.key, 'key', entry.value),
          ),
        );
      }
      failure = null;
      expect(
        await authorization().authorize(IdentityProvider.wechat),
        'one-time-wechat-proof',
      );
    },
  );
}
