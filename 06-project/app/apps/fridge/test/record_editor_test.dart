import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge_inventory/fridge_inventory.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';

void main() {
  final strings = FridgeStrings.fromJson(
    jsonDecode(File('assets/i18n/messages.json').readAsStringSync())
        as Map<String, dynamic>,
    'zh-CN',
  );
  final food = FoodRecord(
    id: '001',
    photoPath: 'photo',
    zone: StorageZone.cold,
    addedAt: DateTime(2026, 11, 1),
    dueAt: DateTime(2026, 11, 4, 17, 30),
    intervalDays: 3,
  );
  final photo = MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jvWQAAAAASUVORK5CYII=',
    ),
  );

  testWidgets(
    'interval edit validates and never silently submits a changed reminder cycle',
    (tester) async {
      RecordEdits? saved;
      var closed = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: fridgeTheme(),
          home: Scaffold(
            body: RecordEditor(
              food: food,
              strings: strings,
              photo: photo,
              onSave: (edits) async {
                saved = edits;
              },
              onReplace: () async {},
              onDelete: () async {},
              onClose: () => closed++,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '0');
      await tester.ensureVisible(find.text(strings.text('saveChanges')));
      await tester.tap(find.text(strings.text('saveChanges')));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.text(strings.text('error')), findsOneWidget);
      await tester.enterText(find.byType(TextField), '١٤');
      await tester.ensureVisible(find.text(strings.text('saveChanges')));
      await tester.tap(find.text(strings.text('saveChanges')));
      await tester.pumpAndSettle();
      expect(saved!.intervalDays, 14);
      expect(saved!.dueAt, isNull);
      expect(saved!.zone, StorageZone.cold);
      expect(saved!.addedAt, food.addedAt);
      expect(closed, 1);
    },
  );

  testWidgets('permanent delete requires an explicit confirmation', (
    tester,
  ) async {
    var deleted = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: fridgeTheme(),
        home: Scaffold(
          body: RecordEditor(
            food: food,
            strings: strings,
            photo: photo,
            onSave: (_) async {},
            onReplace: () async {},
            onDelete: () async {
              deleted++;
            },
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text(strings.text('deleteRecordAction')));
    await tester.tap(find.text(strings.text('deleteRecordAction')));
    await tester.pumpAndSettle();
    expect(deleted, 0);
    expect(find.text(strings.text('confirmDelete')), findsOneWidget);
    final confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text(strings.text('delete')),
    );
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });
}
