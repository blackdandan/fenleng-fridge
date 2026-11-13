part of 'capture_screen.dart';

extension _CaptureControls on CaptureScreen {
  Widget _localTag(BuildContext context) {
    final l = FridgeLayout.of(context);
    final p = Theme.of(context).extension<FridgePalette>()!;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        key: const ValueKey('capture-local'),
        padding: EdgeInsets.symmetric(
          horizontal: l.d(FridgeProductTokens.spaceCameraTagHorizontal),
          vertical: l.d(FridgeProductTokens.spaceCameraTagVertical),
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: p.color('cameraTagBorder'),
            width: l.d(FridgeProductTokens.sizeBorder),
          ),
          borderRadius: BorderRadius.circular(
            l.d(FridgeProductTokens.radiusCameraTag),
          ),
        ),
        child: Text(
          strings.text('localOnly'),
          style: TextStyle(
            fontSize: l.font(FridgeProductTokens.fontCaption),
            height: 1.4,
            color: p.color('cameraTag'),
          ),
        ),
      ),
    );
  }

  Widget _selector(BuildContext context) {
    final l = FridgeLayout.of(context);
    final p = Theme.of(context).extension<FridgePalette>()!;
    return Container(
      key: const ValueKey('capture-selector-surface'),
      decoration: BoxDecoration(
        color: p.color('cameraControl'),
        border: Border.all(
          color: p.color('cameraSelectorBorder'),
          width: l.d(FridgeProductTokens.sizeBorder),
        ),
        borderRadius: BorderRadius.circular(
          l.d(FridgeProductTokens.radiusOuter),
        ),
      ),
      child: PopupMenuButton<StorageZone>(
        key: const ValueKey('capture-zone'),
        enabled: !busy,
        tooltip: strings.text('add'),
        initialValue: zone,
        onSelected: onZone,
        itemBuilder: (_) => [
          for (final value in StorageZone.values)
            PopupMenuItem(
              value: value,
              child: Text(
                strings.format('putInto', {
                  'zone': strings.text('${value.name}Zone'),
                }),
              ),
            ),
        ],
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            l.d(FridgeProductTokens.spaceCameraSelectorStart),
            l.d(FridgeProductTokens.spaceCameraSelectorVertical),
            l.d(FridgeProductTokens.spaceCameraSelectorEnd),
            l.d(FridgeProductTokens.spaceCameraSelectorVertical),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  strings.format('putInto', {
                    'zone': strings.text('${zone.name}Zone'),
                  }),
                  style: TextStyle(
                    fontSize: l.font(FridgeProductTokens.fontBody),
                    height: 1.5,
                    color: p.color('cameraSelectorInk'),
                  ),
                ),
              ),
              SizedBox(width: l.d(FridgeProductTokens.spaceSmall)),
              FridgeIcon(
                FridgeIconName.chevronDown,
                scale: l.scale,
                color: p.color('cameraSelectorInk'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls(BuildContext context) {
    final l = FridgeLayout.of(context);
    final p = Theme.of(context).extension<FridgePalette>()!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(
          width: l.d(FridgeProductTokens.sizeCameraSide),
          child: TextButton(
            key: const ValueKey('capture-album'),
            onPressed: locked ? null : onAlbum,
            style: TextButton.styleFrom(
              foregroundColor: p.color('cameraMuted'),
              minimumSize: const Size(44, 44),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FridgeIcon(
                  FridgeIconName.album,
                  scale: l.scale,
                  color: p.color('cameraMuted'),
                ),
                SizedBox(height: l.d(FridgeProductTokens.spacePhotoCaptionTop)),
                Text(
                  strings.text('album'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: l.font(FridgeProductTokens.fontSecondary),
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox.square(
          dimension: math.max(44, l.d(FridgeProductTokens.sizeCameraShutter)),
          child: Semantics(
            label: strings.text('captureNow'),
            button: true,
            enabled: !locked && ready,
            onTap: locked || !ready ? null : onCapture,
            excludeSemantics: true,
            child: OutlinedButton(
              key: const ValueKey('capture-shutter'),
              onPressed: locked || !ready ? null : onCapture,
              style: OutlinedButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                backgroundColor: p.color('cameraInk'),
                disabledBackgroundColor: p
                    .color('cameraInk')
                    .withValues(alpha: .5),
                side: BorderSide(
                  color: p.color('cameraShutterBorder'),
                  width: l.d(FridgeProductTokens.sizeCameraShutterBorder),
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: busy
                  ? const CircularProgressIndicator()
                  : const SizedBox.shrink(),
            ),
          ),
        ),
        SizedBox(
          width: l.d(FridgeProductTokens.sizeCameraSide),
          child: Semantics(
            liveRegion: true,
            child: Text(
              '${strings.text('capturedLabel')}\n${strings.format('recordCountShort', {'count': savedCount})}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: l.font(FridgeProductTokens.fontMetadata),
                height: 1.3,
                color: p.color('cameraCaption'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _footer(BuildContext context) {
    final l = FridgeLayout.of(context);
    final p = Theme.of(context).extension<FridgePalette>()!;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failed) ...[
            SizedBox(height: l.d(FridgeProductTokens.spaceRow)),
            Semantics(
              liveRegion: true,
              child: Text(
                strings.text('error'),
                style: TextStyle(color: p.color('danger')),
                textAlign: TextAlign.center,
              ),
            ),
            TextButton(
              key: const ValueKey('capture-retry'),
              onPressed: busy ? null : onRetry,
              child: Text(strings.text('retry')),
            ),
          ],
          SizedBox(height: l.d(FridgeProductTokens.spaceCameraHintTop)),
          Text(
            strings.text('cameraHint'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: l.font(FridgeProductTokens.fontMetadata),
              height: 1.8,
              color: p.color('cameraCaption'),
            ),
          ),
          const Spacer(),
          SizedBox(height: l.d(FridgeProductTokens.spaceCameraFinishTop)),
          OutlinedButton(
            key: const ValueKey('capture-finish'),
            onPressed: locked ? null : onFinish,
            style: OutlinedButton.styleFrom(
              backgroundColor: p.color('cameraControl'),
              foregroundColor: p.color('cameraFinishInk'),
              minimumSize: const Size(0, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.symmetric(
                horizontal: l.d(FridgeProductTokens.spaceSettingsCard),
                vertical: l.d(FridgeProductTokens.spaceRow),
              ),
              side: BorderSide(
                color: p.color('cameraControlBorder'),
                width: l.d(FridgeProductTokens.sizeBorder),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  l.d(FridgeProductTokens.radiusCameraFinish),
                ),
              ),
              textStyle: TextStyle(
                fontSize: l.font(FridgeProductTokens.fontLabel),
                height: 1.4,
                letterSpacing: 0,
              ),
            ),
            child: Text(strings.text('done'), textAlign: TextAlign.center),
          ),
          SizedBox(height: l.d(FridgeProductTokens.spaceCameraBottom)),
        ],
      ),
    );
  }
}
