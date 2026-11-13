import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:fridge_core/fridge_core.dart';
import 'product_event.dart';

class NotificationStatus {
  final bool enabled, authorized, requested, limited;
  const NotificationStatus({
    this.enabled = false,
    this.authorized = false,
    this.requested = false,
    this.limited = false,
  });
  factory NotificationStatus.fromJson(Map<String, dynamic> value) =>
      NotificationStatus(
        enabled: value['enabled'] == true,
        authorized: value['authorized'] == true,
        requested: value['requested'] == true,
        limited: value['limited'] == true,
      );
}

abstract interface class LocalNotificationPlatform {
  Stream<String> get taps;
  Future<NotificationStatus> status();
  Future<NotificationStatus> request();
  Future<NotificationStatus> setEnabled(bool value);
  Future<void> sync(List<Map<String, Object>> cycles, Map<String, String> copy);
  Future<String?> consumeTap();
  Future<void> openSettings();
  Future<void> close();
}

class NotificationSession extends ChangeNotifier {
  final InventoryRepository repository;
  final LocalNotificationPlatform platform;
  final bool Function() consent;
  final Map<String, String> Function() copy;
  final DateTime Function() clock;
  final ProductEvent? onEvent;
  NotificationStatus status = const NotificationStatus();
  String? errorKey, pendingDay;
  bool busy = false, _closed = false, _active = true, _queued = false;
  Future<void>? _tail;
  StreamSubscription<InventoryState>? _inventory;
  StreamSubscription<String>? _taps;
  Timer? _timer;
  NotificationSession({
    required this.repository,
    required this.platform,
    required this.consent,
    required this.copy,
    DateTime Function()? clock,
    this.onEvent,
  }) : clock = clock ?? DateTime.now;

  Future<void> start() async {
    if (_closed || _inventory != null || !consent()) return;
    _inventory = repository.changes.listen((_) {
      unawaited(synchronize());
      _scheduleClock();
    });
    _taps = platform.taps.listen(_tap);
    await synchronize();
    await _drainTap();
    _scheduleClock();
  }

  void _tap(String day) {
    if (_closed ||
        !consent() ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) {
      return;
    }
    pendingDay = day;
    _notify();
  }

  String? takeTap() {
    final day = pendingDay;
    pendingDay = null;
    return day;
  }

  Future<void> _drainTap() async {
    try {
      final day = await platform.consumeTap();
      if (day != null) _tap(day);
    } catch (_) {}
  }

  Future<void> _serialize(Future<void> Function() operation) {
    late final Future<void> result;
    result = (_tail ?? Future<void>.value())
        .then((_) async {
          if (_closed || !consent()) return;
          try {
            await operation();
            errorKey = null;
          } catch (_) {
            errorKey = 'notificationUnavailable';
          }
          _notify();
        })
        .whenComplete(() {
          if (identical(_tail, result)) _tail = null;
        });
    _tail = result;
    return result;
  }

  Future<void> synchronize() {
    if (_closed || _queued || !consent()) return _tail ?? Future.value();
    _queued = true;
    return _serialize(() async {
      _queued = false;
      status = await platform.status();
      await platform.sync(notificationPlan(repository.state), copy());
      status = await platform.status();
    }).whenComplete(() {
      _queued = false;
    });
  }

  Future<void> enable(Future<bool> Function() explain) async {
    if (busy || _closed || !consent()) return;
    busy = true;
    errorKey = null;
    _notify();
    await _serialize(() async {
      status = await platform.status();
      if (!status.authorized) {
        if (!await explain()) {
          _permissionEvent('cancelled');
          return;
        }
        if (_closed || !consent()) return;
        status = await platform.request();
        _permissionEvent(status.authorized ? 'granted' : 'denied');
      }
      if (_closed || !consent() || !status.authorized) return;
      status = await platform.setEnabled(true);
      await platform.sync(notificationPlan(repository.state), copy());
      status = await platform.status();
    });
    busy = false;
    _notify();
  }

  Future<void> disable() async {
    if (busy || _closed) return;
    busy = true;
    _notify();
    await _serialize(() async {
      status = await platform.setEnabled(false);
    });
    busy = false;
    _notify();
  }

  void _permissionEvent(String result) {
    if (!_closed && consent()) {
      emitProductEvent(onEvent, 'fridge.permission.resolved.v1', {
        'permission': 'notifications',
        'result': result,
      });
    }
  }

  Future<void> openSettings() => _serialize(platform.openSettings);
  void setActive(bool value) {
    _active = value;
    _timer?.cancel();
    if (value && !_closed && consent()) unawaited(refresh());
  }

  Future<void> refresh() async {
    if (_closed || !consent()) return;
    try {
      await repository.refreshDue();
      await synchronize();
      await _drainTap();
    } catch (_) {
      errorKey = 'error';
      _notify();
    }
    _scheduleClock();
  }

  void _scheduleClock() {
    _timer?.cancel();
    if (!_active || _closed || !consent()) return;
    var wait = const Duration(seconds: 30);
    final now = clock();
    for (final food in repository.state.active) {
      final delay = food.dueAt.difference(now);
      if (delay > Duration.zero && delay < wait) wait = delay;
    }
    _timer = Timer(wait, () => unawaited(refresh()));
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    await _inventory?.cancel();
    await _taps?.cancel();
    await _tail;
    await platform.close();
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }
}
