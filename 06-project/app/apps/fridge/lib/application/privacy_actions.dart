part of 'bootstrap.dart';

extension PrivacyActions on FridgeBootstrap {
  Future<bool> openLegal(String key) async {
    if (!legal.containsKey(key)) throw ArgumentError.value(key);
    if (_legalBusy) return false;
    _legalBusy = true;
    final allowWithdrawal = key == 'privacy' && onlineConsent;
    var html = legal[key]!;
    if (appearance != DisplayAppearance.system) {
      html = html.replaceAll(
        '@media(prefers-color-scheme:dark)',
        appearance == DisplayAppearance.dark ? '@media all' : '@media not all',
      );
    }
    if (allowWithdrawal) {
      final label = const HtmlEscape().convert(
        strings!.text('privacyWithdrawLink'),
      );
      html = html.replaceFirst(
        '</main>',
        '<footer><a href="fridge://privacy/withdraw" lang="${const HtmlEscape().convert(strings!.locale)}" dir="auto" '
            'style="display:block;min-height:44px;margin-top:24px;padding:12px 0;color:inherit;font:inherit;line-height:1.6">$label</a></footer></main>',
      );
    }
    try {
      final result = await native.invokeMethod<Object>('legal.open', {
        'html': html,
        'htmlBase64': base64Encode(utf8.encode(html)),
        'title': strings!.text(key),
        'backLabel': strings!.text('back'),
        'errorLabel': strings!.text('error'),
        'appearance': appearance.name,
        'withdrawalEnabled': allowWithdrawal ? 'true' : 'false',
      });
      if (result == 'withdraw') return allowWithdrawal && onlineConsent;
      if (result != true) throw StateError('LEGAL_OPEN_FAILED');
      return false;
    } finally {
      _legalBusy = false;
    }
  }

  /// No logout HTTP is started after withdrawal. A durable native pending flag
  /// lets the same cleanup resume before any SDK/business initialization.
  Future<void> withdrawPrivacy() {
    if (_withdrawal case final pending?) return pending;
    _privacyAccepted = false;
    _online.invalidate();
    _busy = true;
    telemetry?.close();
    final deletionClosing = deletion?.close();
    if (deletionClosing != null) unawaited(deletionClosing);
    stage = BootstrapStage.loading;
    localReminders?.setActive(false);
    final draftClosing = feedback?.close();
    if (draftClosing != null) unawaited(draftClosing);
    _withdrawal =
        Future<void>(() async {
          var failed = false;
          try {
            await identity?.stopForWithdrawal();
          } catch (_) {
            failed = true;
          }
          try {
            if (await native.invokeMethod<bool>('privacy.revoke') != true) {
              failed = true;
            }
          } catch (_) {
            failed = true;
          }
          try {
            final path = await native.invokeMethod<String>('privacy.directory');
            if (path == null || path.isEmpty) {
              throw StateError('PRIVACY_CLEANUP_UNAVAILABLE');
            }
            await IdentityStorage.clearRevokedSession(Directory(path));
          } catch (_) {
            failed = true;
          }
          try {
            await localReminders?.close();
          } catch (_) {
            failed = true;
          }
          try {
            await inventory?.close();
          } catch (_) {
            failed = true;
          }
          if (!failed) {
            try {
              if (await native.invokeMethod<bool>('privacy.finishRevoke') !=
                  true) {
                failed = true;
              }
            } catch (_) {
              failed = true;
            }
          }
          if (failed) {
            stage = BootstrapStage.withdrawalError;
            return;
          }
          localReminders?.dispose();
          localReminders = null;
          feedback?.dispose();
          feedback = null;
          deletion?.dispose();
          deletion = null;
          identity?.dispose();
          identity = null;
          telemetry = null;
          inventory = null;
          dataDirectory = null;
          if (_disposed) return;
          if (FridgeBootstrap.channel == 'global') {
            try {
              await _startBusiness();
            } catch (_) {
              stage = BootstrapStage.error;
            }
          } else {
            stage = BootstrapStage.consent;
          }
        }).whenComplete(() {
          _withdrawal = null;
          _busy = false;
          notifyListeners();
        });
    notifyListeners();
    return _withdrawal!;
  }
}
