part of 'global_firebase_identity.dart';

/// Actual FlutterFire and official Google plugin driver. The only FL ID-token
/// read uses the existing official Fenleng Firebase bridge, with forceRefresh.
class FlutterFirebaseNativeIdentity implements FirebaseNativeIdentity {
  static final _coordinationKey = Object();
  @override
  Object get coordinationKey => _coordinationKey;
  static const appName = 'fenleng-fridge-global';
  final MethodChannel bootstrap;
  FirebaseAuth? _auth;
  static Future<void>? _googleInitializing;
  static String? _googleConfig;
  static bool _googleReady = false;
  bool Function()? _current;
  @override
  void bindCurrent(bool Function() current) {
    _current = current;
  }

  void _check() {
    if (_current?.call() != true) throw const IdentityFailure('loginCancelled');
  }

  GlobalFirebaseConfig? _config;
  FlutterFirebaseNativeIdentity({
    this.bootstrap = const MethodChannel('fenleng.fridge/bootstrap'),
  });
  @override
  String? get uid => _auth?.currentUser?.uid;
  @override
  Future<void> initialize(GlobalFirebaseConfig config) async {
    _check();
    if (_auth != null) return;
    if (await bootstrap.invokeMethod<bool>('plugins.initializeOnline', {
          'releaseChannel': 'global',
          'policyVersion': 'V0.4',
        }) !=
        true) {
      throw const IdentityFailure('loginNotConfigured');
    }
    _check();
    final app = await Firebase.initializeApp(
      name: appName,
      options: FirebaseOptions(
        apiKey: config.apiKey,
        appId: config.appId,
        messagingSenderId: config.senderId,
        projectId: config.projectId,
      ),
    );
    if (app.options.projectId != config.projectId ||
        app.options.appId != config.appId) {
      throw const IdentityFailure('loginNotConfigured');
    }
    _config = config;
    _auth = FirebaseAuth.instanceFor(app: app);
    _check();
  }

  Future<OAuthCredential> _googleCredential() async {
    _check();
    final key =
        '${Platform.isIOS ? _config!.googleIosClientId : ''}|${_config!.googleServerClientId}';
    if (_googleConfig != null && _googleConfig != key) {
      throw const IdentityFailure('loginNotConfigured');
    }
    if (_googleInitializing == null) {
      _googleConfig = key;
      _googleInitializing = GoogleSignIn.instance
          .initialize(
            clientId: Platform.isIOS ? _config!.googleIosClientId : null,
            serverClientId: _config!.googleServerClientId,
          )
          .then(
            (_) => _googleReady = true,
            onError: (Object error, StackTrace stack) {
              _googleInitializing = null;
              _googleConfig = null;
              Error.throwWithStackTrace(error, stack);
            },
          );
    }
    await _googleInitializing;
    _check();
    final account = await GoogleSignIn.instance.authenticate();
    _check();
    final token = account.authentication.idToken;
    if (token == null || token.isEmpty) {
      throw const IdentityFailure('loginFailed');
    }
    return GoogleAuthProvider.credential(idToken: token);
  }

  @override
  Future<void> signIn(FirebaseProvider provider) async {
    _check();
    if (provider == FirebaseProvider.apple) {
      await _auth!.signInWithProvider(AppleAuthProvider());
    } else {
      final credential = await _googleCredential();
      _check();
      await _auth!.signInWithCredential(credential);
    }
  }

  @override
  Future<void> reauthenticate(FirebaseProvider provider) async {
    _check();
    final current = _auth!.currentUser;
    if (current == null) throw const IdentityFailure('loginFailed');
    if (provider == FirebaseProvider.apple) {
      await current.reauthenticateWithProvider(AppleAuthProvider());
    } else {
      final credential = await _googleCredential();
      _check();
      await current.reauthenticateWithCredential(credential);
    }
  }

  @override
  Future<String> token() {
    _check();
    return FirebaseAuthIdTokenSource(_auth!).getIdToken(forceRefresh: true);
  }

  @override
  Future<void> clearLocal() async {
    await _auth?.signOut();
    if (_googleReady) await GoogleSignIn.instance.signOut();
  }
}
