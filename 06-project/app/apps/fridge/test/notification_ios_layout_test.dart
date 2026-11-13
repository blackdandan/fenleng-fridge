import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_settings/fridge_settings.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';
import 'support/presentation_fixture.dart';

void main() {
  testWidgets(
    'iOS grouped scheduling and capacity copy fit iPad orientations, RTL and large text',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final messages = await pageMessages(tester);
      for (final size in [const Size(768, 1024), const Size(1024, 768)]) {
        pageSize(tester, width: size.width, height: size.height);
        for (final locale in messages.keys) {
          final strings = FridgeStrings.fromJson(messages, locale);
          for (final dark in [false, true]) {
            var disabled = false;
            await tester.pumpWidget(
              pageHost(
                strings,
                NotificationSettingsScreen(
                  strings: strings,
                  enabled: true,
                  authorized: true,
                  requested: true,
                  busy: false,
                  limited: true,
                  timingKey: 'notificationTimingIOS',
                  onEnable: () {},
                  onDisable: () => disabled = true,
                  onSettings: () {},
                ),
                width: size.width,
                height: size.height,
                scale: 2,
                dark: dark,
              ),
            );
            await tester.pumpAndSettle();
            final content = find.byType(ListView);
            final bounds = tester.getRect(content);
            expect(bounds.width, lessThanOrEqualTo(600));
            expect(bounds.center.dx, closeTo(size.width / 2, .1));
            final action = find.byKey(const ValueKey('notifications-disable'));
          await tester.scrollUntilVisible(action, 300);
            await tester.pumpAndSettle();
            expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
            await tester.tap(action);
            expect(disabled, true);
            expect(
              tester.takeException(),
              isNull,
              reason: '$locale $size $dark',
            );
          }
        }
      }
    },
  );
}
