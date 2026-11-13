part of 'auth.dart';

enum FlutterSessionStatus {
  unauthenticated,
  authenticating,
  authenticated,
  sessionExpired,
}

class FlutterCurrentUser {
  final String id, kind, status;
  const FlutterCurrentUser(this.id, this.kind, this.status);
  factory FlutterCurrentUser.fromJson(Map<String, dynamic> value) {
    final id = value['id'], kind = value['kind'], status = value['status'];
    if (id is! String || id.isEmpty || id.length > 128 ||
        kind is! String || status is! String) {
      throw const FenlengSdkException('RESPONSE_INVALID', 'Invalid current user');
    }
    return FlutterCurrentUser(id, kind, status);
  }
}

abstract interface class FlutterIdentityExtension {
  String get provider;
  Future<Map<String, dynamic>> authenticate(Map<String, dynamic> challenge);
}

/// Stable application context shared by all FL client SDKs.
class FenlengAuthConfig {
  const FenlengAuthConfig({
    required this.applicationCode,
    this.clientTarget = 'mobile',
    this.clientId,
  });
  final String applicationCode;
  final String clientTarget;
  final String? clientId;
  String get resolvedClientId => clientId ?? '$applicationCode-$clientTarget';
}
