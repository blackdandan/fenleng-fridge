import 'package:flutter/material.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';

class SettingsChoice {
  final String value, label;
  const SettingsChoice(this.value, this.label);
}

class SettingsChoices extends StatefulWidget {
  final String title, selected;
  final FridgeStrings strings;
  final List<SettingsChoice> choices;
  final Future<void> Function(String) onSelect;
  const SettingsChoices({
    super.key,
    required this.title,
    required this.selected,
    required this.strings,
    required this.choices,
    required this.onSelect,
  });
  @override
  State<SettingsChoices> createState() => _SettingsChoicesState();
}

class _SettingsChoicesState extends State<SettingsChoices> {
  bool busy = false, failed = false;
  Future<void> select(String value) async {
    if (busy) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      await widget.onSelect(value);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: FridgePage(
      title: widget.title,
      child: Builder(
        builder: (context) {
          final l = FridgeLayout.of(context);
          return ListView(
            padding: EdgeInsets.symmetric(
              vertical: l.d(FridgeProductTokens.spaceSection),
            ),
            children: [
              if (failed)
                Semantics(
                  liveRegion: true,
                  child: Text(widget.strings.text('error')),
                ),
              for (final choice in widget.choices)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: l.d(FridgeProductTokens.spaceSmall),
                  ),
                  child: Semantics(
                    selected: choice.value == widget.selected,
                    child: FridgeChoice(
                      label: choice.label,
                      selected: choice.value == widget.selected,
                      fontSize: FridgeProductTokens.fontBody,
                      onPressed: busy ? null : () => select(choice.value),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
