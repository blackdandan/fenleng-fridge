part of 'bootstrap.dart';

class _OnlineLifecycleState {
  bool mutating = false, foreground = true;
  int epoch = 0;
  Future<void>? accepting, starting;
  void invalidate() {
    epoch++;
    mutating = false;
    accepting = null;
    starting = null;
  }
}

extension OnlineSessions on FridgeBootstrap {
  Future<void> _startOnlineSessions() async {
    // Global local-only home does not imply consent to online identity/analytics.
    if (!onlineConsent) return;
    await ensureOnlineServices();
  }

  Future<void> _ensureOnlineServices() {
    if (!onlineConsent) {
      return Future.error(StateError('ONLINE_CONSENT_REQUIRED'));
    }
    if (identity != null &&
        (_online.mutating ||
            deletion?.busy == true ||
            deletion?.receiptIncomplete == true)) {
      return Future.value();
    }
    if (_online.starting case final pending?) return pending;
    late final Future<void> operation;
    operation = _composeOnlineSessions().whenComplete(() {
      if (identical(_online.starting, operation)) _online.starting = null;
    });
    _online.starting = operation;
    return operation;
  }

  /// Global local-home startup never calls this. A visible feature-triggered
  /// confirmation must finish before persisting the shared online agreement.
  Future<void> acceptOnline() {
    if (FridgeBootstrap.channel != 'global' ||
        stage != BootstrapStage.ready ||
        _disposed ||
        _withdrawal != null) {
      return Future.error(StateError('ONLINE_CONSENT_UNAVAILABLE'));
    }
    if (onlineConsent) return ensureOnlineServices();
    if (_online.accepting case final pending?) return pending;
    final epoch = _online.epoch;
    late final Future<void> operation;
    operation =
        Future<void>(() async {
          final saved = await native.invokeMethod<bool>('privacy.accept', {
            'policyVersion': FridgeBootstrap.policyVersion,
            'releaseChannel': FridgeBootstrap.channel,
            'acceptedAt': DateTime.now().toUtc().toIso8601String(),
          });
          if (saved != true) throw StateError('CONSENT_WRITE_FAILED');
          if (_disposed ||
              _online.epoch != epoch ||
              stage != BootstrapStage.ready ||
              _withdrawal != null) {
            throw StateError('ONLINE_CONSENT_CANCELLED');
          }
          _privacyAccepted = true;
          await ensureOnlineServices();
          if (_disposed || _online.epoch != epoch || !onlineConsent) {
            throw StateError('ONLINE_CONSENT_CANCELLED');
          }
          notifyListeners();
        }).whenComplete(() {
          if (identical(_online.accepting, operation)) _online.accepting = null;
        });
    _online.accepting = operation;
    return operation;
  }

  Future<void> _composeOnlineSessions() async {
    if (!onlineConsent) return;
    final epoch = _online.epoch;
    const config = PlatformIdentityConfig();
    identity ??= IdentitySession(
      backend: PlatformIdentityBackend(dataDirectory!, config),
      authorization: PlatformAuthorization(
        config,
        consent: () => onlineConsent,
      ),
      consent: () => onlineConsent,
      configured: config.ready,
      guestEnabled: config.guestEnabled,
      onSessionReset: () => telemetry?.withdraw(),
      canChangeSession: () => onlineSessionMutable,
    );
    final backend = identity!.backend as PlatformIdentityBackend;
    deletion ??= AccountDeletionSession(
      storage: FileDeletionStorage(dataDirectory!),
      gateway: PlatformDeletionGateway(
        auth: backend.auth,
        identity: () => identity!,
        provider: () => deletionProvider,
        consent: () => onlineConsent,
        configured: config.ready,
        firebase: FridgeBootstrap.channel == 'global',
      ),
      consent: () => onlineConsent,
    );
    feedback ??= FeedbackSession(
      storage: FileFeedbackDraftStorage(dataDirectory!),
      gateway: PlatformFeedbackGateway(
        client: backend.client,
        configured: config.ready,
        ensureSession: () async {
          if (!onlineSessionMutable) return false;
          await identity!.ensureSession();
          return identity!.sessionAvailable && identity!.errorKey == null;
        },
      ),
      consent: () => onlineConsent,
      onEvent: recordEvent,
    );
    // Optional online identity must not delay the local inventory/home screen.
    unawaited(() async {
      final current = identity;
      await deletion!.start();
      if (onlineSessionMutable && identical(identity, current)) {
        await current?.ensureSession();
      }
    }());
    if (telemetry == null) {
      final catalog =
          jsonDecode(
                await rootBundle.loadString('assets/telemetry-events.json'),
              )
              as Map<String, dynamic>;
      if (!onlineConsent || _disposed || epoch != _online.epoch) return;
      telemetry = ProductTelemetry(
        client: backend.client,
        catalog: catalog,
        enabled:
            config.ready &&
            const bool.fromEnvironment('FRIDGE_TELEMETRY_ENABLED'),
        consent: () => onlineConsent,
        ensureSession: () async {
          if (!onlineSessionMutable) return false;
          if (!identity!.busy &&
              identity!.sessionAvailable &&
              identity!.errorKey == null) {
            return true;
          }
          await identity!.ensureSession();
          return identity!.sessionAvailable && identity!.errorKey == null;
        },
        context: () => FlutterTelemetryContext(
          platform: Platform.isIOS
              ? 'ios'
              : Platform.operatingSystem == 'ohos'
              ? 'ohos'
              : 'android',
          appVersion: const String.fromEnvironment(
            'FRIDGE_APP_VERSION',
            defaultValue: '0.1.0',
          ),
          buildNumber: const String.fromEnvironment(
            'FRIDGE_BUILD_NUMBER',
            defaultValue: '1',
          ),
          releaseChannel: FridgeBootstrap.channel,
          locale: strings!.locale,
        ),
      );
    }
  }

