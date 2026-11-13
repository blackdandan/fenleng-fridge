import 'dart:async';
import 'package:flutter/services.dart';
import '../application/notification_session.dart';

class MethodChannelNotifications implements LocalNotificationPlatform {
  final MethodChannel channel;
  final _taps = StreamController<String>.broadcast(sync: true);
  MethodChannelNotifications({
    this.channel = const MethodChannel('fenleng.fridge/notifications'),
  }) {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'openReminder') {
        final args = call.arguments;
        if (args is Map && _taps.hasListener) {
          try {
            final day = await consumeTap();
            if (day != null && !_taps.isClosed) _taps.add(day);
          } catch (_) {}
        }
      }
    });
  }
  @override
  Stream<String> get taps => _taps.stream;
  Future<NotificationStatus> _status(
    String method, [
    Object? arguments,
  ]) async => NotificationStatus.fromJson(
    Map<String, dynamic>.from(
      await channel.invokeMapMethod<String, dynamic>(method, arguments) ?? {},
    ),
  );
  @override
  Future<NotificationStatus> status() => _status('status');
  @override
  Future<NotificationStatus> request() => _status('request');
  @override
  Future<NotificationStatus> setEnabled(bool value) =>
      _status('enable', {'enabled': value});
  @override
  Future<void> sync(
    List<Map<String, Object>> cycles,
    Map<String, String> copy,
  ) async {
    if (await channel.invokeMethod<bool>('sync', {
          'cycles': cycles,
          'copy': copy,
        }) !=
        true) {
      throw StateError('NOTIFICATION_SYNC_FAILED');
    }
  }

  @override
  Future<String?> consumeTap() => channel.invokeMethod<String>('consumeTap');
  @override
  Future<void> openSettings() async {
    if (await channel.invokeMethod<bool>('settings') != true) {
      throw StateError('NOTIFICATION_SETTINGS_FAILED');
    }
  }

  @override
  Future<void> close() async {
    channel.setMethodCallHandler(null);
    await _taps.close();
  }
}
