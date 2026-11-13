import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import 'package:fenleng_sdk_flutter_firebase_identity/fenleng_sdk_flutter_firebase_identity.dart';
import '../application/identity_session.dart';

part 'global_firebase_native.dart';

enum FirebaseProvider { google, apple }

/// Public client configuration only. Server credentials never enter Dart defines.
class GlobalFirebaseConfig {
  final bool enabled;
  final String channel,
      projectId,
      appId,
      apiKey,
      senderId,
      googleServerClientId,
      googleIosClientId;
  const GlobalFirebaseConfig({
    this.enabled = const bool.fromEnvironment('FRIDGE_FIREBASE_ENABLED'),
    this.channel = const String.fromEnvironment(
      'APP_RELEASE_CHANNEL',
      defaultValue: 'china',
    ),
    this.projectId = const String.fromEnvironment(
      'FRIDGE_FIREBASE_PROJECT_ID',
      defaultValue: 'fenleng-fridge-global-TODO',
    ),
    this.appId = const String.fromEnvironment('FRIDGE_FIREBASE_APP_ID'),
    this.apiKey = const String.fromEnvironment('FRIDGE_FIREBASE_API_KEY'),
    this.senderId = const String.fromEnvironment(
      'FRIDGE_FIREBASE_MESSAGING_SENDER_ID',
    ),
    this.googleServerClientId = const String.fromEnvironment(
      'FRIDGE_GOOGLE_SERVER_CLIENT_ID',
    ),
    this.googleIosClientId = const String.fromEnvironment(
      'FRIDGE_GOOGLE_IOS_CLIENT_ID',
    ),
  });
  bool ready(String platform) =>
      enabled &&
      channel == 'global' &&
      ['android', 'ios'].contains(platform) &&
      RegExp(r'^fenleng-fridge-[a-z0-9-]{1,40}$').hasMatch(projectId) &&
      !projectId.contains('todo') &&
      RegExp('^1:[0-9]+:$platform:[A-Za-z0-9]+\$').hasMatch(appId) &&
      RegExp(r'^[0-9]+$').hasMatch(senderId) &&
      appId.split(':')[1] == senderId &&
      apiKey.startsWith('AIza') &&
      apiKey.length >= 30 &&
      !apiKey.toLowerCase().contains('placeholder') &&
      googleServerClientId.endsWith('.apps.googleusercontent.com') &&
      (platform != 'ios' ||
          googleIosClientId.endsWith('.apps.googleusercontent.com'));
}

abstract interface class FirebaseNativeIdentity {
  Object get coordinationKey;
  void bindCurrent(bool Function() current);
  String? get uid;
  Future<void> initialize(GlobalFirebaseConfig config);
  Future<void> signIn(FirebaseProvider provider);
  Future<void> reauthenticate(FirebaseProvider provider);
  Future<String> token();
  Future<void> clearLocal();
}

/// No Firebase object, plugin or cache read is constructed before a user action
/// passes the persisted online-consent gate. This class does not open FL sessions.
class GlobalFirebaseIdentity {
  static final _leases = <Object, Future<String>>{};
  final GlobalFirebaseConfig config;
  final FirebaseNativeIdentity native;
  final bool Function() consent;
  final String platform;
  final Duration timeout;
  Future<String>? _work;
  int _epoch = 0;
  bool _closed = false;
  Future<void>? _closing;
  GlobalFirebaseIdentity({
    required this.config,
    required this.native,
    required this.consent,
    required this.platform,
    this.timeout = const Duration(seconds: 120),
  });
  void _gate(int epoch) {
    if (_closed || !consent() || epoch != _epoch) {
      throw const IdentityFailure('loginCancelled');
    }
  }

  Future<String> authorize(
    FirebaseProvider provider, {
    bool reauthenticate = false,
  }) {
    if (_closed || !consent()) {
      return Future.error(const IdentityFailure('loginCancelled'));
    }
    if (!config.ready(platform) ||
        provider == FirebaseProvider.apple && platform != 'ios') {
      return Future.error(const IdentityFailure('loginNotConfigured'));
    }
    if (_work != null || _leases.containsKey(native.coordinationKey)) {
      return Future.error(const IdentityFailure('loginTimeout'));
    }
    final epoch = _epoch;
    final operation = Future<String>(() async {
      try {
        _gate(epoch);
        native.bindCurrent(() => !_closed && consent() && epoch == _epoch);
        await native.initialize(config);
        _gate(epoch);
        final original = native.uid;
        if (reauthenticate) {
          if (original == null) throw const IdentityFailure('loginFailed');
          await native.reauthenticate(provider);
        } else {
          await native.signIn(provider);
        }
        _gate(epoch);
        if (native.uid == null || reauthenticate && native.uid != original) {
          throw const IdentityFailure('loginFailed');
        }
        final proof = await native.token();
        _gate(epoch);
        if (proof.trim().isEmpty) throw const IdentityFailure('loginFailed');
        return proof;
      } catch (error) {
        throw globalIdentityFailure(error);
      } finally {
        // A timed out or withdrawn native flow can still return later. It may
        // clear only this serialized provider flow, never start a platform login.
        if (_closed || !consent() || epoch != _epoch) {
          try {
            await native.clearLocal();
          } catch (_) {}
        }
      }
    });
    late final Future<String> pending;
    pending = operation.whenComplete(() {
      _work = null;
      if (identical(_leases[native.coordinationKey], pending)) {
        _leases.remove(native.coordinationKey);
      }
    });
    _work = pending;
    _leases[native.coordinationKey] = pending;
    return pending.timeout(
      timeout,
      onTimeout: () {
        _epoch++;
        throw const IdentityFailure('loginTimeout');
      },
    );
  }

  Future<void> clearLocal() => _closed ? Future.value() : native.clearLocal();

  /// Normal host disposal preserves a settled Provider cache for next-launch
  /// reauthentication, but fences an outstanding native authorization.
  void invalidate() {
    _closed = true;
    _epoch++;
  }

  Future<void> close() {
    if (_closing case final closing?) return closing;
    _closed = true;
    _epoch++;
    return _closing = Future<void>.sync(native.clearLocal).catchError((
      Object error,
      StackTrace stack,
    ) {
      // Failed withdrawal cleanup remains retryable; a completed close stays
      // idempotent so an old owner cannot later clear a replacement session.
      _closing = null;
      Error.throwWithStackTrace(error, stack);
    });
  }
}

IdentityFailure globalIdentityFailure(Object error) {
  if (error is IdentityFailure) return error;
  if (error is TimeoutException) return const IdentityFailure('loginTimeout');
  if (error is GoogleSignInException) {
    if (error.code.name == 'canceled') {
      return const IdentityFailure('loginCancelled');
    }
    if (error.code.name.contains('Configuration')) {
      return const IdentityFailure('loginNotConfigured');
    }
  }
  if (error is FirebaseAuthException &&
      [
        'web-context-canceled',
        'canceled-popup-request',
        'user-cancelled',
      ].contains(error.code)) {
    return const IdentityFailure('loginCancelled');
  }
  return const IdentityFailure('loginFailed');
}
