import 'dart:async';
import 'dart:convert';
import 'storage.dart';
import 'client.dart';
import 'commerce.dart';

abstract interface class NativePaymentBridge {
  Future<Map<String, dynamic>> invoke(
      String provider, Map<String, String> clientPayload);
}

abstract interface class AppleStoreBridge implements NativePaymentBridge {
  Future<List<Map<String, dynamic>>> products(List<String> ids);
  Future<List<Map<String, dynamic>>> unfinished();
  Future<List<Map<String, dynamic>>> restore();
  Stream<Map<String, dynamic>> get transactions;
  Future<void> finish(String transactionId);
  Future<void> manageSubscriptions();
}

abstract class NativePaymentAdapter {
  String get provider;
  final NativePaymentBridge bridge;
  NativePaymentAdapter(this.bridge);
  Future<Map<String, dynamic>> invoke(Map<String, String> payload) =>
      bridge.invoke(provider, payload);
}

class AppleStorePaymentAdapter extends NativePaymentAdapter {
  AppleStorePaymentAdapter(super.bridge);
  @override
  String get provider => 'apple-app-store';
}

class GooglePlayPaymentAdapter extends NativePaymentAdapter {
  GooglePlayPaymentAdapter(super.bridge);
  @override
  String get provider => 'google-play';
}

class WechatPaymentAdapter extends NativePaymentAdapter {
  WechatPaymentAdapter(super.bridge);
  @override
  String get provider => 'wechat-pay';
}

class AlipayPaymentAdapter extends NativePaymentAdapter {
  AlipayPaymentAdapter(super.bridge);
  @override
  String get provider => 'alipay';
}

/// Owner policy for digital subscriptions; channel comes from the build, never locale.
class DigitalSubscriptionPaymentPolicy {
  final String channel;
  final String platform;
  DigitalSubscriptionPaymentPolicy(
      {required this.channel, required this.platform}) {
    if (!const {'china', 'global'}.contains(channel)) {
      throw ArgumentError.value(channel, 'channel');
    }
  }
  Set<String> get allowedProviders => switch (platform.toLowerCase()) {
        'ios' => const {'apple-app-store'},
        'ohos' when channel == 'china' => const {'alipay', 'wechat-pay'},
        'android' when channel == 'china' => const {'alipay', 'wechat-pay'},
        'android' => const {'google-play'},
        _ => const {},
      };
}

/// Coordinates native interaction with the authoritative server order.
/// A pending result remains pending when the bounded confirmation window expires.
class FlutterPaymentCoordinator {
  final FlutterCommerceSDK commerce;
  final Map<String, NativePaymentAdapter> adapters;
  final DigitalSubscriptionPaymentPolicy? policy;
  final Future<void> Function()? refreshSession;
  Future<void>? _refreshing;

  Future<T> _authorized<T>(Future<T> Function() request,
      {bool refreshForbidden = false}) async {
    try {
      return await request();
    } on FenlengSdkException catch (error) {
      if (refreshSession == null ||
          !(error.status == 401 ||
              (refreshForbidden &&
                  error.status == 403 &&
                  error.code == 'PERMISSION_DENIED'))) rethrow;
      await (_refreshing ??= refreshSession!().whenComplete(() {
        _refreshing = null;
      }));
      return request();
    }
  }

  Future<Map<String, dynamic>> currentAccess(String applicationId) async {
    final subscription = await _authorized(() => commerce.subscription(
        provider: adapters.containsKey('apple-app-store')
            ? 'apple-app-store'
            : null));
    final entitlements = await _authorized(
        () => commerce.entitlements(applicationId),
        refreshForbidden: true);
    return {'subscription': subscription, 'entitlements': entitlements};
  }

