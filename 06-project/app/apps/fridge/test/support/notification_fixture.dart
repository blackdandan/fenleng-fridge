import 'dart:async';
import 'package:fridge/application/notification_session.dart';

class FakeNotifications implements LocalNotificationPlatform {
  final events = StreamController<String>.broadcast(sync: true);
  NotificationStatus current = const NotificationStatus();
  int reads = 0, requests = 0, syncs = 0, settings = 0;
  bool grant = true, fail = false;
  String? launch;
  Completer<void>? gate;
  List<Map<String, Object>> plan = [];
  Map<String, String> copy = {};
  void Function()? onSync;
  @override
  Stream<String> get taps => events.stream;
  @override
  Future<NotificationStatus> status() async {
    reads++;
    if (gate != null) await gate!.future;
    if (fail) throw StateError('private error');
    return current;
  }

  @override
  Future<NotificationStatus> request() async {
    requests++;
    return current = NotificationStatus(
      enabled: current.enabled,
      authorized: grant,
      requested: true,
    );
  }

  @override
  Future<NotificationStatus> setEnabled(bool value) async {
    if (fail) throw StateError('private error');
    return current = NotificationStatus(
      enabled: value,
      authorized: current.authorized,
      requested: current.requested,
    );
  }

  @override
  Future<void> sync(
    List<Map<String, Object>> value,
    Map<String, String> words,
  ) async {
    syncs++;
    plan = value;
    copy = words;
    onSync?.call();
  }

  @override
  Future<String?> consumeTap() async {
    final value = launch;
    launch = null;
    return value;
  }

  @override
  Future<void> openSettings() async {
    settings++;
  }

  @override
  Future<void> close() => events.close();
}
