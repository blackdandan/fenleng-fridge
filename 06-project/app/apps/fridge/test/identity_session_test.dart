import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/application/identity_session.dart';

class Backend implements IdentityBackend {
  int exchanges = 0, logouts = 0, restores = 0;
  Completer<void>? gate;
  Completer<void>? restoreGate;
  bool restored = false;
  bool closed = false;
  @override
  Future<bool> restore() async {
    restores++;
    await restoreGate?.future;
    return restored;
  }

  @override
  Future<void> exchange(IdentityProvider provider, String proof) async {
    expect(proof, 'one-time-code');
    exchanges++;
    await gate?.future;
  }

  @override
  Future<void> logout() async {
    logouts++;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

class Authorization implements IdentityAuthorization {
  int calls = 0;
  Completer<String>? gate;
  String? failure;
  @override
  Future<String> authorize(IdentityProvider provider) async {
    calls++;
    if (failure != null) throw IdentityFailure(failure!);
    return gate == null ? 'one-time-code' : gate!.future;
  }
}

void main() {
  late Backend backend;
  late Authorization authorization;
  late bool consent;
  IdentitySession create({bool configured = true}) => IdentitySession(
    backend: backend,
    authorization: authorization,
    consent: () => consent,
    configured: configured,
  );
  setUp(() {
    backend = Backend();
    authorization = Authorization();
    consent = true;
  });

  test(
    'unconfigured optional login never authorizes or contacts backend',
    () async {
      final session = create(configured: false);
      await session.restore();
      await session.login(IdentityProvider.wechat);
      expect(session.errorKey, 'loginNotConfigured');
      expect(session.signedIn, false);
      expect(authorization.calls, 0);
      expect(backend.restores + backend.exchanges, 0);
      await session.close();
    },
  );

  test('repeated taps share one authorization and one exchange', () async {
    authorization.gate = Completer();
    final session = create();
    final first = session.login(IdentityProvider.wechat);
    final duplicate = session.login(IdentityProvider.wechat);
    await Future<void>.delayed(Duration.zero);
    expect(authorization.calls, 1);
    authorization.gate!.complete('one-time-code');
    await Future.wait([first, duplicate]);
    expect(backend.exchanges, 1);
    expect(session.signedIn, true);
    expect(session.busy, false);
    await session.logout();
    expect(session.signedIn, false);
    await session.close();
  });

  test('cancellation ends loading and permits retry', () async {
    authorization.failure = 'loginCancelled';
    final session = create();
    await session.login(IdentityProvider.wechat);
    expect(session.errorKey, 'loginCancelled');
    expect(session.busy, false);
    expect(backend.exchanges, 0);
    authorization.failure = null;
    await session.login(IdentityProvider.wechat);
    expect(session.signedIn, true);
    expect(session.errorKey, null);
    await session.close();
  });

  test(
    'closing from a busy listener prevents native authorization starting',
    () async {
      final session = create();
      late Future<void> closing;
      session.addListener(() {
        if (session.busy) closing = session.close();
      });
      await session.login(IdentityProvider.wechat);
      await closing;
      expect(authorization.calls, 0);
      expect(backend.closed, true);
    },
  );

  test(
    'withdrawal during native authorization prevents token exchange',
    () async {
      authorization.gate = Completer();
      final session = create();
      final operation = session.login(IdentityProvider.wechat);
      await Future<void>.delayed(Duration.zero);
      consent = false;
      authorization.gate!.complete('one-time-code');
      await operation;
      expect(backend.exchanges, 0);
      expect(session.signedIn, false);
      await session.close();
    },
  );

  test(
    'close during exchange waits and removes late session before disposal',
    () async {
      backend.gate = Completer();
      final session = create();
      final operation = session.login(IdentityProvider.wechat);
      await Future<void>.delayed(Duration.zero);
      final closing = session.close();
      expect(backend.closed, false);
      backend.gate!.complete();
      await Future.wait([operation, closing]);
      expect(backend.logouts, 1);
      expect(session.signedIn, false);
      expect(backend.closed, true);
    },
  );

  test(
    'withdrawal during restore clears the restored platform session',
    () async {
      backend.restored = true;
      backend.restoreGate = Completer();
      final session = create();
      final restoring = session.restore();
      await Future<void>.delayed(Duration.zero);
      consent = false;
      backend.restoreGate!.complete();
      await restoring;
      expect(session.signedIn, false);
      expect(session.errorKey, 'loginCancelled');
      expect(backend.logouts, 1);
      await session.close();
    },
  );
}
