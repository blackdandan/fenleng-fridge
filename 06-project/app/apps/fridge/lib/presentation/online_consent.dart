import 'package:flutter/material.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';

/// Feature-triggered global agreement; never part of first-home startup.
class OnlineConsentDialog extends StatefulWidget {
  final FridgeStrings strings;
  final Future<void> Function() onAccept;
  final ValueChanged<String> onDocument;
  const OnlineConsentDialog({
    super.key,
    required this.strings,
    required this.onAccept,
    required this.onDocument,
  });
  @override
  State<OnlineConsentDialog> createState() => _OnlineConsentDialogState();
}

class _OnlineConsentDialogState extends State<OnlineConsentDialog> {
  bool checked = false, busy = false, failed = false;
  Future<void> accept() async {
    if (!checked || busy) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      await widget.onAccept();
      if (!mounted) return;
      setState(() => busy = false);
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Dialog(
      insetPadding: const EdgeInsets.all(FridgeSpace.medium),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(FridgeSpace.page),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.strings.text('onlineConsentTitle'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: FridgeSpace.medium),
                Text(widget.strings.text('onlineConsentBody')),
                const SizedBox(height: FridgeSpace.medium),
                for (final key in ['terms', 'privacy'])
                  TextButton(
                    onPressed: busy ? null : () => widget.onDocument(key),
                    child: Text(widget.strings.text(key)),
                  ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: checked,
                  onChanged: busy
                      ? null
                      : (value) => setState(() => checked = value ?? false),
                  title: Text(widget.strings.text('onlineConsentCheckbox')),
                ),
                if (failed) ...[
                  const SizedBox(height: FridgeSpace.medium),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      widget.strings.text('onlineConsentFailed'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: FridgeSpace.page),
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(context, false),
                  child: Text(widget.strings.text('cancel')),
                ),
                const SizedBox(height: FridgeSpace.small),
                FilledButton(
                  onPressed: busy || !checked ? null : accept,
                  child: Text(widget.strings.text(busy ? 'loading' : 'agree')),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
