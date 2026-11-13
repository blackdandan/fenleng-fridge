part of 'auth.dart';

Future<void> _storeTokenPair(FlutterAuthSDK auth, Map<String, dynamic> tokens,
    {bool guest = false}) async {
  final access = tokens['accessToken'], refresh = tokens['refreshToken'];
  if (access is! String ||
      refresh is! String ||
      access.trim().isEmpty ||
      refresh.trim().isEmpty ||
      RegExp(r'[\r\n]').hasMatch(access + refresh)) {
    throw const FenlengSdkException(
        'TOKEN_RESPONSE_INVALID', 'Invalid token response');
  }
  try {
    await auth.client.options.storage
        .setItem(auth.client.options.tokenKey, access);
    await auth.client.options.storage.setItem(auth._refreshKey, refresh);
    await auth.client.options.storage
        .setItem(_guestSessionKey(auth), guest ? 'guest' : 'account');
  } catch (_) {
    await Future.wait([
      auth.client.options.storage.removeItem(auth.client.options.tokenKey),
      auth.client.options.storage.removeItem(auth._refreshKey),
      auth.client.options.storage.removeItem(_guestSessionKey(auth)),
    ]);
    rethrow;
  }
}

Future<FlutterSessionStatus> _restoreAuthSession(FlutterAuthSDK auth) async {
  final storage = auth.client.options.storage;
  final refresh = await storage.getItem(auth._refreshKey);
  if (refresh == null) return FlutterSessionStatus.unauthenticated;
  try {
    await auth.refresh();
    auth._sessionController.add(FlutterSessionStatus.authenticated);
    return FlutterSessionStatus.authenticated;
  } on FenlengSdkException catch (error) {
    if (error.status != 401 && error.code != 'SESSION_MISSING') rethrow;
    await Future.wait([
      storage.removeItem(auth.client.options.tokenKey),
      storage.removeItem(auth._refreshKey),
      storage.removeItem(_guestSessionKey(auth)),
    ]);
    auth._sessionController.add(FlutterSessionStatus.sessionExpired);
    return FlutterSessionStatus.sessionExpired;
  }
}
