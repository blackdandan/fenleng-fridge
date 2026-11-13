import 'dart:async';
import 'dart:math';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';

/// Strict product enums wrap the sole official SDK collection/transport.
class ProductTelemetry {
  final bool enabled;
  final bool Function() consent;
  final Future<bool> Function() ensureSession;
  final Duration retryDelay, debounce;
  final Map<String, Map<String, Set<String>>> _catalog;
  late final FlutterTelemetrySDK sdk;
  Timer? _timer;
  Future<int>? _flushing;
  bool _closed = false, _foreground = true;
  int _epoch = 0;
  ProductTelemetry({
    required FenlengFlutterClient client,
    required Map<String, dynamic> catalog,
    required FlutterTelemetryContext Function() context,
    required this.consent,
    required this.ensureSession,
    required this.enabled,
    this.retryDelay = const Duration(milliseconds: 300),
    this.debounce = const Duration(seconds: 2),
  }) : _catalog = _readCatalog(catalog) {
    sdk = FlutterTelemetrySDK(
      client: client,
      hasConsent: () => !_closed && consent(),
      catalog: _catalog.keys.toSet(),
      context: context,
      maxQueueSize: 100,
      batchSize: 50,
    );
  }
  int get pendingCount => sdk.pendingCount;
  bool record(String name, [Map<String, String> properties = const {}]) {
    if (_closed || !consent()) return false;
    final allowed = _catalog[name];
    if (allowed == null ||
        properties.length != allowed.length ||
        properties.entries.any(
          (entry) => !(allowed[entry.key]?.contains(entry.value) ?? false),
        )) {
      return false;
    }
    try {
      sdk.track(name, properties);
    } catch (_) {
      return false;
    }
    _schedule();
    return true;
  }

  void _schedule() {
    if (!enabled || _closed || !_foreground || _timer != null || !consent()) {
      return;
    }
    _timer = Timer(debounce, () {
      _timer = null;
      unawaited(flush());
    });
  }

  Future<int> flush() {
    if (_flushing case final pending?) return pending;
    if (!enabled || _closed || !consent() || pendingCount == 0) {
      return Future.value(0);
    }
    final epoch = _epoch;
    _flushing = _drain(epoch).whenComplete(() {
      _flushing = null;
      if (epoch != _epoch && pendingCount > 0) _schedule();
    });
    return _flushing!;
  }

  Future<int> _drain(int epoch) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (_closed || !consent() || epoch != _epoch) return 0;
      try {
        if (!await ensureSession() ||
            _closed ||
            !consent() ||
            epoch != _epoch) {
          return 0;
        }
        final key =
            'fridge-telemetry-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}';
        final accepted = await sdk.flush(key);
        if (epoch == _epoch && pendingCount > 0) _schedule();
        return accepted;
      } catch (_) {
        if (attempt < 2) await Future<void>.delayed(retryDelay * (attempt + 1));
      }
    }
    // Remain bounded; a later user/lifecycle action can request recovery.
    return 0;
  }

  void resume() {
    _foreground = true;
    if (pendingCount > 0) _schedule();
  }

  Future<void> suspend() async {
    _foreground = false;
    _timer?.cancel();
    _timer = null;
    try {
      await flush().timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  void withdraw() {
    _epoch++;
    _timer?.cancel();
    _timer = null;
    sdk.withdrawConsent();
  }

  void close() {
    _closed = true;
    withdraw();
  }
}

Map<String, Map<String, Set<String>>> _readCatalog(Map<String, dynamic> input) {
  if (input['separateAnalyticsToggle'] != false ||
      input['consentSource'] != 'unified-privacy-v0.4') {
    throw const FormatException('TELEMETRY_CATALOG_INVALID');
  }
  final result = <String, Map<String, Set<String>>>{};
  for (final event in input['events'] as List) {
    final name = event['name'] as String;
    if (result.containsKey(name)) {
      throw const FormatException('TELEMETRY_CATALOG_INVALID');
    }
    result[name] = (event['properties'] as Map).map(
      (key, values) =>
          MapEntry(key as String, (values as List).cast<String>().toSet()),
    );
  }
  return result;
}
