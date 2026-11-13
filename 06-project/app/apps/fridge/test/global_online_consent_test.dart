import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/application/bootstrap.dart';
import 'package:fridge/main.dart';
import 'package:fridge/presentation/account_page.dart';
import 'package:fridge/presentation/online_consent.dart';
import 'support/presentation_fixture.dart';

class DeferredGlobalBootstrap extends FridgeBootstrap {
  @override
  Future<void> initialize() async {}
  Future<void> proceed() => super.initialize();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('fenleng.fridge/bootstrap');
  const notifications = MethodChannel('fenleng.fridge/notifications');
  late Directory directory;
  late DeferredGlobalBootstrap bootstrap;
  late Map<String, Object?> record;
  late List<String> calls;
  var writes = true;
  final global = FridgeBootstrap.channel == 'global';
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fridge-global-consent-');
    record = {'locale': 'en'};
    calls = [];
    writes = true;
    bootstrap = DeferredGlobalBootstrap();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, (call) async {
          return switch (call.method) {
            'status' => {'enabled': false, 'authorized': false},
            'sync' => true,
            'consumeTap' => null,
            _ => throw PlatformException(code: 'UNEXPECTED_NOTIFICATION_CALL'),
          };
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(native, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'privacy.read':
              return record;
            case 'plugins.initialize':
              expect((call.arguments as Map)['releaseChannel'], 'global');
              return true;
            case 'data.directory':
            case 'privacy.directory':
              return directory.path;
            case 'privacy.accept':
              if (writes) {
                record.addAll(Map<String, Object?>.from(call.arguments as Map));
              }
              return writes;
            case 'legal.open':
              expect(
                (call.arguments as Map)['html'],
                contains('fenlengtech@163.com'),
              );
              return true;
            case 'privacy.revoke':
              record.remove('policyVersion');
              record.remove('releaseChannel');
              record.remove('acceptedAt');
              record['withdrawalPending'] = true;
              return true;
            case 'privacy.finishRevoke':
              record.remove('withdrawalPending');
              return true;
          }
          throw PlatformException(code: 'UNEXPECTED_NATIVE_CALL');
        });
  });
  tearDown(() async {
    await bootstrap.localReminders?.close();
    await bootstrap.inventory?.close();
    await bootstrap.deletion?.close();
    await bootstrap.identity?.close();
    bootstrap.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(native, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, null);
    expect(
      directory.parent.resolveSymbolicLinksSync(),
      Directory.systemTemp.resolveSymbolicLinksSync(),
    );
    expect(
      directory.uri.pathSegments.where((p) => p.isNotEmpty).last,
      startsWith('fridge-global-consent-'),
    );
    await directory.delete(recursive: true);
  });
  Future<void> mount(WidgetTester tester) async {
    pageSize(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(FridgeApp(bootstrap: bootstrap));
    // First asynchronous launch frame cannot flash the China agreement gate.
    expect(find.byType(OnlineConsentDialog), findsNothing);
    expect(find.text('Agree and continue'), findsNothing);
    await tester.runAsync(bootstrap.proceed);
    await tester.pumpAndSettle();
  }

  Future<void> account(WidgetTester tester) async {
    await tester.tap(find.byTooltip(bootstrap.strings!.text('settings')));
    await tester.pumpAndSettle();
    final entry = find.byKey(const ValueKey('settings-account'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(OnlineConsentDialog), findsOneWidget);
  }

  Future<void> accept(WidgetTester tester) async {
    final checkbox = find.byType(CheckboxListTile);
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    final button = find.widgetWithText(
      FilledButton,
      bootstrap.strings!.text('agree'),
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> drain(WidgetTester tester, bool Function() ready) async {
    for (var i = 0; i < 80 && !ready(); i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(ready(), isTrue);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'first and settled global home have no agreement gate or online SDKs',
    (tester) async {
      await mount(tester);
      expect(bootstrap.stage, BootstrapStage.ready);
      expect(bootstrap.onlineConsent, isFalse);
      expect(find.text(bootstrap.strings!.text('consentTitle')), findsNothing);
      expect(find.text(bootstrap.strings!.text('terms')), findsNothing);
      expect(find.text(bootstrap.strings!.text('privacy')), findsNothing);
      expect(bootstrap.identity, isNull);
      expect(bootstrap.feedback, isNull);
      expect(bootstrap.telemetry, isNull);
      expect(calls, ['privacy.read', 'plugins.initialize', 'data.directory']);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !global,
  );
  testWidgets(
    'account feature asks unchecked consent; legal read and cancel start no online SDK',
    (tester) async {
      await mount(tester);
      await account(tester);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(
                FilledButton,
                bootstrap.strings!.text('agree'),
              ),
            )
            .onPressed,
        isNull,
      );
      final terms = find.widgetWithText(
        TextButton,
        bootstrap.strings!.text('terms'),
      );
      await tester.ensureVisible(terms);
      await tester.tap(terms);
      await tester.pumpAndSettle();
      expect(calls, contains('legal.open'));
      expect(bootstrap.identity, isNull);
      final cancel = find.widgetWithText(
        TextButton,
        bootstrap.strings!.text('cancel'),
      );
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.byType(OnlineConsentDialog), findsNothing);
      expect(bootstrap.onlineConsent, isFalse);
      expect(calls, isNot(contains('privacy.accept')));
      expect(bootstrap.identity, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !global,
  );
  testWidgets(
    'failed save stays in dialog; retry persists global consent before account and missing config stays truthful',
    (tester) async {
      writes = false;
      await mount(tester);
      await account(tester);
      await accept(tester);
      expect(
        find.text(bootstrap.strings!.text('onlineConsentFailed')),
        findsOneWidget,
      );
      expect(bootstrap.onlineConsent, isFalse);
      expect(bootstrap.identity, isNull);
      writes = true;
      final again = find.widgetWithText(
        FilledButton,
        bootstrap.strings!.text('agree'),
      );
      await tester.ensureVisible(again);
      await tester.tap(again);
      await drain(
        tester,
        () =>
            find.byType(AccountPage).evaluate().isNotEmpty &&
            bootstrap.deletion?.initialized == true &&
            bootstrap.identity?.busy == false,
      );
      expect(record['releaseChannel'], 'global');
      expect(record['policyVersion'], 'V0.4');
      expect(bootstrap.onlineConsent, isTrue);
      expect(bootstrap.identity, isNotNull);
      expect(bootstrap.telemetry, isNotNull);
      expect(find.text(bootstrap.strings!.text('wechatLogin')), findsNothing);
      final google = find.widgetWithText(
        FilledButton,
        bootstrap.strings!.text('googleLogin'),
      );
      await tester.tap(google);
      await tester.pumpAndSettle();
      expect(bootstrap.identity!.signedIn, isFalse);
      expect(
        find.text(bootstrap.strings!.text('loginNotConfigured')),
        findsOneWidget,
      );
      expect(calls, isNot(contains('plugins.initializeOnline')));
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !global,
  );
}