  Future<Map<String, dynamic>> readOrder(String id) =>
      _authorized(() => commerce.order(id));
  Future<List<Map<String, dynamic>>> prices(String planId) async {
    final prices = await _authorized(() => commerce.prices(planId));
    final bridge = adapters['apple-app-store']?.bridge;
    if (bridge is! AppleStoreBridge) return prices;
    final ids =
        prices.map((p) => p['appleProductId']).whereType<String>().toList();
    if (ids.isEmpty) return [];
    final products = await bridge.products(ids);
    if (!products.any((product) => ids.contains(product['productId']))) {
      throw const FenlengSdkException('PAYMENT_PROVIDER_PRODUCT_UNAVAILABLE',
          'Apple store products are temporarily unavailable',
          retryable: true);
    }
    return prices
        .where(
            (p) => products.any((s) => s['productId'] == p['appleProductId']))
        .map((p) {
      final product =
          products.firstWhere((s) => s['productId'] == p['appleProductId']);
      final expectedPeriod = switch (p['interval']) {
        'MONTH' => ('month', 1),
        'QUARTER' => ('month', 3),
        'YEAR' => ('year', 1),
        _ => ('', 0),
      };
      if (product['subscriptionPeriodUnit'] != expectedPeriod.$1 ||
          product['subscriptionPeriodValue'] != expectedPeriod.$2) {
        throw const FenlengSdkException('PAYMENT_SESSION_INVALID',
            'Apple billing period does not match the product binding');
      }

      return {
        ...p,
        'amountMinor': product['amountMinor'],
        'currency': product['currency'],
        'displayPrice': product['displayPrice'],
        'billingMode': 'SUBSCRIPTION',
        'storePeriodUnit': product['subscriptionPeriodUnit'],
        'storePeriodValue': product['subscriptionPeriodValue']
      };
    }).toList();
  }

  AppleStoreBridge get appleBridge {
    final bridge = adapters['apple-app-store']?.bridge;
    if (bridge is! AppleStoreBridge)
      throw const FenlengSdkException(
          'PAYMENT_PROVIDER_UNSUPPORTED', 'Apple is not configured');
    return bridge;
  }

  Future<void> manageAppleSubscriptions() => appleBridge.manageSubscriptions();
  Future<void> syncAppleTransaction(Map<String, dynamic> transaction,
      {required bool Function() isCurrentUser}) async {
    if (!isCurrentUser()) return;
    final id = transaction['transactionId'];
    final orderId = transaction['appAccountToken'];
    if (id is! String || orderId is! String)
      throw const FenlengSdkException(
          'PAYMENT_SESSION_INVALID', 'Apple account association is missing');
    await _authorized(() => commerce.restoreApplePurchase(orderId, id,
        signedTransaction: transaction['signedTransaction'] as String?));
    if (isCurrentUser()) await appleBridge.finish(id);
  }

  Future<void> syncAppleUnfinishedForOrder(String orderId,
      {required bool Function() isCurrentUser}) async {
    if (!isCurrentUser()) return;
    final transactions =
        await appleBridge.unfinished().timeout(const Duration(seconds: 15));
    for (final transaction in transactions) {
      if (!isCurrentUser()) return;
      if (transaction['appAccountToken'] == orderId) {
        await syncAppleTransaction(transaction, isCurrentUser: isCurrentUser);
      }
    }
  }

  StreamSubscription<Map<String, dynamic>>? _appleUpdates;
  int _appleUpdateGeneration = 0;
  Future<void> stopAppleUpdates() async {
    _appleUpdateGeneration++;
    final subscription = _appleUpdates;
    _appleUpdates = null;
    await subscription?.cancel();
  }

  Future<void> startAppleUpdates(
      {required bool Function() isCurrentUser,
      required void Function(Object) onError,
      void Function(String productId)? onPurchaseIntent}) async {
    final generation = ++_appleUpdateGeneration;
    final previous = _appleUpdates;
    _appleUpdates = null;
    await previous?.cancel();
    if (generation != _appleUpdateGeneration || !isCurrentUser()) return;
    _appleUpdates = appleBridge.transactions.listen((transaction) {
      if (isCurrentUser()) {
        if (transaction['outcome'] == 'PURCHASE_INTENT') {
          final productId = transaction['productId'];
          if (productId is String && productId.isNotEmpty) {
            onPurchaseIntent?.call(productId);
          }
          return;
        }
        unawaited(
            syncAppleTransaction(transaction, isCurrentUser: isCurrentUser)
                .catchError(onError));
      }
    }, onError: onError);
    for (final transaction in await appleBridge.unfinished()) {
      if (!isCurrentUser()) return;
      try {
        await syncAppleTransaction(transaction, isCurrentUser: isCurrentUser);
      } catch (error) {
        onError(error);
      }
    }
  }

  Future<void> restoreApplePurchases(
      {required bool Function() isCurrentUser}) async {
    final transactions = await appleBridge.restore();
    Object? firstError;
    StackTrace? firstStack;
    for (final transaction in transactions) {
      if (!isCurrentUser()) return;
      try {
        await syncAppleTransaction(transaction, isCurrentUser: isCurrentUser);
      } catch (error, stack) {
        firstError ??= error;
        firstStack ??= stack;
      }
    }
    if (firstError != null && isCurrentUser()) {
      Error.throwWithStackTrace(firstError, firstStack!);
    }
  }

