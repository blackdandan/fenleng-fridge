import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge_settings/fridge_settings.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';
import 'support/presentation_fixture.dart';

SettingsScreen settings(
  FridgeStrings strings, {
  Future<void> Function(Map<StorageZone, int>, int, int)? save,
  ValueChanged<String>? legal,
  VoidCallback? feedback,
}) => SettingsScreen(
  state: pageInventory(),
  strings: strings,
  appearance: DisplayAppearance.system,
  languageLabel: strings.text('system'),
  onSaveDefaults: save ?? (_, _, _) async {},
  onHistory: () {},
  onLanguage: () {},
  onAppearance: () {},
  onAccount: () {},
  onFeedback: feedback ?? () {},
  onFiling: () {},
  onLegal: legal ?? (_) {},
);

void main() {
  testWidgets(
    'defaults use source-sized original icons/fields; validation, 24h picker and save are serialized',
    (tester) async {
      pageSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = FridgeStrings.fromJson(
        await pageMessages(tester),
        'zh-CN',
      );
      var calls = 0;
      Map<StorageZone, int>? values;
      int? hour, minute;
      final gate = Completer<void>();
      await tester.pumpWidget(
        pageHost(
          strings,
          settings(
            strings,
            save: (map, h, m) {
              calls++;
              values = map;
              hour = h;
              minute = m;
              return gate.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(SettingsScreen),
        matchesGoldenFile('goldens/settings-430.png'),
      );
      expect(find.byType(TextField), findsNWidgets(3));
      expect(
        tester.getSize(
          find.byKey(const ValueKey('settings-number-surface-cold')),
        ),
        const Size(76, 35.6),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('settings-time-surface')))
            .height,
        closeTo(38.2, .001),
      );
      expect(find.byType(FridgeIcon), findsNWidgets(5));
      await tester.enterText(
        find.byKey(const ValueKey('settings-default-cold')),
        '0',
      );
      await tester.tap(find.byKey(const ValueKey('settings-save')));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text(strings.text('invalidInterval')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('settings-default-cold')),
        '٧',
      );
      await tester.tap(find.byKey(const ValueKey('settings-time')));
      await tester.pumpAndSettle();
      final picker = find.byType(TimePickerDialog);
      final fields = find.descendant(
        of: picker,
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), '09');
      await tester.enterText(fields.at(1), '15');
      await tester.tap(
        find.text(
          MaterialLocalizations.of(tester.element(picker)).okButtonLabel,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-save')));
      await tester.tap(find.byKey(const ValueKey('settings-save')));
      await tester.pump();
      expect(calls, 1);
      expect(values, {
        StorageZone.cold: 7,
        StorageZone.frozen: 14,
        StorageZone.pantry: 3,
      });
      expect([hour, minute], [9, 15]);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text(strings.text('saved')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'bottom legal and feedback actions remain reachable; filing is subtle and choices recover from failures',
    (tester) async {
      pageSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = FridgeStrings.fromJson(
        await pageMessages(tester),
        'zh-CN',
      );
      String? opened;
      var feedback = 0;
      await tester.pumpWidget(
        pageHost(
          strings,
          settings(
            strings,
            legal: (key) => opened = key,
            feedback: () => feedback++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('settings-privacy')),
      );
      await tester.tap(find.byKey(const ValueKey('settings-privacy')));
      expect(opened, 'privacy');
      await tester.ensureVisible(
        find.byKey(const ValueKey('settings-feedback')),
      );
      await tester.tap(find.byKey(const ValueKey('settings-feedback')));
      expect(feedback, 1);
      await tester.ensureVisible(find.byKey(const ValueKey('settings-filing')));
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('settings-filing')))
            .style!
            .textStyle!
            .resolve({})!
            .fontSize,
        10,
      );
      var attempts = 0;
      await tester.pumpWidget(
        pageHost(
          strings,
          SettingsChoices(
            title: strings.text('appearance'),
            selected: 'system',
            strings: strings,
            choices: [
              for (final value in ['system', 'light', 'dark'])
                SettingsChoice(value, strings.text(value)),
            ],
            onSelect: (_) async {
              if (++attempts == 1) throw StateError('private error');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.text('dark')));
      await tester.pumpAndSettle();
      expect(find.text(strings.text('error')), findsOneWidget);
      expect(find.text('private error'), findsNothing);
      await tester.tap(find.text(strings.text('dark')));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'feedback draft/error/receipt preserve design geometry and visual baseline',
    (tester) async {
      pageSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = FridgeStrings.fromJson(
        await pageMessages(tester),
        'zh-CN',
      );
      for (final state in ['draft', 'error', 'receipt']) {
        await tester.pumpWidget(
          pageHost(
            strings,
            FeedbackScreen(
              key: ValueKey(state),
              strings: strings,
              draft: state == 'error' ? 'test feedback' : '',
              loading: false,
              initialized: true,
              busy: false,
              receipt: state == 'receipt' ? 'accepted-test-receipt-123' : null,
              errorKey: state == 'error' ? 'feedbackFailed' : null,
              onChanged: (_) {},
              onSubmit: () {},
              onRetryLoad: () {},
              onWriteAnother: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (state != 'receipt') {
          expect(
            tester.getSize(
              find.byKey(const ValueKey('feedback-input-surface')),
            ),
            const Size(382, 204.8),
          );
          expect(
            tester
                .getSize(find.byKey(const ValueKey('feedback-submit')))
                .height,
            44,
          );
        }
        await expectLater(
          find.byType(FeedbackScreen),
          matchesGoldenFile('goldens/feedback-$state-430.png'),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'settings and feedback default/error/receipt fit 20 locales and two themes at320 with large text',
    (tester) async {
      pageSize(tester, width: 320, height: 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final messages = await pageMessages(tester);
      for (final locale in messages.keys) {
        final strings = FridgeStrings.fromJson(messages, locale);
        for (final dark in [false, true]) {
          await tester.pumpWidget(
            pageHost(
              strings,
              settings(strings),
              width: 320,
              height: 800,
              scale: 2,
              dark: dark,
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.byKey(const ValueKey('settings-filing')),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'settings $locale $dark',
          );
          for (final state in ['draft', 'error', 'receipt']) {
            await tester.pumpWidget(
              pageHost(
                strings,
                FeedbackScreen(
                  key: ValueKey('$state-$locale-$dark'),
                  strings: strings,
                  draft: state == 'draft' ? '' : 'test feedback',
                  loading: false,
                  initialized: true,
                  busy: false,
                  receipt: state == 'receipt'
                      ? 'accepted-server-receipt-123'
                      : null,
                  errorKey: state == 'error' ? 'feedbackFailed' : null,
                  onChanged: (_) {},
                  onSubmit: () {},
                  onRetryLoad: () {},
                  onWriteAnother: () {},
                ),
                width: 320,
                height: 800,
                scale: 2,
                dark: dark,
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'feedback $state $locale $dark',
            );
          }
        }
      }
    },
  );
}
