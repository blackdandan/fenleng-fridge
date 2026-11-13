part of 'record_editor.dart';

extension _RecordFields on _RecordEditorState {
  Widget _fields(BuildContext context) {
    final layout = FridgeLayout.of(context);
    final palette = Theme.of(context).extension<FridgePalette>()!;
    final labelStyle = TextStyle(
      fontSize: layout.font(FridgeProductTokens.fontSecondary),
      height: 4 / 3,
      color: palette.color('editorLabel'),
    );
    InputDecoration decoration() => InputDecoration(
      isDense: true,
      filled: true,
      fillColor: palette.color('surface'),
      contentPadding: EdgeInsets.all(
        layout.d(FridgeProductTokens.spaceFieldPadding),
      ),
      constraints: const BoxConstraints(minHeight: 44),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          layout.d(FridgeProductTokens.radiusChoice),
        ),
        borderSide: BorderSide(color: palette.border, width: layout.d(.8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          layout.d(FridgeProductTokens.radiusChoice),
        ),
        borderSide: BorderSide(color: palette.border, width: layout.d(.8)),
      ),
    );
    Widget field(String key, Widget child) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.text(key), style: labelStyle),
        SizedBox(height: layout.d(FridgeProductTokens.spaceSmall)),
        child,
      ],
    );
    Widget dateField(String key, DateTime value, bool reminder) => field(
      key,
      OutlinedButton(
        key: ValueKey(key),
        onPressed: locked ? null : () => _pick(reminder),
        style: OutlinedButton.styleFrom(
          backgroundColor: palette.color('surface'),
          foregroundColor: palette.color('ink'),
          minimumSize: const Size(0, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.all(
            layout.d(FridgeProductTokens.spaceFieldPadding),
          ),
          side: BorderSide(color: palette.border, width: layout.d(.8)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              layout.d(FridgeProductTokens.radiusChoice),
            ),
          ),
          textStyle: TextStyle(
            fontSize: layout.font(FridgeProductTokens.fontBody),
            height: 1.3,
            letterSpacing: 0,
            fontWeight: FontWeight.w400,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(FridgeDates.editable(context, strings.locale, value)),
            ),
            SizedBox(width: layout.d(FridgeProductTokens.spaceSmall)),
            SizedBox(
              width: layout.d(FridgeProductTokens.spaceEditorRow),
              height: layout.d(FridgeProductTokens.spaceEditorRow),
              child: Center(
                child: FridgeIcon(FridgeIconName.calendar, scale: layout.scale),
              ),
            ),
          ],
        ),
      ),
    );
    final zoneField = field(
      'storageZone',
      DropdownButtonFormField<StorageZone>(
        key: const ValueKey('record-zone'),
        initialValue: zone,
        decoration: decoration().copyWith(
          contentPadding: EdgeInsetsDirectional.fromSTEB(
            layout.d(FridgeProductTokens.spaceFieldPadding),
            layout.d(FridgeProductTokens.spaceIntroTop),
            layout.d(FridgeProductTokens.spaceEditorChevronEnd),
            layout.d(FridgeProductTokens.spaceIntroTop),
          ),
        ),
        isExpanded: true,
        style: TextStyle(
          fontSize: layout.font(FridgeProductTokens.fontSecondary),
          color: palette.color('editorLabel'),
          height: 1.3,
          letterSpacing: 0,
        ),
        iconSize: layout.d(FridgeProductTokens.fontCaption),
        // Flutter's form-field dropdown reserves a fixed 12px suffix margin.
        // Keep the source SVG intrinsic size and place its ink in the design slot.
        icon: Transform.translate(
          offset: Offset(
            layout.d(FridgeProductTokens.spaceEditorChevronOffset) *
                (Directionality.of(context) == TextDirection.rtl ? -1 : 1),
            0,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: FridgeIcon(
              FridgeIconName.editorChevron,
              scale: layout.scale,
            ),
          ),
        ),
        items: StorageZone.values
            .map(
              (z) =>
                  DropdownMenuItem(value: z, child: Text(strings.text(z.name))),
            )
            .toList(),
        onChanged: locked
            ? null
            : (value) {
                if (value != null) changeZone(value);
              },
      ),
    );
    final intervalField = field(
      'interval',
      Semantics(
        label: strings.text('interval'),
        child: Focus(
          onFocusChange: changeIntervalFocus,
          child: Container(
            key: const ValueKey('record-interval-surface'),
            alignment: Alignment.center,
            constraints: const BoxConstraints(minHeight: 44),
            padding: EdgeInsets.all(
              layout.d(FridgeProductTokens.spaceFieldPadding),
            ),
            decoration: BoxDecoration(
              color: palette.color('surface'),
              borderRadius: BorderRadius.circular(
                layout.d(FridgeProductTokens.radiusChoice),
              ),
              border: Border.all(
                color: palette.color(intervalFocused ? 'primary' : 'line'),
                width: layout.d(FridgeProductTokens.sizeBorder),
              ),
            ),
            child: TextField(
              key: const ValueKey('record-interval'),
              controller: interval,
              enabled: !locked,
              keyboardType: TextInputType.number,
              style: TextStyle(
                fontSize: layout.font(FridgeProductTokens.fontSecondary),
                color: palette.color('editorLabel'),
                height: 1.3,
                letterSpacing: 0,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                isDense: true,
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
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        dateField('addedAt', addedAt, false),
        SizedBox(height: layout.d(FridgeProductTokens.spaceEditorRow)),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 260 ||
                MediaQuery.textScalerOf(context).scale(12) > 16) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  zoneField,
                  SizedBox(
                    height: layout.d(FridgeProductTokens.spaceEditorRow),
                  ),
                  intervalField,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: zoneField),
                SizedBox(width: layout.d(FridgeProductTokens.spaceRow)),
                Expanded(child: intervalField),
              ],
            );
          },
        ),
        SizedBox(height: layout.d(FridgeProductTokens.spaceEditorRow)),
        dateField('nextCheck', dueAt, true),
      ],
    );
  }
}
