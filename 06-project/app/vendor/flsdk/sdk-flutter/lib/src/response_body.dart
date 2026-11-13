part of 'client.dart';

/// Bound body collection as well as header arrival; cancel only this response.
Future<http.Response> _readResponseBody(
    http.StreamedResponse streamed, Duration timeout) async {
  final result = Completer<List<int>>();
  final bytes = <int>[];
  late StreamSubscription<List<int>> subscription;
  final timer = Timer(timeout, () {
    if (result.isCompleted) return;
    result.completeError(TimeoutException('Response body timed out', timeout));
    unawaited(subscription.cancel().catchError((Object _) {}));
  });
  try {
    subscription = streamed.stream.listen(bytes.addAll, onDone: () {
      timer.cancel();
      if (!result.isCompleted) result.complete(bytes);
    }, onError: (Object error, StackTrace stack) {
      timer.cancel();
      if (!result.isCompleted) result.completeError(error, stack);
    }, cancelOnError: true);
  } catch (_) {
    timer.cancel();
    rethrow;
  }
  return http.Response.bytes(await result.future, streamed.statusCode,
      headers: streamed.headers,
      request: streamed.request,
      isRedirect: streamed.isRedirect,
      persistentConnection: streamed.persistentConnection,
      reasonPhrase: streamed.reasonPhrase);
}
