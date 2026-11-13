import 'dart:convert';
import 'client.dart';

class FlutterTelemetryContext {
  const FlutterTelemetryContext(
      {required this.platform,
      required this.appVersion,
      required this.buildNumber,
      required this.releaseChannel,
      required this.locale,
      this.sessionId});
  final String platform;
  final String appVersion;
  final String buildNumber;
  final String releaseChannel;
  final String locale;
  final String? sessionId;
  Map<String, dynamic> toJson() => {
        'platform': platform,
        'appVersion': appVersion,
        'buildNumber': buildNumber,
        'releaseChannel': releaseChannel,
        'locale': locale,
        if (sessionId != null) 'sessionId': sessionId
      };
}

class FlutterTelemetrySDK {
  FlutterTelemetrySDK(
      {required this.client,
      required this.hasConsent,
      required this.catalog,
      required this.context,
      this.maxQueueSize = 100,
      this.batchSize = 50}) {
    if (maxQueueSize < 1 ||
        maxQueueSize > 1000 ||
        batchSize < 1 ||
        batchSize > 50)
      throw const FenlengSdkException(
          'CONFIGURATION_INVALID', 'Telemetry queue settings are invalid');
  }
  final FenlengFlutterClient client;
  final bool Function() hasConsent;
  final Set<String> catalog;
  final FlutterTelemetryContext Function() context;
  final int maxQueueSize;
  final int batchSize;
  final List<Map<String, dynamic>> _events = [];
  int _consentGeneration = 0;
  Future<int>? _flushing;
  List<Map<String, dynamic>>? _pendingBatch;
  String? _pendingKey;
  int get pendingCount => _events.length;
  void track(String name, [Map<String, dynamic> properties = const {}]) {
    if (!hasConsent()) return;
    if (!catalog.contains(name))
      throw const FenlengSdkException(
          'TELEMETRY_EVENT_UNREGISTERED', 'Event is not registered');
    late Map<String, dynamic> snapshot;
    try {
      snapshot = jsonDecode(jsonEncode(properties)) as Map<String, dynamic>;
    } catch (_) {
      throw const FenlengSdkException('TELEMETRY_PROPERTIES_INVALID',
          'Telemetry properties must be JSON values');
    }
    _rejectSensitive(snapshot);
    final eventContext = context();
    _validateContext(eventContext);
    if (_events.length >= maxQueueSize) _events.removeAt(0);
    _events.add({
      'event': name,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'properties': snapshot,
      'context': eventContext.toJson()
    });
  }

  void withdrawConsent() {
    _consentGeneration++;
    _events.clear();
    _pendingBatch = null;
    _pendingKey = null;
  }

  Future<int> flush(String idempotencyKey) {
    if (_flushing != null) return _flushing!;
    if (!hasConsent() || (_events.isEmpty && _pendingBatch == null))
      return Future.value(0);
    final generation = _consentGeneration;
    if (_pendingBatch == null) {
      _pendingBatch = List<Map<String, dynamic>>.from(_events.take(batchSize));
      _pendingKey = idempotencyKey;
    }
    _flushing = _send(_pendingBatch!, generation, _pendingKey!)
        .whenComplete(() => _flushing = null);
    return _flushing!;
  }

  Future<int> _send(List<Map<String, dynamic>> batch, int generation,
      String idempotencyKey) async {
    final response = await client.request('/api/platform/v1/telemetry/events',
        method: 'POST',
        body: {'events': batch},
        idempotencyKey: idempotencyKey);
    if (generation != _consentGeneration) return 0;
    if (response['accepted'] is! int || response['accepted'] != batch.length)
      throw const FenlengSdkException(
          'TELEMETRY_RESPONSE_INVALID', 'Telemetry receipt was not confirmed');
    _events.removeWhere((event) => batch.any((sent) => identical(event, sent)));
    _pendingBatch = null;
    _pendingKey = null;
    return batch.length;
  }
}

void _validateContext(FlutterTelemetryContext value) {
  if (!const {'ios', 'android', 'ohos', 'web', 'mini-program'}
          .contains(value.platform) ||
      !const {'china', 'global', 'internal'}.contains(value.releaseChannel) ||
      value.appVersion.isEmpty ||
      value.buildNumber.isEmpty ||
      value.locale.isEmpty)
    throw const FenlengSdkException(
        'TELEMETRY_CONTEXT_INVALID', 'Telemetry context is invalid');
  if (value.appVersion.length > 32 ||
      value.buildNumber.length > 32 ||
      value.locale.length < 2 ||
      value.locale.length > 16)
    throw const FenlengSdkException(
        'TELEMETRY_CONTEXT_INVALID', 'Telemetry context is invalid');
}

void _rejectSensitive(Object? value) {
  if (value is List) {
    for (final item in value) {
      _rejectSensitive(item);
    }
    return;
  }
  if (value is! Map) return;
  for (final entry in value.entries) {
    if (RegExp(
            r'token|secret|password|authorization|credential|receipt|verification.?code|email',
            caseSensitive: false)
        .hasMatch(entry.key.toString()))
      throw const FenlengSdkException('TELEMETRY_SENSITIVE_FIELD_REJECTED',
          'Sensitive telemetry property is not allowed');
    _rejectSensitive(entry.value);
  }
}
