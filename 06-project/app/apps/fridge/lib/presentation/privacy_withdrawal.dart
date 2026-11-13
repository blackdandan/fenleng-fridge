import 'package:flutter/material.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';

class PrivacyWithdrawalDialog extends StatelessWidget {
  final FridgeStrings strings;
  const PrivacyWithdrawalDialog({super.key, required this.strings});
  @override
  Widget build(BuildContext context) => Dialog(
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
                strings.text('privacyWithdrawTitle'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: FridgeSpace.medium),
              Text(strings.text('privacyWithdrawBody')),
              const SizedBox(height: FridgeSpace.page),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(strings.text('privacyWithdrawConfirm')),
              ),
              const SizedBox(height: FridgeSpace.small),
              TextButton(
                autofocus: true,
                onPressed: () => Navigator.pop(context, false),
                child: Text(strings.text('cancel')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PrivacyWithdrawalError extends StatelessWidget {
  final FridgeStrings strings;
  final VoidCallback onRetry;
  final ValueChanged<String> onDocument;
  const PrivacyWithdrawalError({
    super.key,
    required this.strings,
    required this.onRetry,
    required this.onDocument,
  });
  @override
  Widget build(BuildContext context) => FridgePage(
    title: strings.text('privacy'),
    back: false,
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: FridgeSpace.page),
          Text(
            strings.text('privacyWithdrawFailed'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: FridgeSpace.medium),
          Text(strings.text('privacyWithdrawRetryBody')),
          const SizedBox(height: FridgeSpace.page),
          FilledButton(onPressed: onRetry, child: Text(strings.text('retry'))),
          const SizedBox(height: FridgeSpace.medium),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                onPressed: () => onDocument('terms'),
                child: Text(strings.text('terms')),
              ),
              TextButton(
                onPressed: () => onDocument('privacy'),
                child: Text(strings.text('privacy')),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
