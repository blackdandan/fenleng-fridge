import 'dart:convert';
import 'dart:io';
import '../application/feedback_session.dart';

class FileFeedbackDraftStorage implements FeedbackDraftStorage {
  final Directory directory;
  FileFeedbackDraftStorage(this.directory);
  File get _file => File('${directory.path}/feedback-draft.json');
  @override
  Future<FeedbackDraft> load() async {
    if (!await _file.exists()) return (text: '', key: null, receipt: null);
    try {
      final value = jsonDecode(await _file.readAsString());
      if (value is! Map ||
          value['text'] is! String ||
          (value['key'] != null && value['key'] is! String) ||
          (value['receipt'] != null && value['receipt'] is! String)) {
        throw const FormatException('FEEDBACK_DRAFT_INVALID');
      }
      return (
        text: value['text'] as String,
        key: value['key'] as String?,
        receipt: value['receipt'] as String?,
      );
    } on FormatException {
      await _file.copy(
        '${_file.path}.corrupt-${DateTime.now().microsecondsSinceEpoch}',
      );
      rethrow;
    }
  }

  @override
  Future<void> save(FeedbackDraft value) async {
    await directory.create(recursive: true);
    final pending = File('${_file.path}.pending');
    await pending.writeAsString(
      jsonEncode({
        'text': value.text,
        'key': value.key,
        'receipt': value.receipt,
      }),
      flush: true,
    );
    await pending.rename(_file.path);
  }
}
