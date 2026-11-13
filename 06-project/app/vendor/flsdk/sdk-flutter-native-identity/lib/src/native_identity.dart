import 'package:flutter/services.dart';

enum FenlengNativeIdentityProvider { wechat, apple, google }

final class FenlengNativeIdentityException implements Exception {
  const FenlengNativeIdentityException(this.code, this.message, [this.details]);

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => 'FenlengNativeIdentityException($code, $message)';
}

final class FenlengWechatIdentityConfig {
  const FenlengWechatIdentityConfig({
    required this.appId,
    this.universalLink,
    this.scope = 'snsapi_userinfo',
  });

  final String appId;
  final String? universalLink;
  final String scope;

  Map<String, Object> toMap() => <String, Object>{
        'appId': appId,
        if (universalLink case final String link) 'universalLink': link,
        'scope': scope,
      };
}

abstract interface class FenlengNativeIdentityClient {
  Future<void> configureWechat(FenlengWechatIdentityConfig config);
  Future<bool> isAvailable(FenlengNativeIdentityProvider provider);
  Future<String> authorize(FenlengNativeIdentityProvider provider);
}

final class MethodChannelFenlengNativeIdentity
    implements FenlengNativeIdentityClient {
  const MethodChannelFenlengNativeIdentity();

  static const MethodChannel _channel =
      MethodChannel('com.fenleng.sdk/native_identity');

  @override
  Future<void> configureWechat(FenlengWechatIdentityConfig config) =>
      _invoke<void>('configureWechat', config.toMap());

  @override
  Future<bool> isAvailable(FenlengNativeIdentityProvider provider) async =>
      await _invoke<bool>('isAvailable', <String, Object>{
        'provider': provider.name,
      }) ??
      false;

  @override
  Future<String> authorize(FenlengNativeIdentityProvider provider) async {
    final code = await _invoke<String>('authorize', <String, Object>{
      'provider': provider.name,
    });
    if (code == null || code.isEmpty) {
      throw const FenlengNativeIdentityException(
        'IDENTITY_CODE_MISSING',
        '身份提供方未返回授权码',
      );
    }
    return code;
  }

  Future<T?> _invoke<T>(String method, [Map<String, Object>? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      throw FenlengNativeIdentityException(
        error.code,
        error.message ?? '原生身份认证失败',
        error.details,
      );
    }
  }
}
