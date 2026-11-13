import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/application/identity_session.dart';
import 'package:fridge/infrastructure/global_firebase_identity.dart';

const configured = GlobalFirebaseConfig(
  enabled: true,
  channel: 'global',
  projectId: 'fenleng-fridge-global',
  appId: '1:123:android:abc123',
  apiKey: 'AIza000000000000000000000000000000000',
  senderId: '123',
  googleServerClientId: 'fridge-web.apps.googleusercontent.com',
);

class Native implements FirebaseNativeIdentity {
  @override
  void bindCurrent(bool Function() current) {}
  @override
  final Object coordinationKey;
  Native([Object? key]) : coordinationKey = key ?? Object();
  @override
  String? uid;
  int initializes = 0, signIns = 0, reauths = 0, tokens = 0, clears = 0;
  Completer<void>? pending;
  Completer<void>? cleared;
  bool mismatch = false;
  bool failClear = false;
  @override
  Future<void> initialize(GlobalFirebaseConfig config) async {
    initializes++;
  }

  @override
  Future<void> signIn(FirebaseProvider provider) async {
    signIns++;
    await pending?.future;
    uid = 'firebase-one';
  }

  @override
  Future<void> reauthenticate(FirebaseProvider provider) async {
    reauths++;
    await pending?.future;
    if (mismatch) uid = 'other-user';
  }

  @override
  Future<String> token() async {
    tokens++;
    return 'fresh-provider-token';
  }

  @override
  Future<void> clearLocal() async {
    clears++;
    if (failClear) {
      failClear = false;
      throw StateError('synthetic native cleanup failure');
    }
    uid = null;
    if (cleared?.isCompleted == false) {
      cleared!.complete();
    }
  }
}

