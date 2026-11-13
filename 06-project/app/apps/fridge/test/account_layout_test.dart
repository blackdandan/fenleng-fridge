import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/application/identity_session.dart';
import 'package:fridge/presentation/account_page.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';

class Backend implements IdentityBackend {
  @override
  Future<bool> restore() async => false;
  @override
  Future<void> exchange(IdentityProvider provider, String proof) async {}
  @override
  Future<void> logout() async {}
  @override
  Future<void> close() async {}
}

class Authorization implements IdentityAuthorization {
  @override
  Future<String> authorize(IdentityProvider provider) async => 'test-proof';
}

void main() {
  testWidgets(
    'account controls fit twenty locales at large scale on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    final messages =
        jsonDecode((await tester.runAsync(() => rootBundle.loadString('assets/i18n/messages.json')))!)
              as Map<String, dynamic>;
      final session = IdentitySession(
        backend: Backend(),
        authorization: Authorization(),
        consent: () => true,
        configured: false,
      );
      session.errorKey = 'loginNotConfigured';
      for (final locale in messages.keys) {
        final strings = FridgeStrings.fromJson(messages, locale);
        for (final dark in [false, true]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: fridgeTheme(dark: dark),
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 700),
                  textScaler: TextScaler.linear(2),
                ),
                child: Directionality(
                  textDirection: strings.rtl
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: AccountPage(
                    session: session,
                    strings: strings,
                    china: true,
                    showApple: true,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$locale, dark=$dark');
          expect(find.text(strings.text('wechatLogin')), findsOneWidget);
          expect(find.text(strings.text('appleLogin')), findsOneWidget);
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    },
  );
}
