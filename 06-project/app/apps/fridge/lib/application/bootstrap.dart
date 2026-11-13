import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';
import '../infrastructure/food_media.dart';
import '../infrastructure/platform_identity.dart';
import 'identity_session.dart';
import 'account_deletion.dart';
import '../infrastructure/platform_deletion.dart';
import '../infrastructure/deletion_storage.dart';
import 'feedback_session.dart';
import 'photo_lifecycle.dart';
import 'notification_session.dart';
import '../infrastructure/local_notifications.dart';
import '../infrastructure/feedback_draft_storage.dart';
import '../infrastructure/platform_feedback.dart';
import '../infrastructure/product_telemetry.dart';
import '../infrastructure/identity_storage.dart';
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart'
    show FlutterTelemetryContext;

part 'inventory_actions.dart';
part 'online_sessions.dart';
part 'privacy_actions.dart';

enum BootstrapStage {
  loading,
  consent,
  declined,
  ready,
  error,
  withdrawalError,
}

class FridgeBootstrap extends ChangeNotifier with _InventoryActions {
  static const channel = String.fromEnvironment(
    'APP_RELEASE_CHANNEL',
    defaultValue: 'china',
  );
  static const policyVersion = 'V0.4';
  final MethodChannel native;
  BootstrapStage stage = BootstrapStage.loading;
  FridgeStrings? strings;
  final Map<String, String> legal = {};
  @override
  InventoryRepository? inventory;
  @override
  Directory? dataDirectory;
  IdentitySession? identity;
  AccountDeletionSession? deletion;
  IdentityProvider deletionProvider = channel == 'global'
      ? IdentityProvider.google
      : IdentityProvider.wechat;
  final _online = _OnlineLifecycleState();
  bool get onlineSessionMutable =>
      onlineConsent &&
      !_online.mutating &&
      !(deletion?.busy ?? false) &&
      !(deletion?.receiptIncomplete ?? false);
  FeedbackSession? feedback;
  ProductTelemetry? telemetry;
  @override
  void recordEvent(String name, Map<String, String> properties) =>
      telemetry?.record(name, properties);
  NotificationSession? localReminders;
  DisplayAppearance appearance = DisplayAppearance.system;
  String? localePreference;
  bool _busy = false;
  bool _privacyAccepted = false;
  bool _disposed = false;
  Future<void>? _withdrawal;
  bool _legalBusy = false;
  bool get onlineConsent =>
      !_disposed && stage == BootstrapStage.ready && _privacyAccepted;
  Future<void> ensureOnlineServices() => _ensureOnlineServices();
  Future<void> _displayTail = Future.value();
  FridgeBootstrap({
    this.native = const MethodChannel('fenleng.fridge/bootstrap'),
  });

