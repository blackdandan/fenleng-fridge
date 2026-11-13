import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/application/account_deletion.dart';
import 'package:fridge/application/identity_session.dart';
import 'package:fridge/presentation/account_deletion.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';
import 'support/deletion_fixture.dart';
import 'support/presentation_fixture.dart';

void main() {
  testWidgets(
    '20 locales x2 themes x10 deletion states fit320 at text scale2 with16px dialog margins',
    (tester) async {
      pageSize(tester, width: 320, height: 940);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final messages = await pageMessages(tester), h = DeletionHarness();
      const receipt = DeletionReceipt(
        'request-one',
        '2030-01-01T00:00:00Z',
        '2030-01-08T00:00:00Z',
      );
      const states = [
        'loading',
        'guest',
        'ready',
        'confirm',
        'busy',
        'accepted',
        'unsaved',
        'cleanup',
        'unknown',
        'restored',
      ];
      for (final locale in messages.keys) {
        final strings = FridgeStrings.fromJson(messages, locale);
        for (final dark in [false, true]) {
          for (final state in states) {
            final model = h.model;
            model.loading = state == 'loading';
            model.initialized = state != 'loading';
            model.busy = state == 'busy';
            model.durable = state != 'unsaved';
            model.cleanupPending = state == 'cleanup';
            model.errorKey = state == 'unsaved'
                ? 'deletionStorageFailed'
                : state == 'cleanup'
                ? 'deletionCleanupFailed'
                : null;
            model.entry =
                [
                  'accepted',
                  'unsaved',
                  'cleanup',
                  'unknown',
                  'restored',
                ].contains(state)
                ? DeletionEntry(
                    'fixture-owner',
                    'delete-intent',
                    state == 'unknown'
                        ? DeletionPhase.unknown
                        : state == 'restored'
                        ? DeletionPhase.cancelled
                        : DeletionPhase.accepted,
                    state == 'unknown' ? null : receipt,
                  )
                : null;
            final child = state == 'confirm'
                ? AccountDeletionDialog(
                    key: ValueKey(state),
                    strings: strings,
                    china: true,
                    showApple: true,
                    initialProvider: IdentityProvider.wechat,
                    onProvider: (_) {},
                  )
                : FridgePage(
                    title: strings.text('account'),
                    child: SingleChildScrollView(
                      child: AccountDeletionSection(
                        model: model,
                        strings: strings,
                        signedIn: state != 'guest',
                        disabled: false,
                        onSubmit: () {},
                        onRetry: () {},
                      ),
                    ),
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
            expect(
              tester.takeException(),
              isNull,
              reason: '$locale/$dark/$state',
            );
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
            if (state == 'confirm') {
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
          }
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await h.close();
    },
  );
}
