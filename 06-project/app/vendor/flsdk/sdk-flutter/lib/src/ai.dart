import 'dart:convert';
import 'package:http/http.dart' as http;
import 'client.dart';

class FlutterAIServiceSDK {
  final FenlengFlutterClient client;
  FlutterAIServiceSDK({required this.client});

  Stream<Map<String, dynamic>> connectStream(
    String endpoint,
    Map<String, dynamic> payload,
  ) async* {
    if (!endpoint.startsWith('/api/platform/v1/ai/')) {
      throw const FenlengSdkException('ENDPOINT_INVALID', 'AI stream endpoint must use the Platform AI API');
    }
    final request = http.Request('POST', client.options.baseUrl.resolve(endpoint));
    request.headers.addAll(await client.getHeaders());
    request.headers['Accept'] = 'text/event-stream';
    request.body = jsonEncode(payload);
    final response = await client.options.httpClient.send(request).timeout(client.options.timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FenlengSdkException(
        'HTTP_${response.statusCode}',
        'AI stream connection failed',
        status: response.statusCode,
        retryable: response.statusCode >= 500,
      );
    }
    final dataLines = <String>[];
    await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (dataLines.isNotEmpty) {
          final decoded = jsonDecode(dataLines.join('\n'));
          if (decoded is! Map<String, dynamic>) {
            throw const FenlengSdkException('STREAM_EVENT_INVALID', 'AI stream event must be a JSON object');
          }
          yield decoded;
          dataLines.clear();
        }
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }
    if (dataLines.isNotEmpty) {
      final decoded = jsonDecode(dataLines.join('\n'));
      if (decoded is! Map<String, dynamic>) {
        throw const FenlengSdkException('STREAM_EVENT_INVALID', 'AI stream event must be a JSON object');
      }
      yield decoded;
    }
  }
}
