import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_settings/fridge_settings.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';
import 'support/presentation_fixture.dart';

void main() {
  testWidgets('large consent keeps16 margin inside real system insets', (
    tester,
  ) async {
    final strings = FridgeStrings.fromJson(await pageMessages(tester), 'en');
    pageSize(tester, width: 320, height: 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      pageHost(
        strings,
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            padding: EdgeInsets.only(top: 32, bottom: 24),
            textScaler: TextScaler.linear(2),
          ),
          child: ConsentScreen(
            strings: strings,
            declined: false,
            onAccept: () {},
            onDecline: () {},
            onReconsider: () {},
            onDocument: (_) {},
          ),
        ),
        width: 320,
        height: 640,
        scale: 2,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final rect = tester.getRect(
      find
          .descendant(of: find.byType(Dialog), matching: find.byType(Material))
          .first,
    );
    expect(rect.top, greaterThanOrEqualTo(48));
    expect(rect.bottom, lessThanOrEqualTo(600));
    await tester.ensureVisible(find.text(strings.text('decline')));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'first consent and declined states support20 locales themes and narrow large text',
    (tester) async {
      final messages = await pageMessages(tester);
      pageSize(tester, width: 320, height: 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final locale in messages.keys) {
        final strings = FridgeStrings.fromJson(messages, locale);
        for (final dark in [false, true]) {
          for (final declined in [false, true]) {
            var accepted = 0;
            await tester.pumpWidget(
              pageHost(
                strings,
                ConsentScreen(
                  key: ValueKey(declined),
                  strings: strings,
                  declined: declined,
                  onAccept: () => accepted++,
                  onDecline: () {},
                  onReconsider: () {},
                  onDocument: (_) {},
                ),
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
              reason: '$locale/$dark/$declined',
            );
            expect(accepted, 0);
            expect(
              find.text(strings.text('consentPermissionNotice')),
              findsOneWidget,
            );
            final rect = tester.getRect(
              find
                  .descendant(
                    of: find.byType(Dialog),
                    matching: find.byType(Material),
                  )
                  .first,
            );
            expect(rect.left, greaterThanOrEqualTo(16));
            expect(rect.right, lessThanOrEqualTo(304));
            expect(rect.top, greaterThanOrEqualTo(16));
            expect(rect.bottom, lessThanOrEqualTo(624));
            final button = find.text(
              strings.text(declined ? 'retry' : 'agree'),
            );
            await tester.ensureVisible(button);
            expect(tester.takeException(), isNull);
            if (!declined) {
              await tester.tap(button);
              expect(accepted, 1);
            }
          }
        }
      }
    },
  );

  testWidgets(
    'document reads and refusal never imply acceptance, and reconsider is distinct',
    (tester) async {
      final strings = FridgeStrings.fromJson(await pageMessages(tester), 'en');
      pageSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var accepted = 0, declined = 0, reconsidered = 0;
      final documents = <String>[];
      Widget screen(bool refusal) => pageHost(
        strings,
        ConsentScreen(
          key: ValueKey(refusal),
          strings: strings,
          declined: refusal,
          onAccept: () => accepted++,
          onDecline: () => declined++,
          onReconsider: () => reconsidered++,
          onDocument: documents.add,
        ),
      );
      await tester.pumpWidget(screen(false));
      await tester.pumpAndSettle();
      for (final key in ['terms', 'privacy', 'decline']) {
        final label = find.text(strings.text(key));
        await tester.ensureVisible(label);
        await tester.tap(label);
      }
      expect(documents, ['terms', 'privacy']);
      expect(accepted, 0);
      expect(declined, 1);
      await tester.pumpWidget(screen(true));
      await tester.pumpAndSettle();
      expect(find.text(strings.text('agree')), findsNothing);
      await tester.tap(find.text(strings.text('retry')));
      expect(reconsidered, 1);
      expect(accepted, 0);
    },
  );
}
