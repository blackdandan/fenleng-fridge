import 'client.dart';

class FlutterCommerceSDK {
  final FenlengFlutterClient client;
  FlutterCommerceSDK({required this.client});
  Future<
      List<
          Map<String, dynamic>>> prices(String planId) => client.requestList(
      '/api/platform/v1/commerce/plans/${Uri.encodeComponent(planId)}/prices');

  Future<List<Map<String, dynamic>>> orders({int limit = 20}) {
    if (limit < 1 || limit > 100) throw ArgumentError.value(limit, 'limit');
    return client.requestList('/api/platform/v1/commerce/orders?limit=$limit');
  }

  Future<Map<String, dynamic>> createOrder(
          String priceOptionId, String idempotencyKey,
          {Map<String, dynamic>? agreementConfirmation,
          Map<String, dynamic>? appleStoreQuote}) =>
      client.request('/api/platform/v1/commerce/orders',
          method: 'POST',
          body: {
            'priceOptionId': priceOptionId,
            if (agreementConfirmation != null)
              'agreementConfirmation': agreementConfirmation,
            if (appleStoreQuote != null) 'appleStoreQuote': appleStoreQuote
          },
          idempotencyKey: idempotencyKey);
  Future<Map<String, dynamic>?> purchaseAgreement(String priceOptionId) =>
      client.requestNullableObject(
          '/api/platform/v1/commerce/prices/${Uri.encodeComponent(priceOptionId)}/purchase-agreement');

  Future<
      Map<String,
          dynamic>> abandonApplePayment(String attemptId) => client.request(
      '/api/platform/v1/commerce/payments/${Uri.encodeComponent(attemptId)}/abandon-apple',
      method: 'POST');
  Future<Map<String, dynamic>> restoreApplePurchase(
          String orderId, String transactionId, {String? signedTransaction}) =>
      client.request(
          '/api/platform/v1/commerce/providers/apple-app-store/restore',
          method: 'POST',
          body: {
            'orderId': orderId,
            'transactionId': transactionId,
            if (signedTransaction != null)
              'signedTransaction': signedTransaction
          });
  Future<Map<String, dynamic>> order(String id) => client
      .request('/api/platform/v1/commerce/orders/${Uri.encodeComponent(id)}');
  Future<Map<String, dynamic>> paymentAttempt(String id) => client
      .request('/api/platform/v1/commerce/payments/${Uri.encodeComponent(id)}');
  Future<Map<String, dynamic>> startPayment(String orderId, String provider,
          {String? returnUrl,
          String? presentation,
          String? resumeAttemptId,
          required String idempotencyKey}) =>
      client.request('/api/platform/v1/commerce/payments',
          method: 'POST',
          body: {
            'orderId': orderId,
            'provider': provider,
            'returnUrl': returnUrl,
            if (resumeAttemptId != null) 'resumeAttemptId': resumeAttemptId,
            if (presentation != null) 'presentation': presentation
          },
          idempotencyKey: idempotencyKey);
  Future<
      Map<String,
          dynamic>> reconcilePayment(String attemptId) => client.request(
      '/api/platform/v1/commerce/payments/${Uri.encodeComponent(attemptId)}/reconcile',
      method: 'POST');
  Future<
      Map<String,
          dynamic>> cancelPayment(String attemptId) => client.request(
      '/api/platform/v1/commerce/payments/${Uri.encodeComponent(attemptId)}/cancel',
      method: 'POST');
  Future<Map<String, dynamic>> verifyPurchase(
          String attemptId, String purchaseToken,
          {required String idempotencyKey, String? signedTransaction}) =>
      client.request(
          '/api/platform/v1/commerce/payments/${Uri.encodeComponent(attemptId)}/verify',
          method: 'POST',
          body: {
            'purchaseToken': purchaseToken,
            if (signedTransaction != null)
              'signedTransaction': signedTransaction
          },
          idempotencyKey: idempotencyKey);
  Future<
      Map<String,
          dynamic>> entitlements(String applicationId) => client.request(
      '/api/platform/v1/applications/${Uri.encodeComponent(applicationId)}/entitlements/me');
  Future<Map<String, dynamic>> restorePurchases(String applicationId) =>
      entitlements(applicationId);
  Future<Map<String, dynamic>> subscription({String? provider}) async =>
      await client.requestNullableObject(
          '/api/platform/v1/commerce/subscription${provider == null ? '' : '?provider=${Uri.encodeComponent(provider)}'}') ??
      {};
}
