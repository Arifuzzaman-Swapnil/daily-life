// GENERATED from design/tokens.json (Daily Life design system). Do not edit by hand —
// re-run tools/gen_assets.js if tokens change.
// ignore_for_file: lines_longer_than_80_chars
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';

/// Colour tokens as a ThemeExtension. Read with `Theme.of(context).extension<DLColors>()!`
/// or the `context.dl` extension below. Every token has a light and a dark value.
@immutable
class DLColors extends ThemeExtension<DLColors> {
  const DLColors({required this.brand, required this.brandHover, required this.onBrand, required this.onBrandAccent, required this.brandMuted, required this.accent, required this.accentText, required this.accentSoft, required this.onAccent, required this.actionPrimary, required this.actionPrimaryHover, required this.onActionPrimary, required this.background, required this.surface, required this.surfaceRaised, required this.surfaceSunken, required this.textPrimary, required this.textSecondary, required this.textDisabled, required this.divider, required this.borderStrong, required this.focusRing, required this.scrim, required this.success, required this.successText, required this.successSoft, required this.onSuccess, required this.warning, required this.warningText, required this.warningSoft, required this.danger, required this.dangerText, required this.dangerSoft, required this.onDanger, required this.income, required this.expense, required this.catEvent, required this.catTask, required this.catTaskText, required this.catTaskSoft, required this.catReminder, required this.catBill, required this.chart1, required this.chart2, required this.chart3, required this.chart4, required this.chartGrid});
  /// Deep Navy, the identity colour. Bottom navigation bar, BalanceCard ground, app icon. Pair with `on-brand` text (14.7:1 light, 10.4:1 dark).
  final Color brand;
  /// Raised fills ON `brand`: active nav pill, chips and dividers inside BalanceCard, pressed nav items. Never a page ground.
  final Color brandHover;
  /// Primary text and icons on `brand` and `brand-hover` (≥8:1 both themes).
  final Color onBrand;
  /// Highlight text/icons on `brand` / `brand-hover`: active nav icon, positive delta on BalanceCard (8.2:1 light, 5.7:1 dark on `brand`).
  final Color onBrandAccent;
  /// Secondary text and inactive nav icons/labels on `brand` (7.4:1 light, 5.2:1 dark). Not for use on `brand-hover` in dark (4.1:1).
  final Color brandMuted;
  /// Soft Blue. Fills and marks only: FAB, progress bars, chart series 1, focus border on inputs, active underline, icons. As text it is 3.7:1 on white, so use `accent-text` for words.
  final Color accent;
  /// Blue words: links, secondary/ghost button labels, selected tab label, % on SavingsCard. 6.7:1 on `surface`, 5.5:1 on `accent-soft` (light); 9.5:1 / 7.9:1 (dark).
  final Color accentText;
  /// Tinted fill behind `accent-text`: selected chips, tonal icon buttons, event date block, empty-state halo, menu selection.
  final Color accentSoft;
  /// Icon colour on an `accent` fill (FAB). Light: 3.7:1, icons and 24px+ text only; dark: 7.4:1.
  final Color onAccent;
  /// Primary button, filled icon button, selected calendar day. Navy in light, bright blue in dark so it stands off the dark ground.
  final Color actionPrimary;
  /// Pressed / hover state of `action-primary`.
  final Color actionPrimaryHover;
  /// Label on `action-primary` (14.7:1 light, 7.4:1 dark).
  final Color onActionPrimary;
  /// App/page background behind cards and lists. Screens never use pure white as ground.
  final Color background;
  /// Cards, list groups, inputs, search bar, secondary buttons.
  final Color surface;
  /// Dialogs, bottom sheets, dropdown menus, active segmented tab: anything above the page in elevation.
  final Color surfaceRaised;
  /// Recessed fills: progress tracks, segmented tab well, neutral chips, disabled buttons, hover rows. Carries `text-primary` only (secondary text drops to 4.3:1).
  final Color surfaceSunken;
  /// Headings, body, amounts. On `background`, `surface`, `surface-raised`, `surface-sunken`: ≥14:1 light, ≥13:1 dark.
  final Color textPrimary;
  /// Supporting copy, metadata, placeholders, captions. 4.8:1 on `surface`; 4.48:1 on `background` in light (the brief's exact value, a hair under AA) so keep it on cards or at 15px+ on the page ground. Dark: ≥6.1:1 everywhere.
  final Color textSecondary;
  /// Disabled labels and icons only (exempt from contrast).
  final Color textDisabled;
  /// Hairlines between list rows, legend top rule, sheet sections, quiet borders on chips and menus. Decorative, never the only boundary of a control.
  final Color divider;
  /// Control borders that must be seen: text fields, select, secondary button, unchecked checkbox, sheet handle (3.6:1 light, 3.2:1 dark on `surface`).
  final Color borderStrong;
  /// 2px keyboard focus outline, 2px offset, on every interactive element. ≥3:1 on `surface`, `background` and `brand` in both themes.
  final Color focusRing;
  /// Overlay behind dialogs and bottom sheets.
  final Color scrim;
  /// Positive fills and marks: checked task, completed progress, income icon. As text use `success-text`.
  final Color success;
  /// Positive words and income amounts. 5.0:1 on `surface`, 4.6:1 on `success-soft` (light).
  final Color successText;
  /// Tint behind `success-text`: income icon chip, good-delta pill, success badge.
  final Color successSoft;
  /// Check mark on a `success` fill (icon only in light, 3.3:1).
  final Color onSuccess;
  /// Caution fills and marks: due-soon bars, chart series 4. Never as text on light grounds (2.1:1).
  final Color warning;
  /// Caution words: due-soon status, medium priority, reminder icon. 5.0:1 on `surface`, 4.5:1 on `warning-soft`.
  final Color warningText;
  /// Tint behind `warning-text`: reminder icon chip, warning badge.
  final Color warningSoft;
  /// Destructive fills and marks: delete button, error field border, notification dot, count badge.
  final Color danger;
  /// Error and negative words: field errors, overdue dates, expense amounts. 6.5:1 on `surface`, 5.3:1 on `danger-soft`.
  final Color dangerText;
  /// Tint behind `danger-text`: bill reminder chip, bad-delta pill, delete dialog icon.
  final Color dangerSoft;
  /// Label on a `danger` fill (4.8:1 light, 6.8:1 dark).
  final Color onDanger;
  /// Income amounts (+৳). Always shown with a + sign and the income arrow, never colour alone.
  final Color income;
  /// Expense amounts (−৳). Always shown with a − sign; the expense icon stays neutral in lists so a page of spending does not turn red.
  final Color expense;
  /// Calendar dot and tag for events.
  final Color catEvent;
  /// Calendar dot for tasks (3.7:1 on `surface`).
  final Color catTask;
  /// Task tag label on `cat-task-soft` (4.9:1 light, 9.8:1 dark).
  final Color catTaskText;
  /// Task tag fill.
  final Color catTaskSoft;
  /// Calendar dot and tag for reminders.
  final Color catReminder;
  /// Calendar dot and tag for bills due.
  final Color catBill;
  /// Chart series 1 (primary metric, e.g. this month).
  final Color chart1;
  /// Chart series 2 (comparison, e.g. last month). Navy in light, pale blue in dark.
  final Color chart2;
  /// Chart series 3 (categories).
  final Color chart3;
  /// Chart series 4 (categories).
  final Color chart4;
  /// Chart gridlines and baselines.
  final Color chartGrid;

