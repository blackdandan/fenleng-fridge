import 'dart:convert';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';
import '../application/account_deletion.dart';
import '../application/identity_session.dart';

/// SDK-only transport. Opening the context never refreshes or creates identity.
class PlatformDeletionGateway implements DeletionGateway {
  final FlutterAuthSDK auth;
  final IdentitySession Function() identity;
  final IdentityProvider Function() provider;
  final bool Function() consent;
  final bool configured;
  final bool firebase;
  final DateTime Function() clock;
  PlatformDeletionGateway({
    required this.auth,
    required this.identity,
    required this.provider,
    required this.consent,
    required this.configured,
    this.firebase = false,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  @override
  Future<DeletionContext> open() async {
    if (!configured || !consent()) {
      throw const DeletionFailure('deletionUnavailable');
    }
    final session = identity();
    if (!session.signedIn || session.guestReady || session.busy) {
      throw const DeletionFailure('deletionLoginRequired');
    }
    final context = _PlatformDeletionContext(this, session, session.revision);
    try {
      context.check();
      final user = await auth.currentUser();
      context.check();
      if (user.kind != 'HUMAN' || user.status != 'ACTIVE') {
        throw const DeletionFailure('deletionLoginRequired');
      }
      context.userId = user.id;
      return context;
    } catch (error) {
      context.cancel();
      throw _mapped(error);
    }
  }
}

class _PlatformDeletionContext implements DeletionContext {
  final PlatformDeletionGateway gateway;
  final IdentitySession session;
  final int revision;
  late String userId;
  late IdentityProvider selectedProvider;
  String? challengeId, intent;
  DateTime? expiresAt;
  bool _cancelled = false;
  late int cleanupRevision = revision;
  _PlatformDeletionContext(this.gateway, this.session, this.revision);
  @override
  String get owner => jsonEncode([
    gateway.auth.client.options.baseUrl.toString().replaceFirst(
      RegExp(r'/$'),
      '',
    ),
    gateway.auth.clientId,
    userId,
  ]);
  @override
  bool get current =>
      !_cancelled &&
      gateway.consent() &&
      identical(gateway.identity(), session) &&
      session.revision == revision &&
      session.signedIn &&
      !session.busy;
  void check() {
    if (!current) throw const DeletionFailure('deletionCancelled');
  }

  void _checkChallenge(String id, String key) {
    check();
    if (challengeId != id ||
        intent != key ||
        expiresAt == null ||
        !gateway.clock().toUtc().isBefore(expiresAt!)) {
      throw const DeletionFailure('deletionFailed');
    }
  }

  @override
  Future<String> challenge(String key) async {
    check();
    selectedProvider = gateway.provider();
    final provider = gateway.firebase
        ? 'FIREBASE'
        : selectedProvider == IdentityProvider.wechat
        ? 'WECHAT'
        : 'APPLE';
    try {
      final result = await gateway.auth.createFederatedDeletionChallenge(
        provider,
        key,
      );
      check();
      final id = result['challengeId'], date = result['expiresAt'];
      final expiry = date is String ? deletionInstant(date) : null;
      if (id is! String ||
          id.length > 128 ||
          !RegExp(r'^fdc-[A-Za-z0-9._:-]+$').hasMatch(id) ||
          result['provider'] != provider ||
          expiry == null ||
          !gateway.clock().toUtc().isBefore(expiry)) {
        throw const DeletionFailure('deletionFailed');
      }
      challengeId = id;
      intent = key;
      expiresAt = expiry;
      return id;
    } catch (error) {
      throw _mapped(error);
    }
  }

  @override
  Future<String> authorize() async {
    _checkChallenge(challengeId ?? '', intent ?? '');
    try {
      final authorizer = session.authorization;
      if (gateway.firebase && authorizer is! IdentityReauthorization) {
        throw const DeletionFailure('deletionFailed');
      }
      final proof = authorizer is IdentityReauthorization
          ? await (authorizer as IdentityReauthorization).reauthorize(selectedProvider)
          : await authorizer.authorize(selectedProvider);
      check();
      if (proof.trim().isEmpty) throw const DeletionFailure('deletionFailed');
      return proof;
    } catch (error) {
      throw _mapped(error);
    }
  }

  @override
  Future<String> confirm(String challenge, String proof, String key) async {
    _checkChallenge(challenge, key);
    try {
      final result = await gateway.auth
          .confirmFederatedDeletionReauthentication(challenge, proof);
      check();
      final date = result['expiresAt'];
      final expiry = date is String ? deletionInstant(date) : null;
      if (result['confirmationId'] != challenge ||
          result['deletionIdempotencyKey'] != key ||
          expiry == null ||
          !gateway.clock().toUtc().isBefore(expiry)) {
        throw const DeletionFailure('deletionFailed');
      }
      expiresAt = expiry;
      return challenge;
    } catch (error) {
      throw _mapped(error);
    }
  }

  @override
  Future<void> stopReminders() async {
    check();
    // App reminders derive only from retained local inventory. There is no
    // account-bound mini subscription to revoke in this App adapter.
  }

  @override
  Future<DeletionReceipt> submit(String key, String confirmation) async {
    _checkChallenge(confirmation, key);
    final result = await gateway.auth.requestData(
      'DELETE',
      key,
      actionConfirmationId: confirmation,
    );
    final id = result['id'],
        requested = result['requestedAt'],
        eligible = result['nextAttemptAt'];
    if (result['userId'] != userId ||
        result['type'] != 'DELETE' ||
        result['status'] != 'PENDING' ||
        id is! String ||
        requested is! String ||
        eligible is! String) {
      throw const DeletionFailure('deletionUnknown');
    }
    final receipt = DeletionReceipt(id, requested, eligible);
    if (!receipt.valid) throw const DeletionFailure('deletionUnknown');
    // Original ACK remains meaningful after concurrent session expiry. The model
    // gates consent/generation; do not re-check the now-revoked session here.
    return receipt;
  }

  @override
  Future<void> finish() async {
    if (!gateway.consent() ||
        !identical(gateway.identity(), session) ||
        session.revision != cleanupRevision) {
      return;
    }
    try {
      await session.endLocalSession(cleanupRevision);
    } finally {
      cleanupRevision = session.revision;
    }
  }

  @override
  void cancel() {
    _cancelled = true;
  }
}

DeletionFailure _mapped(Object error) {
  if (error is DeletionFailure) return error;
  if (error is IdentityFailure && error.key == 'loginCancelled') {
    return const DeletionFailure('deletionCancelled');
  }
  return const DeletionFailure('deletionFailed');
}
