import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/application/account_deletion.dart';
import 'package:fridge/presentation/account_page.dart';
import 'package:fridge/presentation/account_deletion.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';
import 'support/deletion_fixture.dart';

void main() {
  late DeletionHarness h;
  late FridgeStrings strings;
  setUp(() async {
    h = DeletionHarness();
    await h.start();
    strings = FridgeStrings.fromJson(
      jsonDecode(await rootBundle.loadString('assets/i18n/messages.json'))
          as Map<String, dynamic>,
      'zh-CN',
    );
  });
  tearDown(() async {
    await h.close();
  });
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: fridgeTheme(dark: false),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('zh', 'CN')],
        locale: const Locale('zh', 'CN'),
        home: AccountPage(
          session: h.identity,
          strings: strings,
          china: true,
          showApple: true,
          deletion: h.model,
          onDeletionProvider: (provider) => h.provider = provider,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    final button = find.widgetWithText(
      OutlinedButton,
      strings.text('deletionTitle'),
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(AccountDeletionDialog), findsOneWidget);
  }

  Future<void> confirm(WidgetTester tester) async {
    final button = find.widgetWithText(
      OutlinedButton,
      strings.text('deletionConfirmAction'),
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('cancel visible confirmation never asks provider or DELETE', (
    tester,
  ) async {
    await mount(tester);
    await open(tester);
    await tester.tap(find.widgetWithText(TextButton, strings.text('cancel')));
    await tester.pumpAndSettle();
    expect(h.deletes, 0);
    expect(h.proof.calls, 0);
    expect(h.journal.entries, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'actual account page SDK ACK shows year and dates after local-only logout',
    (tester) async {
      await mount(tester);
      await open(tester);
      await confirm(tester);
      expect(h.deletes, 1);
      expect(h.model.entry?.phase, DeletionPhase.accepted);
      expect(h.identity.signedIn, isFalse);
      expect(find.textContaining('2030'), findsNWidgets(2));
      expect(find.text(strings.text('deletionPending')), findsOneWidget);
      expect(find.text(strings.text('deletionLoginRecovery')), findsOneWidget);
      expect(await h.tokens.getItem('access'), isNull);
      expect(h.requests.any((r) => r.url.path.endsWith('/logout')), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'accepted receipt quota failure blocks login until local-only retry',
    (tester) async {
      h.journal.failReceipt = true;
      await mount(tester);
      await open(tester);
      await confirm(tester);
      expect(h.model.receiptIncomplete, isTrue);
      expect(await h.tokens.getItem('access'), 'original-access');
      expect(find.text(strings.text('deletionUnsaved')), findsOneWidget);
      final logout = tester.widget<TextButton>(
        find.widgetWithText(TextButton, strings.text('logout')),
      );
      expect(logout.onPressed, isNull);
      h.journal.failReceipt = false;
      final retry = find.widgetWithText(
        FilledButton,
        strings.text('deletionRetryReceipt'),
      );
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(h.deletes, 1);
      expect(h.model.receiptIncomplete, isFalse);
      expect(await h.tokens.getItem('access'), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'unknown result then explicit login creates a new intent without fake cancellation receipt',
    (tester) async {
      h.unknown = true;
      await mount(tester);
      await open(tester);
      await confirm(tester);
      expect(h.model.entry?.phase, DeletionPhase.unknown);
      final key = h.model.entry!.key;
      final logout = find.widgetWithText(TextButton, strings.text('logout'));
      await tester.ensureVisible(logout);
      await tester.tap(logout);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(strings.text('wechatLogin')));
      await tester.tap(find.text(strings.text('wechatLogin')));
      await tester.pumpAndSettle();
      expect(h.model.entry?.phase, DeletionPhase.cancelled);
      expect(h.model.entry?.receipt, isNull);
      expect(find.text(strings.text('deletionLoginResolved')), findsOneWidget);
      h.unknown = false;
      await open(tester);
      await confirm(tester);
      expect(h.deletes, 2);
      expect(h.model.entry!.key, isNot(key));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'withdrawal during held DELETE fences late ACK and retains original journal marker',
    (tester) async {
      h.holdDelete = Completer<void>();
      await mount(tester);
      await open(tester);
      final button = find.widgetWithText(
        OutlinedButton,
        strings.text('deletionConfirmAction'),
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      for (var i = 0; i < 30 && h.deletes == 0; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(h.deletes, 1);
      h.consent = false;
      h.model.freeze();
      h.holdDelete!.complete();
      await tester.pumpAndSettle();
      expect(h.journal.entries.single.phase, DeletionPhase.submitting);
      expect(await h.tokens.getItem('access'), 'original-access');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
