part of '../main.dart';

extension _FridgeRoutes on _FridgeAppState {
  void _detail(BuildContext context, FoodRecord food) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Theme.of(
        context,
      ).extension<FridgePalette>()!.color('scrim'),
      builder: (dialogContext) => _reactive((state) {
        final current = state.foods[food.id] ?? food;
        return RecordEditor(
          food: current,
          strings: bootstrap.strings!,
          photo: _photo(current.photoPath),
          onSave: (edits) => bootstrap.editRecord(
            current,
            zone: edits.zone,
            intervalDays: edits.intervalDays,
            addedAt: edits.addedAt,
            dueAt: edits.dueAt,
          ),
          onReplace: () => bootstrap.replacePhoto(current),
          onDelete: () => bootstrap.deleteRecord(current),
          onClose: () => Navigator.of(dialogContext).pop(),
        );
      }),
    );
  }

  void _zone(BuildContext context, StorageZone zone) {
    final strings = bootstrap.strings!;
    if (!bootstrap.inventory!.state.active.any((f) => f.zone == zone)) {
      unawaited(_import(context, zone));
      return;
    }
    _push(
      context,
      _reactive(
        (state) => RecordsScreen(
          title: strings.text('${zone.name}Zone'),
          foods: state.active.where((f) => f.zone == zone).toList(),
          strings: strings,
          photo: _photo,
          onAdd: () => _import(context, zone),
          onOrganize: () => _review(context, zone: zone),
          onOpen: (food) => _detail(context, food),
        ),
      ),
    );
  }

  void _review(
    BuildContext context, {
    StorageZone? zone,
    CheckReminder? reminder,
  }) {
    _push(
      context,
      _reactive(
        (state) => ReviewScreen(
          title: zone == null
              ? null
              : bootstrap.strings!.format('organizeZone', {
                  'zone': bootstrap.strings!.text(zone.name),
                }),
          foods: reviewItems(
            state,
            DateTime.now(),
            zone: zone,
            reminderDay: reminder?.day,
          ),
          strings: bootstrap.strings!,
          photo: _photo,
          onOpen: (food) => _detail(context, food),
          completedReminder: reminder != null,
          onConfirm: (food, remaining) => _perform(context, () async {
            await bootstrap.organize(food, remaining);
            final revision = bootstrap.inventory!.revision;
            if (context.mounted) {
              final messenger = ScaffoldMessenger.of(context);
              messenger.clearSnackBars();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(bootstrap.strings!.text(remaining.name)),
                  action: SnackBarAction(
                    label: bootstrap.strings!.text('undo'),
                    onPressed: () => _perform(
                      context,
                      () =>
                          bootstrap.inventory!.undo(expectedRevision: revision),
                    ),
                  ),
                ),
              );
            }
          }),
        ),
      ),
    );
  }

  void _reminders(BuildContext context, {String source = 'home'}) {
    bootstrap.recordEvent('fridge.reminder.opened.v1', {'source': source});
    _push(
      context,
      _reactive(
        (state) => RemindersScreen(
          state: state,
          strings: bootstrap.strings!,
          onOpen: (reminder) => _review(context, reminder: reminder),
        ),
      ),
    );
  }

  void _settings(BuildContext context) => _push(
    context,
    ListenableBuilder(
      listenable: bootstrap,
      builder: (context, _) => _reactive((state) {
        final strings = bootstrap.strings!;
        final language = bootstrap.localePreference;
        return SettingsScreen(
          state: state,
          strings: strings,
          appearance: bootstrap.appearance,
          languageLabel: language == null
              ? strings.text('system')
              : strings.messages[language]!['_localeName']!,
          filing: const String.fromEnvironment('FRIDGE_APP_FILING_NUMBER'),
          onSaveDefaults: bootstrap.changeDefaults,
          onHistory: () => _history(context),
          onLanguage: () => _language(context),
          onAppearance: () => _appearance(context),
          onAccount: () => unawaited(_account(context)),
          onNotifications: bootstrap.localReminders == null
              ? null
              : () => _notificationSettings(context),
          onLegal: (key) => _legal(context, key),
          onFeedback: () => _feedback(context),
          onFiling: () => unawaited(_perform(context, bootstrap.openFiling)),
        );
      }),
    ),
  );

  Future<void> _feedback(BuildContext context) async {
    if (!await _ensureOnline(context) || !context.mounted) return;
    final model = bootstrap.feedback;
    if (model == null) {
      unawaited(
        _perform(context, () async => throw StateError('FEEDBACK_NOT_READY')),
      );
      return;
    }
    unawaited(model.start());
    _push(
      context,
      ListenableBuilder(
        listenable: model,
        builder: (context, _) => FeedbackScreen(
          strings: bootstrap.strings!,
          draft: model.text,
          receipt: model.receipt,
          errorKey: model.errorKey,
          loading: model.loading,
          initialized: model.initialized,
          busy: model.busy,
          onChanged: (value) => unawaited(model.edit(value)),
          onSubmit: () => unawaited(model.submit()),
          onRetryLoad: () => unawaited(model.start()),
          onWriteAnother: () => unawaited(model.writeAnother()),
        ),
      ),
    );
  }

  void _appearance(BuildContext context) => _push(
    context,
    SettingsChoices(
      title: bootstrap.strings!.text('appearance'),
      selected: bootstrap.appearance.name,
      strings: bootstrap.strings!,
      choices: [
        for (final appearance in DisplayAppearance.values)
          SettingsChoice(
            appearance.name,
            bootstrap.strings!.text(appearance.name),
          ),
      ],
      onSelect: (value) async {
        await bootstrap.changeAppearance(
          DisplayAppearance.values.byName(value),
        );
        if (context.mounted) Navigator.of(context).pop();
      },
    ),
  );

  void _history(BuildContext context) => _push(
    context,
    _reactive(
      (state) => HistoryScreen(
        state: state,
        strings: bootstrap.strings!,
        photo: _photo,
        onOpen: (food) => _detail(context, food),
        onRestore: bootstrap.restore,
      ),
    ),
  );

  void _language(BuildContext context) => _push(
    context,
    SettingsChoices(
      title: bootstrap.strings!.text('language'),
      selected: bootstrap.localePreference ?? 'system',
      strings: bootstrap.strings!,
      choices: [
        SettingsChoice('system', bootstrap.strings!.text('system')),
        for (final entry in bootstrap.strings!.messages.entries)
          SettingsChoice(entry.key, entry.value['_localeName']!),
      ],
      onSelect: (value) async {
        await bootstrap.changeLocale(value == 'system' ? null : value);
        if (context.mounted) Navigator.of(context).pop();
      },
    ),
  );

  Future<void> _import(BuildContext context, StorageZone zone) => _perform(
    context,
    () async {
      late final CameraCoordinator coordinator;
      coordinator = CameraCoordinator(
        directory: bootstrap.dataDirectory!,
        repository: bootstrap.inventory!,
        zone: zone,
        strings: bootstrap.strings!,
        rationale: (_) async {
          if (!context.mounted) return false;
          final choice = await showCameraRationale(context, bootstrap.strings!);
          if (choice == CameraRationaleChoice.album) {
            unawaited(coordinator.chooseAlbum());
          }
          return choice == CameraRationaleChoice.request;
        },
        onEvent: bootstrap.recordEvent,
      );
      try {
        if (context.mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CapturePage(
                coordinator: coordinator,
                strings: bootstrap.strings!,
              ),
            ),
          );
        }
      } finally {
        await coordinator.close();
      }
    },
  );

  Future<void> _perform(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              bootstrap.strings!.text(
                error is StateError && error.message == 'UNDO_STATE_CHANGED'
                    ? 'undoExpired'
                    : 'error',
              ),
            ),
          ),
        );
      }
    }
  }
}
