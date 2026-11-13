import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';
import '../application/feedback_session.dart';

class PlatformFeedbackGateway implements FeedbackGateway {
  final FlutterFeedbackSDK sdk;
  final bool configured;
  final Future<bool> Function() ensureSession;
  PlatformFeedbackGateway({
    required FenlengFlutterClient client,
    required this.configured,
    required this.ensureSession,
  }) : sdk = FlutterFeedbackSDK(
         client: client,
         projectId: 'fenleng-fridge',
         version: const String.fromEnvironment(
           'FRIDGE_APP_VERSION',
           defaultValue: '0.1.0+1',
         ),
       );
  @override
  Future<String> submit(String message, String idempotencyKey) async {
    if (!configured) throw const FeedbackFailure('feedbackUnavailable');
    if (!await ensureSession()) {
      throw const FeedbackFailure('feedbackSessionUnavailable');
    }
    final result = await sdk.submit(message, idempotencyKey);
    final id = result['id'];
    if (result['status'] != 'RECEIVED' ||
        id is! String ||
        id.trim().isEmpty ||
        id.length > 128) {
      throw const FeedbackFailure('feedbackFailed');
    }
    return id;
  }
}
