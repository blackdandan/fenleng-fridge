import 'package:firebase_auth/firebase_auth.dart';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';

/// Supplies a fresh Firebase ID token without exposing Firebase credentials to
/// the Fenleng SDK. Applications authenticate users with any Firebase-enabled
/// provider (Google, Facebook, Apple, email, SAML/OIDC, etc.) before using it.
abstract interface class FirebaseIdTokenSource {
  Future<String> getIdToken({bool forceRefresh = false});
}

final class FirebaseAuthIdTokenSource implements FirebaseIdTokenSource {
  FirebaseAuthIdTokenSource(this._auth);

  final FirebaseAuth _auth;

  @override
  Future<String> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const FenlengSdkException(
          'FIREBASE_USER_MISSING', 'No Firebase user is signed in');
    }
    final token = await user.getIdToken(forceRefresh);
    if (token == null || token.isEmpty) {
      throw const FenlengSdkException(
          'FIREBASE_ID_TOKEN_MISSING', 'Firebase did not return an ID token');
    }
    return token;
  }
}

/// Bridges an already authenticated Firebase user to the provider-neutral
/// Fenleng session. It deliberately does not expose provider secrets or trust
/// a Firebase client result as a Fenleng login.
final class FirebaseIdentitySessionBridge {
  FirebaseIdentitySessionBridge({
    required FlutterAuthSDK auth,
    required FirebaseIdTokenSource tokenSource,
  })  : _auth = auth,
        _tokenSource = tokenSource;

  final FlutterAuthSDK _auth;
  final FirebaseIdTokenSource _tokenSource;

  Future<Map<String, dynamic>> login({
    Map<String, dynamic>? device,
    bool forceRefresh = false,
  }) async =>
      _auth.loginWithFirebaseIdToken(
        await _tokenSource.getIdToken(forceRefresh: forceRefresh),
        device: device,
      );
}