void main() {
  late Native native;
  var consent = true;
  late GlobalFirebaseIdentity flow;
  setUp(() {
    consent = true;
    native = Native();
    flow = GlobalFirebaseIdentity(
      config: configured,
      native: native,
      consent: () => consent,
      platform: 'android',
    );
  });
  tearDown(() async {
    await flow.close();
  });
  Matcher failure(String key) =>
      isA<IdentityFailure>().having((e) => e.key, 'stable key', key);
  Future<void> entered() async {
    for (var i = 0; i < 30 && native.signIns + native.reauths == 0; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(native.signIns + native.reauths, 1);
  }

  test(
    'disabled placeholders china foreign project or unsupported platform cannot initialize',
    () async {
      final cases = [
        const GlobalFirebaseConfig(),
        const GlobalFirebaseConfig(enabled: true, channel: 'global'),
        const GlobalFirebaseConfig(
          enabled: true,
          channel: 'china',
          projectId: 'fenleng-fridge-global',
        ),
        const GlobalFirebaseConfig(
          enabled: true,
          channel: 'global',
          projectId: 'another-product',
        ),
      ];
      for (final config in cases) {
        final candidate = GlobalFirebaseIdentity(
          config: config,
          native: native,
          consent: () => true,
          platform: 'android',
        );
        await expectLater(
          candidate.authorize(FirebaseProvider.google),
          throwsA(failure('loginNotConfigured')),
        );
      }
      expect(configured.ready('android'), isTrue);
      expect(configured.ready('ohos'), isFalse);
      expect(configured.ready('ios'), isFalse);
      expect(native.initializes, 0);
    },
  );
  test(
    'no persisted online consent prevents even SDK initialization',
    () async {
      consent = false;
      await expectLater(
        flow.authorize(FirebaseProvider.google),
        throwsA(failure('loginCancelled')),
      );
      expect([native.initializes, native.signIns, native.tokens], [0, 0, 0]);
    },
  );
  test(
    'explicit login returns fresh proof without owning a platform session',
    () async {
      expect(
        await flow.authorize(FirebaseProvider.google),
        'fresh-provider-token',
      );
      expect(
        [native.initializes, native.signIns, native.reauths, native.tokens],
        [1, 1, 0, 1],
      );
    },
  );
  test(
    'deletion reauth uses existing same Firebase user and never regular sign-in',
    () async {
      native.uid = 'firebase-one';
      expect(
        await flow.authorize(FirebaseProvider.google, reauthenticate: true),
        'fresh-provider-token',
      );
      expect([native.signIns, native.reauths, native.tokens], [0, 1, 1]);
    },
  );
  test(
    'missing or different reauthenticated user cannot produce deletion proof',
    () async {
      await expectLater(
        flow.authorize(FirebaseProvider.google, reauthenticate: true),
        throwsA(failure('loginFailed')),
      );
      native.uid = 'firebase-one';
      native.mismatch = true;
      await expectLater(
        flow.authorize(FirebaseProvider.google, reauthenticate: true),
        throwsA(failure('loginFailed')),
      );
      expect(native.signIns, 0);
      expect(native.tokens, 0);
    },
  );
  test(
    'withdrawn native callback clears local provider state and returns no proof',
    () async {
      native.pending = Completer<void>();
      native.cleared = Completer<void>();
      final work = flow.authorize(FirebaseProvider.google);
      final rejected = expectLater(work, throwsA(failure('loginCancelled')));
      await entered();
      consent = false;
      await flow.close();
      native.pending!.complete();
      await rejected;
      expect(native.uid, isNull);
      expect(native.tokens, 0);
      expect(native.clears, 2);
    },
  );
  test(
    'concurrent user action does not open duplicate native authorization',
    () async {
      native.pending = Completer<void>();
      final work = flow.authorize(FirebaseProvider.google);
      await entered();
      await expectLater(
        flow.authorize(FirebaseProvider.google),
        throwsA(failure('loginTimeout')),
      );
      native.pending!.complete();
      await work;
      expect(native.signIns, 1);
    },
  );
  test(
    'timeout keeps native lease until late callback cleanup before allowing a new owner',
    () async {
      flow = GlobalFirebaseIdentity(
        config: configured,
        native: native,
        consent: () => consent,
        platform: 'android',
        timeout: const Duration(milliseconds: 20),
      );
      native.pending = Completer<void>();
      native.cleared = Completer<void>();
      await expectLater(
        flow.authorize(FirebaseProvider.google),
        throwsA(failure('loginTimeout')),
      );
      final replacementNative = Native(native.coordinationKey);
      final replacement = GlobalFirebaseIdentity(
        config: configured,
        native: replacementNative,
        consent: () => true,
        platform: 'android',
      );
      await expectLater(
        replacement.authorize(FirebaseProvider.google),
        throwsA(failure('loginTimeout')),
      );
      native.pending!.complete();
      await native.cleared!.future;
      // Finish the original finally/lease microtasks before retry, without
      // treating a fixed delay as proof of cleanup.
      await Future<void>.delayed(Duration.zero);
      expect(
        await replacement.authorize(FirebaseProvider.google),
        'fresh-provider-token',
      );
      expect(native.uid, isNull);
      expect(replacementNative.uid, 'firebase-one');
      await replacement.close();
    },
  );
  test(
    'Apple cannot be accidentally launched from Android Firebase configuration',
    () async {
      await expectLater(
        flow.authorize(FirebaseProvider.apple),
        throwsA(failure('loginNotConfigured')),
      );
      expect(native.initializes, 0);
    },
  );
  test(
    'failed local withdrawal cleanup retries; successful close stays idempotent',
    () async {
      native.failClear = true;
      await expectLater(flow.close(), throwsStateError);
      await flow.close();
      await flow.close();
      expect(native.clears, 2);
      await expectLater(
        flow.authorize(FirebaseProvider.google),
        throwsA(failure('loginCancelled')),
      );
      expect(native.initializes, 0);
      expect(native.clears, 2);
    },
  );
}