  static const light = DLColors(
    brand: Color(0xFF172554),
    brandHover: Color(0xFF26387A),
    onBrand: Color(0xFFFFFFFF),
    onBrandAccent: Color(0xFF93C5FD),
    brandMuted: Color(0xFFA9B8DA),
    accent: Color(0xFF3B82F6),
    accentText: Color(0xFF1D4ED8),
    accentSoft: Color(0xFFDBEAFE),
    onAccent: Color(0xFFFFFFFF),
    actionPrimary: Color(0xFF172554),
    actionPrimaryHover: Color(0xFF1E3A8A),
    onActionPrimary: Color(0xFFFFFFFF),
    background: Color(0xFFF7F8FC),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFF1F4F9),
    textPrimary: Color(0xFF172033),
    textSecondary: Color(0xFF64748B),
    textDisabled: Color(0xFFA0AABB),
    divider: Color(0xFFE8ECF3),
    borderStrong: Color(0xFF7A879C),
    focusRing: Color(0xFF3B82F6),
    scrim: Color.fromRGBO(11, 17, 32, 0.48),
    success: Color(0xFF16A34A),
    successText: Color(0xFF15803D),
    successSoft: Color(0xFFDCFCE7),
    onSuccess: Color(0xFFFFFFFF),
    warning: Color(0xFFF59E0B),
    warningText: Color(0xFFB45309),
    warningSoft: Color(0xFFFEF3C7),
    danger: Color(0xFFDC2626),
    dangerText: Color(0xFFB91C1C),
    dangerSoft: Color(0xFFFEE2E2),
    onDanger: Color(0xFFFFFFFF),
    income: Color(0xFF15803D),
    expense: Color(0xFFB91C1C),
    catEvent: Color(0xFF3B82F6),
    catTask: Color(0xFF0D9488),
    catTaskText: Color(0xFF0F766E),
    catTaskSoft: Color(0xFFCCFBF1),
    catReminder: Color(0xFFF59E0B),
    catBill: Color(0xFFDC2626),
    chart1: Color(0xFF3B82F6),
    chart2: Color(0xFF172554),
    chart3: Color(0xFF0D9488),
    chart4: Color(0xFFF59E0B),
    chartGrid: Color(0xFFE8ECF3),
  );
  static const dark = DLColors(
    brand: Color(0xFF1E3A8A),
    brandHover: Color(0xFF2B4AA0),
    onBrand: Color(0xFFFFFFFF),
    onBrandAccent: Color(0xFF93C5FD),
    brandMuted: Color(0xFFA9B8DA),
    accent: Color(0xFF60A5FA),
    accentText: Color(0xFF93C5FD),
    accentSoft: Color(0xFF172A4D),
    onAccent: Color(0xFF0B1120),
    actionPrimary: Color(0xFF60A5FA),
    actionPrimaryHover: Color(0xFF93C5FD),
    onActionPrimary: Color(0xFF0B1120),
    background: Color(0xFF0B1120),
    surface: Color(0xFF131B2E),
    surfaceRaised: Color(0xFF1A2338),
    surfaceSunken: Color(0xFF0F172A),
    textPrimary: Color(0xFFE8EDF7),
    textSecondary: Color(0xFF94A3B8),
    textDisabled: Color(0xFF55627A),
    divider: Color(0xFF243049),
    borderStrong: Color(0xFF5B6B85),
    focusRing: Color(0xFF60A5FA),
    scrim: Color.fromRGBO(0, 0, 0, 0.64),
    success: Color(0xFF4ADE80),
    successText: Color(0xFF4ADE80),
    successSoft: Color(0xFF12301F),
    onSuccess: Color(0xFF0B1120),
    warning: Color(0xFFFBBF24),
    warningText: Color(0xFFFBBF24),
    warningSoft: Color(0xFF33250A),
    danger: Color(0xFFF87171),
    dangerText: Color(0xFFF87171),
    dangerSoft: Color(0xFF3A1717),
    onDanger: Color(0xFF0B1120),
    income: Color(0xFF4ADE80),
    expense: Color(0xFFF87171),
    catEvent: Color(0xFF60A5FA),
    catTask: Color(0xFF2DD4BF),
    catTaskText: Color(0xFF5EEAD4),
    catTaskSoft: Color(0xFF0F2E2B),
    catReminder: Color(0xFFFBBF24),
    catBill: Color(0xFFF87171),
    chart1: Color(0xFF60A5FA),
    chart2: Color(0xFF93C5FD),
    chart3: Color(0xFF2DD4BF),
    chart4: Color(0xFFFBBF24),
    chartGrid: Color(0xFF243049),
  );

  @override
  DLColors copyWith({Color? brand, Color? brandHover, Color? onBrand, Color? onBrandAccent, Color? brandMuted, Color? accent, Color? accentText, Color? accentSoft, Color? onAccent, Color? actionPrimary, Color? actionPrimaryHover, Color? onActionPrimary, Color? background, Color? surface, Color? surfaceRaised, Color? surfaceSunken, Color? textPrimary, Color? textSecondary, Color? textDisabled, Color? divider, Color? borderStrong, Color? focusRing, Color? scrim, Color? success, Color? successText, Color? successSoft, Color? onSuccess, Color? warning, Color? warningText, Color? warningSoft, Color? danger, Color? dangerText, Color? dangerSoft, Color? onDanger, Color? income, Color? expense, Color? catEvent, Color? catTask, Color? catTaskText, Color? catTaskSoft, Color? catReminder, Color? catBill, Color? chart1, Color? chart2, Color? chart3, Color? chart4, Color? chartGrid}) => DLColors(brand: brand ?? this.brand, brandHover: brandHover ?? this.brandHover, onBrand: onBrand ?? this.onBrand, onBrandAccent: onBrandAccent ?? this.onBrandAccent, brandMuted: brandMuted ?? this.brandMuted, accent: accent ?? this.accent, accentText: accentText ?? this.accentText, accentSoft: accentSoft ?? this.accentSoft, onAccent: onAccent ?? this.onAccent, actionPrimary: actionPrimary ?? this.actionPrimary, actionPrimaryHover: actionPrimaryHover ?? this.actionPrimaryHover, onActionPrimary: onActionPrimary ?? this.onActionPrimary, background: background ?? this.background, surface: surface ?? this.surface, surfaceRaised: surfaceRaised ?? this.surfaceRaised, surfaceSunken: surfaceSunken ?? this.surfaceSunken, textPrimary: textPrimary ?? this.textPrimary, textSecondary: textSecondary ?? this.textSecondary, textDisabled: textDisabled ?? this.textDisabled, divider: divider ?? this.divider, borderStrong: borderStrong ?? this.borderStrong, focusRing: focusRing ?? this.focusRing, scrim: scrim ?? this.scrim, success: success ?? this.success, successText: successText ?? this.successText, successSoft: successSoft ?? this.successSoft, onSuccess: onSuccess ?? this.onSuccess, warning: warning ?? this.warning, warningText: warningText ?? this.warningText, warningSoft: warningSoft ?? this.warningSoft, danger: danger ?? this.danger, dangerText: dangerText ?? this.dangerText, dangerSoft: dangerSoft ?? this.dangerSoft, onDanger: onDanger ?? this.onDanger, income: income ?? this.income, expense: expense ?? this.expense, catEvent: catEvent ?? this.catEvent, catTask: catTask ?? this.catTask, catTaskText: catTaskText ?? this.catTaskText, catTaskSoft: catTaskSoft ?? this.catTaskSoft, catReminder: catReminder ?? this.catReminder, catBill: catBill ?? this.catBill, chart1: chart1 ?? this.chart1, chart2: chart2 ?? this.chart2, chart3: chart3 ?? this.chart3, chart4: chart4 ?? this.chart4, chartGrid: chartGrid ?? this.chartGrid);

  @override
  DLColors lerp(ThemeExtension<DLColors>? other, double t) {
    if (other is! DLColors) return this;
    return DLColors(brand: Color.lerp(brand, other.brand, t)!, brandHover: Color.lerp(brandHover, other.brandHover, t)!, onBrand: Color.lerp(onBrand, other.onBrand, t)!, onBrandAccent: Color.lerp(onBrandAccent, other.onBrandAccent, t)!, brandMuted: Color.lerp(brandMuted, other.brandMuted, t)!, accent: Color.lerp(accent, other.accent, t)!, accentText: Color.lerp(accentText, other.accentText, t)!, accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!, onAccent: Color.lerp(onAccent, other.onAccent, t)!, actionPrimary: Color.lerp(actionPrimary, other.actionPrimary, t)!, actionPrimaryHover: Color.lerp(actionPrimaryHover, other.actionPrimaryHover, t)!, onActionPrimary: Color.lerp(onActionPrimary, other.onActionPrimary, t)!, background: Color.lerp(background, other.background, t)!, surface: Color.lerp(surface, other.surface, t)!, surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!, surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!, textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!, textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!, textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!, divider: Color.lerp(divider, other.divider, t)!, borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!, focusRing: Color.lerp(focusRing, other.focusRing, t)!, scrim: Color.lerp(scrim, other.scrim, t)!, success: Color.lerp(success, other.success, t)!, successText: Color.lerp(successText, other.successText, t)!, successSoft: Color.lerp(successSoft, other.successSoft, t)!, onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!, warning: Color.lerp(warning, other.warning, t)!, warningText: Color.lerp(warningText, other.warningText, t)!, warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!, danger: Color.lerp(danger, other.danger, t)!, dangerText: Color.lerp(dangerText, other.dangerText, t)!, dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!, onDanger: Color.lerp(onDanger, other.onDanger, t)!, income: Color.lerp(income, other.income, t)!, expense: Color.lerp(expense, other.expense, t)!, catEvent: Color.lerp(catEvent, other.catEvent, t)!, catTask: Color.lerp(catTask, other.catTask, t)!, catTaskText: Color.lerp(catTaskText, other.catTaskText, t)!, catTaskSoft: Color.lerp(catTaskSoft, other.catTaskSoft, t)!, catReminder: Color.lerp(catReminder, other.catReminder, t)!, catBill: Color.lerp(catBill, other.catBill, t)!, chart1: Color.lerp(chart1, other.chart1, t)!, chart2: Color.lerp(chart2, other.chart2, t)!, chart3: Color.lerp(chart3, other.chart3, t)!, chart4: Color.lerp(chart4, other.chart4, t)!, chartGrid: Color.lerp(chartGrid, other.chartGrid, t)!);
  }
}

