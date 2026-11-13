import 'package:fridge_core/fridge_core.dart';

abstract interface class PhotoLibrary {
  Future<String?> replacement();
  Future<void> discardSaved(String path);
  Future<void> collectUnreferenced(Set<String> retained);
}

/// Run recovery before opening a capture/editor route: no candidate is in flight.
/// Current, undo and backup snapshots all own references to their photo files.
class PhotoLifecycle {
  final InventoryRepository repository;
  final PhotoLibrary photos;
  final Future<Set<String>> Function() snapshotReferences;
  PhotoLifecycle({
    required this.repository,
    required this.photos,
    required this.snapshotReferences,
  });

  Future<Set<String>> _retained() async => {
    ...await snapshotReferences(),
    ...repository.retainedPhotoPaths,
  };

  Future<bool> recoverOrphans() async {
    try {
      await photos.collectUnreferenced(await _retained());
      return true;
    } catch (_) {
      // A missing cleanup opportunity must not turn a valid fridge into an error.
      return false;
    }
  }

  Future<void> replace(String id) async {
    final candidate = await photos.replacement();
    if (candidate == null) return;
    try {
      await repository.update(
        (state) => InventoryRules.edit(state, id, photoPath: candidate),
      );
    } catch (_) {
      try {
        if (!(await _retained()).contains(candidate)) {
          await photos.discardSaved(candidate);
        }
      } catch (_) {
        // Retain unknown references; startup recovery can retry cleanup later.
      }
      rethrow;
    }
    // The previous photo may still belong to undo or a recovery snapshot.
    // Next startup rotates the backup, then safely collects abandoned files.
  }
}
