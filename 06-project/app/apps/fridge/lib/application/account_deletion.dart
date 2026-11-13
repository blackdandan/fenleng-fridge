import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

enum DeletionPhase { prepared, submitting, unknown, accepted, cancelled }

/// Preserve the server's exact timestamp, including Java Instant nanoseconds.
DateTime? deletionInstant(String value) {
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,9}))?Z$',
  ).firstMatch(value);
  if (match == null) return null;
  final parts = List.generate(6, (i) => int.parse(match.group(i + 1)!));
  final date = DateTime.tryParse(value);
  if (date == null ||
      !listEquals(parts, [
        date.year,
        date.month,
        date.day,
        date.hour,
        date.minute,
        date.second,
      ])) {
    return null;
  }
  return date;
}

class DeletionReceipt {
  final String id, requestedAt, eligibleAt;
  const DeletionReceipt(this.id, this.requestedAt, this.eligibleAt);
  bool get valid {
    final requested = deletionInstant(requestedAt);
    final eligible = deletionInstant(eligibleAt);
    return RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$').hasMatch(id) &&
        requested != null &&
        eligible != null &&
        eligible.difference(requested) >= const Duration(days: 7);
  }
}

class DeletionEntry {
  final String owner, key;
  final DeletionPhase phase;
  final DeletionReceipt? receipt;
  const DeletionEntry(this.owner, this.key, this.phase, [this.receipt]);
  DeletionEntry withPhase(DeletionPhase next) =>
      DeletionEntry(owner, key, next, receipt);
}

abstract interface class DeletionStorage {
  Future<List<DeletionEntry>> load();
  Future<void> save(List<DeletionEntry> entries);
}

abstract interface class DeletionContext {
  String get owner;
  bool get current;
  Future<String> challenge(String key);
  Future<String> authorize();
  Future<String> confirm(String challenge, String proof, String key);
  Future<void> stopReminders();
  Future<DeletionReceipt> submit(String key, String confirmation);

  /// Local-only cleanup, fenced against any subsequently established identity.
  Future<void> finish();
  void cancel();
}

abstract interface class DeletionGateway {
  /// Read the existing human identity; never create a guest or start a login.
  Future<DeletionContext> open();
}

class DeletionFailure implements Exception {
  final String key;
  const DeletionFailure(this.key);
}

/// The journal records server ACKs, never inferred success from a logout/401.
class AccountDeletionSession extends ChangeNotifier {
  final DeletionStorage storage;
  final DeletionGateway gateway;
  final bool Function() consent;
  final String Function() nextKey;
  List<DeletionEntry> _entries = [];
  DeletionEntry? entry;
  bool loading = true, initialized = false, busy = false;
  bool durable = true, cleanupPending = false;
  String? errorKey;
  bool _closed = false;
  int _generation = 0;
  Future<void>? _starting, _operation;
  DeletionContext? _context;
  Future<void> Function()? _pendingFinish;
  AccountDeletionSession({
    required this.storage,
    required this.gateway,
    required this.consent,
    String Function()? nextKey,
  }) : nextKey =
           nextKey ??
           (() =>
               'fridge-delete-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff).toRadixString(16)}');

  bool get receiptIncomplete =>
      entry?.phase == DeletionPhase.accepted && (!durable || cleanupPending);
  void _notify() {
    if (!_closed) notifyListeners();
  }

  void _gate(int generation, [DeletionContext? context]) {
    if (_closed ||
        !consent() ||
        generation != _generation ||
        context != null && !context.current) {
      throw const DeletionFailure('deletionCancelled');
    }
  }

  Future<void> start() {
    if (_closed || initialized) return Future.value();
    if (_starting case final starting?) return starting;
    final generation = _generation;
    loading = true;
    return _starting = Future<void>(() async {
      try {
        _gate(generation);
        final loaded = await storage.load();
        _gate(generation);
        _entries = loaded
            .map(
              (value) => value.phase == DeletionPhase.submitting
                  ? value.withPhase(DeletionPhase.unknown)
                  : value,
            )
            .toList();
        entry = _entries.lastOrNull;
        initialized = true;
        errorKey = null;
      } catch (error) {
        errorKey = error is DeletionFailure
            ? error.key
            : 'deletionStorageFailed';
      } finally {
        loading = false;
        _notify();
      }
    }).whenComplete(() => _starting = null);
  }

  Future<void> _save(DeletionEntry value, int generation) async {
    _gate(generation);
    final next = [
      ..._entries.where((item) => item.owner != value.owner),
      value,
    ];
    try {
      await storage.save(List.unmodifiable(next));
    } catch (_) {
      throw const DeletionFailure('deletionStorageFailed');
    }
    _gate(generation);
    _entries = next;
    entry = value;
    durable = true;
    _notify();
  }

