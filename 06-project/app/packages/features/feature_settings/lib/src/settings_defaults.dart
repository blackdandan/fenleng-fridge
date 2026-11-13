part of 'settings_screen.dart';

extension _SettingsDefaults on _SettingsScreenState {
  Widget _defaults(BuildContext context) {
    final l = FridgeLayout.of(context);
    final p = Theme.of(context).extension<FridgePalette>()!;
    final inputFont = MediaQuery.textScalerOf(
      context,
    ).scale(l.font(FridgeProductTokens.fontSecondary));
    final numberPaint = math.max(
      l.d(FridgeProductTokens.sizeSettingsNumberPaint),
      inputFont * 1.3 +
          l.d(FridgeProductTokens.spaceSettingsInputPadding) * 2 +
          l.d(FridgeProductTokens.sizeBorder) * 2,
    );
    final numberWidth = math.max(
      l.d(FridgeProductTokens.sizeSettingsNumber),
      inputFont * 2.6 +
          l.d(FridgeProductTokens.spaceSettingsInputPadding) * 2 +
          l.d(FridgeProductTokens.sizeBorder) * 2,
    );
    final timePaint = math.max(
      l.d(FridgeProductTokens.sizeSettingsTimePaint),
      inputFont * 1.3 +
          l.d(FridgeProductTokens.spaceSmall) * 2 +
          l.d(FridgeProductTokens.sizeBorder) * 2,
    );
    final rowText = TextStyle(
      fontSize: l.font(FridgeProductTokens.fontLabel),
      height: 1.3,
    );
    Widget row(Widget label, Widget field, {bool timeRow = false}) =>
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 280 ||
                MediaQuery.textScalerOf(context).scale(13) > 18;
            return ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: l.d(
                  timeRow
                      ? FridgeProductTokens.sizeSettingsTimeRow
                      : FridgeProductTokens.sizeSettingsDefaultRow,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: l.d(
                    timeRow
                        ? FridgeProductTokens.spaceSettingsTimeVertical
                        : FridgeProductTokens.spaceSettingsRowVertical,
                  ),
                ),
                child: stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          label,
                          SizedBox(height: l.d(FridgeProductTokens.spaceSmall)),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: field,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: label),
                          SizedBox(width: l.d(FridgeProductTokens.spaceSmall)),
                          field,
                        ],
                      ),
              ),
            );
          },
        );
    Widget number(StorageZone zone) => Semantics(
      label: '${strings.text(zone.name)} ${strings.text('interval')}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: locked ? null : fields[zone]!.requestFocus,
        child: SizedBox(
          width: numberWidth,
          height: math.max(44, numberPaint),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                key: ValueKey('settings-number-surface-${zone.name}'),
                height: numberPaint,
                decoration: BoxDecoration(
                  color: p.color('settingsField'),
                  borderRadius: BorderRadius.circular(
                    l.d(FridgeProductTokens.radiusSettingsInput),
                  ),
                  border: Border.all(
                    color: p.border,
                    width: l.d(FridgeProductTokens.sizeBorder),
                  ),
                ),
              ),
              TextField(
                key: ValueKey('settings-default-${zone.name}'),
                controller: controllers[zone],
                focusNode: fields[zone],
                enabled: !locked,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                textAlignVertical: TextAlignVertical.center,
                onChanged: changed,
                style: TextStyle(
                  fontSize: l.font(FridgeProductTokens.fontSecondary),
                  height: 1.3,
                  color: p.color('ink'),
                  letterSpacing: 0,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  isCollapsed: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final clock = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(time, alwaysUse24HourFormat: true);
    final clockStyle = DefaultTextStyle.of(context).style.merge(
      TextStyle(
        fontSize: l.font(FridgeProductTokens.fontSecondary),
        height: 1.3,
        letterSpacing: 0,
      ),
    );
    final clockMeasure = TextPainter(
      text: TextSpan(text: clock, style: clockStyle),
      textDirection: strings.direction,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final timeWidth = math.max(
      l.d(FridgeProductTokens.sizeSettingsTime),
      clockMeasure.width +
          l.d(11.375) +
          l.d(
            FridgeProductTokens.spaceSettingsTimeStart +
                FridgeProductTokens.spaceSettingsTimeEnd +
                FridgeProductTokens.spaceSmall,
          ),
    );
    clockMeasure.dispose();
    final timeField = Semantics(
      label: strings.text('reminderTime'),
      button: true,
      child: InkWell(
        key: const ValueKey('settings-time'),
        onTap: locked ? null : chooseTime,
        child: SizedBox(
          width: timeWidth,
          height: math.max(44, timePaint),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Align(
                  child: Container(
                    key: const ValueKey('settings-time-surface'),
                    height: timePaint,
                    decoration: BoxDecoration(
                      color: p.color('settingsField'),
                      borderRadius: BorderRadius.circular(
                        l.d(FridgeProductTokens.radiusSettingsInput),
                      ),
                      border: Border.all(
                        color: p.border,
                        width: l.d(FridgeProductTokens.sizeBorder),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: l.d(FridgeProductTokens.spaceSettingsTimeStart),
                    end: l.d(FridgeProductTokens.spaceSettingsTimeEnd),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        clock,
                        style: TextStyle(
                          fontSize: l.font(FridgeProductTokens.fontSecondary),
                          height: 1.3,
                        ),
                      ),
                      FridgeIcon(FridgeIconName.clock, scale: l.scale),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return _group(context, [
      for (final zone in StorageZone.values)
        row(
          Row(
            children: [
              FridgeIcon(switch (zone) {
                StorageZone.cold => FridgeIconName.settingsCold,
                StorageZone.frozen => FridgeIconName.settingsFrozen,
                StorageZone.pantry => FridgeIconName.settingsPantry,
              }, scale: l.scale),
              SizedBox(width: l.d(FridgeProductTokens.spaceCabinet)),
              Expanded(child: Text(strings.text(zone.name), style: rowText)),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              number(zone),
              SizedBox(width: l.d(FridgeProductTokens.spaceTiny)),
              Text(strings.text('daysUnit'), style: rowText),
            ],
          ),
        ),
      row(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.text('reminderTime'), style: rowText),
            SizedBox(height: l.d(FridgeProductTokens.spacePhotoCaptionTop)),
            Text(
              strings.text('reminderRule'),
              style: TextStyle(
                fontSize: l.font(FridgeProductTokens.fontMetadata),
                height: 1.2,
                color: p.muted,
              ),
            ),
          ],
        ),
        timeField,
        timeRow: true,
      ),
    ]);
  }
}
