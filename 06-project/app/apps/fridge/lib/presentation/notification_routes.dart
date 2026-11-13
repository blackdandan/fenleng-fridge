part of '../main.dart';

extension _NotificationRoutes on _FridgeAppState {
  void _attachReminders() {
    if (!mounted) return;
    final model = bootstrap.localReminders;
    if (model != _notifications) {
      _notifications?.removeListener(_openPendingReminder);
      _notifications = model;
      model?.addListener(_openPendingReminder);
    }
    if (model != null) unawaited(model.synchronize());
    _openPendingReminder();
  }

  void _openPendingReminder() {
    if (!mounted ||
        _openingNotification ||
        bootstrap.stage != BootstrapStage.ready ||
        _notifications?.pendingDay == null) {
      return;
    }
    _openingNotification = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted || bootstrap.stage != BootstrapStage.ready) return;
        final nav = _navigator.currentState;
        if (nav?.overlay == null) return;
        await bootstrap.inventory!.refreshDue();
        if (!mounted || bootstrap.stage != BootstrapStage.ready) return;
        final day = _notifications?.takeTap();
        if (day == null) return;
        final matches = bootstrap.inventory!.state.reminders.where(
          (r) => r.day == day,
        );
        nav!.popUntil((route) => route.isFirst);
        final context = nav.overlay!.context;
        if (!context.mounted) return;
        if (matches.isEmpty) {
          _reminders(context, source: 'notification');
        } else {
          bootstrap.recordEvent('fridge.reminder.opened.v1', {
            'source': 'notification',
          });
          _review(context, reminder: matches.first);
        }
      } catch (_) {
        /* A retained in-app list remains usable on a refresh failure. */
      }
      // A later model/foreground change retries a retained tap after a failure.
      finally {
        _openingNotification = false;
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _notificationSettings(BuildContext context) {
    final model = bootstrap.localReminders;
    if (model == null) return;
    _push(
      context,
      ListenableBuilder(
        listenable: model,
        builder: (context, _) => NotificationSettingsScreen(
          strings: bootstrap.strings!,
          enabled: model.status.enabled,
          authorized: model.status.authorized,
          requested: model.status.requested,
          busy: model.busy,
          errorKey: model.errorKey,
          limited: model.status.limited,
          timingKey: Platform.isIOS
              ? 'notificationTimingIOS'
              : 'notificationTiming',
          onEnable: () =>
              unawaited(model.enable(() => _explainNotifications(context))),
          onDisable: () => unawaited(model.disable()),
          onSettings: () => unawaited(model.openSettings()),
        ),
      ),
    );
  }

  Future<bool> _explainNotifications(BuildContext context) async {
    if (FridgeBootstrap.channel != 'china') return true;
    if (!context.mounted) return false;
    final strings = bootstrap.strings!;
    return await showDialog<bool>(
          context: context,
          builder: (context) => NotificationPermissionDialog(
            strings: strings,
            onContinue: () => Navigator.pop(context, true),
            onLater: () => Navigator.pop(context, false),
          ),
        ) ??
        false;
  }
}
