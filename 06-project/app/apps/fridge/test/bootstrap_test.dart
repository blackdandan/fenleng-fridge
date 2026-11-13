import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/application/bootstrap.dart';
import 'package:fridge/main.dart';

class DeferredBootstrap extends FridgeBootstrap {
  @override
  Future<void> initialize() async {}
  Future<void> proceed() => super.initialize();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('fenleng.fridge/bootstrap');
  late Directory directory;
  late List<String> calls;
  late Map<String, dynamic> record;
  var acceptWrites = true;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fridge-bootstrap-test-');
    calls = [];
    record = {'locale': 'zh-CN'};
    acceptWrites = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(native, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'privacy.read':
              return record;
            case 'privacy.accept':
              if (acceptWrites) {
                record.addAll(Map<String, dynamic>.from(call.arguments as Map));
              }
              return acceptWrites;
            case 'plugins.initialize':
              return true;
            case 'data.directory':
              return directory.path;
            case 'legal.open':
              final args = Map<String, dynamic>.from(call.arguments as Map);
              expect(args['html'], contains('fenlengtech@163.com'));
              expect(args['html'], contains("default-src 'none'"));
              expect(args['html'], isNot(contains('<script')));
              return true;
          }
          throw PlatformException(code: 'UNEXPECTED_METHOD');
        });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(native, null);
    await directory.delete(recursive: true);
  });

  test('before consent no plugins or business files are opened', () async {
    final bootstrap = FridgeBootstrap();
    await bootstrap.initialize();
    expect(bootstrap.stage, BootstrapStage.consent);
    expect(calls, ['privacy.read']);
    expect(directory.listSync(), isEmpty);
    bootstrap.decline();
    expect(bootstrap.stage, BootstrapStage.declined);
    expect(calls, ['privacy.read']);
    bootstrap.dispose();
  });
  test('unaccepted channel never constructs online SDKs', () async {
    final bootstrap = FridgeBootstrap();
    try {
      await bootstrap.initialize();
      expect(bootstrap.onlineConsent, false);
      expect(bootstrap.identity, null);
      expect(bootstrap.feedback, null);
      expect(bootstrap.telemetry, null);
      expect(
        calls.contains('plugins.initialize'),
        FridgeBootstrap.channel == 'global',
      );
      expect(
        bootstrap.stage,
        FridgeBootstrap.channel == 'global'
            ? BootstrapStage.ready
            : BootstrapStage.consent,
      );
    } finally {
      await bootstrap.localReminders?.close();
      await bootstrap.inventory?.close();
      bootstrap.dispose();
    }
  });

  test(
    'persisted consent precedes one plugin bootstrap and inventory opening',
    () async {
      final bootstrap = FridgeBootstrap();
      await bootstrap.initialize();
      await Future.wait([bootstrap.accept(), bootstrap.accept()]);
      expect(bootstrap.stage, BootstrapStage.ready);
      expect(calls, [
        'privacy.read',
        'privacy.accept',
        'plugins.initialize',
        'data.directory',
      ]);
      expect(record['policyVersion'], 'V0.4');
      expect(bootstrap.inventory!.state.active, isEmpty);
      await bootstrap.inventory!.close();
      bootstrap.dispose();
    },
  );

  test(
    'consent write failure does not initialize plugins or erase inventory',
    () async {
      final bootstrap = FridgeBootstrap();
      await bootstrap.initialize();
      acceptWrites = false;
      await bootstrap.accept();
      expect(bootstrap.stage, BootstrapStage.error);
      expect(calls, ['privacy.read', 'privacy.accept']);
      expect(directory.listSync(), isEmpty);
      bootstrap.dispose();
    },
  );

  testWidgets(
    'first frame is neutral; offline WebView can open before business consent',
    (tester) async {
      final bootstrap = DeferredBootstrap();
      await tester.pumpWidget(FridgeApp(bootstrap: bootstrap));
      expect(find.text('同意并继续'), findsNothing);
      await tester.runAsync(bootstrap.proceed);
      await tester.pumpAndSettle();
      expect(find.text('同意并继续'), findsOneWidget);
      await tester.tap(find.text('用户协议'));
      await tester.pumpAndSettle();
      expect(calls, ['privacy.read', 'legal.open']);
      expect(find.text('同意并继续'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      bootstrap.dispose();
    },
  );
}
