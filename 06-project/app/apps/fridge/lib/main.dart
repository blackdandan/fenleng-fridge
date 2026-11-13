import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge_inventory/fridge_inventory.dart';
import 'package:fridge_settings/fridge_settings.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';
import 'application/bootstrap.dart';
import 'application/notification_session.dart';
import 'application/camera_coordinator.dart';
import 'application/review_items.dart';
import 'presentation/capture_page.dart';
import 'presentation/camera_rationale.dart';
import 'presentation/account_page.dart';
import 'presentation/privacy_withdrawal.dart';
import 'presentation/online_consent.dart';

part 'presentation/app_routes.dart';
part 'presentation/notification_routes.dart';
part 'presentation/privacy_routes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FridgeApp());
}

class FridgeApp extends StatefulWidget {
  final FridgeBootstrap? bootstrap;
  final ImageProvider Function(String)? photoLoader;
  const FridgeApp({super.key, this.bootstrap, this.photoLoader});
  @override
  State<FridgeApp> createState() => _FridgeAppState();
}

class _FridgeAppState extends State<FridgeApp> with WidgetsBindingObserver {
  late final FridgeBootstrap bootstrap;
  final _navigator = GlobalKey<NavigatorState>();
  NotificationSession? _notifications;
  bool _openingNotification = false;
  bool _homeTracked = false;
  bool _onlinePromptOpen = false;
  late final NavigatorObserver _telemetryRoutes;
  @override
  void initState() {
    super.initState();
    bootstrap = widget.bootstrap ?? FridgeBootstrap();
    _telemetryRoutes = _HomeTelemetryObserver(() {
      if (bootstrap.stage != BootstrapStage.ready) return;
      _homeTracked = true;
      bootstrap.recordEvent('fridge.home.viewed.v1', {});
    });
    WidgetsBinding.instance.addObserver(this);
    bootstrap.addListener(_attachReminders);
    unawaited(bootstrap.initialize().whenComplete(_attachReminders));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: bootstrap,
    builder: (context, _) {
      final strings = bootstrap.strings;
      final localeParts = strings?.locale.split('-') ?? ['zh', 'CN'];
      return MaterialApp(
        navigatorKey: _navigator,
        navigatorObservers: [_telemetryRoutes],
        debugShowCheckedModeBanner: false,
        title: strings?.text('home') ?? '',
        theme: fridgeTheme(),
        darkTheme: fridgeTheme(dark: true),
        themeMode: switch (bootstrap.appearance) {
          DisplayAppearance.light => ThemeMode.light,
          DisplayAppearance.dark => ThemeMode.dark,
          DisplayAppearance.system => ThemeMode.system,
        },
        locale: Locale(
          localeParts.first,
          localeParts.length > 1 ? localeParts.last : null,
        ),
        supportedLocales: (strings?.messages.keys ?? ['zh-CN', 'en']).map((
          value,
        ) {
          final parts = value.split('-');
          return Locale(parts.first, parts.length > 1 ? parts.last : null);
        }),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(builder: (context) => _home(context)),
      );
    },
  );

  Widget _home(BuildContext context) {
    if (bootstrap.stage != BootstrapStage.ready) {
      _homeTracked = false;
    } else if (!_homeTracked) {
      _homeTracked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            bootstrap.stage == BootstrapStage.ready &&
            _navigator.currentState?.canPop() == false) {
          bootstrap.recordEvent('fridge.home.viewed.v1', {});
        } else {
          _homeTracked = false;
        }
      });
    }
    final strings = bootstrap.strings;
    if (strings == null || bootstrap.stage == BootstrapStage.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return switch (bootstrap.stage) {
      BootstrapStage.consent || BootstrapStage.declined => ConsentScreen(
        strings: strings,
        declined: bootstrap.stage == BootstrapStage.declined,
        onAccept: bootstrap.accept,
        onDecline: bootstrap.decline,
        onReconsider: bootstrap.reconsider,
        onDocument: (key) => _legal(context, key),
      ),
      BootstrapStage.ready => _reactive(
        (state) => CabinetScreen(
          state: state,
          strings: strings,
          photo: _photo,
          onOpenZone: (zone) => _zone(context, zone),
          onSettings: () => _settings(context),
          onReminders: () => _reminders(context),
          onReview: () => _review(context),
        ),
      ),
      BootstrapStage.withdrawalError => PrivacyWithdrawalError(
        strings: strings,
        onRetry: () => unawaited(bootstrap.withdrawPrivacy()),
        onDocument: (key) => _legal(context, key),
      ),
      _ => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(strings.text('error')),
              TextButton(
                onPressed: bootstrap.initialize,
                child: Text(strings.text('retry')),
              ),
            ],
          ),
        ),
      ),
    };
  }

  ImageProvider _photo(String path) =>
      widget.photoLoader?.call(path) ?? FileImage(File(path));
  Widget _reactive(Widget Function(InventoryState) builder) =>
      StreamBuilder<InventoryState>(
        stream: bootstrap.inventory!.changes,
        initialData: bootstrap.inventory!.state,
        builder: (context, _) => builder(bootstrap.inventory!.state),
      );
  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  void _legal(BuildContext context, String key) =>
      unawaited(_perform(context, () => _openLegal(context, key)));

  @override
  void didChangeLocales(List<Locale>? locales) =>
      bootstrap.refreshSystemLocale();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    bootstrap.onlineLifecycle(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    bootstrap.removeListener(_attachReminders);
    _notifications?.removeListener(_openPendingReminder);
    if (widget.bootstrap == null) {
      unawaited(bootstrap.inventory?.close() ?? Future.value());
      bootstrap.dispose();
    }
    super.dispose();
  }
}

class _HomeTelemetryObserver extends NavigatorObserver {
  final VoidCallback onHome;
  _HomeTelemetryObserver(this.onHome);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute && previousRoute?.isFirst == true) onHome();
  }
}
