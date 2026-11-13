import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage.dart';
part 'response_body.dart';

class FenlengSdkException implements Exception {
  final String code;
  final String message;
  final int status;
  final String? requestId;
  final bool retryable;
  const FenlengSdkException(this.code, this.message,
      {this.status = 0, this.requestId, this.retryable = false});
  @override
  String toString() => 'FenlengSdkException($code, status=$status)';
}

class FenlengClientOptions {
  final Uri baseUrl;
  final String apiVersion;
  final FenlengStorageAdapter storage;
  final String tokenKey;
  final Duration timeout;
  final http.Client httpClient;
  FenlengClientOptions({
    required String baseUrl,
    this.apiVersion = '1.0.0',
    required this.storage,
    this.tokenKey = 'fl_session_token',
    this.timeout = const Duration(seconds: 10),
    http.Client? httpClient,
  })  : baseUrl = _validateBaseUrl(baseUrl),
        httpClient = httpClient ?? http.Client() {
    if (apiVersion != '1.0.0')
      throw const FenlengSdkException(
          'INCOMPATIBLE_PLATFORM_API', 'Only Platform API 1.0.0 is supported');
  }
  static Uri _validateBaseUrl(String value) {
    final uri = Uri.parse(value);
    if (!uri.hasScheme || !uri.hasAuthority)
      throw const FenlengSdkException(
          'CONFIGURATION_INVALID', 'baseUrl is required');
    if (uri.scheme != 'https' &&
        uri.host != 'localhost' &&
        uri.host != '127.0.0.1')
      throw const FenlengSdkException(
          'INSECURE_TRANSPORT', 'HTTPS is required outside localhost');
    return uri;
  }
}

class FenlengFlutterClient {
  final FenlengClientOptions options;
  FenlengFlutterClient({required this.options});
  Future<Map<String, String>> getHeaders(
      {String? idempotencyKey, String? actionConfirmationId}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Fenleng-API-Version': options.apiVersion,
      'X-Fenleng-SDK-Version': '0.5.0'
    };
    final token = await options.storage.getItem(options.tokenKey);
    if (token?.isNotEmpty == true) headers['Authorization'] = 'Bearer $token';
    if (idempotencyKey?.isNotEmpty == true)
      headers['Idempotency-Key'] = idempotencyKey!;
    if (actionConfirmationId?.isNotEmpty == true)
      headers['X-Action-Confirmation'] = actionConfirmationId!;
    return headers;
  }

  Future<Map<String, dynamic>> request(String path,
      {String method = 'GET',
      Map<String, dynamic>? body,
      String? idempotencyKey,
      String? actionConfirmationId}) async {
    final decoded = await _requestDecoded(path,
        method: method,
        body: body,
        idempotencyKey: idempotencyKey,
        actionConfirmationId: actionConfirmationId);
    if (decoded is! Map<String, dynamic>) {
      throw const FenlengSdkException(
          'RESPONSE_INVALID', 'Expected a response object');
    }
    return decoded;
  }

  Future<Map<String, dynamic>?> requestNullableObject(String path) async {
    final decoded = await _requestDecoded(path);
    if (decoded == null) return null;
    if (decoded is! Map<String, dynamic>) {
      throw const FenlengSdkException(
          'RESPONSE_INVALID', 'Expected an optional response object');
    }
    return decoded;
  }

  Future<List<Map<String, dynamic>>> requestList(String path) async {
    final decoded = await _requestDecoded(path);
    if (decoded is! List ||
        decoded.any((item) => item is! Map<String, dynamic>)) {
      throw const FenlengSdkException(
          'RESPONSE_INVALID', 'Expected a response list');
    }
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<dynamic> _requestDecoded(String path,
      {String method = 'GET',
      Map<String, dynamic>? body,
      String? idempotencyKey,
      String? actionConfirmationId}) async {
    if (!path.startsWith('/'))
      throw const FenlengSdkException(
          'ENDPOINT_INVALID', 'Endpoint must be absolute');
    try {
      final request = http.Request(method, options.baseUrl.resolve(path))
        ..headers.addAll(await getHeaders(
          idempotencyKey: idempotencyKey,
          actionConfirmationId: actionConfirmationId,
        ));
      if (body != null) request.body = jsonEncode(body);
      final streamed =
          await options.httpClient.send(request).timeout(options.timeout);
      final response = await _readResponseBody(streamed, options.timeout);
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded is Map<String, dynamic>
            ? decoded
            : const <String, dynamic>{};
        throw FenlengSdkException(
            error['code'] as String? ?? 'HTTP_${response.statusCode}',
            error['message'] as String? ?? 'Platform request failed',
            status: response.statusCode,
            requestId: error['requestId'] as String?,
            retryable: {429, 502, 503, 504}.contains(response.statusCode));
      }
      return decoded;
    } on TimeoutException {
      throw const FenlengSdkException('REQUEST_TIMEOUT', 'Request timed out',
          retryable: true);
    } on FenlengSdkException {
      rethrow;
    } catch (_) {
      throw const FenlengSdkException('NETWORK_ERROR', 'Network request failed',
          retryable: true);
    }
  }
}
