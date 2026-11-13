import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';

class FeedbackScreen extends StatefulWidget {
  final FridgeStrings strings;
  final String draft;
  final String? receipt, errorKey;
  final bool loading, initialized, busy;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit, onRetryLoad, onWriteAnother;
  const FeedbackScreen({
    super.key,
    required this.strings,
    required this.draft,
    required this.loading,
    required this.initialized,
    required this.busy,
    required this.onChanged,
    required this.onSubmit,
    required this.onRetryLoad,
    required this.onWriteAnother,
    this.receipt,
    this.errorKey,
  });
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  late final TextEditingController text;
  @override
  void initState() {
    super.initState();
    text = TextEditingController(text: widget.draft);
  }

  @override
  void didUpdateWidget(FeedbackScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (text.text != widget.draft)
      text.value = TextEditingValue(
        text: widget.draft,
        selection: TextSelection.collapsed(offset: widget.draft.length),
      );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.busy,
    child: FridgePage(
      title: widget.strings.text('feedback'),
      headerTop: FridgeProductTokens.spaceHeaderTop,
      titleGap: FridgeProductTokens.spaceHistoryTitleGap,
      child: Builder(
        builder: (context) {
          final l = FridgeLayout.of(context);
          final p = Theme.of(context).extension<FridgePalette>()!;
          final s = widget.strings;
          Widget error() => Padding(
            padding: EdgeInsets.symmetric(
              vertical: l.d(FridgeProductTokens.spaceDoorBottom),
            ),
            child: Semantics(
              liveRegion: true,
              child: Text(
                s.text(widget.errorKey!),
                style: TextStyle(
                  fontSize: l.font(FridgeProductTokens.fontBody),
                  height: 1.6,
                  color: p.color('danger'),
                ),
              ),
            ),
          );
          if (widget.loading)
            return const Center(child: CircularProgressIndicator());
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              top: l.d(FridgeProductTokens.spaceSettingsFirstSection),
              bottom: l.d(FridgeProductTokens.spaceBottom),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.initialized) ...[
                  if (widget.errorKey != null) error(),
                  FridgeAction(
                    label: s.text('retry'),
                    onPressed: widget.onRetryLoad,
                  ),
                ] else if (widget.receipt case final receipt?) ...[
                  Text(
                    s.text('feedbackAccepted'),
                    style: TextStyle(
                      fontSize: l.font(FridgeProductTokens.fontFeedbackSuccess),
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: l.d(FridgeProductTokens.spaceSettingsCard)),
                  SelectableText(
                    s.format('feedbackReceipt', {'id': receipt}),
                    style: TextStyle(
                      fontSize: l.font(FridgeProductTokens.fontFeedbackBody),
                      height: 1.6,
                    ),
                  ),
                  SizedBox(height: l.d(FridgeProductTokens.spaceSettingsCard)),
                  Text(
                    s.text('feedbackAcceptedBody'),
                    style: TextStyle(
                      fontSize: l.font(FridgeProductTokens.fontFeedbackBody),
                      height: 1.6,
                      color: p.muted,
                    ),
                  ),
                  SizedBox(height: l.d(FridgeProductTokens.spaceSettingsCard)),
                  if (widget.errorKey != null) error(),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FridgeAction(
                      label: s.text('feedbackWriteAnother'),
                      secondary: true,
                      onPressed: widget.busy ? null : widget.onWriteAnother,
                    ),
                  ),
                ] else ...[
                  Text(
                    s.text('feedbackSubject'),
                    style: TextStyle(
                      fontSize: l.font(FridgeProductTokens.fontFeedbackBody),
                      height: 1.6,
                    ),
                  ),
                  SizedBox(height: l.d(FridgeProductTokens.spaceRow)),
                  Semantics(
                    label: s.text('feedbackSubject'),
                    child: Container(
                      key: const ValueKey('feedback-input-surface'),
                      height: math.max(
                        l.d(FridgeProductTokens.sizeFeedbackInput),
                        MediaQuery.textScalerOf(context).scale(
                                  l.font(FridgeProductTokens.fontFeedbackBody),
                                ) *
                                4.8 +
                            l.d(FridgeProductTokens.spaceRow) * 2,
                      ),
                      padding: EdgeInsets.all(
                        l.d(FridgeProductTokens.spaceRow),
                      ),
                      decoration: BoxDecoration(
                        color: p.color('surface'),
                        borderRadius: BorderRadius.circular(
                          l.d(FridgeProductTokens.radiusOuter),
                        ),
                        border: Border.all(
                          color: p.border,
                          width: l.d(FridgeProductTokens.sizeBorder),
                        ),
                      ),
                      child: TextField(
                        key: const ValueKey('feedback-message'),
                        controller: text,
                        enabled: !widget.busy,
                        maxLines: null,
                        expands: true,
                        maxLength: 4000,
                        onChanged: widget.onChanged,
                        keyboardType: TextInputType.multiline,
                        style: TextStyle(
                          fontSize: l.font(
                            FridgeProductTokens.fontFeedbackBody,
                          ),
                          height: 1.6,
                          letterSpacing: 0,
                        ),
                        decoration: InputDecoration(
                          hintText: s.text('feedbackPlaceholder'),
                          hintStyle: TextStyle(
                            color: p.color('feedbackPlaceholder'),
                          ),
                          counterText: '',
                          isDense: true,
                          isCollapsed: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: l.d(FridgeProductTokens.spaceRow)),
                  Text(
                    s.text('feedbackPrivacy'),
                    style: TextStyle(
                      fontSize: l.font(FridgeProductTokens.fontSecondary),
                      height: 1.8,
                      color: p.muted,
                    ),
                  ),
                  if (widget.errorKey != null) error(),
                  SizedBox(
                    height: l.d(FridgeProductTokens.spaceFeedbackActionTop),
                  ),
                  FridgeAction(
                    key: const ValueKey('feedback-submit'),
                    minHeight: FridgeProductTokens.sizeFeedbackAction,
                    fontSize: FridgeProductTokens.fontSettingsLegal,
                    label: s.text(
                      widget.busy
                          ? 'loading'
                          : widget.errorKey != null
                          ? 'feedbackRetrySubmit'
                          : 'feedbackSubmit',
                    ),
                    onPressed: widget.busy ? null : widget.onSubmit,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ),
  );
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }
}
