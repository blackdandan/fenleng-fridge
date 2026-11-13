import 'package:flutter_test/flutter_test.dart';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';

class FailingOnceStorage extends FenlengMemoryStorageAdapter {
  bool failNextWrite = true;
  @override
  Future<void> setItem(String key, String value) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('storage unavailable');
    }
    await super.setItem(key, value);
  }
}

void main() {
  test('failed persistence is reported and does not poison later writes',
      () async {
    final store = FlutterPaymentRecoveryStore(
        storage: FailingOnceStorage(), applicationId: 'app');
    await expectLater(
        store.save('user', const PaymentRecoveryRecord('order-1', 'attempt-1')),
        throwsStateError);
    await store.save(
        'user', const PaymentRecoveryRecord('order-2', 'attempt-2'));
    expect((await store.pending('user')).single.orderId, 'order-2');
  });

  test('recovery survives store recreation and isolates accounts and orders',
      () async {
    final storage = FenlengMemoryStorageAdapter();
    final store =
        FlutterPaymentRecoveryStore(storage: storage, applicationId: 'app');
    await Future.wait([
      store.save('user-a', const PaymentRecoveryRecord('order-1', 'attempt-1')),
      store.save('user-a', const PaymentRecoveryRecord('order-2', 'attempt-2')),
    ]);
    final restarted =
        FlutterPaymentRecoveryStore(storage: storage, applicationId: 'app');
    expect((await restarted.read('user-a', 'order-1'))?.paymentAttemptId,
        'attempt-1');
    expect(await restarted.read('user-b', 'order-1'), isNull);
    expect((await restarted.pending('user-a')).map((r) => r.orderId),
        ['order-1', 'order-2']);
    expect(await restarted.pending('user-b'), isEmpty);
    await restarted.remove('user-a', 'order-1');
    expect(await restarted.read('user-a', 'order-1'), isNull);
    expect((await restarted.read('user-a', 'order-2'))?.paymentAttemptId,
        'attempt-2');
  });
}
