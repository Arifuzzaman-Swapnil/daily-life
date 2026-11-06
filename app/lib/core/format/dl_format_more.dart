// Formats the screens need beyond the kit's DLFormat. Kept in their own file so
// dl_format.dart stays as copied from the kit.
import '../../l10n/app_localizations.dart';
import '../db/enums.dart';
import 'dl_format.dart';

extension DLFormatMore on DLFormat {
  /// Compact taka for chart labels (prototype `F.tkk`): 40000 → `৳৪০হা` / `৳40k`,
  /// 12500 → `৳১২.৫হা` / `৳12.5k`.
  String takaCompact(num n) {
    if (hideAmounts) return '••';
    final k = (n.abs() / 1000 * 10).round() / 10;
    final s = k == k.truncateToDouble() ? k.toInt().toString() : k.toString();
    return '৳${digitsOf(s)}${lang == AppLang.en ? 'k' : 'হা'}';
  }

  /// Short month name (prototype `monS`): নভে / Nov.
  String monthShort(DateTime d) => (lang == AppLang.en ? DLFormat.monthsEnShort : DLFormat.monthsBnShort)[d.month - 1];

  /// Month name without the year: নভেম্বর / November.
  String monthName(DateTime d) => (lang == AppLang.en ? DLFormat.monthsEn : DLFormat.monthsBn)[d.month - 1];

  /// Long date with the year (transaction details): `৩ নভেম্বর, মঙ্গলবার, ২০২৬`.
  String dateLongYear(DateTime d) => dateStyle == DateStyle.numeric ? dateNumeric(d) : '${dateLong(d)}, ${digitsOf(d.year)}';

  /// A whole number in the selected digits, e.g. a count.
  String count(int n) => digitsOf(n);

  /// Logged time (prototype `F.dur`): 135 → `২ ঘ ১৫ মি` / `2h 15m`, 45 → `৪৫ মি` / `45m`,
  /// 120 → `২ ঘ` / `2h`.
  String duration(num minutes) {
    final total = minutes.round();
    final h = total ~/ 60, m = total % 60;
    if (lang == AppLang.en) return h > 0 ? '${digitsOf(h)}h${m > 0 ? ' ${digitsOf(m)}m' : ''}' : '${digitsOf(m)}m';
    return h > 0 ? '${digitsOf(h)} ঘ${m > 0 ? ' ${digitsOf(m)} মি' : ''}' : '${digitsOf(m)} মি';
  }

  /// A number with at most one decimal (prototype week-hours labels): 7.5 → `৭.৫`, 6.0 → `৬`.
  String oneDecimal(num v) {
    final r = (v * 10).round() / 10;
    return digitsOf(r == r.truncateToDouble() ? r.toInt() : r);
  }

  /// Short date (prototype `short`): `৬ নভে` / `6 Nov`, or `০৬/১১` with numeric dates.
  String dateShort(DateTime d) => dateStyle == DateStyle.numeric
      ? digitsOf('${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}')
      : '${digitsOf(d.day)} ${monthShort(d)}';

  /// Short weekday (prototype `wd`): শুক্র / Fri.
  String weekdayShort(DateTime d) => (lang == AppLang.en ? DLFormat.weekdaysEnShort : DLFormat.weekdaysBnShort)[d.weekday % 7];

  /// The Bangla months a Gregorian month spans (prototype `bMon`): November 2026
  /// → `কার্তিক–অগ্রহায়ণ ১৪৩৩` / `Kartik–Agrahayan 1433`.
  String banglaMonthSpan(DateTime month) {
    final first = BanglaDate.from(DateTime(month.year, month.month));
    final last = BanglaDate.from(DateTime(month.year, month.month + 1, 0));
    final names = lang == AppLang.en ? DLFormat.banglaMonthsEn : DLFormat.banglaMonthsBn;
    return '${names[first.month]}–${names[last.month]} ${digitsOf(last.year)}';
  }

  /// A stopwatch reading: 2723 s → `০০:৪৫:২৩`.
  String stopwatch(int seconds) {
    String two(int n) => n.toString().padLeft(2, '0');
    return digitsOf('${two(seconds ~/ 3600)}:${two(seconds ~/ 60 % 60)}:${two(seconds % 60)}');
  }
}

/// The Saturday that starts [d]'s week (the week starts on Saturday everywhere).
DateTime weekStartOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday % 7 + 1) % 7);

/// Minutes from `HH:mm` [a] to `HH:mm` [b] (negative when [b] is earlier).
int minutesBetween(String a, String b) {
  int m(String hm) {
    final p = hm.split(':').map(int.parse).toList();
    return p[0] * 60 + (p.length > 1 ? p[1] : 0);
  }

  return m(b) - m(a);
}

/// Localized payment method name (`pm_*`).
String paymentLabel(AppLocalizations t, PaymentMethod m) => switch (m) {
      PaymentMethod.cash => t.pm_cash,
      PaymentMethod.bkash => t.pm_bkash,
      PaymentMethod.nagad => t.pm_nagad,
      PaymentMethod.bank => t.pm_bank,
      PaymentMethod.card => t.pm_card,
    };
