import 'client.dart';

const _capabilityPattern = r'^[A-Za-z0-9_-]{43}$';

enum QrLoginChallengeStatus { waiting, scanned, confirmed, expired }

final class GeneratedQrLoginChallenge {
  final String challengeToken;
  final String pollToken;
  final Uri qrUri;
  final DateTime expiresAt;

  const GeneratedQrLoginChallenge({
    required this.challengeToken,
    required this.pollToken,
    required this.qrUri,
    required this.expiresAt,
  });

  factory GeneratedQrLoginChallenge.fromJson(Map<String, dynamic> json) {
    final challengeToken =
        _capability(json['challengeToken'], 'challengeToken');
    final pollToken = _capability(json['pollToken'], 'pollToken');
    final qrUri = Uri.tryParse(json['qrUri'] as String? ?? '');
    final expiresAt = DateTime.tryParse(json['expiresAt'] as String? ?? '');
    if (qrUri == null || !qrUri.hasScheme || expiresAt == null) {
      throw const FenlengSdkException(
        'QR_LOGIN_RESPONSE_INVALID',
        'Invalid QR login challenge response',
      );
    }
    return GeneratedQrLoginChallenge(
      challengeToken: challengeToken,
      pollToken: pollToken,
      qrUri: qrUri,
      expiresAt: expiresAt,
    );
  }
}

final class QrLoginTransition {
  final QrLoginChallengeStatus status;
  const QrLoginTransition(this.status);

  factory QrLoginTransition.fromJson(Map<String, dynamic> json) {
    final status = _status(json['status']);
    if (status != QrLoginChallengeStatus.scanned &&
        status != QrLoginChallengeStatus.confirmed) {
      throw const FenlengSdkException(
        'QR_LOGIN_RESPONSE_INVALID',
        'Invalid QR login transition',
      );
    }
    return QrLoginTransition(status);
  }
}

final class QrLoginStatus {
  final QrLoginChallengeStatus status;
  final DateTime? expiresAt;
  final Map<String, dynamic>? tokens;

  const QrLoginStatus({
    required this.status,
    required this.expiresAt,
    required this.tokens,
  });

  factory QrLoginStatus.fromJson(Map<String, dynamic> json) {
    final rawTokens = json['tokens'];
    if (rawTokens != null && rawTokens is! Map<String, dynamic>) {
      throw const FenlengSdkException(
        'QR_LOGIN_RESPONSE_INVALID',
        'Invalid QR login token response',
      );
    }
    return QrLoginStatus(
      status: _status(json['status']),
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
      tokens: rawTokens as Map<String, dynamic>?,
    );
  }
}

String _capability(Object? value, String field) {
  if (value is String && RegExp(_capabilityPattern).hasMatch(value))
    return value;
  throw FenlengSdkException(
    'QR_LOGIN_RESPONSE_INVALID',
    'Invalid QR login $field',
  );
}

QrLoginChallengeStatus _status(Object? value) {
  switch (value) {
    case 'WAITING':
      return QrLoginChallengeStatus.waiting;
    case 'SCANNED':
      return QrLoginChallengeStatus.scanned;
    case 'CONFIRMED':
      return QrLoginChallengeStatus.confirmed;
    case 'EXPIRED':
      return QrLoginChallengeStatus.expired;
    default:
      throw const FenlengSdkException(
        'QR_LOGIN_RESPONSE_INVALID',
        'Unknown QR login status',
      );
  }
}
