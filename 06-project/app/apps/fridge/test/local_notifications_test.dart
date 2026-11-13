import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/infrastructure/local_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('fridge.test.notifications');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const codec = StandardMethodCodec();
  late MethodChannelNotifications platform;
  String? pending;
  var consumes = 0;
  var accepted = true;
  final calls = <MethodCall>[];
  setUp(() {
    pending = null;
    consumes = 0;
    accepted = true;
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'consumeTap') {
        consumes++;
        final value = pending;
        pending = null;
        return value;
      }
      if (call.method == 'status' ||
          call.method == 'request' ||
          call.method == 'enable') {
        return {
          'enabled': true,
          'authorized': false,
          'requested': true,
          'limited': true,
        };
      }
      return accepted;
    });
    platform = MethodChannelNotifications(channel: channel);
  });
  tearDown(() async {
    await platform.close();
    messenger.setMockMethodCallHandler(channel, null);
  });
  Future<void> hint() async {
    await messenger.handlePlatformMessage(
      channel.name,
      codec.encodeMethodCall(
        const MethodCall('openReminder', {'day': '2026-11-13'}),
      ),
      null,
    );
  }

  test(
    'native tap hints acknowledge the persisted value exactly once and keep cold hints until a listener exists',
    () async {
      pending = '2026-11-13';
      await hint();
      expect(consumes, 0);
      expect(pending, '2026-11-13');
      final values = <String>[];
      final subscription = platform.taps.listen(values.add);
      await hint();
      await hint();
      expect(values, ['2026-11-13']);
      expect(consumes, 2);
      expect(pending, isNull);
      await subscription.cancel();
    },
  );
  test(
    'real method codec carries plan and copy, status flags are separate, and failed native commit is not success',
    () async {
      final status = await platform.status();
      expect(status.enabled, true);
      expect(status.authorized, false);
      expect(status.requested, true);
      expect(status.limited, true);
      const cycles = [
        {
          'key': '["001",0]',
          'day': '2026-11-13',
          'hour': 17,
          'minute': 30,
          'second': 0,
          'millisecond': 0,
        },
      ];
      const copy = {
        'title': 'Check',
        'body': 'Due: {count}',
        'channel': 'Checks',
        'locale': 'en',
      };
      await platform.sync(cycles, copy);
      expect(calls.last.arguments, {'cycles': cycles, 'copy': copy});
      await platform.setEnabled(false);
      expect(calls.last.arguments, {'enabled': false});
      accepted = false;
      await expectLater(platform.sync(cycles, copy), throwsStateError);
      await expectLater(platform.openSettings(), throwsStateError);
    },
  );
}
