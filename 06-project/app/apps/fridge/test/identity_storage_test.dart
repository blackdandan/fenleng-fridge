import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge/infrastructure/identity_storage.dart';

void main() {
  test(
    'session survives a fresh adapter, corruption recovery preserves inventory and evidence',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'fridge-identity-',
      );
      try {
        final inventory = File('${directory.path}/inventory.json');
        await inventory.writeAsString('unrelated-local-inventory');
        final first = IdentityStorage(directory);
        await Future.wait([
          first.setItem('access', 'server-access'),
          first.setItem('refresh', 'server-refresh'),
        ]);
        final restored = IdentityStorage(directory);
        expect(await restored.getItem('access'), 'server-access');
        expect(await restored.getItem('refresh'), 'server-refresh');
        final file = File('${directory.path}/platform-session.json');
        await file.writeAsString('broken-json');
        final recovered = IdentityStorage(directory);
        expect(await recovered.getItem('access'), null);
        await recovered.setItem('access', 'new-server-session');
        expect(await recovered.getItem('access'), 'new-server-session');
        final evidence = await directory
            .list()
            .where((entry) => entry.path.contains('.corrupt-'))
            .toList();
        expect(evidence, hasLength(1));
        expect(await File(evidence.single.path).readAsString(), 'broken-json');
        expect(await inventory.readAsString(), 'unrelated-local-inventory');
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
