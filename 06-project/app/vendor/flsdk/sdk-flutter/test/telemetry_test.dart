import 'dart:convert';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main(){test('telemetry sends controlled context and rejects sensitive fields',() async {late http.Request sent;final client=FenlengFlutterClient(options:FenlengClientOptions(baseUrl:'http://localhost',storage:FenlengMemoryStorageAdapter(),httpClient:MockClient((request)async{sent=request;return http.Response('{"accepted":1}',200);})));final telemetry=FlutterTelemetrySDK(client:client,hasConsent:()=>true,catalog:{'prompt.created.v1'},context:()=>const FlutterTelemetryContext(platform:'ios',appVersion:'1.0.0',buildNumber:'3',releaseChannel:'global',locale:'zh-CN'));telemetry.track('prompt.created.v1',{'source':'editor'});expect(()=>telemetry.track('prompt.created.v1',{'verificationCode':'123456'}),throwsA(isA<FenlengSdkException>()));expect(await telemetry.flush('telemetry-1'),1);final body=jsonDecode(sent.body) as Map<String,dynamic>;expect(((body['events'] as List).first['context'] as Map)['platform'],'ios');});}
