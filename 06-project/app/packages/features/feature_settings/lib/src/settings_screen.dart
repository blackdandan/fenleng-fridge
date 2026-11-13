import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';

part 'settings_defaults.dart';
part 'settings_groups.dart';

class SettingsScreen extends StatefulWidget {
  final InventoryState state;
  final FridgeStrings strings;
  final DisplayAppearance appearance;
  final String languageLabel, filing;
  final Future<void> Function(Map<StorageZone, int>, int, int) onSaveDefaults;
  final VoidCallback onHistory, onLanguage, onAppearance, onFeedback, onFiling;
  final VoidCallback? onAccount;
  final VoidCallback? onNotifications;
  final String? notificationStatus;
  final ValueChanged<String> onLegal;
  const SettingsScreen({
    super.key,
    required this.state,
    required this.strings,
    required this.appearance,
    required this.languageLabel,
    required this.onSaveDefaults,
    required this.onHistory,
    required this.onLanguage,
    required this.onAppearance,
    required this.onFeedback,
    required this.onFiling,
    required this.onLegal,
    this.onAccount,
    this.onNotifications,
    this.notificationStatus,
    this.filing = '',
  });
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final Map<StorageZone, TextEditingController> controllers;
  late final Map<StorageZone, FocusNode> fields;
  late TimeOfDay time;
  bool busy = false, selecting = false;
  String? status;
  bool get locked => busy || selecting;
  FridgeStrings get strings => widget.strings;
  @override
  void initState() {
    super.initState();
    controllers = {
      for (final zone in StorageZone.values)
        zone: TextEditingController(text: '${widget.state.defaults[zone]}'),
    };
    fields = {for (final zone in StorageZone.values) zone: FocusNode()};
    time = TimeOfDay(
      hour: widget.state.reminderHour,
      minute: widget.state.reminderMinute,
    );
  }

  Future<void> save() async {
    if (locked) return;
    final values = <StorageZone, int>{};
    for (final entry in controllers.entries) {
      final number = parseLocalizedInt(entry.value.text);
      if (number == null || number < 1 || number > 3650) {
        setState(() => status = 'invalidInterval');
        return;
      }
      values[entry.key] = number;
    }
    FocusScope.of(context).unfocus();
    setState(() => busy = true);
    try {
      await widget.onSaveDefaults(values, time.hour, time.minute);
      if (mounted) setState(() => status = 'saved');
    } catch (_) {
      if (mounted) setState(() => status = 'error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> chooseTime() async {
    if (locked) return;
    setState(() => selecting = true);
    try {
      final result = await showTimePicker(
        context: context,
        initialTime: time,
        initialEntryMode: TimePickerEntryMode.input,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );
      if (result != null && mounted)
        setState(() {
          time = result;
          status = null;
        });
    } finally {
      if (mounted) setState(() => selecting = false);
    }
  }

  void changed(String _) {
    if (status != null) setState(() => status = null);
  }

  @override
  Widget build(BuildContext context) => FridgePage(
    title: strings.text('settings'),
    headerTop: FridgeProductTokens.spaceHeaderTop,
    titleGap: FridgeProductTokens.spaceHistoryTitleGap,
    child: Builder(
      builder: (context) {
        final l = FridgeLayout.of(context);
        final p = Theme.of(context).extension<FridgePalette>()!;
        return DefaultTextStyle.merge(
          style: const TextStyle(letterSpacing: 0),
          child: SingleChildScrollView(
            key: const ValueKey('settings-scroll'),
            padding: EdgeInsets.only(
              bottom: l.d(FridgeProductTokens.spaceBottom),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _section(
                  context,
                  strings.text('settingsDefaultsTitle'),
                  first: true,
                ),
                SizedBox(height: l.d(FridgeProductTokens.spaceRow)),
                _defaults(context),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    l.d(FridgeProductTokens.spaceSettingsHintInset),
                    l.d(FridgeProductTokens.spaceSettingsHintTop),
                    l.d(FridgeProductTokens.spaceSettingsHintInset),
                    0,
                  ),
                  child: Text(
                    strings.text('defaultsHint'),
                    style: TextStyle(
                      fontSize: l.font(FridgeProductTokens.fontMetadata),
                      height: 1.9,
                      color: p.color('settingsHint'),
                    ),
                  ),
                ),
                SizedBox(height: l.d(FridgeProductTokens.spaceSettingsSaveTop)),
                FridgeAction(
                  key: const ValueKey('settings-save'),
                  label: strings.text('saveDefaults'),
                  onPressed: locked ? null : save,
                ),
                Padding(
                  padding: EdgeInsets.only(
                    top: l.d(FridgeProductTokens.spaceSettingsStatusTop),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: l.d(FridgeProductTokens.sizeSettingsStatus),
                    ),
                    child: status == null
                        ? const SizedBox.shrink()
                        : Semantics(
                            liveRegion: true,
                            child: Text(
                              strings.text(status!),
                              style: TextStyle(
                                fontSize: l.font(
                                  FridgeProductTokens.fontSecondary,
                                ),
                                color: p.color(
                                  status == 'saved' ? 'primary' : 'danger',
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                _section(context, strings.text('localRecordsTitle')),
                SizedBox(height: l.d(FridgeProductTokens.spaceRow)),
                _group(context, [
                  _link(
                    context,
                    'history',
                    widget.onHistory,
                    subtitle: strings.text('historyDescription'),
                  ),
                  if (widget.onAccount != null)
                    _link(context, 'account', widget.onAccount!),
                  if (widget.onNotifications != null)
                    _link(
                      context,
                      'notificationSettings',
                      widget.onNotifications!,
                      value: widget.notificationStatus,
                    ),
                ]),
                Padding(
                  padding: EdgeInsets.only(
                    top: l.d(FridgeProductTokens.spaceSettingsHintTop),
                  ),
                  child: Text(
                    strings.text('localOnly'),
                    style: TextStyle(
                      fontSize: l.font(FridgeProductTokens.fontMetadata),
                      height: 1.9,
                      color: p.color('settingsHint'),
                    ),
                  ),
                ),
                _section(context, strings.text('displaySettingsTitle')),
                SizedBox(height: l.d(FridgeProductTokens.spaceRow)),
                _group(context, [
                  _link(
                    context,
                    'appearance',
                    widget.onAppearance,
                    value: strings.text(widget.appearance.name),
                  ),
                  _link(
                    context,
                    'language',
                    widget.onLanguage,
                    value: widget.languageLabel,
                  ),
                ]),
                _section(context, strings.text('agreementsHelp')),
                SizedBox(height: l.d(FridgeProductTokens.spaceRow)),
                _group(context, [
                  for (final key in ['terms', 'privacy'])
                    _link(context, key, () => widget.onLegal(key), legal: true),
                  _link(context, 'feedback', widget.onFeedback, legal: true),
                ]),
                Padding(
                  padding: EdgeInsets.only(
                    top: l.d(FridgeProductTokens.spaceSettingsFilingTop),
                  ),
                  child: TextButton(
                    key: const ValueKey('settings-filing'),
                    onPressed: locked ? null : widget.onFiling,
                    style: TextButton.styleFrom(
                      foregroundColor: p.color('recordDate'),
                      minimumSize: const Size(44, 44),
                      textStyle: TextStyle(
                        fontSize: l.font(FridgeProductTokens.fontCaption),
                        letterSpacing: 0,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    child: Text(
                      widget.filing.isEmpty
                          ? strings.text('filingPending')
                          : widget.filing,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  @override
  void dispose() {
    for (final c in controllers.values) c.dispose();
    for (final f in fields.values) f.dispose();
    super.dispose();
  }
}
