import 'package:fenleng_sdk_flutter_native_identity/fenleng_sdk_flutter_native_identity.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.fenleng.sdk/native_identity');
  const client = MethodChannelFenlengNativeIdentity();

  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  test('configuration forwards only the existing public identity contract',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'configureWechat');
      expect(call.arguments,
          {'appId': 'wxb0143172ff84f79e', 'scope': 'snsapi_userinfo'});
      return null;
    });
    await client.configureWechat(
        const FenlengWechatIdentityConfig(appId: 'wxb0143172ff84f79e'));
  });
  for (final code in [
    'WECHAT_STATE_MISMATCH',
    'WECHAT_AUTH_TIMEOUT',
    'WECHAT_NOT_INSTALLED',
    'WECHAT_AUTH_UNCONFIRMED',
    'IDENTITY_AUTH_IN_PROGRESS'
  ]) {
    test('preserves $code without returning an authorization code', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(
            code: code, message: 'authorization did not complete');
      });
      await expectLater(
          client.authorize(FenlengNativeIdentityProvider.wechat),
          throwsA(isA<FenlengNativeIdentityException>()
              .having((error) => error.code, 'code', code)));
    });
  }
  for (final value in [null, '']) {
    test('rejects missing authorization result $value', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => value);
      await expectLater(
          client.authorize(FenlengNativeIdentityProvider.wechat),
          throwsA(isA<FenlengNativeIdentityException>()
              .having((error) => error.code, 'code', 'IDENTITY_CODE_MISSING')));
    });
  }
  test('passes provider-neutral requests to the native plugin', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'isAvailable' ? true : 'code';
    });

    expect(
        await client.isAvailable(FenlengNativeIdentityProvider.wechat), isTrue);
    expect(
        await client.authorize(FenlengNativeIdentityProvider.wechat), 'code');
    expect(calls.first.arguments, <String, Object>{'provider': 'wechat'});
  });

  test('converts platform errors to stable SDK errors', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(
          code: 'WECHAT_AUTH_CANCELLED', message: 'cancelled');
    });

    await expectLater(
      client.authorize(FenlengNativeIdentityProvider.wechat),
      throwsA(isA<FenlengNativeIdentityException>()
          .having((error) => error.code, 'code', 'WECHAT_AUTH_CANCELLED')),
    );
  });
}
