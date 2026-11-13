part of 'capture_screen.dart';

extension _CaptureViewfinder on CaptureScreen {
  Widget _viewfinder(BuildContext context) {
    final l = FridgeLayout.of(context);
    final p = Theme.of(context).extension<FridgePalette>()!;
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        key: const ValueKey('capture-preview'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: p.color('cameraControl'),
          borderRadius: BorderRadius.circular(
            l.d(FridgeProductTokens.radiusCameraPreview),
          ),
          border: Border.all(
            color: p.color('cameraPreviewBorder'),
            width: l.d(FridgeProductTokens.sizeBorder),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (ready) preview,
            if (ready)
              IgnorePointer(
                child: Padding(
                  padding: EdgeInsets.all(
                    l.d(FridgeProductTokens.spaceCameraGuide),
                  ),
                  child: Container(
                    key: const ValueKey('capture-guide'),
                    padding: EdgeInsets.fromLTRB(
                      l.d(FridgeProductTokens.spaceSmall),
                      0,
                      l.d(FridgeProductTokens.spaceSmall),
                      l.d(FridgeProductTokens.spaceCameraGuideBottom),
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        l.d(FridgeProductTokens.radiusOuter),
                      ),
                      border: Border.all(
                        color: p.color('cameraGuideBorder'),
                        width: l.d(FridgeProductTokens.sizeBorder),
                      ),
                    ),
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: l.d(
                          FridgeProductTokens.spaceCameraGuideHorizontal,
                        ),
                        vertical: l.d(
                          FridgeProductTokens.spaceCameraGuideVertical,
                        ),
                      ),
                      decoration: BoxDecoration(
                        color: p.color('cameraGuideScrim'),
                        borderRadius: BorderRadius.circular(
                          l.d(FridgeProductTokens.radiusCameraGuideCaption),
                        ),
                      ),
                      child: Text(
                        strings.text('cameraSingleCaption'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: l.font(FridgeProductTokens.fontMetadata),
                          height: 1.4,
                          color: p.color('cameraGuideInk'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (!ready)
              Padding(
                padding: EdgeInsets.all(l.d(FridgeProductTokens.spacePage)),
                child: Center(
                  child: opening
                      ? const CircularProgressIndicator()
                      : SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                strings.text('cameraUnavailable'),
                                textAlign: TextAlign.center,
                              ),
                              TextButton(
                                onPressed: onCameraRetry,
                                child: Text(strings.text('retry')),
                              ),
                              TextButton(
                                onPressed: onSettings,
                                child: Text(strings.text('openSettings')),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
