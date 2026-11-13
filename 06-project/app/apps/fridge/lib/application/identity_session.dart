import 'dart:async';
import 'package:flutter/foundation.dart';

enum IdentityProvider { wechat, apple, google }

abstract interface class IdentityBackend {
  Future<bool> restore();
  Future<void> exchange(IdentityProvider provider, String proof);
  Future<void> logout();
  Future<void> close();
}

abstract interface class IdentityAuthorization {
  Future<String> authorize(IdentityProvider provider);
}

abstract interface class IdentityReauthorization {
  Future<String> reauthorize(IdentityProvider provider);
}

abstract interface class IdentityAuthorizationLifecycle {
  Future<void> clearLocal();
  Future<void> stopForWithdrawal();
  void invalidate();
}

abstract interface class GuestIdentityBackend {
  bool get guestSession;
  Future<void> createGuest();
}

abstract interface class LocalIdentityBackend {
  Future<void> sealForWithdrawal();
}

abstract interface class LocalSessionIdentityBackend {
  Future<void> endLocalSession();
}

class IdentityFailure implements Exception {
  final String key;
  const IdentityFailure(this.key);
}

/// Optional identity never owns, migrates or clears the local inventory.
class IdentitySession extends ChangeNotifier {
  final IdentityBackend backend;
  final IdentityAuthorization authorization;
  final bool Function() consent;
  final bool configured;
  final bool guestEnabled;
  final VoidCallback? onSessionReset;
  final bool Function()? canChangeSession;
  bool signedIn = false;
  bool guestReady = false;
  bool get sessionAvailable => signedIn || guestReady;
  bool busy = false;
  String? errorKey;
  Future<void>? _operation;
  bool _closed = false;
  bool _withdrawing = false;
  int _revision = 0;
  int get revision => _revision;
  Future<void>? _closing;
  IdentitySession({
    required this.backend,
    required this.authorization,
    required this.consent,
    required this.configured,
    this.guestEnabled = false,
    this.onSessionReset,
    this.canChangeSession,
  });

  Future<void> restore() => _run(() => _restore(createGuest: false));

  Future<void> ensureSession() =>
      _run(() => _restore(createGuest: guestEnabled));

  Future<void> _restore({required bool createGuest}) async {
    if (!configured) return;
    final wasSignedIn = signedIn, wasGuest = guestReady;
    var restored = await backend.restore();
    if (!restored && sessionAvailable) _resetEvents();
    final guest = backend is GuestIdentityBackend
        ? backend as GuestIdentityBackend
        : null;
    if (!restored && createGuest && guest != null && !_closed && consent()) {
      await guest.createGuest();
      restored = true;
    }
    if (_closed || !consent()) {
      await _clearLateSession();
      signedIn = false;
      guestReady = false;
      throw const IdentityFailure('loginCancelled');
    }
    guestReady = restored && (guest?.guestSession ?? false);
    signedIn = restored && !guestReady;
    if (wasSignedIn != signedIn || wasGuest != guestReady) _revision++;
  }

  Future<void> login(IdentityProvider provider) => _run(() async {
    if (!configured) throw const IdentityFailure('loginNotConfigured');
    _revision++;
    _resetEvents();
    final proof = await authorization.authorize(provider);
    if (_closed || !consent()) throw const IdentityFailure('loginCancelled');
    await backend.exchange(provider, proof);
    if (_closed || !consent()) {
      await _clearLateSession();
      signedIn = false;
      guestReady = false;
      throw const IdentityFailure('loginCancelled');
    }
    signedIn = true;
    guestReady = false;
  });

  Future<void> logout() => _run(() async {
    _revision++;
    _resetEvents();
    try {
      await backend.logout();
    } finally {
      signedIn = false;
      guestReady = false;
      if (authorization is IdentityAuthorizationLifecycle) {
        await (authorization as IdentityAuthorizationLifecycle).clearLocal();
      }
    }
  });

  /// A server DELETE already revoked the original session. Never send logout
  /// HTTP or remove a replacement human/guest session from an old receipt.
  Future<void> endLocalSession(int expectedRevision) async {
    if (_closed || !consent() || _revision != expectedRevision) return;
    if (busy || backend is! LocalSessionIdentityBackend) {
      throw const IdentityFailure('loginFailed');
    }
    _revision++;
    busy = true;
    _resetEvents();
    try {
      await (backend as LocalSessionIdentityBackend).endLocalSession();
      if (authorization is IdentityAuthorizationLifecycle) {
        await (authorization as IdentityAuthorizationLifecycle).clearLocal();
      }
    } finally {
      signedIn = false;
      guestReady = false;
      busy = false;
      if (!_closed) notifyListeners();
    }
  }

  void _resetEvents() {
    try {
      onSessionReset?.call();
    } catch (_) {}
  }

  Future<void> _run(Future<void> Function() action) {
    if (_closed || busy) return _operation ?? Future.value();
    if (canChangeSession?.call() == false) return Future.value();
    busy = true;
    errorKey = null;
    final operation = Future<void>(() async {
      try {
        if (_closed || !consent()) {
          throw const IdentityFailure('loginCancelled');
        }
        await action();
      } on IdentityFailure catch (error) {
        errorKey = error.key;
      } catch (_) {
        errorKey = 'loginFailed';
      } finally {
        busy = false;
        if (!_closed) notifyListeners();
      }
    }).whenComplete(() => _operation = null);
    _operation = operation;
    notifyListeners();
    return operation;
  }

  Future<void> stopForWithdrawal() async {
    _revision++;
    _withdrawing = true;
    _closed = true;
    signedIn = false;
    guestReady = false;
    _resetEvents();
    try {
      if (backend is LocalIdentityBackend) {
        await (backend as LocalIdentityBackend).sealForWithdrawal();
      } else {
        throw StateError('LOCAL_SESSION_CLEANUP_UNAVAILABLE');
      }
    } finally {
      if (authorization is IdentityAuthorizationLifecycle) {
        await (authorization as IdentityAuthorizationLifecycle)
            .stopForWithdrawal();
      }
    }
    unawaited(close());
  }

  Future<void> _clearLateSession() =>
      _withdrawing && backend is LocalIdentityBackend
      ? (backend as LocalIdentityBackend).sealForWithdrawal()
      : backend.logout();

  Future<void> close() {
    if (_closing case final closing?) return closing;
    _closed = true;
    if (authorization is IdentityAuthorizationLifecycle) {
      (authorization as IdentityAuthorizationLifecycle).invalidate();
    }
    return _closing = Future<void>.microtask(() async {
      await _operation;
      await backend.close();
    });
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }
}
