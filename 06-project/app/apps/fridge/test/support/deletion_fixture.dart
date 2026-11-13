import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';
import 'package:fridge/application/account_deletion.dart';
import 'package:fridge/application/identity_session.dart';
import 'package:fridge/infrastructure/platform_identity.dart';
import 'package:fridge/infrastructure/platform_deletion.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class DeletionJournal implements DeletionStorage {
  List<DeletionEntry> entries = [];
  bool failReceipt = false;
  @override
  Future<List<DeletionEntry>> load() async => entries;
  @override
  Future<void> save(List<DeletionEntry> values) async {
    if (failReceipt && values.last.phase == DeletionPhase.accepted) {
      throw StateError('synthetic quota');
    }
    entries = List.of(values);
  }
}

class DeletionProof implements IdentityAuthorization {
  int calls = 0;
  @override
  Future<String> authorize(IdentityProvider provider) async {
    calls++;
    return 'fresh-native-proof';
  }
}

class DeletionHarness {
  final journal = DeletionJournal(), proof = DeletionProof();
  final FenlengStorageAdapter tokens;
  final requests = <http.Request>[];
  late final PlatformIdentityBackend backend;
  late final IdentitySession identity;
  late final AccountDeletionSession model;
  bool consent = true, unknown = false;
  int next = 0;
  Completer<void>? holdDelete;
  IdentityProvider provider = IdentityProvider.wechat;
  DeletionHarness({
    FenlengStorageAdapter? storage,
    bool Function()? sessionGate,
  }) : tokens = storage ?? FenlengMemoryStorageAdapter() {
    final client = FenlengFlutterClient(
      options: FenlengClientOptions(
        baseUrl: 'https://platform.example.test',
        storage: tokens,
        tokenKey: 'access',
        httpClient: MockClient((request) async {
          requests.add(request);
          final path = request.url.path;
          if (path.endsWith('/data-requests')) {
            await holdDelete?.future;
            if (unknown) throw StateError('synthetic response loss');
            return http.Response(
              jsonEncode({
                'id': 'request-one',
                'userId': 'user-one',
                'type': 'DELETE',
                'status': 'PENDING',
                'requestedAt': '2030-01-01T00:00:00Z',
                'nextAttemptAt': '2030-01-08T00:00:00Z',
              }),
              200,
            );
          }
          final data = path.endsWith('/me')
              ? {'id': 'user-one', 'kind': 'HUMAN', 'status': 'ACTIVE'}
              : path.endsWith('/challenges')
              ? {
                  'challengeId': 'fdc-test',
                  'provider': jsonDecode(request.body)['provider'],
                  'expiresAt': '2030-01-01T00:05:00Z',
                }
              : path.endsWith('/confirm')
              ? {
                  'confirmationId': 'fdc-test',
                  'deletionIdempotencyKey': journal.entries.last.key,
                  'expiresAt': '2030-01-01T00:05:00Z',
                }
              : path.endsWith('/login')
              ? {'accessToken': 'new-access', 'refreshToken': 'new-refresh'}
              : throw StateError('Unexpected SDK request');
          return http.Response(jsonEncode(data), 200);
        }),
      ),
    );
    backend = PlatformIdentityBackend(
      Directory.systemTemp,
      const PlatformIdentityConfig(clientId: 'fenleng-fridge-android'),
      client: client,
    );
    identity = IdentitySession(
      backend: backend,
      authorization: proof,
      consent: () => consent,
      configured: true,
      canChangeSession: () =>
          !model.busy &&
          !model.receiptIncomplete &&
          (sessionGate?.call() ?? true),
    );
    identity.signedIn = true;
    model = AccountDeletionSession(
      storage: journal,
      gateway: PlatformDeletionGateway(
        auth: backend.auth,
        identity: () => identity,
        provider: () => provider,
        consent: () => consent,
        configured: true,
        clock: () => DateTime.utc(2030),
      ),
      consent: () => consent,
      nextKey: () => 'delete-intent-${++next}',
    );
  }
  Future<void> start() async {
    await tokens.setItem('access', 'original-access');
    await tokens.setItem('access:refresh', 'original-refresh');
    await model.start();
  }

  int get deletes =>
      requests.where((r) => r.url.path.endsWith('/data-requests')).length;
  Future<void> close() async {
    await model.close();
    await identity.close();
    model.dispose();
    identity.dispose();
  }
}
