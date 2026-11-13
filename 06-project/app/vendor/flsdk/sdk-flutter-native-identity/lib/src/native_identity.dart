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

final class FenlengAppleIdentityCredential {
  const FenlengAppleIdentityCredential(
      {required this.identityToken, this.displayName});
  final String identityToken;
  final String? displayName;
  @override
  String toString() =>
      'FenlengAppleIdentityCredential(identityToken: <redacted>)';
}

/// Optional additive interface; existing WeChat hosts remain source-compatible.
abstract interface class FenlengAppleIdentityClient {
  Future<FenlengAppleIdentityCredential> authorizeApple();
}

final class MethodChannelFenlengNativeIdentity
    implements FenlengNativeIdentityClient, FenlengAppleIdentityClient {
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

  @override
  Future<FenlengAppleIdentityCredential> authorizeApple() async {
    final raw = await _invoke<Object?>('authorizeApple');
    if (raw is! Map ||
        raw['identityToken'] is! String ||
        (raw['identityToken'] as String).trim().isEmpty ||
        (raw['identityToken'] as String).length > 16384 ||
        (raw['identityToken'] as String).contains('\r') ||
        (raw['identityToken'] as String).contains('\n') ||
        (raw['displayName'] != null && raw['displayName'] is! String)) {
      throw const FenlengNativeIdentityException(
          'APPLE_IDENTITY_TOKEN_MISSING', 'Apple credential is invalid');
    }
    return FenlengAppleIdentityCredential(
      identityToken: raw['identityToken'] as String,
      displayName: raw['displayName'] as String?,
    );
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