  Future<Map<String, dynamic>?> purchaseAgreement(String priceOptionId) =>
      _authorized(() => commerce.purchaseAgreement(priceOptionId));

  final Map<String, Future<Map<String, dynamic>>> _recovering = {};
  final int confirmationAttempts;
  final Duration confirmationInterval;
  final Map<String, Future<Map<String, dynamic>>> _inFlight = {};
  final Map<String, String> _purchaseFingerprints = {};

  FlutterPaymentCoordinator({
    required this.commerce,
    required List<NativePaymentAdapter> adapters,
    this.policy,
    this.refreshSession,
    this.confirmationAttempts = 10,
    this.confirmationInterval = const Duration(seconds: 1),
  }) : adapters = {for (final item in adapters) item.provider: item} {
    if (confirmationAttempts < 1 || confirmationInterval.isNegative) {
      throw ArgumentError('Invalid payment confirmation policy');
    }
  }

  Future<Map<String, dynamic>> purchase(
      String priceOptionId, String provider, String idempotencyKey,
      {String? applicationId,
      Map<String, dynamic>? agreementConfirmation,
      Map<String, dynamic>? appleStoreQuote,
      FutureOr<void> Function(String orderId, String attemptId)?
          onSessionCreated}) {
    final confirmation = agreementConfirmation == null
        ? null
        : Map<String, dynamic>.unmodifiable(agreementConfirmation);
    final fingerprint = jsonEncode([
      priceOptionId,
      provider,
      applicationId,
      confirmation?['documentId'],
      confirmation?['documentVersion'],
      confirmation?['contentSha256'],
      confirmation?['accepted'],
      appleStoreQuote?['amountMinor'],
      appleStoreQuote?['currency']
    ]);
    final quote = appleStoreQuote == null
        ? null
        : Map<String, dynamic>.unmodifiable(appleStoreQuote);
    final existing = _inFlight[idempotencyKey];
    if (existing != null) {
      if (_purchaseFingerprints[idempotencyKey] != fingerprint) {
        return Future.error(const FenlengSdkException('IDEMPOTENCY_KEY_REUSED',
            'Purchase confirmation changed during an active request'));
      }
      return existing;
    }
    _purchaseFingerprints[idempotencyKey] = fingerprint;
    return _inFlight[idempotencyKey] = _purchase(
            priceOptionId,
            provider,
            idempotencyKey,
            applicationId,
            onSessionCreated,
            confirmation,
            quote)
        .whenComplete(() {
      _inFlight.remove(idempotencyKey);
      _purchaseFingerprints.remove(idempotencyKey);
    });
  }

