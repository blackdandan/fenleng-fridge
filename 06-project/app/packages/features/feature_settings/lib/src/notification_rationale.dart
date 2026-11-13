import 'package:flutter/material.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';

/// Dialog routes live outside FridgePage, so install their layout explicitly.
class NotificationPermissionDialog extends StatelessWidget {
  final FridgeStrings strings;
  final VoidCallback onContinue, onLater;
  const NotificationPermissionDialog({
    super.key,
    required this.strings,
    required this.onContinue,
    required this.onLater,
  });
  @override
  Widget build(BuildContext context) => FridgeLayout(
    scale:
        MediaQuery.sizeOf(context).width.clamp(0.0, FridgeSpace.maxWidth) / 430,
    child: Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.all(FridgeSpace.medium),
      constraints: const BoxConstraints(maxWidth: FridgeSpace.maxWidth),
      child: Padding(
        padding: const EdgeInsets.all(FridgeSpace.page),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.text('notificationPermissionTitle'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: FridgeSpace.medium),
              Text(strings.text('notificationPermissionBody')),
              const SizedBox(height: FridgeSpace.medium),
              FridgeAction(
                label: strings.text('continueRequest'),
                onPressed: onContinue,
              ),
              const SizedBox(height: FridgeSpace.small),
              FridgeAction(
                label: strings.text('notificationLater'),
                secondary: true,
                onPressed: onLater,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
