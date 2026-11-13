import 'package:flutter/material.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';
import '../application/account_deletion.dart';
import '../application/identity_session.dart';

class AccountDeletionSection extends StatelessWidget {
  final AccountDeletionSession model;
  final FridgeStrings strings;
  final bool signedIn, disabled;
  final VoidCallback onSubmit, onRetry;
  const AccountDeletionSection({
    super.key,
    required this.model,
    required this.strings,
    required this.signedIn,
    required this.disabled,
    required this.onSubmit,
    required this.onRetry,
  });
  @override
  Widget build(BuildContext context) {
    final entry = model.entry, receipt = model.entry?.receipt;
    final accepted = entry?.phase == DeletionPhase.accepted,
        unknown = entry?.phase == DeletionPhase.unknown;
    final error = accepted && !model.durable
        ? 'deletionUnsaved'
        : unknown && model.errorKey == 'deletionUnknown'
        ? null
        : model.errorKey;
    String timestamp(String raw) {
      final value = deletionInstant(raw)!.toLocal();
      final l10n = MaterialLocalizations.of(context);
      return '${l10n.formatFullDate(value)} ${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(value), alwaysUse24HourFormat: true)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: FridgeSpace.page),
        const Divider(),
        const SizedBox(height: FridgeSpace.medium),
        Text(
          strings.text('deletionTitle'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: FridgeSpace.medium),
        if (model.loading)
          Text(strings.text('loading'))
        else ...[
          if (entry != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(FridgeSpace.page),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      strings.text('deletionLocalRecord'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: FridgeSpace.small),
                    if (accepted) Text(strings.text('deletionPending')),
                    if (unknown) Text(strings.text('deletionUnknown')),
                    if (entry.phase == DeletionPhase.cancelled)
                      Text(
                        strings.text(
                          receipt == null
                              ? 'deletionLoginResolved'
                              : 'deletionRestored',
                        ),
                      ),
                    if (receipt != null) ...[
                      const SizedBox(height: FridgeSpace.medium),
                      Text(
                        strings.format('deletionRequestedAt', {
                          'time': timestamp(receipt.requestedAt),
                        }),
                      ),
                      if (accepted)
                        Text(
                          strings.format('deletionEligibleAt', {
                            'time': timestamp(receipt.eligibleAt),
                          }),
                        ),
                    ],
                    if (accepted) ...[
                      const SizedBox(height: FridgeSpace.medium),
                      Text(strings.text('deletionWaitingHint')),
                    ],
                  ],
                ),
              ),
            ),
          if (!accepted && !unknown) Text(strings.text('deletionBody')),
          if (error != null) ...[
            const SizedBox(height: FridgeSpace.medium),
            Semantics(
              liveRegion: true,
              child: Text(
                strings.text(error),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
          const SizedBox(height: FridgeSpace.medium),
          if (model.busy)
            Semantics(
              liveRegion: true,
              child: Text(strings.text('deletionProcessing')),
            ),
          if (!model.initialized)
            TextButton(
              onPressed: disabled || model.busy ? null : () => model.start(),
              child: Text(strings.text('retry')),
            )
          else if (model.receiptIncomplete)
            FilledButton(
              onPressed: disabled || model.busy ? null : onRetry,
              child: Text(strings.text('deletionRetryReceipt')),
            )
          else if (signedIn && !accepted)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: disabled || model.busy ? null : onSubmit,
              child: Text(
                strings.text(unknown ? 'deletionRetry' : 'deletionTitle'),
              ),
            )
          else if (!signedIn && !accepted && !unknown)
            Text(strings.text('deletionLoginRequired')),
        ],
      ],
    );
  }
}

class AccountDeletionDialog extends StatefulWidget {
  final FridgeStrings strings;
  final bool china, showApple;
  final IdentityProvider initialProvider;
  final ValueChanged<IdentityProvider> onProvider;
  const AccountDeletionDialog({
    super.key,
    required this.strings,
    required this.china,
    required this.showApple,
    required this.initialProvider,
    required this.onProvider,
  });
  @override
  State<AccountDeletionDialog> createState() => _AccountDeletionDialogState();
}

class _AccountDeletionDialogState extends State<AccountDeletionDialog> {
  late IdentityProvider provider = widget.initialProvider;
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
                widget.strings.text('deletionTitle'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: FridgeSpace.medium),
              Text(widget.strings.text('deletionBody')),
              const SizedBox(height: FridgeSpace.medium),
              Text(widget.strings.text('deletionReauthenticate')),
              if (!widget.china || widget.showApple) ...[
                const SizedBox(height: FridgeSpace.medium),
                for (final choice in [
                  widget.china
                      ? IdentityProvider.wechat
                      : IdentityProvider.google,
                  if (widget.showApple) IdentityProvider.apple,
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: FridgeSpace.small),
                    child: OutlinedButton(
                      onPressed: () => setState(() => provider = choice),
                      child: Row(
                        children: [
                          Icon(
                            provider == choice
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                          ),
                          const SizedBox(width: FridgeSpace.small),
                          Expanded(
                            child: Text(
                              widget.strings.text(
                                choice == IdentityProvider.google
                                    ? 'googleLogin'
                                    : choice == IdentityProvider.wechat
                                    ? 'wechatLogin'
                                    : 'appleLogin',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: FridgeSpace.page),
              TextButton(
                autofocus: true,
                onPressed: () => Navigator.pop(context, false),
                child: Text(widget.strings.text('cancel')),
              ),
              const SizedBox(height: FridgeSpace.small),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () {
                  widget.onProvider(provider);
                  Navigator.pop(context, true);
                },
                child: Text(widget.strings.text('deletionConfirmAction')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
