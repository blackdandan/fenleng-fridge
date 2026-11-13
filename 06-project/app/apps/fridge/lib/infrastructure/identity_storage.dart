import 'dart:convert';
import 'dart:io';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';

/// Application-private durable storage, separate from inventory and photos.
class IdentityStorage implements FenlengStorageAdapter {
  final Directory directory;
  Future<void> _tail = Future.value();
  bool _preservedCorruption = false;
  bool _revoked = false;
  IdentityStorage(this.directory);

  File get _file => File('${directory.path}/platform-session.json');
  Future<Map<String, String>> _read() async {
    if (!await _file.exists()) return {};
    try {
      final value = jsonDecode(await _file.readAsString());
      if (value is! Map || value.values.any((value) => value is! String)) {
        throw const FormatException('SESSION_STORAGE_INVALID');
      }
      return Map<String, String>.from(value);
    } on FormatException {
      if (!_preservedCorruption) {
        await _file.copy(
          '${_file.path}.corrupt-${DateTime.now().microsecondsSinceEpoch}',
        );
        _preservedCorruption = true;
      }
      // A malformed session requires fresh login; inventory remains separate.
      return {};
    }
  }

  @override
  Future<String?> getItem(String key) async {
    await _tail;
    if (_revoked) return null;
    return (await _read())[key];
  }

  Future<void> _write(void Function(Map<String, String>) change) {
    final next = _tail.then((_) async {
      if (_revoked) throw StateError('SESSION_REVOKED');
      final values = await _read();
      change(values);
      await directory.create(recursive: true);
      final pending = File('${_file.path}.pending');
      await pending.writeAsString(jsonEncode(values), flush: true);
      if (_revoked) throw StateError('SESSION_REVOKED');
      await pending.rename(_file.path);
    });
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  @override
  Future<void> setItem(String key, String value) =>
      _write((values) => values[key] = value);
  @override
  Future<void> removeItem(String key) =>
      _revoked ? Future.value() : _write((values) => values.remove(key));

  /// Fence late SDK writes before the native consent intent is committed.
  Future<void> sealForWithdrawal() async {
    _revoked = true;
    await _tail;
  }

  /// Recovery only overwrites the managed active session; never reads inventory.
  static Future<void> clearRevokedSession(Directory directory) async {
    final file = File('${directory.path}/platform-session.json');
    final pending = File('${file.path}.pending');
    if (await file.exists()) {
      final replacing = File('${file.path}.revoking');
      await replacing.writeAsString('{}', flush: true);
      await replacing.rename(file.path);
    }
    if (await pending.exists()) await pending.delete();
  }
}
