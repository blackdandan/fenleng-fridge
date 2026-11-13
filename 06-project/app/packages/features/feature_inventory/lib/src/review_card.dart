part of 'review_screen.dart';

class _ReviewCard extends StatelessWidget {
  final FoodRecord food;
  final FridgeStrings strings;
  final ImageProvider Function(String) photo;
  final bool busy;
  final Future<void> Function(FoodRecord, Remaining) onConfirm;
  final ValueChanged<FoodRecord> onOpen;
  const _ReviewCard({
    required this.food,
    required this.strings,
    required this.photo,
    required this.busy,
    required this.onConfirm,
    required this.onOpen,
  });
  @override
  Widget build(BuildContext context) {
    final layout = FridgeLayout.of(context);
    final palette = Theme.of(context).extension<FridgePalette>()!;
    return Container(
      key: ValueKey('review-card-${food.id}'),
      padding: EdgeInsets.fromLTRB(
        layout.d(FridgeProductTokens.spaceCard),
        layout.d(FridgeProductTokens.spaceCard),
        layout.d(FridgeProductTokens.spaceCard),
        layout.d(FridgeProductTokens.spaceReviewBottom),
      ),
      decoration: BoxDecoration(
        color: palette.color('surface'),
        borderRadius: BorderRadius.circular(
          layout.d(FridgeProductTokens.radiusCard),
        ),
        border: Border.all(
          color: palette.border,
          width: layout.d(FridgeProductTokens.sizeBorder),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              FridgeFoodPhoto(
                key: ValueKey('review-photo-${food.id}'),
                image: photo(food.photoPath),
                size: layout.d(FridgeProductTokens.sizeHomePhoto),
                scale: layout.scale,
                errorLabel: strings.text('error'),
              ),
              SizedBox(width: layout.d(FridgeProductTokens.spaceReviewRow)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${food.id}',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        letterSpacing: 0,
                        fontSize: layout.font(FridgeProductTokens.fontBody),
                        height: 1.2,
                      ),
                    ),
                    SizedBox(
                      height: layout.d(
                        FridgeProductTokens.spacePhotoCaptionTop,
                      ),
                    ),
                    Text(
                      '${strings.format('addedCaption', {'date': FridgeDates.short(context, strings.locale, food.addedAt)})} · ${strings.text(food.zone.name)}',
                      style: TextStyle(
                        letterSpacing: 0,
                        fontSize: layout.font(FridgeProductTokens.fontMetadata),
                        height: 1.8,
                        color: palette.muted,
                      ),
                    ),
                    Text(
                      food.confirmedAt == null
                          ? strings.text('neverOrganized')
                          : strings.format('lastOrganizedCaption', {
                              'date': FridgeDates.confirmed(
                                context,
                                strings.locale,
                                food.confirmedAt!,
                              ),
                            }),
                      style: TextStyle(
                        letterSpacing: 0,
                        fontSize: layout.font(FridgeProductTokens.fontMetadata),
                        height: 1.8,
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: layout.d(108)),
                child: TextButton(
                  key: ValueKey('review-detail-${food.id}'),
                  onPressed: busy ? null : () => onOpen(food),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.zero,
                    alignment: AlignmentDirectional.centerEnd,
                    foregroundColor: palette.color('primary'),
                    textStyle: TextStyle(
                      letterSpacing: 0,
                      fontSize: layout.font(FridgeProductTokens.fontSecondary),
                      height: 1.4,
                    ),
                  ),
                  child: Text(strings.text('detail'), textAlign: TextAlign.end),
                ),
              ),
            ],
          ),
          SizedBox(height: layout.d(FridgeProductTokens.spaceReviewActionsTop)),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < Remaining.values.length; i++) ...[
                  if (i > 0)
                    SizedBox(width: layout.d(FridgeProductTokens.spaceChoice)),
                  Expanded(
                    child: FridgeChoice(
                      key: ValueKey(
                        'review-${food.id}-${Remaining.values[i].name}',
                      ),
                      label: strings.text(Remaining.values[i].name),
                      selected: food.remaining == Remaining.values[i],
                      destructive: Remaining.values[i] == Remaining.gone,
                      onPressed: busy
                          ? null
                          : () => onConfirm(food, Remaining.values[i]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
