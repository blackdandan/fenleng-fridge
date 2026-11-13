part of 'auth.dart';

/// China-channel native Apple proof is verified by Shared Platform, not Firebase.
extension FlutterAppleAuth on FlutterAuthSDK {
  Future<Map<String, dynamic>> loginWithAppleIdentityToken(String identityToken,
      {Map<String, dynamic>? device}) async {
    if (identityToken.trim().isEmpty || identityToken.length > 16384) {
      throw const FenlengSdkException(
          'VALIDATION_FAILED', 'Apple identity token is invalid');
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
}
