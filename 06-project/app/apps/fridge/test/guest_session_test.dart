import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/application/identity_session.dart';
import 'identity_session_test.dart' show Backend, Authorization;

class GuestBackend extends Backend implements GuestIdentityBackend {
  @override
  bool guestSession = false;
  int guests = 0;
  bool offline = false;
  Completer<void>? guestGate;
  @override
  Future<bool> restore() async {
    if (offline) throw StateError('offline');
    return super.restore();
  }

  @override
  Future<void> createGuest() async {
    guests++;
    await guestGate?.future;
    guestSession = true;
    restored = true;
  }

  @override
  Future<void> exchange(IdentityProvider provider, String proof) async {
    await super.exchange(provider, proof);
    guestSession = false;
  }
}

void main() {
  late GuestBackend backend;
  late bool consent;
  IdentitySession create({bool enabled = true}) => IdentitySession(
    backend: backend,
    authorization: Authorization(),
    consent: () => consent,
    configured: true,
    guestEnabled: enabled,
  );
  setUp(() {
    backend = GuestBackend();
    consent = true;
  });

  test(
    'guest starts once and stays distinct from optional WeChat account',
    () async {
      backend.guestGate = Completer();
      final session = create();
      final first = session.ensureSession(),
          duplicate = session.ensureSession();
      await Future<void>.delayed(Duration.zero);
      expect(backend.guests, 1);
      backend.guestGate!.complete();
      await Future.wait([first, duplicate]);
      expect(session.sessionAvailable, true);
      expect(session.guestReady, true);
      expect(session.signedIn, false);
      await session.ensureSession();
      expect(backend.guests, 1);
      await session.login(IdentityProvider.wechat);
      expect(session.signedIn, true);
      expect(session.guestReady, false);
      await session.close();
    },
  );

  test('restored WeChat account never creates another guest', () async {
    backend.restored = true;
    final session = create();
    await session.ensureSession();
    expect(session.signedIn, true);
    expect(backend.guests, 0);
    await session.close();
  });

  test(
    'disabled guest rollout and absent consent never create credentials',
    () async {
      final session = create(enabled: false);
      await session.ensureSession();
      expect(session.sessionAvailable, false);
      expect(backend.guests, 0);
      await session.close();
      consent = false;
      final declined = create();
      await declined.ensureSession();
      expect(backend.guests, 0);
      expect(declined.sessionAvailable, false);
      await declined.close();
    },
  );

  test('transient restore failure cannot replace an existing guest', () async {
    backend.offline = true;
    final session = create();
    await session.ensureSession();
    expect(backend.guests, 0);
    expect(session.errorKey, 'loginFailed');
    backend.offline = false;
    await session.ensureSession();
    expect(backend.guests, 1);
    expect(session.errorKey, null);
    await session.logout();
    expect(session.sessionAvailable, false);
    await session.close();
  });

  test('withdrawal during guest creation clears the late session', () async {
    backend.guestGate = Completer();
    final session = create();
    final creating = session.ensureSession();
    await Future<void>.delayed(Duration.zero);
    consent = false;
    backend.guestGate!.complete();
    await creating;
    expect(backend.logouts, 1);
    expect(session.sessionAvailable, false);
    await session.close();
  });
}
