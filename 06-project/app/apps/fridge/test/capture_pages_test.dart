import 'dart:ui' show SemanticsAction;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge_inventory/fridge_inventory.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';
import 'support/presentation_fixture.dart';

Widget screen(
  FridgeStrings strings, {
  bool ready = true,
  bool opening = false,
  bool busy = false,
  bool pending = false,
  bool failed = false,
  VoidCallback? album,
  VoidCallback? capture,
  ValueChanged<StorageZone>? select,
}) => CaptureScreen(
  key: ValueKey((ready, opening, busy, pending, failed)),
  strings: strings,
  zone: StorageZone.cold,
  savedCount: 2,
  ready: ready,
  opening: opening,
  busy: busy,
  pending: pending,
  failed: failed,
  preview: const ColoredBox(
    key: ValueKey('injected-preview'),
    color: Colors.grey,
  ),
  onZone: select ?? (_) {},
  onCapture: capture ?? () {},
  onAlbum: album ?? () {},
  onRetry: () {},
  onCameraRetry: () {},
  onSettings: () {},
  onFinish: () {},
);

void main() {
  testWidgets(
    'camera is a fixed-dark full page with original assets, square preview and working controls',
    (tester) async {
      final semantics = tester.ensureSemantics();
      pageSize(tester, height: 887);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = FridgeStrings.fromJson(
        await pageMessages(tester),
        'zh-CN',
      );
      var captures = 0, albums = 0;
      StorageZone? selected;
      await tester.pumpWidget(
        pageHost(
          strings,
          screen(
            strings,
            capture: () => captures++,
            album: () => albums++,
            select: (value) => selected = value,
          ),
          height: 887,
        ),
      );
      await tester.pumpAndSettle();
      final preview = find.byKey(const ValueKey('capture-preview'));
      expect(tester.getSize(preview), const Size(382, 382));
      expect(tester.getTopLeft(preview).dy, closeTo(164.8, .01));
      expect(
        tester
            .getSize(find.byKey(const ValueKey('capture-selector-surface')))
            .height,
        closeTo(44.4, .01),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('capture-shutter'))),
        const Size(69, 69),
      );
      expect(find.byKey(const ValueKey('injected-preview')), findsOneWidget);
      final context = tester.element(preview);
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(
        Theme.of(context).scaffoldBackgroundColor,
        FridgeProductTokens.light['camera'],
      );
      final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
      );
      expect(overlay.value.statusBarIconBrightness, Brightness.light);
      expect(find.byType(FridgeIcon), findsNWidgets(3));
      for (final name in [
        FridgeIconName.cameraBack,
        FridgeIconName.album,
        FridgeIconName.chevronDown,
      ]) {
        final icon = find.byWidgetPredicate(
          (w) => w is FridgeIcon && w.name == name,
        );
        expect(
          tester.getSize(icon),
          name == FridgeIconName.chevronDown
              ? const Size(10, 6)
              : const Size(22, 22),
        );
      }
      expect(
        tester
            .widget<FridgeIcon>(
              find.byWidgetPredicate(
                (w) => w is FridgeIcon && w.name == FridgeIconName.cameraBack,
              ),
            )
            .originalColors,
        true,
      );
      final guide = tester.getSize(find.byKey(const ValueKey('capture-guide')));
      expect(guide.width, closeTo(346.4, .001));
      expect(guide.height, closeTo(346.4, .001));
      final tag =
          tester
                  .widget<Container>(
                    find.byKey(const ValueKey('capture-local')),
                  )
                  .decoration
              as BoxDecoration;
      expect(
        (tag.border as Border).top.color,
        FridgeProductTokens.light['cameraTagBorder'],
      );
      expect(
        tester.widget<Text>(find.text(strings.text('cameraHint'))).style!.color,
        FridgeProductTokens.light['cameraCaption'],
      );
      final shutterSemantics = tester
          .getSemantics(find.byKey(const ValueKey('capture-shutter')))
          .getSemanticsData();
      expect(shutterSemantics.label, strings.text('captureNow'));
      expect(shutterSemantics.hasAction(SemanticsAction.tap), true);
      semantics.dispose();
      await expectLater(
        find.byType(CaptureScreen),
        matchesGoldenFile('goldens/camera-430.png'),
      );
      await tester.tap(find.byKey(const ValueKey('capture-album')));
      await tester.tap(find.byKey(const ValueKey('capture-shutter')));
      expect([albums, captures], [1, 1]);
      await tester.tap(find.byKey(const ValueKey('capture-zone')));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .text(
              strings.format('putInto', {'zone': strings.text('frozenZone')}),
            )
            .last,
      );
      await tester.pumpAndSettle();
      expect(selected, StorageZone.frozen);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'camera busy/pending disables acquisition and completion; unavailable keeps album and recovery',
    (tester) async {
      pageSize(tester, height: 887);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = FridgeStrings.fromJson(
        await pageMessages(tester),
        'zh-CN',
      );
      for (final busy in [false, true]) {
        await tester.pumpWidget(
          pageHost(
            strings,
            screen(strings, busy: busy, pending: true, failed: !busy),
            height: 887,
          ),
        );
        await tester.pump();
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(const ValueKey('capture-shutter')),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<TextButton>(find.byKey(const ValueKey('capture-album')))
              .onPressed,
          isNull,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('capture-finish')),
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(const ValueKey('capture-finish')),
              )
              .onPressed,
          isNull,
        );
      }
      await tester.pumpWidget(
        pageHost(strings, screen(strings, ready: false), height: 887),
      );
      await tester.pumpAndSettle();
      expect(find.text(strings.text('cameraUnavailable')), findsOneWidget);
      expect(find.text(strings.text('openSettings')), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('capture-album')))
            .onPressed,
        isNotNull,
      );
      expect(find.byKey(const ValueKey('capture-guide')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'camera ready/unavailable/failed fits20 locales at320 and text2 in either host theme',
    (tester) async {
      pageSize(tester, width: 320, height: 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final messages = await pageMessages(tester);
      for (final locale in messages.keys) {
        final strings = FridgeStrings.fromJson(messages, locale);
        for (final dark in [false, true]) {
          for (final state in ['ready', 'unavailable', 'failed']) {
            await tester.pumpWidget(
              pageHost(
                strings,
                KeyedSubtree(
                  key: ValueKey('$locale-$dark-$state'),
                  child: screen(
                    strings,
                    ready: state != 'unavailable',
                    pending: state == 'failed',
                    failed: state == 'failed',
                  ),
                ),
                width: 320,
                height: 800,
                scale: 2,
                dark: dark,
              ),
            );
            await tester.pumpAndSettle();
            // Drag the outer viewport's edge, outside the unavailable-preview's
            // inner scroll area, so the test reaches the page footer itself.
            for (
              var n = 0;
              n < 30 &&
                  find
                      .byKey(const ValueKey('capture-finish'))
                      .evaluate()
                      .isEmpty;
              n++
            ) {
              final box = tester.getRect(find.byType(CustomScrollView));
              await tester.dragFrom(
                Offset(box.left + 2, box.bottom - 40),
                const Offset(0, -300),
              );
              await tester.pumpAndSettle();
            }
            await tester.ensureVisible(
              find.byKey(const ValueKey('capture-finish')),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$locale $dark $state',
            );
          }
        }
      }
    },
  );
}