  Future<Map<String, dynamic>> _purchase(
    String price,
    String provider,
    String key,
    String? applicationId,
    FutureOr<void> Function(String orderId, String attemptId)? onSessionCreated,
    Map<String, dynamic>? agreementConfirmation,
    Map<String, dynamic>? appleStoreQuote,
  ) async {
    if (policy != null && !policy!.allowedProviders.contains(provider)) {
      throw const FenlengSdkException(
          'PAYMENT_CHANNEL_FORBIDDEN', 'Provider is forbidden for this build');
    }
    final adapter = adapters[provider];
    if (adapter == null) {
      throw const FenlengSdkException(
          'PAYMENT_PROVIDER_UNSUPPORTED', 'Provider is not configured');
    }
    final bridge = adapter.bridge;
    if (provider == 'apple-app-store' && appleStoreQuote == null) {
      throw const FenlengSdkException(
          'PAYMENT_SESSION_INVALID', 'The displayed Apple price is required');
    }
    if (provider == 'apple-app-store') {
      // The user may return from Apple's subscription manager while our screen
      // still has an expired snapshot. Recheck the authoritative subscription
      // before creating another checkout for the same active Apple product.
      final subscription = await _authorized(
          () => commerce.subscription(provider: 'apple-app-store'));
      final end =
          DateTime.tryParse(subscription?['periodEnd']?.toString() ?? '');
      if (subscription?['provider'] == 'apple-app-store' &&
          subscription?['priceOptionId'] == price &&
          const {'ACTIVE', 'CANCEL_AT_PERIOD_END', 'PAST_DUE'}
              .contains(subscription?['status']) &&
          end != null &&
          end.isAfter(DateTime.now())) {
        return {'nativeOutcome': 'RESTORED', 'subscription': subscription};
      }
    }
    final order = await _authorized(() => commerce.createOrder(price, key,
        agreementConfirmation: agreementConfirmation,
        appleStoreQuote: appleStoreQuote));
    if (_terminal(order)) return _withEntitlements(order, applicationId);
    final orderId = order['id'] as String;
    final started = await _authorized(() => commerce.startPayment(
        orderId, provider,
        presentation:
            const {'alipay', 'wechat-pay', 'apple-app-store'}.contains(provider)
                ? 'NATIVE_APP'
                : null,
        idempotencyKey: '$key:payment'));
    final attemptId = started['paymentAttemptId'] as String;
    await onSessionCreated?.call(orderId, attemptId);
    final payload =
        (started['clientPayload'] as Map?)?.cast<String, String>() ?? {};
    Map<String, dynamic> native;
    try {
      native = await adapter.invoke(payload);
    } on Exception catch (error) {
      if (provider == 'apple-app-store' &&
          error is FenlengSdkException &&
          error.code == 'PAYMENT_PRICE_CHANGED') {
        await _authorized(() => commerce.abandonApplePayment(attemptId));
        return {...await readOrder(orderId), 'nativeOutcome': 'PRICE_CHANGED'};
      }
      if (!const {'alipay', 'wechat-pay'}.contains(provider)) rethrow;
      // A native transport exception cannot determine the provider transaction.
      // The host already persisted the session before native invocation.
      final result = await recover(orderId,
          paymentAttemptId: attemptId, applicationId: applicationId);
      return {
        ...result,
        'nativeOutcome': 'UNCONFIRMED',
        'nativeErrorCode':
            error is FenlengSdkException ? error.code : 'PAYMENT_NATIVE_FAILED'
      };
    }
    // Alipay SDK results (including 9000) are not purchase receipts. Query the
    // provider through the platform instead of trusting client resultStatus.
    if (provider == 'apple-app-store') {
      final restored = await _restoreOwnedAppleReceipt(
          native, orderId, attemptId, applicationId);
      if (restored != null) return restored;
    }
    if (!const {'alipay', 'wechat-pay'}.contains(provider)) {
      final purchaseToken = native['purchaseToken'];
      if (purchaseToken is String) {
        await _authorized(() => commerce.verifyPurchase(
            attemptId, purchaseToken,
            idempotencyKey: '$key:verify',
            signedTransaction: native['signedTransaction'] as String?));
        if (bridge is AppleStoreBridge) {
          final confirmed = await readOrder(orderId);
          if (confirmed['status'] == 'PAID') await bridge.finish(purchaseToken);
        }
      }
    }
    if (provider == 'apple-app-store' && native['purchaseToken'] == null) {
      if (native['outcome'] == 'USER_CANCELED')
        await _authorized(() => commerce.abandonApplePayment(attemptId));
      return {
        ...await readOrder(orderId),
        'nativeOutcome': native['outcome'] ?? 'UNCONFIRMED'
      };
    }
    final result = await recover(orderId,
        paymentAttemptId: const {'alipay', 'wechat-pay'}.contains(provider)
            ? attemptId
            : null,
        applicationId: applicationId);
    return {
      ...result,
      'nativeOutcome':
          (provider == 'alipay' && native['resultStatus'] == '6001') ||
                  (provider == 'wechat-pay' && native['outcome'] == 'CANCELLED')
              ? 'USER_CANCELED'
              : 'RETURNED'
    };
  }

