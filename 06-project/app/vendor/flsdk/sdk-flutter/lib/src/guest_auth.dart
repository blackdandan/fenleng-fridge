part of 'auth.dart';

final _guestRequests = Expando<Future<Map<String, dynamic>>>();
String _guestSessionKey(FlutterAuthSDK auth) =>
    '${auth.client.options.tokenKey}:kind';

/// Explicit guest authentication; callers must enforce privacy consent.
extension FlutterGuestIdentity on FlutterAuthSDK {
  Future<bool> isGuestSession() async =>
      await client.options.storage.getItem(_guestSessionKey(this)) == 'guest';

  /// Concurrent guest creation shares one request. Failed writes are never
  /// replayed automatically; a later caller may make a controlled new attempt.
  Future<Map<String, dynamic>> loginAsGuest({Map<String, dynamic>? device}) {
    final existing = _guestRequests[this];
    if (existing != null) return existing;
    final operation = _loginAsGuest(device);
    final result = operation.whenComplete(() => _guestRequests[this] = null);
    _guestRequests[this] = result;
    return result;
  }

  Future<Map<String, dynamic>> _loginAsGuest(
      Map<String, dynamic>? device) async {
    _sessionController.add(FlutterSessionStatus.authenticating);
    try {
      final tokens = await client
          .request('/api/platform/v1/auth/guest/login', method: 'POST', body: {
        'applicationCode': applicationCode,
        'clientId': clientId,
        if (device != null) 'device': device,
      });
      await _storeTokenPair(this, tokens, guest: true);
      _sessionController.add(FlutterSessionStatus.authenticated);
      return tokens;
    } catch (_) {
      _sessionController.add(FlutterSessionStatus.unauthenticated);
      rethrow;
    }
  }
}
