import 'package:fridge/application/feedback_session.dart';

class DraftMemory implements FeedbackDraftStorage {
  FeedbackDraft value = (text: '', key: null, receipt: null);
  bool failLoad = false, failWrite = false;
  @override
  Future<FeedbackDraft> load() async {
    if (failLoad) throw StateError('private read details');
    return value;
  }

  @override
  Future<void> save(FeedbackDraft next) async {
    if (failWrite) throw StateError('private write details');
    value = next;
  }
}

class FeedbackSender implements FeedbackGateway {
  final List<({String text, String key})> calls = [];
  Future<String> Function(String, String) send = (_, _) async => 'receipt-1';
  @override
  Future<String> submit(String message, String key) {
    calls.add((text: message, key: key));
    return send(message, key);
  }
}