  Future<Map<String, dynamic>?> _restoreOwnedAppleReceipt(
      Map<String, dynamic> native,
      String orderId,
      String attemptId,
      String? applicationId) async {
    final token = native['appAccountToken'];
    final transactionId = native['purchaseToken'];
    if (token is! String ||
        token.toLowerCase() == orderId.toLowerCase() ||
        transactionId is! String) return null;
    // StoreKit may return an already-owned subscription. Its receipt must be
    // restored against the original account association, never this new order.
    try {
      await _authorized(() => commerce.restoreApplePurchase(token, transactionId,
          signedTransaction: native['signedTransaction'] as String?));
    } on FenlengSdkException catch (error) {
      if (error.status != 404) rethrow;
      // This receipt belongs to a different order. Closing this uncharged
      // checkout does not settle, reassign, or finish the rejected receipt.
      // Transport/verification failures keep their recoverable session instead.
      await _authorized(() => commerce.abandonApplePayment(attemptId));
      return {
        ...await readOrder(orderId),
        'nativeOutcome': 'ASSOCIATION_REQUIRED',
        'nativeErrorCode': 'APPLE_PURCHASE_ASSOCIATION_REQUIRED',
      };
    }
    await _authorized(() => commerce.abandonApplePayment(attemptId));
    final closed = await readOrder(orderId);
    if (closed['status'] == 'CANCELED') {
      final bridge = adapters['apple-app-store']?.bridge;
      if (bridge is AppleStoreBridge) await bridge.finish(transactionId);
    }
    return {...closed, 'nativeOutcome': 'RESTORED'};
  }

  Future<Map<String, dynamic>> resumeApple(String orderId, String attemptId,
      {String? applicationId,
      required String idempotencyKey,
      required bool Function() isCurrentUser}) async {
    if (policy != null &&
        !policy!.allowedProviders.contains('apple-app-store')) {
      throw const FenlengSdkException(
          'PAYMENT_CHANNEL_FORBIDDEN', 'Apple is forbidden for this build');
    }
    if (!isCurrentUser())
      throw const FenlengSdkException(
          'PAYMENT_SESSION_INVALID', 'Account changed');
    for (final transaction in await appleBridge.unfinished()) {
      if (transaction['appAccountToken'] == orderId) {
        await syncAppleTransaction(transaction, isCurrentUser: isCurrentUser);
      }
    }
    final order = await readOrder(orderId);
    if (_terminal(order))
      return _withAgreementOutcome(order, attemptId, applicationId);
    final session = await _authorized(() => commerce.startPayment(
        orderId, 'apple-app-store',
        presentation: 'NATIVE_APP',
        resumeAttemptId: attemptId,
        idempotencyKey: idempotencyKey));
    if (!isCurrentUser())
      throw const FenlengSdkException(
          'PAYMENT_SESSION_INVALID', 'Account changed');
    Map<String, dynamic> outcome;
    try {
      outcome = await appleBridge.invoke('apple-app-store',
          (session['clientPayload'] as Map).cast<String, String>());
    } on FenlengSdkException catch (error) {
      if (error.code != 'PAYMENT_PRICE_CHANGED') rethrow;
      await _authorized(() => commerce.abandonApplePayment(attemptId));
      return {...await readOrder(orderId), 'nativeOutcome': 'PRICE_CHANGED'};
    }
    final restored = await _restoreOwnedAppleReceipt(
        outcome, orderId, attemptId, applicationId);
    if (restored != null) return restored;
    final token = outcome['purchaseToken'];
    if (token is String) {
      await _authorized(() => commerce.verifyPurchase(attemptId, token,
          idempotencyKey: '$idempotencyKey:verify',
          signedTransaction: outcome['signedTransaction'] as String?));
      if (isCurrentUser() && (await readOrder(orderId))['status'] == 'PAID')
        await appleBridge.finish(token);
    } else if (outcome['outcome'] == 'USER_CANCELED') {
      await _authorized(() => commerce.abandonApplePayment(attemptId));
    }
    return {
      ...await queryOnce(orderId, applicationId: applicationId),
      'nativeOutcome': outcome['outcome'] ?? 'UNCONFIRMED'
    };
  }

  /// Reopens an unpaid wallet order using the original server-owned provider.
  Future<Map<String, dynamic>> resume(String orderId, String attemptId,
      {String? applicationId,
      required String idempotencyKey,
      FutureOr<void> Function()? beforeNative}) async {
    final attempt = await _authorized(() => commerce.paymentAttempt(attemptId));
    final provider = attempt['provider'];
    if (attempt['orderId'] != orderId ||
        !const {'alipay', 'wechat-pay'}.contains(provider)) {
      throw const FenlengSdkException('PAYMENT_SESSION_INVALID',
          'A matching wallet payment attempt is required');
    }
    if (policy != null && !policy!.allowedProviders.contains(provider)) {
      throw const FenlengSdkException(
          'PAYMENT_CHANNEL_FORBIDDEN', 'Provider is forbidden');
    }
    final adapter = adapters[provider];
    if (adapter == null)
      throw const FenlengSdkException(
          'PAYMENT_PROVIDER_UNSUPPORTED', 'Provider is not configured');
    final order = await queryOnce(orderId,
        paymentAttemptId: attemptId, applicationId: applicationId);
    if (_terminal(order)) return order;
    final session = await _authorized(() => commerce.startPayment(
        orderId, provider,
        presentation: 'NATIVE_APP',
        resumeAttemptId: attemptId,
        idempotencyKey: idempotencyKey));
    await beforeNative?.call();
    Map<String, dynamic> native;
    try {
      native = await adapter
          .invoke((session['clientPayload'] as Map).cast<String, String>());
    } on Exception {
      native = {'resultStatus': 'UNKNOWN'};
    }
    final result = await queryOnce(orderId,
        paymentAttemptId: attemptId, applicationId: applicationId);
    return {
      ...result,
      'nativeOutcome':
          native['resultStatus'] == '6001' || native['outcome'] == 'CANCELLED'
              ? 'USER_CANCELED'
              : 'RETURNED'
    };
  }

