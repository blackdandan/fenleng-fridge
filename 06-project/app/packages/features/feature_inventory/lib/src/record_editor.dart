import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';

part 'record_editor_fields.dart';

typedef RecordEdits = ({
  StorageZone zone,
  int intervalDays,
  DateTime addedAt,
  DateTime? dueAt,
});

class RecordEditor extends StatefulWidget {
  final FoodRecord food;
  final FridgeStrings strings;
  final ImageProvider photo;
  final Future<void> Function(RecordEdits) onSave;
  final Future<void> Function() onReplace, onDelete;
  final VoidCallback onClose;
  const RecordEditor({
    super.key,
    required this.food,
    required this.strings,
    required this.photo,
    required this.onSave,
    required this.onReplace,
    required this.onDelete,
    required this.onClose,
  });
  @override
  State<RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<RecordEditor> {
  late StorageZone zone;
  late DateTime addedAt, dueAt;
  late final TextEditingController interval;
  bool dueChanged = false, busy = false, failed = false, choosing = false;
  bool intervalFocused = false;
  bool get locked => busy || choosing;
  FridgeStrings get strings => widget.strings;
  void changeZone(StorageZone value) => setState(() => zone = value);
  void changeIntervalFocus(bool value) {
    if (mounted) setState(() => intervalFocused = value);
  }

  @override
  void initState() {
    super.initState();
    zone = widget.food.zone;
    addedAt = widget.food.addedAt;
    dueAt = widget.food.dueAt;
    interval = TextEditingController(text: widget.food.intervalDays.toString());
  }

  Future<void> _pick(bool reminder) async {
    if (locked) return;
    setState(() => choosing = true);
    final initial = reminder ? dueAt : addedAt;
    try {
      final date = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(math.min(1900, initial.year)),
        lastDate: DateTime(math.max(2200, initial.year), 12, 31),
      );
      if (date == null || !mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );
      if (time == null || !mounted) return;
      final value = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      setState(() {
        if (reminder) {
          dueAt = value;
          dueChanged = true;
        } else {
          addedAt = value;
        }
      });
    } finally {
      if (mounted) setState(() => choosing = false);
    }
  }

