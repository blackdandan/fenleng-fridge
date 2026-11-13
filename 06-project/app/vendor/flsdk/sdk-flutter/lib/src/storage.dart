/// Storage Adapter Specification for Fenleng SDK
abstract class FenlengStorageAdapter {
  Future<String?> getItem(String key);
  Future<void> setItem(String key, String value);
  Future<void> removeItem(String key);
}

/// In-memory Storage Adapter fallback
class FenlengMemoryStorageAdapter implements FenlengStorageAdapter {
  final Map<String, String> _store = {};

  @override
  Future<String?> getItem(String key) async {
    return _store[key];
  }

  @override
  Future<void> setItem(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> removeItem(String key) async {
    _store.remove(key);
  }
}
