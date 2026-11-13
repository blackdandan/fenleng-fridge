import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';

part 'capture_controls.dart';
part 'capture_viewfinder.dart';

/// Presentation only: the host supplies the real camera preview and operations.
class CaptureScreen extends StatelessWidget {
  final FridgeStrings strings;
  final StorageZone zone;
  final int savedCount;
  final bool ready, opening, busy, pending, failed;
  final Widget preview;
  final ValueChanged<StorageZone> onZone;
  final VoidCallback onCapture,
      onAlbum,
      onRetry,
      onCameraRetry,
      onSettings,
      onFinish;
  const CaptureScreen({
    super.key,
    required this.strings,
    required this.zone,
    required this.savedCount,
    required this.ready,
    required this.opening,
    required this.busy,
    required this.pending,
    required this.failed,
    required this.preview,
    required this.onZone,
    required this.onCapture,
    required this.onAlbum,
    required this.onRetry,
    required this.onCameraRetry,
    required this.onSettings,
    required this.onFinish,
  });

  bool get locked => busy || pending;
  @override
  Widget build(BuildContext context) => Theme(
    data: fridgeCameraTheme(),
    child: FridgePage(
      title: strings.text('add'),
      backIcon: FridgeIconName.cameraBack,
      backIconOriginalColors: true,
      titleWeight: FontWeight.w500,
      titleHeight: 1.5,
      headerTop: FridgeProductTokens.spaceCameraHeaderTop,
      child: Builder(
        builder: (context) {
          final l = FridgeLayout.of(context);
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: l.d(FridgeProductTokens.spaceCameraIntroTop),
                    ),
                    _localTag(context),
                    SizedBox(height: l.d(FridgeProductTokens.spaceRow)),
                    _selector(context),
                    SizedBox(
                      height: l.d(FridgeProductTokens.spaceCameraPreviewTop),
                    ),
                    _viewfinder(context),
                    SizedBox(
                      height: l.d(FridgeProductTokens.spaceCameraControlsTop),
                    ),
                    _controls(context),
                  ],
                ),
              ),
              _footer(context),
            ],
          );
        },
      ),
    ),
  );
}
