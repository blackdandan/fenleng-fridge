import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';

class RecordsScreen extends StatelessWidget {
  final String title;
  final List<FoodRecord> foods;
  final FridgeStrings strings;
  final ImageProvider Function(String) photo;
  final VoidCallback onAdd, onOrganize;
  final ValueChanged<FoodRecord> onOpen;
  const RecordsScreen({
    super.key,
    required this.title,
    required this.foods,
    required this.strings,
    required this.photo,
    required this.onAdd,
    required this.onOrganize,
    required this.onOpen,
  });
  @override
  Widget build(BuildContext context) => FridgePage(
    title: title,
    count: strings.format('recordCount', {'count': foods.length}),
    child: Builder(
      builder: (context) {
        final layout = FridgeLayout.of(context);
        final palette = Theme.of(context).extension<FridgePalette>()!;
        final numberStyle = DefaultTextStyle.of(context).style.merge(
          TextStyle(
            letterSpacing: 0,
            color: palette.color('recordNumber'),
            fontSize: layout.font(FridgeProductTokens.fontRecordNumber),
            height: 1.2,
            fontWeight: FontWeight.w400,
          ),
        );
        final dateStyle = DefaultTextStyle.of(context).style.merge(
          TextStyle(
            letterSpacing: 0,
            color: palette.color('recordDate'),
            fontSize: layout.font(FridgeProductTokens.fontCaption),
            height: 1.4,
            fontWeight: FontWeight.w400,
          ),
        );
        String caption(FoodRecord food) => strings.format('addedCaption', {
          'date': FridgeDates.short(context, strings.locale, food.addedAt),
        });
        return LayoutBuilder(
          builder: (context, box) {
            final gap = layout.d(FridgeProductTokens.gapRecords);
            final width = (box.maxWidth - 2 * gap) / 3;
            double height(
              String text,
              TextStyle style, {
              bool number = false,
            }) => (TextPainter(
              text: TextSpan(text: text, style: style),
              textDirection: number ? TextDirection.ltr : strings.direction,
              textScaler: MediaQuery.textScalerOf(context),
            )..layout(maxWidth: width)).height;
            var numberHeight = height('#001', numberStyle, number: true);
            var dateHeight = height(
              strings.format('addedCaption', {
                'date': FridgeDates.short(
                  context,
                  strings.locale,
                  DateTime.now(),
                ),
              }),
              dateStyle,
            );
            for (final food in foods) {
              numberHeight = math.max(
                numberHeight,
                height('#${food.id}', numberStyle, number: true),
              );
              dateHeight = math.max(
                dateHeight,
                height(caption(food), dateStyle),
              );
            }
            final tileHeight =
                width +
                layout.d(FridgeProductTokens.spaceRecordNumberTop) +
                numberHeight +
                layout.d(FridgeProductTokens.spaceRecordDateTop) +
                dateHeight;
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          top: layout.d(FridgeProductTokens.spaceIntroTop),
                        ),
                        child: Text(
                          strings.text('recordsHint'),
                          style: TextStyle(
                            letterSpacing: 0,
                            fontSize: layout.font(
                              FridgeProductTokens.fontSecondary,
                            ),
                            height: 1.8,
                            color: palette.muted,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: layout.d(FridgeProductTokens.spaceActionTop),
                      ),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: FridgeAction(
                                key: const ValueKey('zone-add'),
                                label: strings.text('add'),
                                onPressed: onAdd,
                                icon: FridgeIconName.camera,
                              ),
                            ),
                            SizedBox(
                              width: layout.d(
                                FridgeProductTokens.gapSmallPhotos,
                              ),
                            ),
                            Expanded(
                              child: FridgeAction(
                                key: const ValueKey('zone-review'),
                                label: strings.text('organize'),
                                onPressed: foods.isEmpty ? null : onOrganize,
                                secondary: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.only(
                    top: layout.d(FridgeProductTokens.spaceRecordsTop),
                    bottom: layout.d(FridgeProductTokens.spaceBottom),
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: gap,
                      mainAxisSpacing: layout.d(
                        FridgeProductTokens.gapRecordRows,
                      ),
                      mainAxisExtent: tileHeight,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final food = foods[index];
                      return Semantics(
                        button: true,
                        label: '#${food.id}',
                        child: InkWell(
                          onTap: () => onOpen(food),
                          borderRadius: BorderRadius.circular(
                            layout.d(FridgeProductTokens.radiusControl),
                          ),
                          child: Column(
                            children: [
                              FridgeFoodPhoto(
                                key: ValueKey('zone-photo-${food.id}'),
                                image: photo(food.photoPath),
                                size: width,
                                scale: layout.scale,
                                borderWidth:
                                    FridgeProductTokens.sizeRecordBorder,
                                errorLabel: strings.text('error'),
                              ),
                              SizedBox(
                                height: layout.d(
                                  FridgeProductTokens.spaceRecordNumberTop,
                                ),
                              ),
                              SizedBox(
                                height: numberHeight,
                                child: Text(
                                  '#${food.id}',
                                  style: numberStyle,
                                  textDirection: TextDirection.ltr,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(
                                height: layout.d(
                                  FridgeProductTokens.spaceRecordDateTop,
                                ),
                              ),
                              SizedBox(
                                height: dateHeight,
                                child: Text(
                                  caption(food),
                                  style: dateStyle,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: foods.length),
                  ),
                ),
              ],
            );
          },
        );
      },
    ),
  );
}
