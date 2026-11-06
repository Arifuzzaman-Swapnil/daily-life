import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The app's icon set: Lucide outlines, mapped to the names the prototype uses
/// (prototype/source/Main.dc.html → `I` / `ic`). Screens use these names only, so
/// the stroke weight can be tuned in one place.
abstract final class DLIcons {
  static const IconData home = LucideIcons.house;
  static const IconData wallet = LucideIcons.wallet;
  static const IconData calendar = LucideIcons.calendar;
  static const IconData briefcase = LucideIcons.briefcase;
  static const IconData grid = LucideIcons.layoutGrid;
  static const IconData gear = LucideIcons.settings;
  static const IconData back = LucideIcons.arrowLeft;
  static const IconData check = LucideIcons.check;
  static const IconData chevronRight = LucideIcons.chevronRight;
}
