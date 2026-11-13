import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';

enum CameraRationaleChoice { request, album, cancel }

Future<CameraRationaleChoice> showCameraRationale(
  BuildContext context,
  FridgeStrings strings,
) async =>
    await showDialog<CameraRationaleChoice>(
      context: context,
      barrierColor: Theme.of(
        context,
      ).extension<FridgePalette>()!.color('scrim'),
      builder: (context) => _CameraRationale(strings: strings),
    ) ??
    CameraRationaleChoice.cancel;

class _CameraRationale extends StatelessWidget {
  final FridgeStrings strings;
  const _CameraRationale({required this.strings});
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final scale = math.min(width, FridgeSpace.maxWidth) / 430;
    final palette = Theme.of(context).extension<FridgePalette>()!;
    return Dialog(
      alignment: Alignment.topCenter,
      backgroundColor: palette.color('page'),
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(FridgeSpace.medium),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          FridgeProductTokens.radiusDialog * scale,
        ),
        side: BorderSide(
          color: palette.border,
          width: FridgeProductTokens.sizeBorder * scale,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: math.min(width - 32, FridgeSpace.maxWidth - 32),
        child: FridgeLayout(
          scale: scale,
          child: Builder(
            builder: (context) {
              final layout = FridgeLayout.of(context);
              final closeSize = math.max(
                44.0,
                layout.d(FridgeProductTokens.sizeTouchMin),
              );
              void choose(CameraRationaleChoice choice) =>
                  Navigator.pop(context, choice);
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  layout.d(FridgeProductTokens.spacePage),
                  layout.d(FridgeProductTokens.spacePermissionTop),
                  layout.d(FridgeProductTokens.spacePage),
                  layout.d(FridgeProductTokens.spacePermissionBottom),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            strings.text('permissionTitle'),
                            style: TextStyle(
                              color: palette.color('ink'),
                              fontSize: layout.font(
                                FridgeProductTokens.fontDialogTitle,
                              ),
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                        SizedBox(width: layout.d(FridgeSpace.small)),
                        SizedBox(
                          width: closeSize,
                          height: closeSize,
                          child: TextButton(
                            onPressed: () =>
                                choose(CameraRationaleChoice.cancel),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: palette.color('dialogClose'),
                              foregroundColor: palette.color('dialogCloseInk'),
                              shape: const CircleBorder(),
                            ),
                            child: Semantics(
                              label: MaterialLocalizations.of(
                                context,
                              ).closeButtonTooltip,
                              child: ExcludeSemantics(
                                child: Text(
                                  '×',
                                  style: TextStyle(
                                    fontSize: layout.font(
                                      FridgeProductTokens.fontDialogClose,
                                    ),
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: layout.d(
                        FridgeProductTokens.spacePermissionBodyTop,
                      ),
                    ),
                    Text(
                      strings.text('permissionBody'),
                      style: TextStyle(
                        color: palette.color('ink'),
                        fontSize: layout.font(
                          FridgeProductTokens.fontPermissionBody,
                        ),
                        height: 1.6,
                      ),
                    ),
                    SizedBox(height: layout.d(FridgeSpace.medium)),
                    FridgeAction(
                      label: strings.text('continueRequest'),
                      fontSize: FridgeProductTokens.fontPermissionAction,
                      minHeight: FridgeProductTokens.sizeTouch,
                      onPressed: () => choose(CameraRationaleChoice.request),
                    ),
                    SizedBox(height: layout.d(FridgeProductTokens.spaceRow)),
                    FridgeAction(
                      label: strings.text('album'),
                      secondary: true,
                      fontSize: FridgeProductTokens.fontPermissionAction,
                      minHeight: FridgeProductTokens.sizePermissionSecondary,
                      onPressed: () => choose(CameraRationaleChoice.album),
                    ),
                    SizedBox(height: layout.d(FridgeProductTokens.spaceRow)),
                    FridgeAction(
                      label: strings.text('notNow'),
                      secondary: true,
                      fontSize: FridgeProductTokens.fontPermissionAction,
                      minHeight: FridgeProductTokens.sizePermissionSecondary,
                      onPressed: () => choose(CameraRationaleChoice.cancel),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
