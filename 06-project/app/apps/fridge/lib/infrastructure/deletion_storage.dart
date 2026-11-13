import 'dart:convert';
import 'dart:io';
import '../application/account_deletion.dart';

/// App-private journal, independent of photos, inventory and session credentials.
class FileDeletionStorage implements DeletionStorage {
  final Directory directory;
  Future<void> _tail = Future.value();
  FileDeletionStorage(this.directory);
  File get _file => File('${directory.path}/account-deletion.json');

  static Map<String, Object?> _encode(DeletionEntry entry) => {
    'owner': entry.owner,
    'key': entry.key,
    'phase': entry.phase.name,
    'receipt': entry.receipt == null
        ? null
        : {
            'id': entry.receipt!.id,
            'requestedAt': entry.receipt!.requestedAt,
            'eligibleAt': entry.receipt!.eligibleAt,
          },
  };
  static List<DeletionEntry> _decode(Object? value) {
    const failure = FormatException('DELETION_JOURNAL_INVALID');
    if (value is! Map || value['version'] != 1 || value['entries'] is! List) {
      throw failure;
    }
    final owners = <String>{};
    return (value['entries'] as List).map((raw) {
      if (raw is! Map || raw['owner'] is! String || raw['key'] is! String) {
        throw failure;
      }
      final owner = raw['owner'] as String, key = raw['key'] as String;
      final scope = jsonDecode(owner);
      if (owner.length > 1024 ||
          scope is! List ||
          scope.length != 3 ||
          scope.any(
            (part) => part is! String || part.isEmpty || part.length > 512,
          ) ||
          !owners.add(owner) ||
          !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$').hasMatch(key)) {
        throw failure;
      }
      final phase = DeletionPhase.values
          .where((p) => p.name == raw['phase'])
          .firstOrNull;
      if (phase == null) throw failure;
      final receipt = raw['receipt'];
      DeletionReceipt? parsed;
      if (receipt != null) {
        if (receipt is! Map ||
            receipt['id'] is! String ||
            receipt['requestedAt'] is! String ||
            receipt['eligibleAt'] is! String) {
          throw failure;
        }
        parsed = DeletionReceipt(
          receipt['id'] as String,
          receipt['requestedAt'] as String,
          receipt['eligibleAt'] as String,
        );
        if (!parsed.valid) throw failure;
      }
      if (phase == DeletionPhase.accepted && parsed == null ||
          ![DeletionPhase.accepted, DeletionPhase.cancelled].contains(phase) &&
              parsed != null) {
        throw failure;
      }
      return DeletionEntry(owner, key, phase, parsed);
    }).toList();
  }

  Future<List<DeletionEntry>> _read() async {
    if (!await _file.exists()) return [];
    // Corruption is surfaced and preserved, never treated as an empty journal.
    return _decode(jsonDecode(await _file.readAsString()));
  }

  @override
  Future<List<DeletionEntry>> load() async {
    await _tail;
    return _read();
  }

  @override
  Future<void> save(List<DeletionEntry> entries) {
    final value = {'version': 1, 'entries': entries.map(_encode).toList()};
    _decode(value);
    final next = _tail.then((_) async {
      await _read();
      await directory.create(recursive: true);
      final pending = File('${_file.path}.pending');
      await pending.writeAsString(jsonEncode(value), flush: true);
      await pending.rename(_file.path);
    });
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}
