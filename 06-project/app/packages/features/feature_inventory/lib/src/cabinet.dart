import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';

part 'cabinet_door.dart';
part 'cabinet_photos.dart';

class CabinetScreen extends StatelessWidget {
  final InventoryState state;
  final FridgeStrings strings;
  final ImageProvider Function(String) photo;
  final ValueChanged<StorageZone> onOpenZone;
  final VoidCallback onSettings, onReminders, onReview;
  const CabinetScreen({
    super.key,
    required this.state,
    required this.strings,
    required this.photo,
    required this.onOpenZone,
    required this.onSettings,
    required this.onReminders,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) => FridgePage(
    title: strings.text('home'),
    back: false,
    actions: [
      FridgeHeaderIcon(
        label: strings.text('notifications'),
        onPressed: onReminders,
        icon: Builder(
          builder: (context) => Badge(
            isLabelVisible: state.hasPending(DateTime.now()),
            child: FridgeIcon(
              FridgeIconName.bell,
              scale: FridgeLayout.of(context).scale,
            ),
          ),
        ),
      ),
      FridgeHeaderIcon(
        label: strings.text('settings'),
        onPressed: onSettings,
        icon: Builder(
          builder: (context) => FridgeIcon(
            FridgeIconName.settings,
            scale: FridgeLayout.of(context).scale,
          ),
        ),
      ),
    ],
    child: Builder(
      builder: (context) {
        final layout = FridgeLayout.of(context);
        final palette = Theme.of(context).extension<FridgePalette>()!;
        final now = DateTime.now();
        final hint = state.active.any((food) => !food.dueAt.isAfter(now))
            ? 'dueHint'
            : state.shouldShowInactivity(now)
            ? 'inactivityHint'
            : null;
        return ListView(
          padding: EdgeInsets.only(
            top: layout.d(FridgeProductTokens.spaceCabinetTop),
            bottom: layout.d(FridgeProductTokens.spaceBottom),
          ),
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                PositionedDirectional(
                  start: layout.d(FridgeProductTokens.spaceFeetInset),
                  end: layout.d(FridgeProductTokens.spaceFeetInset),
                  bottom: layout.d(-FridgeProductTokens.sizeFeetHeight),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < 2; i++)
                        Container(
                          width: layout.d(FridgeProductTokens.sizeFeetWidth),
                          height: layout.d(FridgeProductTokens.sizeFeetHeight),
                          decoration: BoxDecoration(
                            color: palette.color('feet'),
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(layout.d(2)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  key: const ValueKey('cabinet'),
                  padding: EdgeInsets.all(
                    layout.d(FridgeProductTokens.spaceCabinet),
                  ),
                  decoration: BoxDecoration(
                    color: palette.color('cabinet'),
                    border: Border.all(
                      color: palette.color('cabinetBorder'),
                      width: layout.d(FridgeProductTokens.sizeBorder),
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(
                        layout.d(FridgeProductTokens.radiusCabinetTop),
                      ),
                      bottom: Radius.circular(
                        layout.d(FridgeProductTokens.radiusCabinetBottom),
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: palette.color('cabinetShadow'),
                        offset: Offset(0, layout.d(8)),
                        blurRadius: layout.d(15),
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, box) => Column(
                      children: [
                        _door(context, StorageZone.cold, box.maxWidth),
                        SizedBox(
                          height: layout.d(FridgeProductTokens.gapCabinet),
                        ),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _door(
                                  context,
                                  StorageZone.frozen,
                                  (box.maxWidth -
                                          layout.d(
                                            FridgeProductTokens.gapCabinet,
                                          )) /
                                      2,
                                ),
                              ),
                              SizedBox(
                                width: layout.d(FridgeProductTokens.gapCabinet),
                              ),
                              Expanded(
                                child: _door(
                                  context,
                                  StorageZone.pantry,
                                  (box.maxWidth -
                                          layout.d(
                                            FridgeProductTokens.gapCabinet,
                                          )) /
                                      2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (hint != null)
              Padding(
                padding: EdgeInsets.only(
                  top: layout.d(FridgeProductTokens.spaceSection),
                ),
                child: Container(
                  padding: EdgeInsets.all(
                    layout.d(FridgeProductTokens.spaceCard),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.text(hint)),
                      TextButton(
                        onPressed: onReview,
                        child: Text(strings.text('goOrganize')),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );

  Widget _door(BuildContext context, StorageZone zone, double width) =>
      _CabinetDoor(
        foods: state.active.where((food) => food.zone == zone).toList(),
        strings: strings,
        photo: photo,
        zone: zone,
        width: width,
        onTap: () => onOpenZone(zone),
      );
}
