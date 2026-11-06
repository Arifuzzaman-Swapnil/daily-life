import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';

/// The system date picker (in the app's theme and language). Resolves to the
/// picked day at local midnight, or null when cancelled.
Future<DateTime?> pickDate(BuildContext context, DateTime initial) async {
  final d = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100, 12, 31),
  );
  return d == null ? null : dateOnly(d);
}

/// The system time picker for an `HH:mm` value; resolves to the new `HH:mm`.
Future<String?> pickTime(BuildContext context, String hm) async {
  final parts = hm.split(':');
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: int.tryParse(parts.first) ?? 12, minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0),
  );
  if (picked == null) return null;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(picked.hour)}:${two(picked.minute)}';
}
