import 'package:flutter/foundation.dart';
import 'package:fridge_core/fridge_core.dart';
import 'product_event.dart';

abstract interface class FoodPhotoSource {
  Future<String> capture();
  Future<List<String>> album();
  Future<String> persist(String path);
  Future<void> discardSaved(String path);
}

class PendingPhoto {
  final String path;
  final StorageZone zone;
  final String origin;
  String? savedPath;
  PendingPhoto(this.path, this.zone, this.origin);
}

class CaptureFlow extends ChangeNotifier {
  final InventoryRepository repository;
  final FoodPhotoSource source;
  final DateTime Function() clock;
  final ProductEvent? onEvent;
  StorageZone zone;
  bool busy = false;
  bool failed = false;
  int savedCount = 0;
  final List<PendingPhoto> _pending = [];
  bool _closed = false;
  bool get hasPending => _pending.isNotEmpty;
  CaptureFlow({
    required this.repository,
    required this.source,
    required this.zone,
    DateTime Function()? clock,
    this.onEvent,
  }) : clock = clock ?? DateTime.now;

  void selectZone(StorageZone value) {
    zone = value;
    _publish();
  }

  Future<void> take() => _run(() async {
    if (_pending.isNotEmpty) return;
    final destination = zone;
    _event('fridge.capture.started.v1', 'camera', destination);
    _pending.add(PendingPhoto(await source.capture(), destination, 'camera'));
  }, origin: 'camera');

  Future<void> chooseAlbum() => _run(() async {
    if (_pending.isNotEmpty) return;
    final destination = zone;
    _event('fridge.capture.started.v1', 'album', destination);
    _pending.addAll(
      (await source.album()).map(
        (path) => PendingPhoto(path, destination, 'album'),
      ),
    );
  }, origin: 'album');

  Future<void> retry() => _run(() async {});

  Future<void> abandon() async {
    if (busy) return;
    for (final photo in _pending) {
      if (photo.savedPath != null) {
        try {
          await source.discardSaved(photo.savedPath!);
        } catch (_) {
          /* Unreferenced private files can be cleaned later. */
        }
      }
    }
    _pending.clear();
    failed = false;
    _publish();
  }

  Future<void> _run(Future<void> Function() acquire, {String? origin}) async {
    if (busy || _closed) return;
    busy = true;
    failed = false;
    _publish();
    final destination = zone;
    var acquiring = true;
    try {
      await acquire();
      acquiring = false;
      while (_pending.isNotEmpty) {
        final photo = _pending.first;
        photo.savedPath ??= await source.persist(photo.path);
        await repository.update(
          (state) => InventoryRules.add(
            state,
            id: state.nextNumber.toString().padLeft(3, '0'),
            photoPath: photo.savedPath!,
            zone: photo.zone,
            now: clock(),
          ),
        );
        _pending.removeAt(0);
        savedCount++;
        _event(
          'fridge.inventory.added.v1',
          photo.origin,
          photo.zone,
          'success',
        );
      }
    } catch (_) {
      failed = true;
      final photo = _pending.firstOrNull;
      if (photo != null || origin != null) {
        _event(
          'fridge.inventory.added.v1',
          photo?.origin ?? origin!,
          photo?.zone ?? destination,
          acquiring ? 'read_failed' : 'save_failed',
        );
      }
    } finally {
      busy = false;
      _publish();
    }
  }

  void _event(String name, String origin, StorageZone zone, [String? result]) {
    if (_closed) return;
    emitProductEvent(onEvent, name, {
      'source': origin,
      'zone': zone.name,
      'result': ?result,
    });
  }

  void _publish() {
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
