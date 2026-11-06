import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The app's icon set: Lucide outlines, mapped to the names the prototype uses
/// (prototype/source/Main.dc.html → `I` / `ic`). Screens use these names only, so
/// the stroke weight can be tuned in one place.
abstract final class DLIcons {
  static const IconData home = LucideIcons.house;
  static const IconData wallet = LucideIcons.wallet;
  static const IconData calendar = LucideIcons.calendar;
  static const IconData clock = LucideIcons.clock;
  static const IconData briefcase = LucideIcons.briefcase;
  static const IconData grid = LucideIcons.layoutGrid;
  static const IconData gear = LucideIcons.settings;
  static const IconData back = LucideIcons.arrowLeft;
  static const IconData close = LucideIcons.x;
  static const IconData check = LucideIcons.check;
  static const IconData checkCircle = LucideIcons.circleCheckBig;
  static const IconData alert = LucideIcons.circleAlert;
  static const IconData info = LucideIcons.info;
  static const IconData trash = LucideIcons.trash;
  static const IconData plus = LucideIcons.plus;
  static const IconData minus = LucideIcons.minus;
  static const IconData search = LucideIcons.search;
  static const IconData chevronLeft = LucideIcons.chevronLeft;
  static const IconData chevronRight = LucideIcons.chevronRight;
  static const IconData chevronDown = LucideIcons.chevronDown;
  static const IconData chevronUp = LucideIcons.chevronUp;
  static const IconData edit = LucideIcons.pencil;
  static const IconData sun = LucideIcons.sun;
  static const IconData moon = LucideIcons.moon;
  static const IconData bell = LucideIcons.bell;

  /// Customize dashboard (prototype `sliders`).
  static const IconData sliders = LucideIcons.slidersVertical;
  static const IconData users = LucideIcons.users;

  /// Water (prototype `drop`).
  static const IconData drop = LucideIcons.droplet;
  static const IconData flame = LucideIcons.flame;
  static const IconData filter = LucideIcons.funnel;
  static const IconData tag = LucideIcons.tag;
  static const IconData chart = LucideIcons.chartColumn;
  static const IconData pie = LucideIcons.chartPie;
  static const IconData target = LucideIcons.target;

  // Money.
  /// Income (prototype `inc`): arrow into the wallet.
  static const IconData income = LucideIcons.arrowDownLeft;

  /// Expense (prototype `exp`): arrow out.
  static const IconData expense = LucideIcons.arrowUpRight;
  static const IconData cash = LucideIcons.banknote;
  static const IconData piggy = LucideIcons.piggyBank;
  static const IconData store = LucideIcons.store;
  static const IconData bag = LucideIcons.shoppingBag;

  // Category icons (the `icon` key stored on a category).
  static const IconData gift = LucideIcons.gift;
  static const IconData laptop = LucideIcons.laptop;
  static const IconData dots = LucideIcons.ellipsis;
  static const IconData food = LucideIcons.utensils;
  static const IconData bus = LucideIcons.bus;
  static const IconData heart = LucideIcons.heart;
  static const IconData user = LucideIcons.user;
  static const IconData medical = LucideIcons.pill;
  static const IconData film = LucideIcons.film;
  static const IconData wifi = LucideIcons.wifi;

  // Work.
  static const IconData folder = LucideIcons.folder;
  static const IconData play = LucideIcons.play;
  static const IconData pause = LucideIcons.pause;

  /// Stop (prototype `stop`): a square.
  static const IconData stop = LucideIcons.square;

  /// Priority (prototype `flag`).
  static const IconData flag = LucideIcons.flag;

  // Calendar.
  /// Location (prototype `map`).
  static const IconData mapPin = LucideIcons.mapPin;
  static const IconData repeat = LucideIcons.repeat;

  // Reminders and notes.
  /// Health (prototype `pulse`).
  static const IconData pulse = LucideIcons.activity;
  static const IconData undo = LucideIcons.undo2;
  static const IconData pin = LucideIcons.pin;
  static const IconData archive = LucideIcons.archive;

  /// A note (prototype `note`).
  static const IconData note = LucideIcons.fileText;

  /// A stored icon key (prototype `I` name, e.g. `food`, `cash`) → icon.
  /// Unknown keys fall back to [tag], the custom-category icon.
  static IconData byKey(String key) => switch (key) {
        'cash' => cash,
        'gift' => gift,
        'laptop' => laptop,
        'brief' => briefcase,
        'store' => store,
        'dots' => dots,
        'food' => food,
        'bus' => bus,
        'home' => home,
        'bag' => bag,
        'heart' => heart,
        'user' => user,
        'med' => medical,
        'film' => film,
        'wifi' => wifi,
        'piggy' => piggy,
        'wallet' => wallet,
        // Notification icons (inbox items).
        'bell' => bell,
        'users' => users,
        'drop' => drop,
        'cal' => calendar,
        'flame' => flame,
        _ => tag,
      };
}