extension DLContext on BuildContext {
  DLColors get dl => Theme.of(this).extension<DLColors>()!;
}

/// Type scale. One family: Hind Siliguri (bundle the TTFs under assets/fonts, family name 'HindSiliguri').
/// Amount styles use tabular figures so columns of money align.
class DLText {
  static const family = 'HindSiliguri';
  static const _tab = [FontFeature.tabularFigures()];
  /// One per screen at most: onboarding, greeting on Home ("শুভ সকাল, রাহেলা").
  static const textDisplay = TextStyle(fontFamily: family, fontSize: 32, height: 1.3750, fontWeight: FontWeight.w700);
  /// Screen titles in the large top app bar.
  static const textH1 = TextStyle(fontFamily: family, fontSize: 26, height: 1.3846, fontWeight: FontWeight.w700);
  /// Section titles, dialog and bottom-sheet titles.
  static const textH2 = TextStyle(fontFamily: family, fontSize: 22, height: 1.4545, fontWeight: FontWeight.w600);
  /// Card titles: savings goal, chart, note, event.
  static const textH3 = TextStyle(fontFamily: family, fontSize: 18, height: 1.5556, fontWeight: FontWeight.w600);
  /// Input values, task titles, menu items, primary list text needing emphasis.
  static const textBodyLg = TextStyle(fontFamily: family, fontSize: 17, height: 1.6471, fontWeight: FontWeight.w400);
  /// Default reading text: transaction titles, note bodies, dialog copy.
  static const textBody = TextStyle(fontFamily: family, fontSize: 15, height: 1.6000, fontWeight: FontWeight.w400);
  /// Metadata: category · time, helper text, subtitles.
  static const textBodySm = TextStyle(fontFamily: family, fontSize: 13, height: 1.5385, fontWeight: FontWeight.w400);
  /// Nav labels, timestamps, legend labels, small tags. Never below 12px: Bengali conjuncts (ক্ষ, ন্ত্র) blur.
  static const textCaption = TextStyle(fontFamily: family, fontSize: 12, height: 1.5000, fontWeight: FontWeight.w500);
  /// All button labels. Sentence verbs: "সংরক্ষণ করুন".
  static const textButton = TextStyle(fontFamily: family, fontSize: 15, height: 1.3333, fontWeight: FontWeight.w600);
  /// Field labels, tab labels, chip labels, delta pills.
  static const textLabel = TextStyle(fontFamily: family, fontSize: 14, height: 1.4286, fontWeight: FontWeight.w500);
  /// Total balance on BalanceCard only. Tabular figures, Bengali digits, ৳ prefix, lakh grouping.
  static const amountHero = TextStyle(fontFamily: family, fontSize: 36, height: 1.2222, fontWeight: FontWeight.w700, letterSpacing: -0.36, fontFeatures: _tab);
  /// Card-level totals: income/expense cards, chart totals, amount input.
  static const amountLg = TextStyle(fontFamily: family, fontSize: 24, height: 1.3333, fontWeight: FontWeight.w700, fontFeatures: _tab);
  /// Transaction amounts, savings progress, sub-totals.
  static const amountMd = TextStyle(fontFamily: family, fontSize: 16, height: 1.5000, fontWeight: FontWeight.w600, fontFeatures: _tab);
  /// Legend values, calendar day numbers, percentages, counts.
  static const amountSm = TextStyle(fontFamily: family, fontSize: 13, height: 1.5385, fontWeight: FontWeight.w600, fontFeatures: _tab);
}

