import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:fenleng_sdk_flutter_china_permissions/fenleng_sdk_flutter_china_permissions.dart';
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';
import '../infrastructure/food_media.dart';
import 'bootstrap.dart';
import 'capture_flow.dart';
import 'product_event.dart';

class CameraCoordinator {
  late final CameraSession camera;
  late final CaptureFlow flow;
  late final FenlengPermissionOrchestrator permissions;
  bool _wantCamera = true;
  CameraCoordinator({
    required Directory directory,
    required InventoryRepository repository,
    required StorageZone zone,
    required FridgeStrings strings,
    required FenlengPermissionRationalePresenter rationale,
    ProductEvent? onEvent,
  }) {
    permissions = FenlengPermissionOrchestrator(
      channel: FridgeBootstrap.channel == 'china'
          ? FenlengReleaseChannel.china
          : FenlengReleaseChannel.global,
      platform: const PermissionHandlerFenlengAdapter(),
      presentRationale: rationale,
      purposes: [
        FenlengPermissionPurpose(
          featureId: 'food.capture',
          permission: FenlengPermission.camera,
          featureName: strings.text('add'),
          dataAccessed: strings.text('localOnly'),
          purpose: strings.text('permissionBody'),
          denialImpact: strings.text('cameraUnavailable'),
          policyUrl: Uri.parse('https://fridge.fenlengtech.com/privacy/'),
        ),
      ],
    );
    camera = CameraSession(() async {
      if (!_wantCamera) return false;
      final previous = await permissions.platform.status(
        FenlengPermission.camera,
      );
      final outcome = await permissions.requestForFeature('food.capture');
      if (previous != FenlengPermissionStatus.granted) {
        emitProductEvent(onEvent, 'fridge.permission.resolved.v1', {
          'permission': 'camera',
          'result': switch (outcome) {
            FenlengPermissionOutcome.granted => 'granted',
            FenlengPermissionOutcome.cancelled => 'cancelled',
            FenlengPermissionOutcome.denied => 'denied',
            _ => 'restricted',
          },
        });
      }
      final granted = outcome == FenlengPermissionOutcome.granted;
      if (!granted) _wantCamera = false;
      return granted;
    });
    flow = CaptureFlow(
      repository: repository,
      zone: zone,
      source: ManagedFoodPhotos(directory: directory, camera: camera),
      onEvent: onEvent,
    );
  }
  Listenable get changes => Listenable.merge([camera, flow]);
  Future<void> open() {
    _wantCamera = true;
    return camera.open();
  }

  Future<void> resume() async {
    if (_wantCamera) await camera.open();
  }

  Future<void> chooseAlbum() {
    if (camera.controller?.value.isInitialized != true) _wantCamera = false;
    return flow.chooseAlbum();
  }

  Future<void> openSettings() async {
    await permissions.openSettings();
  }

  Future<void> close() async {
    flow.dispose();
    await camera.close();
  }
}
