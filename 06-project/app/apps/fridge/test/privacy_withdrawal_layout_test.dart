import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/presentation/privacy_withdrawal.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';
import 'support/presentation_fixture.dart';

void main() {
  testWidgets(
    'withdrawal dialog and retry support all locales and large text',
    (tester) async {
      final messages = await pageMessages(tester);
      pageSize(tester, width: 320, height: 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final locale in messages.keys) {
        final strings = FridgeStrings.fromJson(messages, locale);
        for (final dark in [false, true]) {
          await tester.pumpWidget(
            pageHost(
              strings,
              PrivacyWithdrawalDialog(strings: strings),
              width: 320,
              height: 640,
              scale: 2,
              dark: dark,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$locale/$dark/dialog',
          );
          final rect = tester.getRect(
            find
                .descendant(
                  of: find.byType(Dialog),
                  matching: find.byType(Material),
                )
                .last,
          );
          expect(rect.left, greaterThanOrEqualTo(16));
          expect(rect.right, lessThanOrEqualTo(304));
          await tester.ensureVisible(find.text(strings.text('cancel')));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(
            pageHost(
              strings,
              PrivacyWithdrawalError(
                strings: strings,
                onRetry: () {},
                onDocument: (_) {},
              ),
              width: 320,
              height: 640,
              scale: 2,
              dark: dark,
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text(strings.text('privacy')).last);
          expect(tester.takeException(), isNull, reason: '$locale/$dark/retry');
        }
      }
    },
  );
  testWidgets('tablet dialog content remains limited to 520 pixels', (
    tester,
  ) async {
    final messages = await pageMessages(tester);
    final strings = FridgeStrings.fromJson(messages, 'zh-CN');
    pageSize(tester, width: 1024, height: 1366);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      pageHost(
        strings,
        PrivacyWithdrawalDialog(strings: strings),
        width: 1024,
        height: 1366,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(FilledButton)).width,
      lessThanOrEqualTo(520),
    );
    expect(tester.takeException(), isNull);
  });
}
