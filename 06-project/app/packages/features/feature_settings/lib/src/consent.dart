import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';

class ConsentScreen extends StatelessWidget {
  final FridgeStrings strings;
  final bool declined;
  final VoidCallback onAccept, onDecline, onReconsider;
  final ValueChanged<String> onDocument;
  const ConsentScreen({
    super.key,
    required this.strings,
    required this.declined,
    required this.onAccept,
    required this.onDecline,
    required this.onReconsider,
    required this.onDocument,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<FridgePalette>()!;
    final scale =
        math.min(MediaQuery.sizeOf(context).width, FridgeSpace.maxWidth) / 430;
    return Stack(
      children: [
        FridgePage(
          title: strings.text('home'),
          back: false,
          child: LayoutBuilder(
            builder: (context, bounds) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: bounds.maxHeight),
                child: FridgeEmpty(label: strings.text('localOnly')),
              ),
            ),
          ),
        ),
        ModalBarrier(dismissible: false, color: palette.color('scrim')),
        SafeArea(
          child: Dialog(
            backgroundColor: palette.color('page'),
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(FridgeSpace.medium),
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
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: FridgeLayout(
                scale: scale,
                child: Builder(
                  builder: (context) {
                    final layout = FridgeLayout.of(context);
                    final body = TextStyle(
                      color: palette.color('ink'),
                      fontSize: layout.font(
                        FridgeProductTokens.fontConsentBody,
                      ),
                      fontWeight: FontWeight.w400,
                      height: 1.6,
                      letterSpacing: 0,
                    );
                    Widget document(String key) => TextButton(
                      onPressed: () => onDocument(key),
                      style: TextButton.styleFrom(
                        foregroundColor: palette.color('primary'),
                        minimumSize: const Size(44, 44),
                        padding: EdgeInsets.all(layout.d(FridgeSpace.small)),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: TextStyle(
                          fontSize: layout.font(FridgeProductTokens.fontBody),
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                          letterSpacing: 0,
                        ),
                      ),
                      child: Text(strings.text(key)),
                    );
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        layout.d(FridgeProductTokens.spacePage),
                        layout.d(FridgeProductTokens.spaceConsentTop),
                        layout.d(FridgeProductTokens.spacePage),
                        layout.d(FridgeProductTokens.spaceConsentBottom),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            strings.text('consentTitle'),
                            style: TextStyle(
                              color: palette.color('ink'),
                              fontSize: layout.font(
                                FridgeProductTokens.fontDialogTitle,
                              ),
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                              letterSpacing: 0,
                            ),
                          ),
                          SizedBox(
                            height: layout.d(
                              FridgeProductTokens.spaceConsentBodyTop,
                            ),
                          ),
                          Text(strings.text('consentBody'), style: body),
                          SizedBox(height: layout.d(FridgeSpace.medium)),
                          Text(
                            strings.text('consentPermissionNotice'),
                            style: body,
                          ),
                          SizedBox(height: layout.d(FridgeSpace.medium)),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: layout.d(FridgeSpace.small),
                            runSpacing: layout.d(FridgeSpace.small),
                            children: [document('terms'), document('privacy')],
                          ),
                          SizedBox(height: layout.d(FridgeSpace.medium)),
                          FridgeAction(
                            label: strings.text(declined ? 'retry' : 'agree'),
                            fontSize: FridgeProductTokens.fontConsentBody,
                            minHeight: FridgeProductTokens.sizeTouchMin,
                            onPressed: declined ? onReconsider : onAccept,
                          ),
                          if (!declined) ...[
                            SizedBox(
                              height: layout.d(FridgeProductTokens.spaceRow),
                            ),
                            FridgeAction(
                              label: strings.text('decline'),
                              secondary: true,
                              fontSize: FridgeProductTokens.fontConsentBody,
                              minHeight:
                                  FridgeProductTokens.sizeConsentSecondary,
                              onPressed: onDecline,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
