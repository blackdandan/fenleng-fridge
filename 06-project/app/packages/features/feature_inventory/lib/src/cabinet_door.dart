part of 'cabinet.dart';

class _CabinetDoor extends StatelessWidget {
  final List<FoodRecord> foods;
  final FridgeStrings strings;
  final ImageProvider Function(String) photo;
  final StorageZone zone;
  final double width;
  final VoidCallback onTap;
  const _CabinetDoor({
    required this.foods,
    required this.strings,
    required this.photo,
    required this.zone,
    required this.width,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final layout = FridgeLayout.of(context);
    final palette = Theme.of(context).extension<FridgePalette>()!;
    final tall = zone == StorageZone.cold;
    final radius = BorderRadius.only(
      topLeft: Radius.circular(
        layout.d(
          tall
              ? FridgeProductTokens.radiusColdTop
              : FridgeProductTokens.radiusDoor,
        ),
      ),
      topRight: Radius.circular(
        layout.d(
          tall
              ? FridgeProductTokens.radiusColdTop
              : FridgeProductTokens.radiusDoor,
        ),
      ),
      bottomLeft: Radius.circular(
        layout.d(
          zone == StorageZone.frozen
              ? FridgeProductTokens.radiusOuter
              : FridgeProductTokens.radiusDoor,
        ),
      ),
      bottomRight: Radius.circular(
        layout.d(
          zone == StorageZone.pantry
              ? FridgeProductTokens.radiusOuter
              : FridgeProductTokens.radiusDoor,
        ),
      ),
    );
    return Semantics(
      button: true,
      label:
          '${strings.text(zone.name)} ${foods.isEmpty ? strings.text('empty') : strings.format('recordCount', {'count': foods.length})}',
      child: Material(
        color: palette.color(zone.name),
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            key: ValueKey('door-${zone.name}'),
            constraints: BoxConstraints(
              minHeight: layout.d(
                tall
                    ? FridgeProductTokens.sizeCold
                    : FridgeProductTokens.sizeLower,
              ),
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: palette.color('${zone.name}Line'),
                width: layout.d(FridgeProductTokens.sizeBorder),
              ),
              borderRadius: radius,
            ),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    layout.d(FridgeProductTokens.spaceDoorSide),
                    layout.d(FridgeProductTokens.spaceDoorTop),
                    layout.d(FridgeProductTokens.spaceDoorSide),
                    layout.d(FridgeProductTokens.spaceDoorBottom),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: layout.d(
                            FridgeProductTokens.spaceDoorHeaderBottom,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FridgeIcon(
                                    FridgeIconName.values.byName(zone.name),
                                    scale: layout.scale,
                                  ),
                                  SizedBox(
                                    width: layout.d(
                                      FridgeProductTokens.spaceLabelIcon,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      strings.text(zone.name),
                                      style: TextStyle(
                                        fontSize: layout.font(
                                          FridgeProductTokens.fontLabel,
                                        ),
                                        height: 1.23,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (foods.isNotEmpty)
                              Padding(
                                padding: EdgeInsetsDirectional.only(
                                  start: layout.d(4),
                                ),
                                child: Text(
                                  strings.format('recordCountShort', {
                                    'count': foods.length,
                                  }),
                                  style: TextStyle(
                                    fontSize: layout.font(
                                      FridgeProductTokens.fontMetadata,
                                    ),
                                    height: 1.45,
                                    color: palette.color('count'),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      _photos(
                        context,
                        foods,
                        width:
                            width -
                            layout.d(
                              2 *
                                  (FridgeProductTokens.spaceDoorSide +
                                      FridgeProductTokens.sizeBorder),
                            ),
                        tall: tall,
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          top: layout.d(FridgeProductTokens.spaceDoorFooterTop),
                        ),
                        child: Text(
                          '${strings.text(foods.isEmpty ? 'empty' : 'manage')}${foods.isEmpty ? '' : '\u2002\u200A↗\uFE0E'}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: layout.font(
                              FridgeProductTokens.fontCaption,
                            ),
                            height: 1.2,
                            color: palette.color('doorFooter'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (zone != StorageZone.pantry)
                  PositionedDirectional(
                    end: layout.d(FridgeProductTokens.spaceHandleRight),
                    top: layout.d(FridgeProductTokens.spaceHandleTop),
                    child: Container(
                      width: layout.d(FridgeProductTokens.sizeHandleWidth),
                      height: layout.d(FridgeProductTokens.sizeHandleHeight),
                      decoration: BoxDecoration(
                        color: palette.color('handle'),
                        borderRadius: BorderRadius.circular(layout.d(5)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
