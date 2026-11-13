import 'dart:async';
import 'client.dart';
import 'qr_auth.dart';

part 'auth_types.dart';
part 'auth_storage.dart';
part 'guest_auth.dart';

class FlutterAuthSDK {
  final FenlengFlutterClient client;
  final String applicationCode;
  final String clientId;
  final String clientTarget;
  final _sessionController = StreamController<FlutterSessionStatus>.broadcast();
  Future<Map<String, dynamic>>? _refreshing;
  FlutterAuthSDK(
      {required this.client,
      required this.applicationCode,
      String? clientId,
      this.clientTarget = 'mobile'})
      : clientId = clientId ?? '$applicationCode-$clientTarget';
  Stream<FlutterSessionStatus> get onSessionStatusChanged =>
      _sessionController.stream;
  String get _refreshKey => '${client.options.tokenKey}:refresh';
  Future<Map<String, dynamic>> register(
          {required String email,
          required String password,
          required String username,
          required String displayName,
          required String verificationCode,
          Map<String, dynamic>? device}) async {
    _sessionController.add(FlutterSessionStatus.authenticating);
    try {
      final result = await client.request('/api/platform/v1/auth/register', method: 'POST', body: {
        'applicationCode': applicationCode,
        'clientId': clientId,
        'email': email,
        'password': password,
        'username': username,
        'displayName': displayName,
        'verificationCode': verificationCode,
        if (device != null) 'device': device,
      });
      await _store(result);
      _sessionController.add(FlutterSessionStatus.authenticated);
      return result;
    } catch (_) {
      _sessionController.add(FlutterSessionStatus.unauthenticated);
      rethrow;
    }
  }
  Future<Map<String, dynamic>> requestRegistrationEmailVerification(
          String email) =>
      client.request('/api/platform/v1/auth/registration-email-verification',
          method: 'POST',
          body: {
            'applicationCode': applicationCode,
            'clientId': clientId,
            'email': email,
          });
  Future<Map<String, dynamic>> loginWithPassword(String email, String password,
      {Map<String, dynamic>? device}) async {
    _sessionController.add(FlutterSessionStatus.authenticating);
    try {
      final tokens = await client
          .request('/api/platform/v1/auth/login', method: 'POST', body: {
        'applicationCode': applicationCode,
        'clientId': clientId,
        'email': email,
        'password': password,
        if (device != null) 'device': device
      });
      await _store(tokens);
      _sessionController.add(FlutterSessionStatus.authenticated);
      return tokens;
    } catch (_) {
      _sessionController.add(FlutterSessionStatus.unauthenticated);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> loginWithWechatCode(String code,
      {Map<String, dynamic>? device}) async {
    if (code.trim().isEmpty || code.length > 1024) {
      throw const FenlengSdkException(
          'VALIDATION_FAILED', 'WeChat authorization code is invalid');
    }
    _sessionController.add(FlutterSessionStatus.authenticating);
    try {
      final tokens = await client
          .request('/api/platform/v1/auth/wechat/login', method: 'POST', body: {
        'applicationCode': applicationCode,
        'clientId': clientId,
        'code': code,
        if (device != null) 'device': device,
      });
      await _store(tokens);
      _sessionController.add(FlutterSessionStatus.authenticated);
      return tokens;
    } catch (_) {
      _sessionController.add(FlutterSessionStatus.unauthenticated);
      rethrow;
    }
  }

  /// Exchange a native Apple identity token for the same Fenleng session.
  Future<Map<String, dynamic>> loginWithAppleIdentityToken(String identityToken,
      {String? displayName, Map<String, dynamic>? device}) async {
    if (identityToken.trim().isEmpty ||
        identityToken.length > 16384 ||
        identityToken.contains('\r') ||
        identityToken.contains('\n') ||
        (displayName != null && displayName.length > 120)) {
      throw const FenlengSdkException(
          'VALIDATION_FAILED', 'Apple identity credential is invalid');
    }
    _sessionController.add(FlutterSessionStatus.authenticating);
    try {
      final tokens = await client.request(
          '/api/platform/v1/auth/federated/apple/login',
          method: 'POST',
          body: {
            'applicationCode': applicationCode,
            'clientId': clientId,
            'identityToken': identityToken,
            if (displayName != null) 'displayName': displayName,
            if (device != null) 'device': device,
          });
      await _store(tokens);
      _sessionController.add(FlutterSessionStatus.authenticated);
      return tokens;
    } catch (_) {
      _sessionController.add(FlutterSessionStatus.unauthenticated);
      rethrow;
    }
  }

  /// Exchanges a short-lived Firebase ID token for a Fenleng session.
  ///
  /// Firebase is the overseas identity broker. The Shared Platform, rather
  /// than the client, verifies the token signature, issuer, audience and
  /// expiry before linking the external identity and issuing Fenleng tokens.
  Future<Map<String, dynamic>> loginWithFirebaseIdToken(String idToken,
      {Map<String, dynamic>? device}) async {
    if (idToken.trim().isEmpty || idToken.length > 16384) {
      throw const FenlengSdkException(
          'VALIDATION_FAILED', 'Firebase ID token is invalid');
    }
    _sessionController.add(FlutterSessionStatus.authenticating);
    try {
      final tokens = await client.request(
          '/api/platform/v1/auth/federated/firebase/login',
          method: 'POST',
          body: {
            'applicationCode': applicationCode,
            'clientId': clientId,
            'idToken': idToken,
            if (device != null) 'device': device,
          });
      await _store(tokens);
      _sessionController.add(FlutterSessionStatus.authenticated);
      return tokens;
    } catch (_) {
      _sessionController.add(FlutterSessionStatus.unauthenticated);
      rethrow;
    }
  }

  Future<GeneratedQrLoginChallenge> generateQrLoginChallenge(
      {required String deepLinkScheme}) async {
    final response = await client.request(
      '/api/platform/v1/auth/qr/challenges',
      method: 'POST',
      body: {
        'applicationCode': applicationCode,
        'clientId': clientId,
        'deepLinkScheme': deepLinkScheme,
      },
    );
    return GeneratedQrLoginChallenge.fromJson(response);
  }

  Future<QrLoginTransition> scanQrLoginChallenge(String challengeToken) async {
    final response = await client.request(
      '/api/platform/v1/auth/qr/challenges/scan',
      method: 'POST',
      body: {'challengeToken': challengeToken},
    );
    return QrLoginTransition.fromJson(response);
  }

  Future<QrLoginTransition> confirmQrLoginChallenge(
      String challengeToken) async {
    final response = await client.request(
      '/api/platform/v1/auth/qr/challenges/confirm',
      method: 'POST',
      body: {'challengeToken': challengeToken},
    );
    return QrLoginTransition.fromJson(response);
  }

  Future<QrLoginStatus> claimQrLoginChallenge(
      {required String challengeToken, required String pollToken}) async {
    final response = await client.request(
      '/api/platform/v1/auth/qr/challenges/status',
      method: 'POST',
      body: {'challengeToken': challengeToken, 'pollToken': pollToken},
    );
    final status = QrLoginStatus.fromJson(response);
    if (status.tokens != null) {
      await _store(status.tokens!);
      _sessionController.add(FlutterSessionStatus.authenticated);
    }
    return status;
  }

  Future<Map<String, dynamic>> refresh() =>
      _refreshing ??= _performRefresh().whenComplete(() => _refreshing = null);
  Future<Map<String, dynamic>> _performRefresh() async {
    final token = await client.options.storage.getItem(_refreshKey);
    if (token == null)
      throw const FenlengSdkException('SESSION_MISSING', 'No refresh token');
    final tokens = await client.request('/api/platform/v1/auth/refresh',
        method: 'POST', body: {'refreshToken': token});
    await _storeTokenPair(this, tokens, guest: await isGuestSession());
    return tokens;
  }

  Future<void> logout({bool allSessions = false, bool localOnly = false}) async {
    final token = await client.options.storage.getItem(_refreshKey);
    try {
      if (token != null && !localOnly)
        await client.request('/api/platform/v1/auth/logout',
            method: 'POST',
            body: {'refreshToken': token, 'allSessions': allSessions});
    } finally {
      await client.options.storage.removeItem(client.options.tokenKey);
      await client.options.storage.removeItem(_refreshKey);
      await client.options.storage.removeItem(_guestSessionKey(this));
      _sessionController.add(FlutterSessionStatus.unauthenticated);
    }
  }

  Future<FlutterSessionStatus> restoreSession() => _restoreAuthSession(this);

  /// Authenticated read only; never refreshes, creates or replaces a session.
  Future<FlutterCurrentUser> currentUser() async => FlutterCurrentUser.fromJson(
      await client.request('/api/platform/v1/users/me'));

  Future<Map<String, dynamic>> createFederatedDeletionChallenge(
      String provider, String deletionIdempotencyKey) {
    if (!const ['FIREBASE', 'APPLE', 'WECHAT'].contains(provider) ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$').hasMatch(deletionIdempotencyKey)) {
      throw const FenlengSdkException('VALIDATION_FAILED', 'Invalid deletion reauthentication request');
    }
    return client.request('/api/platform/v1/auth/step-up/self-deletion/challenges',
        method: 'POST', body: {'provider': provider, 'deletionIdempotencyKey': deletionIdempotencyKey});
  }

  Future<Map<String, dynamic>> confirmFederatedDeletionReauthentication(
      String challengeId, String identityToken) {
    if (!RegExp(r'^fdc-[A-Za-z0-9._:-]+$').hasMatch(challengeId) || challengeId.length > 128 ||
        identityToken.trim().isEmpty || identityToken.length > 16384) {
      throw const FenlengSdkException('VALIDATION_FAILED', 'Invalid deletion reauthentication proof');
    }
    return client.request('/api/platform/v1/auth/step-up/self-deletion/challenges/${Uri.encodeComponent(challengeId)}/confirm',
        method: 'POST', body: {'identityToken': identityToken});
  }

  Future<Map<String, dynamic>> dataRequests() =>
      client.request('/api/platform/v1/users/me/data-requests');
  Future<Map<String, dynamic>> requestData(String type, String idempotencyKey,
          {String? actionConfirmationId}) =>
      client.request('/api/platform/v1/users/me/data-requests',
          method: 'POST',
          body: {'type': type},
          idempotencyKey: idempotencyKey,
          actionConfirmationId: actionConfirmationId);
  Future<String> confirmAccountDeletion(
      {required String password,
      required String userId,
      required String idempotencyKey}) async {
    final response = await client
        .request('/api/platform/v1/auth/step-up', method: 'POST', body: {
      'password': password,
      'confirmation': {
        'permissionCode': 'platform:self-data:delete',
        'resourceType': 'user-data-request',
        'resourceId': userId,
        'idempotencyKey': idempotencyKey,
      }
    });
    final confirmation = response['confirmation'];
    final id = confirmation is Map<String, dynamic> ? confirmation['id'] : null;
    if (id is! String || id.isEmpty)
      throw const FenlengSdkException('ACTION_CONFIRMATION_MISSING',
          'Deletion confirmation was not issued');
    return id;
  }

  Future<Map<String, dynamic>> devices() =>
      client.request('/api/platform/v1/users/me/devices');
  Future<Map<String, dynamic>> revokeDevice(String id, String idempotencyKey) =>
      client.request(
          '/api/platform/v1/users/me/devices/${Uri.encodeComponent(id)}/revoke',
          method: 'POST',
          body: <String, dynamic>{},
          idempotencyKey: idempotencyKey);
  Future<void> _store(Map<String, dynamic> tokens) => _storeTokenPair(this, tokens);

  void dispose() => _sessionController.close();
}
