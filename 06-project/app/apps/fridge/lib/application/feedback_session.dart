import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'product_event.dart';

typedef FeedbackDraft = ({String text, String? key, String? receipt});

abstract interface class FeedbackDraftStorage {
  Future<FeedbackDraft> load();
  Future<void> save(FeedbackDraft value);
}

abstract interface class FeedbackGateway {
  Future<String> submit(String message, String idempotencyKey);
}

class FeedbackFailure implements Exception {
  final String key;
  const FeedbackFailure(this.key);
}

/// The same payload keeps its persisted key across transport failures/restarts.
/// Only a server receipt followed by a durable local write clears its draft.
class FeedbackSession extends ChangeNotifier {
  final FeedbackDraftStorage storage;
  final FeedbackGateway gateway;
  final bool Function() consent;
  final String Function() nextKey;
  final ProductEvent? onEvent;
  String text = '';
  String? requestKey, receipt, errorKey;
  bool loading = true, busy = false, initialized = false, _closed = false;
  Future<void>? _starting, _submission;
  Future<void> _writes = Future.value();
  int _editRevision = 0;
  FeedbackSession({
    required this.storage,
    required this.gateway,
    required this.consent,
    String Function()? nextKey,
    this.onEvent,
  }) : nextKey =
           nextKey ??
           (() =>
               'fridge-feedback-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff).toRadixString(16)}');
  void _notify() {
    if (!_closed) notifyListeners();
  }

  Future<void> start() {
    if (_closed || initialized) return Future.value();
    if (_starting case final operation?) return operation;
    loading = true;
    errorKey = null;
    final operation = Future<void>(() async {
      try {
        final value = await storage.load();
        text = value.text;
        requestKey = value.key;
        receipt = value.receipt;
        initialized = true;
      } catch (_) {
        errorKey = 'feedbackDraftLoadFailed';
      } finally {
        loading = false;
        _notify();
      }
    });
    _starting = operation;
    _notify();
    return operation.whenComplete(() => _starting = null);
  }

  Future<void> _persist(FeedbackDraft value) {
    final operation = _writes.then((_) => storage.save(value));
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> edit(String value) async {
    if (_closed || !initialized || busy || receipt != null || value == text) {
      return;
    }
    final samePayload = text.trim() == value.trim();
    text = value;
    if (!samePayload) requestKey = null;
    final revision = ++_editRevision;
    errorKey = null;
    _notify();
    try {
      await _persist((text: text, key: requestKey, receipt: null));
    } catch (_) {
      if (revision == _editRevision && !busy && receipt == null) {
        errorKey = 'feedbackDraftSaveFailed';
        _notify();
      }
    }
  }

  Future<void> submit() {
    if (_closed || !initialized || receipt != null) return Future.value();
    if (busy) return _submission ?? Future.value();
    final message = text.trim();
    if (message.isEmpty || message.length > 4000) {
      errorKey = 'feedbackValidation';
      _notify();
      return Future.value();
    }
    busy = true;
    errorKey = null;
    final operation = Future<void>(() async {
      try {
        if (!consent()) throw const FeedbackFailure('feedbackUnavailable');
        requestKey ??= nextKey();
        try {
          await _persist((text: text, key: requestKey, receipt: null));
        } catch (_) {
          throw const FeedbackFailure('feedbackDraftSaveFailed');
        }
        if (!consent()) throw const FeedbackFailure('feedbackUnavailable');
        final accepted = await gateway.submit(message, requestKey!);
        if (!consent()) throw const FeedbackFailure('feedbackUnavailable');
        if (accepted.trim().isEmpty || accepted.length > 128) {
          throw const FeedbackFailure('feedbackFailed');
        }
        try {
          await _persist((text: '', key: null, receipt: accepted));
        } catch (_) {
          throw const FeedbackFailure('feedbackDraftSaveFailed');
        }
        text = '';
        requestKey = null;
        receipt = accepted;
        errorKey = null;
        _event('success');
      } on FeedbackFailure catch (failure) {
        errorKey = failure.key;
        _event(
          failure.key.startsWith('feedbackDraft')
              ? 'storage_failed'
              : failure.key == 'feedbackUnavailable' ||
                    failure.key == 'feedbackSessionUnavailable'
              ? 'identity_unavailable'
              : 'submit_failed',
        );
      } catch (_) {
        errorKey = 'feedbackFailed';
        _event('submit_failed');
      } finally {
        busy = false;
        _notify();
      }
    });
    _submission = operation;
    _notify();
    return operation;
  }

  Future<void> writeAnother() async {
    if (_closed || busy || receipt == null) return;
    busy = true;
    errorKey = null;
    _notify();
    try {
      await _persist((text: '', key: null, receipt: null));
      receipt = null;
      text = '';
      requestKey = null;
    } catch (_) {
      errorKey = 'feedbackDraftSaveFailed';
    } finally {
      busy = false;
      _notify();
    }
  }

  void _event(String result) {
    if (!_closed && consent()) {
      emitProductEvent(onEvent, 'fridge.feedback.submitted.v1', {
        'result': result,
      });
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _starting;
    await _submission;
    await _writes;
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }
}