  Future<void> _run(Future<void> Function(int) action) {
    if (_closed) return Future.value();
    if (_operation case final operation?) return operation;
    final generation = _generation;
    busy = true;
    errorKey = null;
    final operation = Future<void>(() async {
      try {
        await start();
        _gate(generation);
        if (!initialized) throw const DeletionFailure('deletionStorageFailed');
        await action(generation);
      } catch (error) {
        errorKey = error is DeletionFailure ? error.key : 'deletionFailed';
      } finally {
        _context?.cancel();
        _context = null;
        busy = false;
        _notify();
      }
    }).whenComplete(() => _operation = null);
    _operation = operation;
    _notify();
    return operation;
  }

  Future<void> submit(Future<bool> Function() confirmVisible) {
    if (receiptIncomplete) return retryReceipt();
    return _run((generation) async {
      final context = await gateway.open();
      _context = context;
      _gate(generation, context);
      var original = _entries
          .where((e) => e.owner == context.owner)
          .firstOrNull;
      if (original?.phase == DeletionPhase.accepted) {
        original = original!.withPhase(DeletionPhase.cancelled);
        await _save(original, generation);
      }
      entry = original;
      durable = true;
      _notify();
      if (!await confirmVisible()) return;
      _gate(generation, context);
      final key = original != null && original.phase != DeletionPhase.cancelled
          ? original.key
          : nextKey();
      var pending = DeletionEntry(
        context.owner,
        key,
        original?.phase == DeletionPhase.unknown
            ? DeletionPhase.unknown
            : DeletionPhase.prepared,
      );
      await _save(pending, generation);
      _gate(generation, context);
      final challenge = await context.challenge(key);
      _gate(generation, context);
      final proof = await context.authorize();
      _gate(generation, context);
      final confirmation = await context.confirm(challenge, proof, key);
      _gate(generation, context);
      await context.stopReminders();
      _gate(generation, context);
      pending = pending.withPhase(DeletionPhase.submitting);
      await _save(pending, generation);
      _gate(generation, context);
      DeletionReceipt receipt;
      try {
        receipt = await context.submit(key, confirmation);
        // A concurrent401 may invalidate the original session after server ACK.
        // Consent and generation still fence persistence; current is not required.
        _gate(generation);
        if (!receipt.valid) throw const DeletionFailure('deletionUnknown');
      } catch (error) {
        pending = pending.withPhase(DeletionPhase.unknown);
        entry = pending;
        if (!_closed && consent() && generation == _generation) {
          await _save(pending, generation);
        }
        throw error is DeletionFailure && error.key == 'deletionCancelled'
            ? error
            : const DeletionFailure('deletionUnknown');
      }
      pending = DeletionEntry(
        context.owner,
        key,
        DeletionPhase.accepted,
        receipt,
      );
      entry = pending;
      durable = false;
      cleanupPending = true;
      _pendingFinish = context.finish;
      _notify();
      await _save(pending, generation);
      _gate(generation);
      await _finish();
    });
  }

  Future<void> retryReceipt() => _run((generation) async {
    final value = entry;
    if (value == null || value.phase != DeletionPhase.accepted) return;
    await _save(value, generation);
    _gate(generation);
    await _finish();
  });

  Future<void> refreshOwner({bool afterLogin = false}) {
    if (afterLogin && _operation != null) {
      return _operation!.then((_) => refreshOwner(afterLogin: true));
    }
    return _run((generation) async {
      final context = await gateway.open();
      _context = context;
      _gate(generation, context);
      final value = _entries.where((e) => e.owner == context.owner).firstOrNull;
      if (value != null &&
          (value.phase == DeletionPhase.accepted ||
              afterLogin &&
                  [
                    DeletionPhase.unknown,
                    DeletionPhase.submitting,
                  ].contains(value.phase))) {
        await _save(value.withPhase(DeletionPhase.cancelled), generation);
      } else {
        entry = value;
        durable = true;
        _notify();
      }
    });
  }

  Future<void> _finish() async {
    try {
      await _pendingFinish?.call();
      _pendingFinish = null;
      cleanupPending = false;
      _notify();
    } catch (_) {
      throw const DeletionFailure('deletionCleanupFailed');
    }
  }

  void freeze() {
    ++_generation;
    _context?.cancel();
  }

  Future<void> close() async {
    _closed = true;
    freeze();
    _pendingFinish = null;
    await _starting;
    await _operation;
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }
}