  Future<void> _run(
    Future<void> Function() action, {
    bool close = false,
  }) async {
    if (locked) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      await action();
      if (close && mounted) widget.onClose();
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save() async {
    if (locked) return;
    final days = parseLocalizedInt(interval.text);
    if (days == null || days < 1 || days > 3650) {
      setState(() => failed = true);
      return;
    }
    await _run(
      () => widget.onSave((
        zone: zone,
        intervalDays: days,
        addedAt: addedAt,
        dueAt: dueChanged ? dueAt : null,
      )),
      close: true,
    );
  }

  Future<void> _delete() async {
    if (locked) return;
    setState(() => choosing = true);
    bool? yes;
    try {
      yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          insetPadding: const EdgeInsets.all(16),
          content: Text(strings.text('confirmDelete')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(strings.text('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(strings.text('delete')),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => choosing = false);
    }
    if (yes == true && mounted) await _run(widget.onDelete, close: true);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scale = math.min(media.size.width, FridgeSpace.maxWidth) / 430;
    final palette = Theme.of(context).extension<FridgePalette>()!;
    final maxHeight = math.max(
      0.0,
      media.size.height -
          media.padding.vertical -
          media.viewInsets.vertical -
          32,
    );
    return PopScope(
      canPop: !locked,
      child: Dialog(
        backgroundColor: palette.color('page'),
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            FridgeProductTokens.radiusDialog * scale,
          ),
          side: BorderSide(
            color: palette.border,
            width: FridgeProductTokens.sizeBorder * scale,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: math.min(media.size.width - 32, 568),
          height: math.min(
            FridgeProductTokens.sizeDialogHeight * scale,
            maxHeight,
          ),
          child: FridgeLayout(
            scale: scale,
            child: Builder(
              builder: (context) {
                final layout = FridgeLayout.of(context);
                return DefaultTextStyle.merge(
                  style: const TextStyle(letterSpacing: 0),
                  child: SingleChildScrollView(
                    key: const ValueKey('record-editor-scroll'),
                    padding: EdgeInsets.fromLTRB(
                      layout.d(FridgeProductTokens.spacePage),
                      layout.d(FridgeProductTokens.spaceDialogHandleTop),
                      layout.d(FridgeProductTokens.spacePage),
                      layout.d(FridgeProductTokens.spaceEditorBottom),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: layout.d(
                              FridgeProductTokens.sizeDialogHandleWidth,
                            ),
                            height: layout.d(
                              FridgeProductTokens.sizeDialogHandleHeight,
                            ),
                            decoration: BoxDecoration(
                              color: palette.color('dialogHandle'),
                              borderRadius: BorderRadius.circular(
                                layout.d(
                                  FridgeProductTokens.spacePhotoCaptionTop,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: layout.d(
                            FridgeProductTokens.spaceDialogHeaderTop,
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '#${widget.food.id}',
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  fontSize: layout.font(
                                    FridgeProductTokens.fontDialogTitle,
                                  ),
                                  height: 1.4,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: math.max(
                                44,
                                layout.d(FridgeProductTokens.sizeTouchMin),
                              ),
                              height: math.max(
                                44,
                                layout.d(FridgeProductTokens.sizeTouchMin),
                              ),
                              child: TextButton(
                                onPressed: locked ? null : widget.onClose,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  backgroundColor: palette.color('dialogClose'),
                                  foregroundColor: palette.color(
                                    'dialogCloseInk',
                                  ),
                                  shape: const CircleBorder(),
                                ),
                                child: Semantics(
                                  label: MaterialLocalizations.of(
                                    context,
                                  ).closeButtonTooltip,
                                  child: ExcludeSemantics(
                                    child: Text(
                                      '×',
                                      style: TextStyle(
                                        fontSize: layout.font(
                                          FridgeProductTokens.fontDialogClose,
                                        ),
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: layout.d(
                            FridgeProductTokens.spaceDialogPhotoTop,
                          ),
                        ),
                        Center(
                          child: FridgeFoodPhoto(
                            image: widget.photo,
                            size: layout.d(FridgeProductTokens.sizeEditorPhoto),
                            scale: layout.scale,
                            errorLabel: strings.text('error'),
                          ),
                        ),
                        TextButton(
                          onPressed: locked
                              ? null
                              : () => _run(widget.onReplace),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: palette.color('editorPhotoLink'),
                            textStyle: TextStyle(
                              fontSize: layout.font(
                                FridgeProductTokens.fontSecondary,
                              ),
                              letterSpacing: 0,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          child: Transform.translate(
                            offset: Offset(
                              0,
                              -layout.d(
                                FridgeProductTokens.spacePhotoCaptionTop,
                              ),
                            ),
                            child: Text(strings.text('replacePhoto')),
                          ),
                        ),
                        SizedBox(
                          height: layout.d(
                            FridgeProductTokens.spaceEditorFormTop,
                          ),
                        ),
                        _fields(context),
                        SizedBox(
                          height: layout.d(FridgeProductTokens.spaceRow),
                        ),
                        Text(
                          strings.text('editorHint'),
                          style: TextStyle(
                            fontSize: layout.font(
                              FridgeProductTokens.fontSecondary,
                            ),
                            height: 1.8,
                            color: palette.muted,
                          ),
                        ),
                        Text(
                          widget.food.confirmedAt == null
                              ? strings.text('neverOrganized')
                              : strings.format('editorLastOrganized', {
                                  'date': FridgeDates.confirmed(
                                    context,
                                    strings.locale,
                                    widget.food.confirmedAt!,
                                  ),
                                }),
                          style: TextStyle(
                            fontSize: layout.font(
                              FridgeProductTokens.fontSecondary,
                            ),
                            height: 1.8,
                            color: palette.muted,
                          ),
                        ),
                        SizedBox(
                          height: layout.d(FridgeProductTokens.spaceRow),
                        ),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: layout.d(
                              FridgeProductTokens.spaceEditorFormTop,
                            ),
                          ),
                          child: failed
                              ? Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    strings.text('error'),
                                    style: TextStyle(
                                      color: palette.color('danger'),
                                      fontSize: layout.font(
                                        FridgeProductTokens.fontSecondary,
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        SizedBox(
                          height: layout.d(
                            FridgeProductTokens.spaceEditorSaveTop,
                          ),
                        ),
                        FridgeAction(
                          label: strings.text('saveChanges'),
                          onPressed: locked ? null : _save,
                        ),
                        SizedBox(
                          height: layout.d(FridgeProductTokens.spaceSmall),
                        ),
                        TextButton(
                          onPressed: locked ? null : _delete,
                          style: TextButton.styleFrom(
                            foregroundColor: palette.color('editorDelete'),
                            minimumSize: const Size(44, 44),
                            textStyle: TextStyle(
                              fontSize: layout.font(
                                FridgeProductTokens.fontSecondary,
                              ),
                              letterSpacing: 0,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          child: Text(strings.text('deleteRecordAction')),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    interval.dispose();
    super.dispose();
  }
}
