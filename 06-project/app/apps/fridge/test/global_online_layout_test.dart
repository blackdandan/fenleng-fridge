import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/application/identity_session.dart';
import 'package:fridge/presentation/account_page.dart';
import 'package:fridge/presentation/account_deletion.dart';
import 'package:fridge/presentation/online_consent.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';
import 'account_layout_test.dart' show Backend, Authorization;
import 'support/presentation_fixture.dart';

void main() {
  testWidgets(
    '20 locales x2 themes x7 global consent/account states fit320 text2',
    (tester) async {
      pageSize(tester, width: 320, height: 940);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final messages = await pageMessages(tester);
      final session = IdentitySession(
        backend: Backend(),
        authorization: Authorization(),
        consent: () => true,
        configured: false,
      );
      for (final locale in messages.keys) {
        final strings = FridgeStrings.fromJson(messages, locale);
        for (final dark in [false, true]) {
          for (final state in [
            'unchecked',
            'checked',
            'busy',
            'error',
            'account',
            'account-error',
            'deletion',
          ]) {
            final hold = Completer<void>();
            session.errorKey = state == 'account-error'
                ? 'loginNotConfigured'
                : null;
            final Widget child = state.startsWith('account')
                ? AccountPage(
                    key: ValueKey(state),
                    session: session,
                    strings: strings,
                    china: false,
                    showApple: true,
                  )
                : state == 'deletion'
                ? AccountDeletionDialog(
                    key: ValueKey(state),
                    strings: strings,
                    china: false,
                    showApple: true,
                    initialProvider: IdentityProvider.google,
                    onProvider: (_) {},
                  )
                : OnlineConsentDialog(
                    key: ValueKey(state),
                    strings: strings,
                    onDocument: (_) {},
                    onAccept: () => state == 'error'
                        ? Future.error(StateError('synthetic write failure'))
                        : hold.future,
                  );
            await tester.pumpWidget(
              pageHost(
                strings,
                child,
                width: 320,
                height: 940,
                scale: 2,
                dark: dark,
              ),
            );
            await tester.pumpAndSettle();
            if (['checked', 'busy', 'error'].contains(state)) {
              final checkbox = find.byType(CheckboxListTile);
              await tester.ensureVisible(checkbox);
              await tester.tap(checkbox);
              await tester.pumpAndSettle();
            }
            if (['busy', 'error'].contains(state)) {
              final confirm = find.widgetWithText(
                FilledButton,
                strings.text('agree'),
              );
              await tester.ensureVisible(confirm);
              await tester.tap(confirm);
              await tester.pumpAndSettle();
            }
            expect(
              tester.takeException(),
              isNull,
              reason: '$locale/$dark/$state',
            );
            if (state == 'error') {
              expect(
                find.text(strings.text('onlineConsentFailed')),
                findsOneWidget,
              );
            }
            if (state.startsWith('account')) {
              expect(find.text(strings.text('googleLogin')), findsOneWidget);
              expect(find.text(strings.text('appleLogin')), findsOneWidget);
              expect(find.text(strings.text('wechatLogin')), findsNothing);
            }
            for (final element
                in find
                    .byWidgetPredicate((w) => w is ButtonStyleButton)
                    .evaluate()) {
              final finder = find.byElementPredicate(
                (e) => identical(e, element),
              );
              expect(
                tester.getSize(finder).height,
                greaterThanOrEqualTo(44),
                reason: '$locale/$dark/$state',
              );
            }
            if (!state.startsWith('account')) {
              final material = find
                  .descendant(
                    of: find.byType(Dialog),
                    matching: find.byType(Material),
                  )
                  .first;
              final rect = tester.getRect(material);
              expect(rect.left, greaterThanOrEqualTo(16));
              expect(rect.right, lessThanOrEqualTo(304));
              expect(rect.top, greaterThanOrEqualTo(16));
              expect(rect.bottom, lessThanOrEqualTo(924));
            }
            await tester.pumpWidget(const SizedBox.shrink());
            if (!hold.isCompleted) hold.complete();
            await tester.pump();
          }
        }
      }
      await session.close();
      session.dispose();
    },
  );
}
