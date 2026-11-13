import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/application/bootstrap.dart';
import 'package:fridge/application/account_deletion.dart';
import 'package:fridge/application/identity_session.dart';
import 'package:fridge/infrastructure/identity_storage.dart';
import 'support/deletion_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('fenleng.fridge/bootstrap');
  late Directory directory;
  late FridgeBootstrap bootstrap;
  late DeletionHarness h;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'fridge-online-deletion-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          native,
          (call) async => switch (call.method) {
            'privacy.read' => {
              'policyVersion': 'V0.4',
              'releaseChannel': 'china',
              'acceptedAt': '2026-11-13T00:00:00Z',
            },
            'plugins.initialize' ||
            'privacy.revoke' ||
            'privacy.finishRevoke' => true,
            'data.directory' || 'privacy.directory' => directory.path,
            _ => throw PlatformException(code: 'UNEXPECTED_METHOD'),
          },
        );
    bootstrap = FridgeBootstrap();
    await bootstrap.initialize();
    await bootstrap.deletion?.close();
    bootstrap.deletion?.dispose();
    await bootstrap.identity?.close();
    bootstrap.identity?.dispose();
    h = DeletionHarness(
      storage: IdentityStorage(directory),
      sessionGate: () => bootstrap.onlineSessionMutable,
    );
    await h.start();
    bootstrap.identity = h.identity;
    bootstrap.deletion = h.model;
  });
  tearDown(() async {
    h.holdDelete?.complete();
    await bootstrap.localReminders?.close();
    await bootstrap.inventory?.close();
    await h.model.close();
    await h.identity.close();
    bootstrap.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(native, null);
    expect(
      directory.parent.resolveSymbolicLinksSync(),
      Directory.systemTemp.resolveSymbolicLinksSync(),
    );
    expect(
      directory.uri.pathSegments.where((p) => p.isNotEmpty).last,
      startsWith('fridge-online-deletion-'),
    );
    await directory.delete(recursive: true);
  });
  test(
    'bootstrap cancellation closes old feedback safely and unlocks identity without proof',
    () async {
      final previous = bootstrap.feedback;
      await bootstrap.deleteAccount(() async => false);
      expect(h.deletes, 0);
      expect(h.proof.calls, 0);
      expect(h.journal.entries, isEmpty);
      expect(bootstrap.feedback, isNot(same(previous)));
      expect(bootstrap.onlineSessionMutable, isTrue);
      expect(await h.tokens.getItem('access'), 'original-access');
    },
  );
  test(
    'bootstrap known receipt failure suppresses identity restore and explicit login until local retry',
    () async {
      h.journal.failReceipt = true;
      await bootstrap.deleteAccount(() async => true);
      expect(h.model.receiptIncomplete, isTrue);
      expect(bootstrap.onlineSessionMutable, isFalse);
      final calls = h.requests.length, proofs = h.proof.calls;
      await h.identity.ensureSession();
      await bootstrap.loginAccount(IdentityProvider.wechat);
      bootstrap.onlineLifecycle(false);
      bootstrap.onlineLifecycle(true);
      expect(h.requests.length, calls);
      expect(h.proof.calls, proofs);
      expect(await h.tokens.getItem('access'), 'original-access');
      h.journal.failReceipt = false;
      await bootstrap.retryDeletionReceipt();
      expect(h.deletes, 1);
      expect(h.model.receiptIncomplete, isFalse);
      expect(await h.tokens.getItem('access'), isNull);
      expect(bootstrap.onlineSessionMutable, isTrue);
    },
  );
  test(
    'actual bootstrap withdrawal fences a held DELETE and retains inventory and photo bytes',
    () async {
      final stock = File('${directory.path}/inventory-sentinel');
      await stock.writeAsString('original');
      final photo = File('${directory.path}/photo-sentinel');
      await photo.writeAsBytes([4, 5, 6]);
      final held = Completer<void>();
      h.holdDelete = held;
      final deleting = bootstrap.deleteAccount(() async => true);
      for (var i = 0; i < 100 && h.deletes == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(h.deletes, 1);
      expect(h.journal.entries.single.phase, DeletionPhase.submitting);
      await bootstrap.withdrawPrivacy();
      expect(bootstrap.stage, BootstrapStage.consent);
      expect(bootstrap.deletion, isNull);
      held.complete();
      h.holdDelete = null;
      await deleting;
      expect(h.journal.entries.single.phase, DeletionPhase.submitting);
      expect(await IdentityStorage(directory).getItem('access'), isNull);
      expect(await stock.readAsString(), 'original');
      expect(await photo.readAsBytes(), [4, 5, 6]);
      expect(h.requests.any((r) => r.url.path.endsWith('/logout')), isFalse);
    },
  );
}