/// Spacing (4px base). 4px base. Every gap, padding and margin is one of these nine steps.
class DLSpace {
  /// Icon-to-text gap inside chips and meta rows; dot gaps.
  static const double s1 = 4;
  /// Gap between a label and its field, between tags, inside sheet header.
  static const double s2 = 8;
  /// Gap between stacked cards in a list; list-row vertical padding; tight card grid.
  static const double s3 = 12;
  /// Screen side margin (gutter) and default card padding.
  static const double s4 = 16;
  /// BalanceCard padding; horizontal padding of medium buttons; sheet side padding.
  static const double s5 = 20;
  /// Gap between screen sections; dialog padding; large button horizontal padding.
  static const double s6 = 24;
  /// Space above a section title after a hero block.
  static const double s8 = 32;
  /// Empty-state vertical padding; top inset of the sheet stage.
  static const double s10 = 40;
  /// Bottom clearance above the nav bar / FAB on scrolling screens.
  static const double s12 = 48;
}

/// Corner radius. Rounded, never sharp. Nested corners step down one size (card lg → inner chip md).
class DLRadius {
  /// Small buttons, menu items, segmented tabs, small tags.
  static const double sm = 8;
  /// Buttons, inputs, icon chips (44px squares), dropdown menus, calendar cells.
  static const double md = 12;
  /// Cards, list groups, FAB.
  static const double lg = 16;
  /// BalanceCard, dialogs, bottom-sheet top corners, nav bar top corners.
  static const double xl = 20;
  /// Search bar, chips, badges, progress tracks, nav active pill, avatars.
  static const double pill = 999;
}

