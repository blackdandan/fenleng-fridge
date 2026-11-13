import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/main.dart';
import 'package:fridge/application/feedback_session.dart';
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge_settings/fridge_settings.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';
import 'support/presentation_fixture.dart';
import 'support/runtime_fixture.dart';
import 'support/feedback_fixture.dart';

void main() {
  testWidgets(
    'actual App settings persist defaults/theme/language and retain feedback across leave, retry and receipt',
    (tester) async {
      pageSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      tester.platformDispatcher.localeTestValue = const Locale('zh', 'CN');
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      final messages = await pageMessages(tester);
      final zh = FridgeStrings.fromJson(messages, 'zh-CN');
      final en = zh.withLocale('en');
      final repository = InventoryRepository(
        MemoryStorage(pageInventory(count: 2)),
      );
      await repository.open();
      final bootstrap = ReadyBootstrap(repository, zh);
      final draft = DraftMemory();
      final sender = FeedbackSender()
        ..send = (_, _) async => throw StateError('offline');
      final feedback = FeedbackSession(
        storage: draft,
        gateway: sender,
        consent: () => true,
        nextKey: () => 'stable-route-feedback-key',
      );
      bootstrap.feedback = feedback;
      final preferences = <String, Object?>{};
      var writeAllowed = false;
      var filingOpened = 0;
      const native = MethodChannel('fenleng.fridge/bootstrap');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(native, (call) async {
            if (call.method == 'filing.open') {
              filingOpened++;
              return true;
            }
            if (!writeAllowed) return false;
            final key = call.method == 'display.locale'
                ? 'locale'
                : 'appearance';
            preferences[key] = (call.arguments as Map)[key];
            return true;
          });
      Future<void> openSetting(String key) async {
        final finder = find.byKey(ValueKey('settings-$key'));
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      try {
        await tester.pumpWidget(
          FridgeApp(bootstrap: bootstrap, photoLoader: (_) => testPhoto),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(zh.text('settings')));
        await tester.pumpAndSettle();
        final original = repository.state.foods.map(
          (k, v) => MapEntry(k, v.toJson()),
        );
        await tester.enterText(
          find.byKey(const ValueKey('settings-default-cold')),
          '7',
        );
        await tester.tap(find.byKey(const ValueKey('settings-save')));
        await tester.pumpAndSettle();
        expect(repository.state.defaults[StorageZone.cold], 7);
        expect(
          repository.state.foods.map((k, v) => MapEntry(k, v.toJson())),
          original,
        );
        await openSetting('appearance');
        await tester.tap(find.text(zh.text('light')));
        await tester.pumpAndSettle();
        expect(find.text(zh.text('error')), findsOneWidget);
        expect(bootstrap.appearance, DisplayAppearance.system);
        writeAllowed = true;
        await tester.tap(find.text(zh.text('light')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
          ThemeMode.light,
        );
        expect(
          Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
          Brightness.light,
        );
        expect(preferences['appearance'], 'light');
        await openSetting('appearance');
        await tester.tap(find.text(zh.text('dark')));
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
          Brightness.dark,
        );
        await openSetting('appearance');
        await tester.tap(find.text(zh.text('system')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
          ThemeMode.system,
        );
        expect(
          Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
          Brightness.dark,
        );
        await openSetting('language');
        await tester.tap(find.text(en.text('_localeName')));
        await tester.pumpAndSettle();
        expect(bootstrap.localePreference, 'en');
        expect(preferences['locale'], 'en');
        expect(find.text(en.text('settings')), findsOneWidget);
        await openSetting('feedback');
        await tester.enterText(
          find.byKey(const ValueKey('feedback-message')),
          'Useful feedback',
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('feedback-submit')),
        );
        await tester.tap(find.byKey(const ValueKey('feedback-submit')));
        await tester.pumpAndSettle();
        expect(feedback.errorKey, 'feedbackFailed');
        expect(draft.value.text, 'Useful feedback');
        expect(draft.value.key, 'stable-route-feedback-key');
        await tester.tap(find.byTooltip(en.text('back')));
        await tester.pumpAndSettle();
        await openSetting('feedback');
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('feedback-message')))
              .controller!
              .text,
          'Useful feedback',
        );
        sender.send = (_, _) async => 'server-route-receipt';
        await tester.ensureVisible(
          find.byKey(const ValueKey('feedback-submit')),
        );
        await tester.tap(find.byKey(const ValueKey('feedback-submit')));
        await tester.pumpAndSettle();
        expect(find.text(en.text('feedbackAccepted')), findsOneWidget);
        expect(
          find.text(
            en.format('feedbackReceipt', {'id': 'server-route-receipt'}),
          ),
          findsOneWidget,
        );
        expect(sender.calls.map((c) => c.key), [
          'stable-route-feedback-key',
          'stable-route-feedback-key',
        ]);
        expect(draft.value.text, '');
        await tester.tap(find.text(en.text('feedbackWriteAnother')));
        await tester.pumpAndSettle();
        expect(feedback.receipt, isNull);
        await tester.tap(find.byTooltip(en.text('back')));
        await tester.pumpAndSettle();
        await openSetting('filing');
        expect(filingOpened, 1);
        await openSetting('language');
        await tester.tap(find.text(en.text('system')));
        await tester.pumpAndSettle();
        expect(bootstrap.localePreference, isNull);
        expect(bootstrap.strings!.locale, 'zh-CN');
        expect(preferences['locale'], isNull);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        final feedbackClosing = feedback.close();
        await tester.pump();
        await feedbackClosing;
        final closing = repository.close();
        await tester.pump();
        await closing;
        bootstrap.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(native, null);
      }
    },
  );
}
