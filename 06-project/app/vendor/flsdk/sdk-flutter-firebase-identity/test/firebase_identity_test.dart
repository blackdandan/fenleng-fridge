import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';
import 'package:fenleng_sdk_flutter_firebase_identity/fenleng_sdk_flutter_firebase_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

final class FakeTokenSource implements FirebaseIdTokenSource {
  FakeTokenSource(this.token);
  final String token;
  bool forceRefresh = false;
  @override
  Future<String> getIdToken({bool forceRefresh = false}) async {
    this.forceRefresh = forceRefresh;
    return token;
  }
}

void main() {
  test('exchanges a fresh Firebase token only with the Shared Platform', () async {
    late http.Request request;
    final client = FenlengFlutterClient(options: FenlengClientOptions(
      baseUrl: 'https://platform.example.test',
      storage: FenlengMemoryStorageAdapter(),
      httpClient: _CaptureClient((value) => request = value),
    ));
    final source = FakeTokenSource('firebase-id-token');
    final bridge = FirebaseIdentitySessionBridge(
      auth: FlutterAuthSDK(client: client, applicationCode: 'demo', clientId: 'mobile'),
      tokenSource: source,
    );

    await bridge.login(forceRefresh: true);

    expect(source.forceRefresh, isTrue);
    expect(request.url.path, '/api/platform/v1/auth/federated/firebase/login');
    expect(request.body, contains('firebase-id-token'));
    expect(await client.options.storage.getItem(client.options.tokenKey), 'access');
  });
}

final class _CaptureClient extends http.BaseClient {
  _CaptureClient(this.capture);
  final void Function(http.Request) capture;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    capture(request as http.Request);
    return http.StreamedResponse(
      Stream.value(const <int>[123, 34, 97, 99, 99, 101, 115, 115, 84, 111, 107, 101, 110, 34, 58, 34, 97, 99, 99, 101, 115, 115, 34, 44, 34, 114, 101, 102, 114, 101, 115, 104, 84, 111, 107, 101, 110, 34, 58, 34, 114, 101, 102, 114, 101, 115, 104, 34, 125]),
      200,
    );
  }
}
