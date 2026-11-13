import 'package:flutter/material.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';

class NotificationSettingsScreen extends StatelessWidget {
  final FridgeStrings strings;
  final bool enabled, authorized, requested, busy;
  final bool limited;
  final String timingKey;
  final String? errorKey;
  final VoidCallback onEnable, onDisable, onSettings;
  const NotificationSettingsScreen({
    super.key,
    required this.strings,
    required this.enabled,
    required this.authorized,
    required this.requested,
    required this.busy,
    required this.onEnable,
    required this.onDisable,
    required this.onSettings,
    this.errorKey,
    this.limited = false,
    this.timingKey = 'notificationTiming',
  });
  @override
  Widget build(BuildContext context) => FridgePage(
    title: strings.text('notificationSettings'),
    child: Builder(
      builder: (context) {
        final l = FridgeLayout.of(context);
        final p = Theme.of(context).extension<FridgePalette>()!;
        return ListView(
          padding: EdgeInsets.symmetric(
            vertical: l.d(FridgeProductTokens.spaceSection),
          ),
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                strings.text(
                  enabled && authorized
                      ? 'notificationEnabled'
                      : 'notificationDisabled',
                ),
                style: TextStyle(
                  fontSize: l.font(FridgeProductTokens.fontDialogTitle),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(height: l.d(FridgeProductTokens.spaceRow)),
            Text(
              strings.text('notificationHint'),
              style: TextStyle(
                fontSize: l.font(FridgeProductTokens.fontBody),
                height: 1.6,
              ),
            ),
            SizedBox(height: l.d(FridgeProductTokens.spaceRow)),
            Text(
              strings.text(timingKey),
              style: TextStyle(
                fontSize: l.font(FridgeProductTokens.fontSecondary),
                height: 1.8,
                color: p.muted,
              ),
            ),
            if (limited) ...[
              SizedBox(height: l.d(FridgeProductTokens.spaceRow)),
              Semantics(
                liveRegion: true,
                child: Text(
                  strings.text('notificationQueueLimited'),
                  style: TextStyle(color: p.color('danger'), height: 1.6),
                ),
              ),
            ],
            if (requested && !authorized) ...[
              SizedBox(height: l.d(FridgeProductTokens.spaceRow)),
              Text(
                strings.text('notificationDenied'),
                style: TextStyle(color: p.color('danger'), height: 1.6),
              ),
              TextButton(
                onPressed: busy ? null : onSettings,
                child: Text(strings.text('openSettings')),
              ),
            ],
            if (errorKey != null) ...[
              SizedBox(height: l.d(FridgeProductTokens.spaceRow)),
              Semantics(
                liveRegion: true,
                child: Text(
                  strings.text(errorKey!),
                  style: TextStyle(color: p.color('danger'), height: 1.6),
                ),
              ),
            ],
            SizedBox(height: l.d(FridgeProductTokens.spaceSection)),
            if (!enabled || !authorized)
              FridgeAction(
                key: const ValueKey('notifications-enable'),
                label: strings.text(busy ? 'loading' : 'notificationEnable'),
                onPressed: busy ? null : onEnable,
              ),
            if (enabled) ...[
              SizedBox(height: l.d(FridgeProductTokens.spaceRow)),
              FridgeAction(
                key: const ValueKey('notifications-disable'),
                label: strings.text('notificationDisable'),
                secondary: true,
                onPressed: busy ? null : onDisable,
              ),
            ],
          ],
        );
      },
    ),
  );
}