  /// Closing a payment attempt may race with provider confirmation.
  /// Always read the authoritative order, including a paid result after cancel.
  Future<Map<String, dynamic>> cancelAndRecover(
      String orderId, String paymentAttemptId,
      {String? applicationId}) async {
    // Let any preceding bounded query finish before closing the same order.
    final key = '$applicationId:$orderId:$paymentAttemptId';
    try {
      await _recovering[key];
    } on FenlengSdkException {/* Close still can succeed. */}
    try {
      await _authorized(() => commerce.cancelPayment(paymentAttemptId));
    } on FenlengSdkException {
      final order = await readOrder(orderId);
      if (_terminal(order))
        return _withAgreementOutcome(order, paymentAttemptId, applicationId);
      rethrow;
    }
    return recover(orderId,
        paymentAttemptId: paymentAttemptId, applicationId: applicationId);
  }

  Future<Map<String, dynamic>> recover(String orderId,
      {String? paymentAttemptId, String? applicationId}) {
    final key = '$applicationId:$orderId:$paymentAttemptId';
    return _recovering[key] ??=
        _recover(orderId, paymentAttemptId, applicationId).whenComplete(() {
      _recovering.remove(key);
    });
  }

  /// Explicit user query performs one reconciliation, independently of polling.
  Future<Map<String, dynamic>> queryOnce(String orderId,
      {String? paymentAttemptId, String? applicationId}) {
    final key = '$applicationId:$orderId:$paymentAttemptId:once';
    return _recovering[key] ??=
        _recover(orderId, paymentAttemptId, applicationId, attempts: 1)
            .timeout(const Duration(seconds: 20),
                onTimeout: () => throw const FenlengSdkException(
                    'PAYMENT_QUERY_TIMEOUT', 'Payment query timed out'))
            .whenComplete(() {
      _recovering.remove(key);
    });
  }

  Future<Map<String, dynamic>> _recover(
      String orderId, String? paymentAttemptId, String? applicationId,
      {int? attempts}) async {
    final rounds = attempts ?? confirmationAttempts;
    for (var index = 0; index < rounds; index++) {
      var order = await readOrder(orderId);
      if (_terminal(order))
        return _withAgreementOutcome(order, paymentAttemptId, applicationId);
      if (paymentAttemptId != null) {
        await _authorized(() => commerce.reconcilePayment(paymentAttemptId));
        order = await readOrder(orderId);
        if (_terminal(order))
          return _withAgreementOutcome(order, paymentAttemptId, applicationId);
      }
      if (index == rounds - 1) {
        return _withAgreementOutcome(order, paymentAttemptId, applicationId);
      }
      await Future<void>.delayed(confirmationInterval);
    }
    throw StateError('Unreachable confirmation state');
  }

