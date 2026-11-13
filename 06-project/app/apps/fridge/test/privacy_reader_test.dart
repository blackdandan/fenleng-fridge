import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/application/bootstrap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('fenleng.fridge/bootstrap');
  late Directory directory;
  late FridgeBootstrap bootstrap;
  late List<Map<dynamic, dynamic>> readers;
  Completer<Object>? result;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fridge-reader-');
    readers = [];
    result = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(native, (call) async {
          switch (call.method) {
            case 'privacy.read':
              return {'locale': 'ar', 'appearance': 'light'};
            case 'privacy.accept':
            case 'plugins.initialize':
              return true;
            case 'data.directory':
              return directory.path;
            case 'legal.open':
              readers.add(call.arguments as Map);
              return result == null ? true : result!.future;
          }
          throw PlatformException(code: 'UNEXPECTED_METHOD');
        });
    bootstrap = FridgeBootstrap();
    await bootstrap.initialize();
  });
  tearDown(() async {
    await bootstrap.localReminders?.close();
    await bootstrap.inventory?.close();
    bootstrap.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(native, null);
    await directory.delete(recursive: true);
  });
  test('offline legal before consent has no withdrawal action', () async {
    result = Completer<Object>()..complete('withdraw');
    expect(await bootstrap.openLegal('privacy'), false);
    final args = readers.single;
    expect(args['withdrawalEnabled'], 'false');
    expect(args['html'], isNot(contains('fridge://privacy/withdraw')));
    expect(args['html'], contains("default-src 'none'"));
    expect(args['html'], isNot(contains('<script')));
  });
  test(
    'privacy alone returns withdrawal, duplicate reader is suppressed',
    () async {
      await bootstrap.accept();
      result = Completer<Object>();
      final opening = bootstrap.openLegal('privacy');
      await Future<void>.delayed(Duration.zero);
      expect(await bootstrap.openLegal('privacy'), false);
      expect(readers, hasLength(1));
      final args = readers.single;
      expect(args['withdrawalEnabled'], 'true');
      expect(args['html'], contains('lang="ar" dir="auto"'));
      expect(args['html'], contains('@media not all'));
      result!.complete('withdraw');
      expect(await opening, true);
      expect(bootstrap.onlineConsent, true);
      result = Completer<Object>()..complete('withdraw');
      expect(await bootstrap.openLegal('terms'), false);
      expect(readers.last['withdrawalEnabled'], 'false');
    },
  );
  test('normal back and invalid result release the reader lock', () async {
    await bootstrap.accept();
    expect(await bootstrap.openLegal('privacy'), false);
    result = Completer<Object>()..complete(false);
    await expectLater(bootstrap.openLegal('privacy'), throwsStateError);
    result = null;
    expect(await bootstrap.openLegal('privacy'), false);
    expect(readers, hasLength(3));
  });
}
