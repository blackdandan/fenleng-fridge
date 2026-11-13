import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fridge_inventory/fridge_inventory.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';
import '../application/camera_coordinator.dart';

class CapturePage extends StatefulWidget {
  final CameraCoordinator coordinator;
  final FridgeStrings strings;
  const CapturePage({
    super.key,
    required this.coordinator,
    required this.strings,
  });
  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.coordinator.open());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(widget.coordinator.camera.suspend());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(widget.coordinator.resume());
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: fridgeCameraTheme(),
    child: ListenableBuilder(
      listenable: widget.coordinator.changes,
      builder: (context, _) {
        final coordinator = widget.coordinator,
            flow = coordinator.flow,
            session = coordinator.camera;
        final strings = widget.strings, controller = session.controller;
        return PopScope(
          canPop: !flow.busy && !flow.hasPending,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop || flow.busy || !flow.hasPending) return;
            final discard = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                content: Text(strings.text('discardCapture')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(strings.text('cancel')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(strings.text('done')),
                  ),
                ],
              ),
            );
            if (discard == true) {
              await flow.abandon();
              await WidgetsBinding.instance.endOfFrame;
              if (context.mounted) Navigator.pop(context);
            }
          },
          child: CaptureScreen(
            strings: strings,
            zone: flow.zone,
            savedCount: flow.savedCount,
            ready: controller?.value.isInitialized == true,
            opening: session.opening,
            busy: flow.busy,
            pending: flow.hasPending,
            failed: flow.failed,
            preview: controller == null
                ? const SizedBox.shrink()
                : _LiveCamera(controller),
            onZone: flow.selectZone,
            onCapture: flow.take,
            onAlbum: coordinator.chooseAlbum,
            onRetry: flow.retry,
            onCameraRetry: coordinator.open,
            onSettings: coordinator.openSettings,
            onFinish: () => Navigator.of(context).pop(),
          ),
        );
      },
    ),
  );
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// Cover the square viewport without stretching the native sensor image.
class _LiveCamera extends StatelessWidget {
  final CameraController controller;
  const _LiveCamera(this.controller);
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<CameraValue>(
    valueListenable: controller,
    builder: (context, value, _) {
      final size = value.previewSize;
      if (!value.isInitialized || size == null) return const SizedBox.shrink();
      final orientation =
          value.lockedCaptureOrientation ?? value.deviceOrientation;
      final portrait =
          orientation == DeviceOrientation.portraitUp ||
          orientation == DeviceOrientation.portraitDown;
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: portrait ? size.height : size.width,
          height: portrait ? size.width : size.height,
          child: CameraPreview(controller),
        ),
      );
    },
  );
}
