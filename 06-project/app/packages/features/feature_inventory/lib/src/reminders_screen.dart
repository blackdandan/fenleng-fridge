import 'package:flutter/material.dart';
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';

class RemindersScreen extends StatelessWidget {
  final InventoryState state;
  final FridgeStrings strings;
  final ValueChanged<CheckReminder> onOpen;
  final DateTime? now;
  const RemindersScreen({
    super.key,
    required this.state,
    required this.strings,
    required this.onOpen,
    this.now,
  });
  @override
  Widget build(BuildContext context) => FridgePage(
    title: strings.text('notifications'),
    headerTop: FridgeProductTokens.spaceHeaderTop,
    titleGap: FridgeProductTokens.spaceHistoryTitleGap,
    child: Builder(
      builder: (context) {
        final l = FridgeLayout.of(context);
        final p = Theme.of(context).extension<FridgePalette>()!;
        return ListView(
          padding: EdgeInsets.only(
            top: l.d(FridgeProductTokens.spaceRemindersIntro),
            bottom: l.d(FridgeProductTokens.spaceBottom),
          ),
          children: [
            Text(
              strings.text('notificationHint'),
              style: TextStyle(
                fontSize: l.font(FridgeProductTokens.fontSecondary),
                height: 1.8,
                color: p.muted,
              ),
            ),
            if (state.reminders.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: l.d(FridgeProductTokens.spaceBottom),
                ),
                child: Text(
                  strings.text('notificationEmpty'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: l.font(FridgeProductTokens.fontBody),
                    height: 1.6,
                    color: p.muted,
                  ),
                ),
              ),
            for (final reminder in state.reminders)
              Padding(
                padding: EdgeInsets.only(
                  top: l.d(FridgeProductTokens.spaceRow),
                  bottom: l.d(FridgeProductTokens.spaceRow),
                ),
                child: _card(context, reminder),
              ),
          ],
        );
      },
    ),
  );
  Widget _card(BuildContext context, CheckReminder reminder) {
    final l = FridgeLayout.of(context);
    final p = Theme.of(context).extension<FridgePalette>()!;
    final pending = reminder.pending(state, now ?? DateTime.now()).length;
    final date = DateTime.tryParse('${reminder.day}T12:00:00');
    return Container(
      key: ValueKey('reminder-${reminder.day}'),
      padding: EdgeInsets.fromLTRB(
        l.d(FridgeProductTokens.spaceSettingsCard),
        l.d(FridgeProductTokens.spaceReminderCardTop),
        l.d(FridgeProductTokens.spaceSettingsCard),
        l.d(FridgeProductTokens.spaceSmall),
      ),
      decoration: BoxDecoration(
        color: p.color('surface'),
        border: Border.all(
          color: p.border,
          width: l.d(FridgeProductTokens.sizeBorder),
        ),
        borderRadius: BorderRadius.circular(
          l.d(FridgeProductTokens.radiusReminder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            date == null
                ? reminder.day
                : FridgeDates.short(context, strings.locale, date),
            style: TextStyle(
              fontSize: l.font(FridgeProductTokens.fontCaption),
              height: 1.4,
              color: p.color('reminderDate'),
            ),
          ),
          SizedBox(height: l.d(FridgeProductTokens.spaceReminderTitle)),
          Text(
            strings.text('notificationTitle'),
            style: TextStyle(
              fontSize: l.font(FridgeProductTokens.fontBody),
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: l.d(FridgeProductTokens.spaceReminderBody)),
          Text(
            strings.format('notificationBody', {
              'count': reminder.originalCount,
            }),
            style: TextStyle(
              fontSize: l.font(FridgeProductTokens.fontSecondary),
              height: 1.8,
              color: p.muted,
            ),
          ),
          SizedBox(height: l.d(FridgeProductTokens.spaceRow)),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: l.d(FridgeProductTokens.spaceRow),
            runSpacing: l.d(FridgeProductTokens.spaceSmall),
            children: [
              Text(
                strings.format('pendingCount', {'count': pending}),
                style: TextStyle(
                  fontSize: l.font(FridgeProductTokens.fontSecondary),
                  height: 1.8,
                  color: p.muted,
                ),
              ),
              if (pending == 0 || pending < reminder.originalCount)
                Text(
                  strings.text(
                    pending == 0 ? 'notificationHandled' : 'partiallyHandled',
                  ),
                  style: TextStyle(
                    fontSize: l.font(FridgeProductTokens.fontSecondary),
                    height: 1.8,
                    color: p.color(pending == 0 ? 'primary' : 'muted'),
                  ),
                ),
            ],
          ),
          if (pending > 0)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: ValueKey('open-reminder-${reminder.day}'),
                onPressed: () => onOpen(reminder),
                style: TextButton.styleFrom(
                  foregroundColor: p.color('primary'),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: TextStyle(
                    fontSize: l.font(FridgeProductTokens.fontSecondary),
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: Text(strings.text('notificationOpen'))),
                    SizedBox(width: l.d(FridgeProductTokens.spaceTiny)),
                    Icon(
                      Icons.north_east,
                      size: l.font(FridgeProductTokens.fontSecondary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
