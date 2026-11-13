import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';
import 'package:fenleng_sdk_flutter_native_identity/fenleng_sdk_flutter_native_identity.dart';
import '../application/identity_session.dart';
import 'identity_storage.dart';
import 'global_firebase_identity.dart';

class PlatformIdentityConfig {
  final bool enabled;
  final bool guestEnabled;
  final String baseUrl,
      applicationCode,
      clientId,
      wechatAppId,
      universalLink,
      releaseChannel;
  const PlatformIdentityConfig({
    this.enabled = const bool.fromEnvironment('FRIDGE_IDENTITY_ENABLED'),
    this.releaseChannel = const String.fromEnvironment(
      'APP_RELEASE_CHANNEL',
      defaultValue: 'china',
    ),
    this.guestEnabled = const bool.fromEnvironment('FRIDGE_GUEST_ENABLED'),
    this.baseUrl = const String.fromEnvironment('FRIDGE_PLATFORM_URL'),
    this.applicationCode = 'fenleng-fridge',
    this.clientId = const String.fromEnvironment('FRIDGE_PLATFORM_CLIENT_ID'),
    this.wechatAppId = const String.fromEnvironment('FRIDGE_WECHAT_APP_ID'),
    this.universalLink = const String.fromEnvironment(
      'FRIDGE_WECHAT_UNIVERSAL_LINK',
    ),
  });
  bool get ready =>
      enabled &&
      ['china', 'global'].contains(releaseChannel) &&
      Uri.tryParse(baseUrl)?.scheme == 'https' &&
      clientId.startsWith(
        releaseChannel == 'global'
            ? 'fenleng-fridge-global-'
            : 'fenleng-fridge-',
      ) &&
      (releaseChannel != 'china' ||
          !clientId.startsWith('fenleng-fridge-global-'));
}

IdentityFailure identityFailure(Object error) {
  final code = switch (error) {
    FenlengNativeIdentityException e => e.code,
    FenlengSdkException e => e.code,
    PlatformException e => e.code,
    TimeoutException() => 'WECHAT_AUTH_TIMEOUT',
    _ => '',
  };
  return IdentityFailure(switch (code) {
    'WECHAT_NOT_INSTALLED' => 'wechatNotInstalled',
    'WECHAT_AUTH_CANCELLED' || 'APPLE_AUTH_CANCELLED' => 'loginCancelled',
    'WECHAT_AUTH_TIMEOUT' ||
    'WECHAT_AUTH_UNCONFIRMED' ||
    'APPLE_AUTH_TIMEOUT' => 'loginTimeout',
    'IDENTITY_NOT_CONFIGURED' ||
    'IDENTITY_CONFIG_INVALID' ||
    'CONFIGURATION_INVALID' => 'loginNotConfigured',
    'WECHAT_AUTH_DENIED' => 'loginDenied',
    _ => 'loginFailed',
  });
}

