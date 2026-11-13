import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../application/capture_flow.dart';
import '../application/photo_lifecycle.dart';

String _photoKey(String path) {
  final uri = File(path).absolute.uri.normalizePath().toString();
  return Platform.isWindows ? uri.toLowerCase() : uri;
}

class CameraSession extends ChangeNotifier {
  CameraController? controller;
  bool opening = false;
  bool failed = false;
  bool _closed = false;
  int _generation = 0;
  bool _resumeRequested = false;
  final Future<bool> Function() authorize;
  CameraSession(this.authorize);

  Future<void> open() async {
    if (_closed || controller?.value.isInitialized == true) return;
    if (opening) {
      _resumeRequested = true;
      return;
    }
    opening = true;
    failed = false;
    final generation = ++_generation;
    notifyListeners();
    CameraController? candidate;
    try {
      if (!await authorize()) {
        failed = true;
        return;
      }
      if (_closed || generation != _generation) return;
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('CAMERA_UNAVAILABLE');
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      candidate = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await candidate.initialize();
      if (_closed || generation != _generation) {
        await candidate.dispose();
        return;
      }
      controller = candidate;
    } catch (_) {
      await candidate?.dispose();
      failed = true;
    } finally {
      opening = false;
      if (!_closed) notifyListeners();
      final resume = _resumeRequested;
      _resumeRequested = false;
      if (resume && !_closed) unawaited(open());
    }
  }

  Future<void> suspend() async {
    _generation++;
    final previous = controller;
    controller = null;
    await previous?.dispose();
    if (!_closed) notifyListeners();
  }

  Future<void> close() async {
    _closed = true;
    await suspend();
    super.dispose();
  }
}

class ManagedFoodPhotos implements FoodPhotoSource, PhotoLibrary {
  final Directory directory;
  final CameraSession? camera;
  final ImagePicker picker;
  ManagedFoodPhotos({required this.directory, this.camera, ImagePicker? picker})
    : picker = picker ?? ImagePicker();

  @override
  Future<String> persist(String path) async {
    final photos = Directory('${directory.path}/photos');
    await photos.create(recursive: true);
    final random = Random.secure().nextInt(0x7fffffff).toRadixString(16);
    final name = '${DateTime.now().microsecondsSinceEpoch}-$random';
    final temporary = File('${photos.path}/$name.pending');
    final destination = File('${photos.path}/$name.image');
    try {
      await XFile(path).saveTo(temporary.path);
      if (await temporary.length() == 0) throw StateError('PHOTO_EMPTY');
      await temporary.rename(destination.path);
    } catch (_) {
      try {
        if (await temporary.exists()) await temporary.delete();
      } catch (_) {}
      rethrow;
    }
    return destination.path;
  }

  @override
  Future<String> capture() async {
    final controller = camera?.controller;
    if (controller == null || !controller.value.isInitialized) {
      throw StateError('CAMERA_UNAVAILABLE');
    }
    return (await controller.takePicture()).path;
  }

  @override
  Future<List<String>> album() async {
    // Uses the OS picker. No blanket photo/storage permission is requested.
    final selected = await picker.pickMultiImage();
    return selected.map((photo) => photo.path).toList();
  }

  @override
  Future<String?> replacement() async {
    final selected = await picker.pickImage(source: ImageSource.gallery);
    return selected == null ? null : persist(selected.path);
  }

  @override
  Future<void> collectUnreferenced(Set<String> retained) async {
    final photos = Directory('${directory.path}/photos').absolute;
    if (!await photos.exists()) return;
    final references = retained.map(_photoKey).toSet();
    await for (final file in photos.list(followLinks: false)) {
      if (file is! File) continue;
      final name = file.uri.pathSegments.last;
      if (!RegExp(r'^\d+-[a-f0-9]+\.(image|pending)$').hasMatch(name)) continue;
      if (!references.contains(_photoKey(file.path))) await file.delete();
    }
  }

  @override
  Future<void> discardSaved(String path) async {
    final photo = File(path).absolute;
    final photos = Directory('${directory.path}/photos').absolute;
    if (photo.parent.path != photos.path || !photo.path.endsWith('.image')) {
      throw ArgumentError('UNMANAGED_PHOTO');
    }
    if (await photo.exists()) await photo.delete();
  }
}