/// Component sizes. Component dimensions for a 360–412dp Android width.
class DLSize {
  /// Minimum touch target: icon buttons, list rows, menu items, calendar cells.
  static const double touch = 48;
  /// Primary/secondary button height (lg) and text field height.
  static const double controlLg = 52;
  /// Medium buttons (dialogs), search bar height.
  static const double controlMd = 44;
  /// Small buttons inside cards, small icon buttons.
  static const double controlSm = 36;
  /// Floating action button.
  static const double fab = 56;
  /// Default icon size; 20px inside fields, 16px in meta rows.
  static const double icon = 24;
}

/// Elevation. Five elevations, all soft and navy-tinted in light. Dark theme leans on surface lightness instead.
class DLShadows {
  /// Resting cards, list groups, search bar, active segmented tab. Almost a hairline; in dark, surfaces separate by lightness.
  static List<BoxShadow> card(Brightness b) => b == Brightness.dark ? const [BoxShadow(offset: Offset(0, 1), blurRadius: 2, color: Color.fromRGBO(0, 0, 0, 0.32))] : const [BoxShadow(offset: Offset(0, 1), blurRadius: 2, color: Color.fromRGBO(23, 37, 84, 0.04)), BoxShadow(offset: Offset(0, 2), blurRadius: 8, color: Color.fromRGBO(23, 37, 84, 0.05))];
  /// Floating action button only. Blue-tinted in light to read as lifted, not dirty.
  static List<BoxShadow> fab(Brightness b) => b == Brightness.dark ? const [BoxShadow(offset: Offset(0, 4), blurRadius: 12, color: Color.fromRGBO(0, 0, 0, 0.48))] : const [BoxShadow(offset: Offset(0, 4), blurRadius: 12, color: Color.fromRGBO(59, 130, 246, 0.28)), BoxShadow(offset: Offset(0, 1), blurRadius: 3, color: Color.fromRGBO(23, 37, 84, 0.12))];
  /// Dropdown menus, popovers, date pickers attached to a field.
  static List<BoxShadow> dropdown(Brightness b) => b == Brightness.dark ? const [BoxShadow(offset: Offset(0, 8), blurRadius: 24, color: Color.fromRGBO(0, 0, 0, 0.56))] : const [BoxShadow(offset: Offset(0, 8), blurRadius: 24, color: Color.fromRGBO(23, 37, 84, 0.10)), BoxShadow(offset: Offset(0, 2), blurRadius: 6, color: Color.fromRGBO(23, 37, 84, 0.06))];
  /// Centered dialogs, above `scrim`.
  static List<BoxShadow> dialog(Brightness b) => b == Brightness.dark ? const [BoxShadow(offset: Offset(0, 16), blurRadius: 40, color: Color.fromRGBO(0, 0, 0, 0.64))] : const [BoxShadow(offset: Offset(0, 16), blurRadius: 40, color: Color.fromRGBO(23, 37, 84, 0.16))];
  /// Bottom sheets: shadow cast upward from the bottom edge.
  static List<BoxShadow> sheet(Brightness b) => b == Brightness.dark ? const [BoxShadow(offset: Offset(0, -8), blurRadius: 32, color: Color.fromRGBO(0, 0, 0, 0.56))] : const [BoxShadow(offset: Offset(0, -8), blurRadius: 32, color: Color.fromRGBO(23, 37, 84, 0.12))];
}
