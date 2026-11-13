import 'dart:async';
import 'dart:convert';
import 'inventory.dart';

abstract interface class InventoryStorage {
  Future<InventoryState?> load();

  /// Must atomically commit the snapshot or leave the previous one intact.
  Future<void> save(InventoryState state);
}

/// Serializes read/modify/write operations; failed persistence never publishes a
/// successful state. The UI retains its action/draft for an explicit retry.
class InventoryRepository {
  final InventoryStorage storage;
  final DateTime Function() clock;
  InventoryState _state = InventoryState();
  InventoryState? _undo;
  Future<void> _tail = Future.value();
  bool _loaded = false;
  int _revision = 0;
  final _changes = StreamController<InventoryState>.broadcast(sync: true);
  InventoryRepository(this.storage, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  InventoryState get state => _state;
  bool get canUndo => _undo != null;
  int get revision => _revision;
  Set<String> get retainedPhotoPaths => {
    for (final food in _state.foods.values) food.photoPath,
    if (_undo != null)
      for (final food in _undo!.foods.values) food.photoPath,
  };
  Stream<InventoryState> get changes => _changes.stream;

  Future<void> _serialize(Future<void> Function() action) {
    final operation = _tail.then((_) => action());
    _tail = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> open() => _serialize(() async {
    if (_loaded) return;
    final loaded = await storage.load() ?? InventoryState();
    final current = InventoryRules.collectDue(loaded, clock());
    await storage.save(current);
    _state = current;
    _loaded = true;
    _revision++;
    _changes.add(_state);
  });

  Future<void> update(
    InventoryState Function(InventoryState) operation, {
    bool undoable = true,
    bool invalidateUndo = false,
  }) => _serialize(() async {
    if (!_loaded) throw StateError('INVENTORY_NOT_OPEN');
    final next = InventoryRules.collectDue(operation(_state), clock());
    await storage.save(next);
    if (undoable)
      _undo = _state;
    else if (invalidateUndo)
      _undo = null;
    _state = next;
    _revision++;
    _changes.add(_state);
  });

  Future<void> refreshDue() => _serialize(() async {
    if (!_loaded) throw StateError('INVENTORY_NOT_OPEN');
    final next = InventoryRules.collectDue(_state, clock());
    if (jsonEncode(next.toJson()) == jsonEncode(_state.toJson())) return;
    await storage.save(next);
    _state = next;
    _undo = null;
    _revision++;
    _changes.add(_state);
  });

  Future<void> undo({int? expectedRevision}) => _serialize(() async {
    if (expectedRevision != null && expectedRevision != _revision) {
      throw StateError('UNDO_STATE_CHANGED');
    }
    final previous = _undo;
    if (previous == null) return;
    final next = InventoryRules.collectDue(
      previous.copyWith(
        nextNumber: previous.nextNumber > _state.nextNumber
            ? previous.nextNumber
            : _state.nextNumber,
      ),
      clock(),
    );
    await storage.save(next);
    _state = next;
    _undo = null;
    _revision++;
    _changes.add(_state);
  });

  Future<void> close() async {
    await _tail;
    await _changes.close();
  }
}
