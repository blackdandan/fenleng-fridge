import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/presentation/camera_rationale.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';
import 'support/presentation_fixture.dart';

void main() {
  testWidgets(
    'camera explanation fits narrow large text in all locales and themes',
    (tester) async {
      final messages = await pageMessages(tester);
      pageSize(tester, width: 320, height: 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final locale in messages.keys) {
        final strings = FridgeStrings.fromJson(messages, locale);
        for (final dark in [false, true]) {
          await tester.pumpWidget(
            pageHost(
              strings,
              Builder(
                builder: (context) => TextButton(
                  onPressed: () => showCameraRationale(context, strings),
                  child: const Text('open-test-dialog'),
                ),
              ),
              width: 320,
              height: 640,
              scale: 2,
              dark: dark,
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('open-test-dialog'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$locale/$dark');
          final box = tester.getRect(
            find
                .descendant(
                  of: find.byType(Dialog),
                  matching: find.byType(Material),
                )
                .first,
          );
          expect(box.left, greaterThanOrEqualTo(16));
          expect(box.right, lessThanOrEqualTo(304));
          expect(box.top, closeTo(16, 1));
          final close = find
              .ancestor(of: find.text('×'), matching: find.byType(TextButton))
              .first;
          expect(tester.getSize(close).shortestSide, greaterThanOrEqualTo(44));
          expect(
            tester.getSemantics(close).label,
            contains(
              MaterialLocalizations.of(
                tester.element(find.byType(Dialog)),
              ).closeButtonTooltip,
            ),
          );
          await tester.ensureVisible(find.text(strings.text('notNow')));
          expect(tester.takeException(), isNull);
          await tester.tap(find.text(strings.text('notNow')));
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsNothing);
        }
      }
    },
  );

  testWidgets(
    'close cancels while library and continue preserve distinct permission intent',
    (tester) async {
      final strings = FridgeStrings.fromJson(await pageMessages(tester), 'en');
      pageSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final choice in ['close', 'notNow', 'album', 'continueRequest']) {
        CameraRationaleChoice? result;
        await tester.pumpWidget(
          pageHost(
            strings,
            Builder(
              key: ValueKey(choice),
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showCameraRationale(context, strings);
                },
                child: const Text('open-test-dialog'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('open-test-dialog'));
        await tester.pumpAndSettle();
        final target = choice == 'close'
            ? find.bySemanticsLabel('Close')
            : find.text(strings.text(choice));
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(result, switch (choice) {
          'continueRequest' => CameraRationaleChoice.request,
          'album' => CameraRationaleChoice.album,
          _ => CameraRationaleChoice.cancel,
        });
        expect(find.byType(Dialog), findsNothing);
      }
    },
  );
}