  Future<void> loginAccount(IdentityProvider provider) async {
    if (!onlineSessionMutable) return;
    final current = identity;
    await current?.login(provider);
    if (onlineConsent &&
        identical(identity, current) &&
        current?.signedIn == true &&
        current?.errorKey == null) {
      deletionProvider = provider;
      await deletion?.refreshOwner(afterLogin: true);
    }
  }

  Future<void> logoutAccount() async {
    if (onlineSessionMutable) await identity?.logout();
  }

  Future<void> deleteAccount(Future<bool> Function() confirm) =>
      _runDeletion((model) => model.submit(confirm));
  Future<void> retryDeletionReceipt() =>
      _runDeletion((model) => model.retryReceipt());

  Future<void> _runDeletion(
    Future<void> Function(AccountDeletionSession) action,
  ) async {
    if (!onlineConsent ||
        _online.mutating ||
        identity?.busy == true ||
        deletion == null) {
      return;
    }
    _online.mutating = true;
    final epoch = _online.epoch;
    final model = deletion!;
    telemetry?.withdraw();
    final previous = feedback;
    feedback = null;
    notifyListeners();
    try {
      await previous?.close();
      if (onlineConsent && identical(deletion, model)) await action(model);
    } finally {
      previous?.dispose();
      if (_online.epoch == epoch) {
        _online.mutating = false;
        // An accepted but unsaved/uncleaned receipt must be recovered before any
        // automatic session refresh or new guest identity is allowed.
        if (onlineConsent && !(deletion?.receiptIncomplete ?? false)) {
          if (_online.foreground) telemetry?.resume();
        }
        final backend = identity?.backend;
        if (onlineConsent && backend is PlatformIdentityBackend) {
          feedback = FeedbackSession(
            storage: FileFeedbackDraftStorage(dataDirectory!),
            gateway: PlatformFeedbackGateway(
              client: backend.client,
              configured: const PlatformIdentityConfig().ready,
              ensureSession: () async {
                if (!onlineSessionMutable) return false;
                await identity?.ensureSession();
                return identity?.sessionAvailable == true &&
                    identity?.errorKey == null;
              },
            ),
            consent: () => onlineConsent,
            onEvent: recordEvent,
          );
        }
        notifyListeners();
      }
    }
  }

  void onlineLifecycle(bool foreground) {
    _online.foreground = foreground;
    localReminders?.setActive(foreground);
    if (foreground) {
      if (onlineSessionMutable) telemetry?.resume();
    } else {
      // Native provider authorization itself can pause the host; do not cancel
      // that deliberate operation. Consent withdrawal explicitly closes it.
      if (onlineSessionMutable) {
        unawaited(telemetry?.suspend() ?? Future.value());
      }
    }
  }
}
