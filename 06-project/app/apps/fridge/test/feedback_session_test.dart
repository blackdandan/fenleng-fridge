import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/application/feedback_session.dart';
import 'package:fridge/infrastructure/feedback_draft_storage.dart';
import 'support/feedback_fixture.dart';

void main() {
  late DraftMemory storage;
  late FeedbackSender gateway;
  late FeedbackSession session;
  var allowed = true, sequence = 0;
  setUp(() {
    storage = DraftMemory();
    gateway = FeedbackSender();
    allowed = true;
    sequence = 0;
    session = FeedbackSession(
      storage: storage,
      gateway: gateway,
      consent: () => allowed,
      nextKey: () => 'feedback-key-${++sequence}',
    );
  });
  tearDown(() async {
    await session.close();
    session.dispose();
  });
  test('empty and over-limit UTF16 payloads never submit', () async {
    await session.start();
    await session.edit('   ');
    await session.submit();
    expect(session.errorKey, 'feedbackValidation');
    await session.edit(List.filled(2001, '🍅').join());
    await session.submit();
    expect(session.errorKey, 'feedbackValidation');
    expect(gateway.calls, isEmpty);
  });
  test(
    'duplicate taps share one request and only a durable receipt clears the draft',
    () async {
      await session.start();
      await session.edit('  useful feedback  ');
      final gate = Completer<String>();
      gateway.send = (_, _) => gate.future;
      final first = session.submit(), duplicate = session.submit();
      await Future<void>.delayed(Duration.zero);
      expect(gateway.calls, [(text: 'useful feedback', key: 'feedback-key-1')]);
      expect(storage.value.text, '  useful feedback  ');
      expect(storage.value.key, 'feedback-key-1');
      await session.edit('blocked edit while sending');
      expect(session.text, '  useful feedback  ');
      gate.complete('real-server-receipt');
      await Future.wait([first, duplicate]);
      expect(session.receipt, 'real-server-receipt');
      expect(session.text, '');
      expect(storage.value, (
        text: '',
        key: null,
        receipt: 'real-server-receipt',
      ));
    },
  );
  test(
    'transport failure and whitespace-only edits retain the key; new content uses a new key',
    () async {
      await session.start();
      await session.edit('suggestion');
      gateway.send = (_, _) async =>
          throw const SocketException('private network details');
      await session.submit();
      expect(session.errorKey, 'feedbackFailed');
      expect(session.text, 'suggestion');
      await session.edit('suggestion  ');
      expect(session.requestKey, 'feedback-key-1');
      gateway.send = (_, _) async => 'receipt-1';
      await session.submit();
      expect(gateway.calls.map((c) => c.key), [
        'feedback-key-1',
        'feedback-key-1',
      ]);
      await session.writeAnother();
      await session.edit('different suggestion');
      await session.submit();
      expect(gateway.calls.last.key, 'feedback-key-2');
    },
  );
  test('draft persistence failure blocks network and can be retried', () async {
    await session.start();
    await session.edit('suggestion');
    storage.failWrite = true;
    await session.submit();
    expect(session.errorKey, 'feedbackDraftSaveFailed');
    expect(gateway.calls, isEmpty);
    storage.failWrite = false;
    await session.submit();
    expect(session.receipt, 'receipt-1');
  });
  test(
    'receipt write failure retains the original payload/key for safe retry',
    () async {
      await session.start();
      await session.edit('suggestion');
      gateway.send = (_, _) async {
        storage.failWrite = true;
        return 'receipt-1';
      };
      await session.submit();
      expect(session.receipt, isNull);
      expect(session.text, 'suggestion');
      expect(storage.value.key, 'feedback-key-1');
      expect(session.errorKey, 'feedbackDraftSaveFailed');
      storage.failWrite = false;
      gateway.send = (_, _) async => 'receipt-1';
      await session.submit();
      expect(gateway.calls.map((c) => c.key), [
        'feedback-key-1',
        'feedback-key-1',
      ]);
      expect(session.receipt, 'receipt-1');
      expect(session.errorKey, isNull);
    },
  );
  test(
    'empty receipt is never success and feedback remains separate from consent',
    () async {
      await session.start();
      await session.edit('suggestion');
      gateway.send = (_, _) async => '';
      await session.submit();
      expect(session.receipt, isNull);
      expect(session.text, 'suggestion');
      allowed = false;
      await session.submit();
      expect(gateway.calls, hasLength(1));
      expect(session.errorKey, 'feedbackUnavailable');
    },
  );
  test(
    'failed draft load prevents edits until retry recovers the original',
    () async {
      storage.value = (
        text: 'saved draft',
        key: 'persisted-key',
        receipt: null,
      );
      storage.failLoad = true;
      await session.start();
      await session.edit('must not overwrite');
      await session.submit();
      expect(session.initialized, false);
      expect(gateway.calls, isEmpty);
      expect(storage.value.text, 'saved draft');
      storage.failLoad = false;
      await session.start();
      expect(session.text, 'saved draft');
      expect(session.requestKey, 'persisted-key');
    },
  );
  test(
    'real disk restart restores failed request key and later persists receipt',
    () async {
      final dir = await Directory.systemTemp.createTemp('fridge-feedback-');
      try {
        final disk = FileFeedbackDraftStorage(dir);
        final first = FeedbackSession(
          storage: disk,
          gateway: gateway,
          consent: () => true,
          nextKey: () => 'stable-disk-key',
        );
        await first.start();
        await first.edit('survives restart');
        gateway.send = (_, _) async => throw StateError('offline');
        await first.submit();
        await first.close();
        first.dispose();
        final second = FeedbackSession(
          storage: disk,
          gateway: gateway,
          consent: () => true,
          nextKey: () => throw StateError('must reuse key'),
        );
        await second.start();
        expect(second.text, 'survives restart');
        expect(second.requestKey, 'stable-disk-key');
        gateway.send = (_, _) async => 'receipt-from-server';
        await second.submit();
        await second.close();
        second.dispose();
        expect((await disk.load()).receipt, 'receipt-from-server');
        expect((await disk.load()).text, '');
        expect(gateway.calls.map((c) => c.key), [
          'stable-disk-key',
          'stable-disk-key',
        ]);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
}
