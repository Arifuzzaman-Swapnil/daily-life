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
}

/// Localized payment method name (`pm_*`).
String paymentLabel(AppLocalizations t, PaymentMethod m) => switch (m) {
      PaymentMethod.cash => t.pm_cash,
      PaymentMethod.bkash => t.pm_bkash,
      PaymentMethod.nagad => t.pm_nagad,
      PaymentMethod.bank => t.pm_bank,
      PaymentMethod.card => t.pm_card,
    };
