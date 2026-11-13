import 'package:flutter/material.dart';

abstract final class FridgeDates {
  static String editable(BuildContext context, String locale, DateTime value) {
    final date = locale.startsWith('zh')
        ? '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}'
        : MaterialLocalizations.of(context).formatMediumDate(value);
    return '$date ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(value), alwaysUse24HourFormat: true)}';
  }

  static String short(BuildContext context, String locale, DateTime value) {
    if (locale.startsWith('zh'))
      return '${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}';
    return MaterialLocalizations.of(context).formatShortMonthDay(value);
  }

  static String confirmed(
    BuildContext context,
    String locale,
    DateTime value,
  ) =>
      '${short(context, locale, value)} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(value), alwaysUse24HourFormat: true)}';
}
