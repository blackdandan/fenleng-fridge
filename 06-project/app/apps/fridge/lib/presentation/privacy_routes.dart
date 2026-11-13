part of '../main.dart';

extension _PrivacyRoutes on _FridgeAppState {
  Future<bool> _ensureOnline(BuildContext context) async {
    if (bootstrap.onlineConsent) {
      var ready = false;
      await _perform(context, () async {
        await bootstrap.ensureOnlineServices();
        ready = bootstrap.onlineConsent;
      });
      return ready && context.mounted;
    }
    if (FridgeBootstrap.channel != 'global' ||
        _onlinePromptOpen ||
        !context.mounted) {
      return false;
    }
    _onlinePromptOpen = true;
    try {
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => OnlineConsentDialog(
          strings: bootstrap.strings!,
          onAccept: bootstrap.acceptOnline,
          onDocument: (key) => _legal(context, key),
        ),
      );
      return accepted == true && bootstrap.onlineConsent && context.mounted;
    } finally {
      _onlinePromptOpen = false;
    }
  }

  Future<void> _account(BuildContext context) async {
    if (!await _ensureOnline(context) || !context.mounted) return;
    final session = bootstrap.identity;
    if (session == null) return;
    _push(
      context,
      AccountPage(
        session: session,
        strings: bootstrap.strings!,
        china: FridgeBootstrap.channel == 'china',
        showApple: Platform.isIOS,
        deletion: bootstrap.deletion,
        onDelete: bootstrap.deleteAccount,
        onRetryReceipt: bootstrap.retryDeletionReceipt,
        onLogin: bootstrap.loginAccount,
        onLogout: bootstrap.logoutAccount,
        deletionProvider: bootstrap.deletionProvider,
        onDeletionProvider: (provider) => bootstrap.deletionProvider = provider,
      ),
    );
  }

  Future<void> _openLegal(BuildContext context, String key) async {
    if (!await bootstrap.openLegal(key) || !context.mounted) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (_) => PrivacyWithdrawalDialog(strings: bootstrap.strings!),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    _navigator.currentState?.popUntil((route) => route.isFirst);
    await bootstrap.withdrawPrivacy();
  }
}
