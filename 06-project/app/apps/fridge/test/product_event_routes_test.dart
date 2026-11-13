import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/main.dart';
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';
import 'support/presentation_fixture.dart';
import 'support/runtime_fixture.dart';

class RouteEventBootstrap extends ReadyBootstrap {
  final events = <String>[];
  RouteEventBootstrap(super.repository, super.resources);
  @override
  void recordEvent(String name, Map<String, String> properties) {
    events.add(name);
  }

  void redraw() => notifyListeners();
}

void main() {
  testWidgets(
    'real home frames/rebuilds and returning from settings produce one event per exposure',
    (tester) async {
      pageSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = FridgeStrings.fromJson(
        await pageMessages(tester),
        'zh-CN',
      );
      final repository = InventoryRepository(
        MemoryStorage(pageInventory(count: 2)),
      );
      await repository.open();
      final bootstrap = RouteEventBootstrap(repository, strings);
      try {
        await tester.pumpWidget(
          FridgeApp(bootstrap: bootstrap, photoLoader: (_) => testPhoto),
        );
        await tester.pumpAndSettle();
        expect(bootstrap.events, ['fridge.home.viewed.v1']);
        bootstrap.redraw();
        await tester.pumpAndSettle();
        expect(bootstrap.events.length, 1);
        await tester.tap(find.byTooltip(strings.text('settings')));
        await tester.pumpAndSettle();
        expect(bootstrap.events.length, 1);
        final context = tester.element(find.byType(Navigator).first);
        Navigator.of(context).pop();
        await tester.pumpAndSettle();
        expect(bootstrap.events, [
          'fridge.home.viewed.v1',
          'fridge.home.viewed.v1',
        ]);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        bootstrap.dispose();
        await repository.close();
      }
    },
  );
}
