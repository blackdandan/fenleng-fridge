import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';
import '../application/identity_session.dart';
import '../application/account_deletion.dart';
import 'account_deletion.dart';

class AccountPage extends StatefulWidget {
  final IdentitySession session;
  final FridgeStrings strings;
  final bool china;
  final bool showApple;
  final AccountDeletionSession? deletion;
  final Future<void> Function(Future<bool> Function())? onDelete;
  final Future<void> Function()? onRetryReceipt, onLogout;
  final Future<void> Function(IdentityProvider)? onLogin;
  final ValueChanged<IdentityProvider>? onDeletionProvider;
  final IdentityProvider deletionProvider;
  const AccountPage({
    super.key,
    required this.session,
    required this.strings,
    required this.china,
    required this.showApple,
    this.deletion,
    this.onDelete,
    this.onRetryReceipt,
    this.onLogout,
    this.onLogin,
    this.onDeletionProvider,
    this.deletionProvider = IdentityProvider.wechat,
  });
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  int _ownerRevision = -1;
  late IdentityProvider _selectedProvider =
      !widget.china && widget.deletionProvider == IdentityProvider.wechat
      ? IdentityProvider.google
      : widget.deletionProvider;
  IdentitySession get session => widget.session;
  FridgeStrings get strings => widget.strings;
  bool get china => widget.china;
  bool get showApple => widget.showApple;
  bool get locked =>
      session.busy ||
      (widget.deletion?.busy ?? false) ||
      (widget.deletion?.receiptIncomplete ?? false);
  @override
  void initState() {
    super.initState();
    session.addListener(_identityChanged);
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final model = widget.deletion;
    await model?.start();
    if (mounted &&
        identical(model, widget.deletion) &&
        session.signedIn &&
        !session.busy &&
        !(model?.receiptIncomplete ?? false)) {
      await model?.refreshOwner();
      _ownerRevision = session.revision;
    }
  }

  void _identityChanged() {
    final model = widget.deletion;
    if (mounted &&
        session.signedIn &&
        !session.busy &&
        model?.initialized == true &&
        !model!.busy &&
        !model.receiptIncomplete &&
        _ownerRevision != session.revision) {
      _ownerRevision = session.revision;
      unawaited(model.refreshOwner());
    }
  }

  @override
  void dispose() {
    session.removeListener(_identityChanged);
    widget.deletion?.freeze();
    super.dispose();
  }

  Future<void> _login(IdentityProvider provider) async {
    if (widget.onLogin case final login?) {
      await login(provider);
    } else {
      await session.login(provider);
    }
    if (mounted && session.signedIn && session.errorKey == null) {
      _selectedProvider = provider;
      if (widget.onLogin == null) {
        await widget.deletion?.refreshOwner(afterLogin: true);
      }
    }
  }

  Future<bool> _confirm() async {
    if (!mounted) return false;
    return await showDialog<bool>(
              context: context,
              builder: (_) => AccountDeletionDialog(
                strings: strings,
                china: china,
                showApple: showApple,
                initialProvider: _selectedProvider,
                onProvider: (provider) {
                  _selectedProvider = provider;
                  widget.onDeletionProvider?.call(provider);
                },
              ),
            ) ==
            true &&
        mounted;
  }

  Future<void> _delete() async {
    if (widget.onDelete case final remove?) {
      await remove(_confirm);
    } else {
      await widget.deletion?.submit(_confirm);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      session,
      if (widget.deletion != null) widget.deletion!,
    ]),
    builder: (context, _) => FridgePage(
      title: strings.text('account'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.text(session.signedIn ? 'loggedIn' : 'guest'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(strings.text('localOnly')),
            const SizedBox(height: 24),
            if (!session.signedIn &&
                [
                  DeletionPhase.accepted,
                  DeletionPhase.unknown,
                ].contains(widget.deletion?.entry?.phase)) ...[
              Text(strings.text('deletionLoginRecovery')),
              const SizedBox(height: FridgeSpace.medium),
            ],
            if (session.busy) const Center(child: CircularProgressIndicator()),
            if (!session.signedIn) ...[
              if (!china)
                FilledButton(
                  onPressed: locked
                      ? null
                      : () => _login(IdentityProvider.google),
                  child: Text(strings.text('googleLogin')),
                ),
              if (china)
                FilledButton(
                  onPressed: locked
                      ? null
                      : () => _login(IdentityProvider.wechat),
                  child: Text(strings.text('wechatLogin')),
                ),
              if (showApple) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.apple),
                  onPressed: locked
                      ? null
                      : () => _login(IdentityProvider.apple),
                  label: Text(strings.text('appleLogin')),
                ),
              ],
            ] else
              TextButton(
                onPressed: locked ? null : widget.onLogout ?? session.logout,
                child: Text(strings.text('logout')),
              ),
            if (session.errorKey case final String key
                when ![
                  DeletionPhase.accepted,
                  DeletionPhase.unknown,
                ].contains(widget.deletion?.entry?.phase)) ...[
              const SizedBox(height: 16),
              Semantics(liveRegion: true, child: Text(strings.text(key))),
            ],
            if (widget.deletion case final model?)
              AccountDeletionSection(
                model: model,
                strings: strings,
                signedIn: session.signedIn,
                disabled: session.busy,
                onSubmit: () => unawaited(_delete()),
                onRetry: () => unawaited(
                  widget.onRetryReceipt?.call() ?? model.retryReceipt(),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