  Future<Map<String, dynamic>> _withAgreementOutcome(Map<String, dynamic> order,
      String? attemptId, String? applicationId) async {
    var result = await _withEntitlements(order, applicationId);
    if (order['status'] == 'PAID') {
      try {
        final subscription = await _authorized(() => commerce.subscription(
            provider: adapters.containsKey('apple-app-store')
                ? 'apple-app-store'
                : null));
        result = {
          ...result,
          if (subscription['periodEnd'] != null)
            'subscriptionPeriodEnd': subscription['periodEnd'],
          if (subscription['provider'] != null)
            'subscriptionProvider': subscription['provider']
        };
      } on FenlengSdkException {
        /* Retain confirmed payment and access outcome. */
      }
    }
    if (attemptId == null) return result;
    try {
      final attempt =
          await _authorized(() => commerce.paymentAttempt(attemptId));
      return {
        ...result,
        if (attempt['renewalAgreementStatus'] != null)
          'renewalAgreementStatus': attempt['renewalAgreementStatus'],
        if (attempt['renewalAgreementFailureCode'] != null)
          'renewalAgreementFailureCode': attempt['renewalAgreementFailureCode'],
      };
    } on FenlengSdkException {
      // Agreement lookup failure cannot change the authoritative paid result.
      // UNKNOWN is a client observation state, never a successful mandate.
      return {...result, 'renewalAgreementStatus': 'UNKNOWN'};
    }
  }

  bool _terminal(Map<String, dynamic> order) => const {
        'PAID',
        'CANCELED',
        'PARTIALLY_REFUNDED',
        'REFUNDED',
      }.contains(order['status']);

  Future<Map<String, dynamic>> _withEntitlements(
    Map<String, dynamic> order,
    String? applicationId,
  ) async {
    if (applicationId == null || order['status'] != 'PAID') return order;
    try {
      return {
        ...order,
        'entitlements': await _authorized(
            () => commerce.entitlements(applicationId),
            refreshForbidden: true),
        'entitlementRefreshStatus': 'CONFIRMED'
      };
    } on FenlengSdkException catch (error) {
      // A failed entitlement refresh does not erase a confirmed payment.
      return {
        ...order,
        'entitlementRefreshStatus': 'UNCONFIRMED',
        'entitlementRefreshCode': error.code,
        'entitlementRefreshRequestId': error.requestId
      };
    }
  }
}

/// Persist before invoking the native SDK; retain pending orders after restart.
class PaymentRecoveryRecord {
  final String orderId;
  final String paymentAttemptId;
  const PaymentRecoveryRecord(this.orderId, this.paymentAttemptId);
}

/// Use one store instance per application composition root. Writes are serialized.
/// The caller supplies the authenticated platform user ID, never a device ID.
class FlutterPaymentRecoveryStore {
  final FenlengStorageAdapter storage;
  final String applicationId;
  Future<void> _tail = Future<void>.value();
  FlutterPaymentRecoveryStore(
      {required this.storage, required this.applicationId});

  String _key(String userId) {
    if (applicationId.isEmpty || userId.isEmpty) {
      throw ArgumentError('Payment recovery requires application and user IDs');
    }
    return 'fenleng.payment.recovery.v2:${Uri.encodeComponent(applicationId)}:${Uri.encodeComponent(userId)}';
  }

  Future<Map<String, String>> _load(String userId) async {
    final raw = await storage.getItem(_key(userId));
    if (raw == null) return {};
    final values =
        (jsonDecode(raw) as Map<String, dynamic>).cast<String, String>();
    if (values.entries
        .any((entry) => entry.key.isEmpty || entry.value.isEmpty)) {
      throw const FormatException('Invalid payment recovery record');
    }
    return values;
  }

  Future<void> _update(
      String userId, void Function(Map<String, String>) update) {
    final work = _tail.then((_) async {
      final records = await _load(userId);
      update(records);
      if (records.isEmpty) {
        await storage.removeItem(_key(userId));
      } else {
        await storage.setItem(_key(userId), jsonEncode(records));
      }
    });
    // A failed write must reach the caller without disabling later recovery.
    _tail =
        work.then<void>((_) {}, onError: (Object error, StackTrace stack) {});
    return work;
  }

  Future<void> save(String userId, PaymentRecoveryRecord record) {
    if (record.orderId.isEmpty || record.paymentAttemptId.isEmpty) {
      throw ArgumentError('Payment recovery requires order and attempt IDs');
    }
    return _update(
        userId, (records) => records[record.orderId] = record.paymentAttemptId);
  }

  Future<List<PaymentRecoveryRecord>> pending(String userId) async {
    await _tail;
    final records = await _load(userId);
    return records.entries
        .map((entry) => PaymentRecoveryRecord(entry.key, entry.value))
        .toList(growable: false);
  }

  Future<PaymentRecoveryRecord?> read(String userId, String orderId) async {
    for (final record in await pending(userId)) {
      if (record.orderId == orderId) return record;
    }
    return null;
  }

  Future<void> remove(String userId, String orderId) =>
      _update(userId, (records) => records.remove(orderId));
}
