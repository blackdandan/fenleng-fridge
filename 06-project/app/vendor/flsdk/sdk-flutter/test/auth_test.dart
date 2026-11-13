import 'dart:convert';

import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('federated deletion proof preserves session tokens and exact intent', () async {
    final requests=<http.Request>[];
    final storage=FenlengMemoryStorageAdapter();
    final client=FenlengFlutterClient(options:FenlengClientOptions(baseUrl:'http://localhost',storage:storage,
      httpClient:MockClient((request) async {requests.add(request);return http.Response(jsonEncode(
        request.url.path.endsWith('/confirm')?{'confirmationId':'fdc-once','deletionIdempotencyKey':'delete-intent'}:
        {'challengeId':'fdc-once','provider':'APPLE','nonce':'server-nonce'}),200);} )));
    await storage.setItem(client.options.tokenKey,'existing-access');
    await storage.setItem('${client.options.tokenKey}:refresh','existing-refresh');
    final auth=FlutterAuthSDK(client:client,applicationCode:'demo-app');
    final challenge=await auth.createFederatedDeletionChallenge('APPLE','delete-intent');
    final result=await auth.confirmFederatedDeletionReauthentication(challenge['challengeId'] as String,'private-token');
    expect(result['confirmationId'],'fdc-once');expect(requests.length,2);
    expect(jsonDecode(requests[0].body),{'provider':'APPLE','deletionIdempotencyKey':'delete-intent'});
    expect(jsonDecode(requests[1].body),{'identityToken':'private-token'});
    expect(requests[1].url.path,'/api/platform/v1/auth/step-up/self-deletion/challenges/fdc-once/confirm');
    expect(await storage.getItem(client.options.tokenKey),'existing-access');
    expect(await storage.getItem('${client.options.tokenKey}:refresh'),'existing-refresh');
    expect(()=>auth.createFederatedDeletionChallenge('UNKNOWN','delete-intent'),throwsA(isA<FenlengSdkException>()));
    expect(()=>auth.confirmFederatedDeletionReauthentication('fdc-bad/path','token'),throwsA(isA<FenlengSdkException>()));
    expect(requests.length,2);auth.dispose();
  });
  test('registration stores atomic session and publishes authenticated without password login',() async {
    final requests=<http.Request>[];
    final storage=FenlengMemoryStorageAdapter();
    final client=FenlengFlutterClient(options:FenlengClientOptions(baseUrl:'http://localhost',storage:storage,httpClient:MockClient((request) async {
      requests.add(request);
      return http.Response(jsonEncode({'userId':'new-user','accessToken':'new-access','refreshToken':'new-refresh'}),201);
    })));
    final auth=FlutterAuthSDK(client:client,applicationCode:'demo-app');
    final states=<FlutterSessionStatus>[];
    final subscription=auth.onSessionStatusChanged.listen(states.add);
    final result=await auth.register(email:'person@example.com',password:'strong-password',username:'person',displayName:'Person',verificationCode:'123456');
    await Future<void>.delayed(Duration.zero);
    expect(result['userId'],'new-user');expect(requests.length,1);expect(requests.single.url.path,'/api/platform/v1/auth/register');
    expect(await storage.getItem(client.options.tokenKey),'new-access');expect(await storage.getItem('${client.options.tokenKey}:refresh'),'new-refresh');
    expect(states,[FlutterSessionStatus.authenticating,FlutterSessionStatus.authenticated]);
    await subscription.cancel();auth.dispose();
  });
  test('registration without session tokens cannot publish authenticated',() async {
    final storage=FenlengMemoryStorageAdapter();
    final client=FenlengFlutterClient(options:FenlengClientOptions(baseUrl:'http://localhost',storage:storage,httpClient:MockClient((_) async=>http.Response('{}',201))));
    final auth=FlutterAuthSDK(client:client,applicationCode:'demo-app');
    await expectLater(auth.register(email:'person@example.com',password:'strong-password',username:'person',displayName:'Person',verificationCode:'123456'),throwsA(isA<FenlengSdkException>()));
    expect(await storage.getItem(client.options.tokenKey),null);auth.dispose();
  });

  test('login stores only server-issued tokens and refresh is deduplicated',
      () async {
    var refreshes = 0;
    final storage = FenlengMemoryStorageAdapter();
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/refresh')) refreshes++;
      return http.Response(
          jsonEncode({
            'accessToken': 'access-${refreshes + 1}',
            'refreshToken': 'refresh-${refreshes + 1}'
          }),
          200);
    });
    final client = FenlengFlutterClient(
        options: FenlengClientOptions(
            baseUrl: 'http://localhost:8080',
            storage: storage,
            httpClient: httpClient));
    final auth = FlutterAuthSDK(
        client: client,
        applicationCode: 'demo-app',
        clientId: 'flutter-client');
    await auth.loginWithPassword('user@example.com', 'password');
    await Future.wait([auth.refresh(), auth.refresh()]);
    expect(refreshes, 1);
    expect(await storage.getItem(client.options.tokenKey), 'access-2');
    auth.dispose();
  });

  test('account deletion sends step-up confirmation header', () async {
    final requests = <http.Request>[];
    final httpClient = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/auth/step-up')) {
        return http.Response(
            jsonEncode({
              'confirmation': {'id': 'confirmation-1'}
            }),
            200);
      }
      return http.Response(jsonEncode({'status': 'PENDING'}), 202);
    });
    final client = FenlengFlutterClient(
        options: FenlengClientOptions(
            baseUrl: 'http://localhost:8080',
            storage: FenlengMemoryStorageAdapter(),
            httpClient: httpClient));
    final auth = FlutterAuthSDK(
        client: client,
        applicationCode: 'demo-app',
        clientId: 'flutter-client');

    final confirmationId = await auth.confirmAccountDeletion(
        password: 'password', userId: 'user-1', idempotencyKey: 'request-1');
    await auth.requestData('DELETE', 'request-1',
        actionConfirmationId: confirmationId);

    expect(jsonDecode(requests.first.body), {
      'password': 'password',
      'confirmation': {
        'permissionCode': 'platform:self-data:delete',
        'resourceType': 'user-data-request',
        'resourceId': 'user-1',
        'idempotencyKey': 'request-1'
      }
    });
    expect(requests.last.headers['x-action-confirmation'], 'confirmation-1');
    expect(requests.last.headers['idempotency-key'], 'request-1');
  });

  test('incompatible API and insecure transport fail closed', () {
    expect(
        () => FenlengClientOptions(
            baseUrl: 'http://example.com',
            storage: FenlengMemoryStorageAdapter()),
        throwsA(isA<FenlengSdkException>()));
    expect(
        () => FenlengClientOptions(
            baseUrl: 'https://example.com',
            apiVersion: '2.0.0',
            storage: FenlengMemoryStorageAdapter()),
        throwsA(isA<FenlengSdkException>()));
  });
}