class PlatformAuthorization
    implements
        IdentityAuthorization,
        IdentityReauthorization,
        IdentityAuthorizationLifecycle {
  final PlatformIdentityConfig config;
  final FenlengNativeIdentityClient native;
  final MethodChannel apple;
  final bool Function() consent;
  GlobalFirebaseIdentity? _firebase;
  GlobalFirebaseIdentity get firebase => _firebase ??= GlobalFirebaseIdentity(
    config: const GlobalFirebaseConfig(),
    native: FlutterFirebaseNativeIdentity(bootstrap: apple),
    consent: consent,
    platform: Platform.isIOS
        ? 'ios'
        : Platform.isAndroid
        ? 'android'
        : Platform.operatingSystem,
  );
  PlatformAuthorization(
    this.config, {
    this.native = const MethodChannelFenlengNativeIdentity(),
    this.apple = const MethodChannel('fenleng.fridge/bootstrap'),
    bool Function()? consent,
    GlobalFirebaseIdentity? firebase,
  }) : consent = consent ?? (() => false),
       _firebase = firebase;
  @override
  Future<String> authorize(IdentityProvider provider) async {
    try {
      if (config.releaseChannel == 'global') {
        if (provider == IdentityProvider.wechat) {
          throw const IdentityFailure('loginNotConfigured');
        }
        return firebase.authorize(
          provider == IdentityProvider.apple
              ? FirebaseProvider.apple
              : FirebaseProvider.google,
        );
      }
      if (provider == IdentityProvider.google) {
        throw const IdentityFailure('loginNotConfigured');
      }
      if (provider == IdentityProvider.apple) {
        final token = await apple.invokeMethod<String>('identity.apple');
        if (token == null || token.isEmpty) {
          throw const IdentityFailure('loginFailed');
        }
        return token;
      }
      if (!RegExp(r'^wx[0-9a-fA-F]{16}$').hasMatch(config.wechatAppId) ||
          (Platform.isIOS && !config.universalLink.startsWith('https://'))) {
        throw const IdentityFailure('loginNotConfigured');
      }
      await native.configureWechat(
        FenlengWechatIdentityConfig(
          appId: config.wechatAppId,
          universalLink: config.universalLink,
        ),
      );
      if (!await native.isAvailable(FenlengNativeIdentityProvider.wechat)) {
        throw const IdentityFailure('wechatNotInstalled');
      }
      return await native.authorize(FenlengNativeIdentityProvider.wechat);
    } on IdentityFailure {
      rethrow;
    } catch (error) {
      throw identityFailure(error);
    }
  }

  @override
  Future<String> reauthorize(IdentityProvider provider) {
    if (config.releaseChannel != 'global') return authorize(provider);
    if (provider == IdentityProvider.wechat) {
      return Future.error(const IdentityFailure('loginNotConfigured'));
    }
    return firebase.authorize(
      provider == IdentityProvider.apple
          ? FirebaseProvider.apple
          : FirebaseProvider.google,
      reauthenticate: true,
    );
  }

  @override
  Future<void> clearLocal() async {
    await _firebase?.clearLocal();
  }

  @override
  Future<void> stopForWithdrawal() async {
    await _firebase?.close();
  }

  @override
  void invalidate() {
    _firebase?.invalidate();
  }
}

class PlatformIdentityBackend
    implements
        IdentityBackend,
        GuestIdentityBackend,
        LocalIdentityBackend,
        LocalSessionIdentityBackend {
  final FenlengFlutterClient client;
  final PlatformIdentityConfig config;
  late final FlutterAuthSDK auth;
  @override
  bool guestSession = false;
  PlatformIdentityBackend(
    Directory directory,
    this.config, {
    FenlengFlutterClient? client,
  }) : client =
           client ??
           FenlengFlutterClient(
             options: FenlengClientOptions(
               baseUrl: config.ready
                   ? config.baseUrl
                   : 'https://unconfigured.invalid',
               storage: IdentityStorage(directory),
               tokenKey: 'fridge:platform:access',
             ),
           ) {
    auth = FlutterAuthSDK(
      client: this.client,
      applicationCode: config.applicationCode,
      clientId: config.clientId,
      clientTarget: 'mobile',
    );
  }
  @override
  Future<bool> restore() async {
    final restored =
        await auth.restoreSession() == FlutterSessionStatus.authenticated;
    guestSession = restored && await auth.isGuestSession();
    return restored;
  }

  @override
  Future<void> createGuest() async {
    await auth.loginAsGuest();
    guestSession = true;
  }

  @override
  Future<void> exchange(IdentityProvider provider, String proof) async {
    try {
      if (config.releaseChannel == 'global') {
        if (provider == IdentityProvider.wechat) {
          throw const IdentityFailure('loginNotConfigured');
        }
        await auth.loginWithFirebaseIdToken(proof);
      } else if (provider == IdentityProvider.wechat) {
        await auth.loginWithWechatCode(proof);
      } else if (provider == IdentityProvider.apple) {
        await auth.loginWithAppleIdentityToken(proof);
      } else {
        throw const IdentityFailure('loginNotConfigured');
      }
      guestSession = false;
    } on IdentityFailure {
      rethrow;
    } catch (error) {
      throw identityFailure(error);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await auth.logout();
    } finally {
      guestSession = false;
    }
  }

  @override
  Future<void> endLocalSession() async {
    try {
      await auth.logout(localOnly: true);
    } finally {
      guestSession = false;
    }
  }

  @override
  Future<void> close() async {
    auth.dispose();
    client.options.httpClient.close();
  }

  @override
  Future<void> sealForWithdrawal() async {
    client.options.httpClient.close();
    final storage = client.options.storage;
    if (storage is! IdentityStorage) {
      throw StateError('LOCAL_SESSION_STORAGE_UNSUPPORTED');
    }
    await storage.sealForWithdrawal();
    guestSession = false;
  }
}
