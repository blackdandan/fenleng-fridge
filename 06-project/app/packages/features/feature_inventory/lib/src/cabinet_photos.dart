part of 'cabinet.dart';

extension _CabinetPhotoLayout on _CabinetDoor {
  Widget _photos(
    BuildContext context,
    List<FoodRecord> foods, {
    required bool tall,
    required double width,
  }) {
    final layout = FridgeLayout.of(context);
    final palette = Theme.of(context).extension<FridgePalette>()!;
    final capacity = tall ? 6 : 3;
    final shown = foods
        .take(foods.length > capacity ? capacity - 1 : capacity)
        .toList();
    final gap = layout.d(
      tall ? FridgeProductTokens.gapPhotos : FridgeProductTokens.gapSmallPhotos,
    );
    final columnWidth = math.max(0.0, (width - 2 * gap) / 3);
    final diameter = math.min(
      columnWidth,
      layout.d(FridgeProductTokens.sizeHomePhoto),
    );
    final style = TextStyle(
      fontSize: layout.font(FridgeProductTokens.fontPhotoNumber),
      height: 1.22,
      color: palette.color('caption'),
    );
    var captionHeight = layout.font(FridgeProductTokens.fontPhotoNumber) * 1.22;
    for (final label in [
      ...shown.map((food) => '#${food.id}'),
      if (foods.length > capacity) strings.text('more'),
    ]) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: columnWidth);
      captionHeight = math.max(captionHeight, painter.height);
    }
    final rowHeight =
        diameter +
        layout.d(FridgeProductTokens.spacePhotoCaptionTop) +
        captionHeight;
    final slotHeight = tall
        ? math.max(rowHeight, layout.d(FridgeProductTokens.sizeHomeSlot))
        : rowHeight;
    final gridHeight = math.max(
      layout.d(
        tall
            ? FridgeProductTokens.sizeHomeGrid
            : FridgeProductTokens.sizeSmallGrid,
      ),
      tall
          ? slotHeight * 2 + layout.d(FridgeProductTokens.gapPhotoRows)
          : slotHeight,
    );
    Widget slot(Widget circle, String label) => SizedBox(
      width: columnWidth,
      height: slotHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          circle,
          SizedBox(height: layout.d(FridgeProductTokens.spacePhotoCaptionTop)),
          Text(label, style: style, textAlign: TextAlign.center),
        ],
      ),
    );
    return SizedBox(
      height: gridHeight,
      child: foods.isEmpty
          ? Center(
              child: Text(
                '+',
                style: TextStyle(
                  fontSize: layout.font(FridgeProductTokens.fontEmptyPlus),
                  color: palette.muted,
                  height: 1,
                ),
              ),
            )
          : Align(
              alignment: AlignmentDirectional.topStart,
              child: Wrap(
                spacing: gap,
                runSpacing: layout.d(FridgeProductTokens.gapPhotoRows),
                children: [
                  for (final food in shown)
                    slot(
                      FridgeFoodPhoto(
                        key: ValueKey('home-photo-${food.id}'),
                        image: photo(food.photoPath),
                        size: diameter,
                        scale: layout.scale,
                        errorLabel: strings.text('error'),
                      ),
                      '#${food.id}',
                    ),
                  if (foods.length > capacity)
                    slot(
                      FridgeMorePhoto(
                        size: diameter,
                        scale: layout.scale,
                        count: '+${foods.length - shown.length}',
                      ),
                      strings.text('more'),
                    ),
                ],
              ),
            ),
    );
  }
}