  Future<void> initialize() async {
    if (_busy) return;
    _busy = true;
    stage = BootstrapStage.loading;
    notifyListeners();
    try {
      if (channel != 'china' && channel != 'global') {
        throw StateError('RELEASE_CHANNEL_INVALID');
      }
      final json =
          jsonDecode(await rootBundle.loadString('assets/i18n/messages.json'))
              as Map<String, dynamic>;
      strings = FridgeStrings.fromJson(
        json,
        FridgeStrings.resolve(
          json.keys,
          WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag(),
        ),
      );
      legal['terms'] = await rootBundle.loadString('assets/legal/terms.html');
      legal['privacy'] = await rootBundle.loadString(
        'assets/legal/privacy.html',
      );
      final record =
          await native.invokeMapMethod<String, dynamic>('privacy.read') ?? {};
      appearance = DisplayAppearance.values.firstWhere(
        (value) => value.name == record['appearance'],
        orElse: () => DisplayAppearance.system,
      );
      localePreference =
          record['locale'] is String && json.containsKey(record['locale'])
          ? record['locale'] as String
          : null;
      final locale = FridgeStrings.resolve(
        json.keys,
        WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag(),
        preference: localePreference,
      );
      strings = FridgeStrings.fromJson(json, locale);
      if (record['withdrawalPending'] == true) {
        await withdrawPrivacy();
        return;
      }
      final accepted =
          record['policyVersion'] == policyVersion &&
          record['releaseChannel'] == channel &&
          record['acceptedAt'] is String &&
          DateTime.tryParse(record['acceptedAt'] as String) != null;
      _privacyAccepted = accepted;
      if (channel == 'global' || accepted) {
        await _startBusiness();
      } else {
        stage = BootstrapStage.consent;
      }
    } catch (_) {
      stage = BootstrapStage.error;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> accept() async {
    if (_busy || channel != 'china') return;
    _busy = true;
    stage = BootstrapStage.loading;
    notifyListeners();
    try {
      final saved = await native.invokeMethod<bool>('privacy.accept', {
        'policyVersion': policyVersion,
        'releaseChannel': channel,
        'acceptedAt': DateTime.now().toUtc().toIso8601String(),
      });
      if (saved != true) throw StateError('CONSENT_WRITE_FAILED');
      _privacyAccepted = true;
      await _startBusiness();
    } catch (_) {
      stage = BootstrapStage.error;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _startBusiness() async {
    final initialized = await native.invokeMethod<bool>('plugins.initialize', {
      'policyVersion': policyVersion,
      'releaseChannel': channel,
    });
    if (initialized != true) throw StateError('PLUGIN_BOOTSTRAP_FAILED');
    final directory = await native.invokeMethod<String>('data.directory');
    if (directory == null || directory.isEmpty) {
      throw StateError('DATA_DIRECTORY_UNAVAILABLE');
    }
    dataDirectory = Directory(directory);
    final repository =
        inventory ??
        InventoryRepository(FileInventoryStorage(Directory(directory)));
    inventory = repository;
    await repository.open();
    await _photoLifecycle().recoverOrphans();
    stage = BootstrapStage.ready;
    await _startOnlineSessions();
    localReminders ??= NotificationSession(
      repository: repository,
      platform: MethodChannelNotifications(),
      consent: () => stage == BootstrapStage.ready,
      copy: () => {
        'title': strings!.text('notificationTitle'),
        'body': strings!.text('notificationBody'),
        'channel': strings!.text('notifications'),
        'locale': strings!.locale,
      },
      onEvent: recordEvent,
    );
    unawaited(localReminders!.start());
  }

  void decline() {
    _privacyAccepted = false;
    telemetry?.withdraw();
    stage = BootstrapStage.declined;
    notifyListeners();
  }

  void reconsider() {
    _privacyAccepted = false;
    telemetry?.withdraw();
    stage = BootstrapStage.consent;
    notifyListeners();
  }

  Future<void> _saveDisplay(Future<void> Function() action) {
    final operation = _displayTail.then((_) => action());
    _displayTail = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> changeLocale(String? locale) => _saveDisplay(() async {
    if (locale != null && !strings!.messages.containsKey(locale)) {
      throw ArgumentError('LOCALE_UNSUPPORTED');
    }
    final saved = await native.invokeMethod<bool>('display.locale', {
      'locale': locale,
    });
    if (saved != true) throw StateError('DISPLAY_WRITE_FAILED');
    localePreference = locale;
    final current = strings!;
    strings = current.withLocale(
      FridgeStrings.resolve(
        current.messages.keys,
        WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag(),
        preference: locale,
      ),
    );
    notifyListeners();
  });

  Future<void> changeAppearance(DisplayAppearance value) =>
      _saveDisplay(() async {
        final saved = await native.invokeMethod<bool>('display.theme', {
          'appearance': value.name,
        });
        if (saved != true) throw StateError('DISPLAY_WRITE_FAILED');
        appearance = value;
        notifyListeners();
      });

  void refreshSystemLocale() {
    final current = strings;
    if (current == null || localePreference != null) return;
    final next = FridgeStrings.resolve(
      current.messages.keys,
      WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag(),
    );
    if (next == current.locale) return;
    strings = current.withLocale(next);
    notifyListeners();
  }

  Future<void> changeDefaults(
    Map<StorageZone, int> values,
    int hour,
    int minute,
  ) => inventory!.update(
    (state) => InventoryRules.changeDefaults(
      state,
      values,
      hour: hour,
      minute: minute,
    ),
    undoable: false,
    invalidateUndo: true,
  );

  Future<void> openFiling() async {
    if (await native.invokeMethod<bool>('filing.open') != true) {
      throw StateError('FILING_UNAVAILABLE');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _online.invalidate();
    telemetry?.close();
    deletion?.dispose();
    localReminders?.dispose();
    feedback?.dispose();
    identity?.dispose();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }
}
