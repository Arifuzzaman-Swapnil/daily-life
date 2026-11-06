// Formatting rules ported 1:1 from the prototype (see prototype/source/Main.dc.html → mkF()).
// Language and number format are independent settings:
//   AppLanguage  bn | en   → words (months, weekdays, day-parts)
//   NumberFormat bn | en   → digits + grouping (bn: ০-৯ with lakh grouping ১,২৫,০০০; en: 0-9 with 125,000)
// Timezone is always Asia/Dhaka; week starts on Saturday.

enum AppLang { bn, en }

enum DigitStyle { bn, en }

enum DateStyle { written, numeric }

class DLFormat {
  const DLFormat({required this.lang, required this.digits, this.dateStyle = DateStyle.written, this.hideAmounts = false});

  final AppLang lang;
  final DigitStyle digits;
  final DateStyle dateStyle;
  final bool hideAmounts;

  static const _bnDigits = '০১২৩৪৫৬৭৮৯';
  static const monthsBn = ['জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন', 'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'];
  static const monthsBnShort = ['জানু', 'ফেব্রু', 'মার্চ', 'এপ্রি', 'মে', 'জুন', 'জুলা', 'আগ', 'সেপ্টে', 'অক্টো', 'নভে', 'ডিসে'];
  static const monthsEn = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  static const monthsEnShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  // Indexed by DateTime.weekday % 7 (0 = Sunday … 6 = Saturday).
  static const weekdaysBn = ['রবিবার', 'সোমবার', 'মঙ্গলবার', 'বুধবার', 'বৃহস্পতিবার', 'শুক্রবার', 'শনিবার'];
  static const weekdaysBnShort = ['রবি', 'সোম', 'মঙ্গল', 'বুধ', 'বৃহঃ', 'শুক্র', 'শনি'];
  static const weekdaysEn = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  static const weekdaysEnShort = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const banglaMonthsBn = ['বৈশাখ', 'জ্যৈষ্ঠ', 'আষাঢ়', 'শ্রাবণ', 'ভাদ্র', 'আশ্বিন', 'কার্তিক', 'অগ্রহায়ণ', 'পৌষ', 'মাঘ', 'ফাল্গুন', 'চৈত্র'];
  static const banglaMonthsEn = ['Boishakh', 'Joishtho', 'Asharh', 'Srabon', 'Bhadro', 'Ashwin', 'Kartik', 'Agrahayan', 'Poush', 'Magh', 'Falgun', 'Chaitra'];

  bool get _en => lang == AppLang.en;

  /// Converts ASCII digits to the selected digit style.
  String digitsOf(Object v) => digits == DigitStyle.bn ? v.toString().replaceAllMapped(RegExp(r'\d'), (m) => _bnDigits[int.parse(m[0]!)]) : v.toString();

  /// Parses user input that may contain Bengali digits or commas.
  static num? parseAmount(String s) {
    final ascii = s.replaceAllMapped(RegExp('[০-৯]'), (m) => _bnDigits.indexOf(m[0]!).toString()).replaceAll(RegExp(r'[^0-9.]'), '');
    return ascii.isEmpty ? null : num.tryParse(ascii);
  }

  /// 125000 → ১,২৫,০০০ (bn, lakh grouping) or 125,000 (en).
  String group(num n) {
    var s = n.abs().round().toString();
    if (digits == DigitStyle.bn) {
      if (s.length > 3) {
        final head = s.substring(0, s.length - 3).replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (_) => ',');
        s = '$head,${s.substring(s.length - 3)}';
      }
    } else {
      s = s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    }
    return digitsOf(s);
  }

  /// Taka amount. sign: '+' for income, '-' for expense (uses true minus U+2212), null for plain.
  String taka(num n, {String? sign}) {
    if (hideAmounts) return '৳ ••••';
    final p = sign == '+' ? '+' : sign == '-' ? '−' : (n < 0 ? '−' : '');
    return '$p৳${group(n)}';
  }

  String percent(num p) => '${digitsOf(p.round())}%';

  /// 'HH:mm' → bn: "সকাল ৯:৩০" (day-part prefix), en: "9:30 AM".
  String time(String hm) {
    final parts = hm.split(':').map(int.parse).toList();
    final h = parts[0], m = parts.length > 1 ? parts[1] : 0;
    final h12 = ((h + 11) % 12) + 1, mm = m.toString().padLeft(2, '0');
    if (_en) return '${digitsOf('$h12:$mm')} ${h < 12 ? 'AM' : 'PM'}';
    final part = h >= 4 && h < 12 ? 'সকাল' : h >= 12 && h < 15 ? 'দুপুর' : h >= 15 && h < 18 ? 'বিকাল' : h >= 18 && h < 20 ? 'সন্ধ্যা' : 'রাত';
    return '$part ${digitsOf('$h12:$mm')}';
  }

  /// Long date: bn "৬ নভেম্বর, শুক্রবার" / en "Friday, 6 November".
  String dateLong(DateTime d) {
    if (dateStyle == DateStyle.numeric) return dateNumeric(d);
    final w = d.weekday % 7;
    return _en ? '${weekdaysEn[w]}, ${digitsOf(d.day)} ${monthsEn[d.month - 1]}' : '${digitsOf(d.day)} ${monthsBn[d.month - 1]}, ${weekdaysBn[w]}';
  }

  /// Medium date: "৬ নভে ২০২৬" / "6 Nov 2026".
  String dateMedium(DateTime d) => dateStyle == DateStyle.numeric ? dateNumeric(d) : '${digitsOf(d.day)} ${(_en ? monthsEnShort : monthsBnShort)[d.month - 1]} ${digitsOf(d.year)}';

  String dateNumeric(DateTime d) => digitsOf('${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}');

  String monthYear(DateTime d) => '${(_en ? monthsEn : monthsBn)[d.month - 1]} ${digitsOf(d.year)}';

  /// আজ / গতকাল / আগামীকাল (Today / Yesterday / Tomorrow), else short date.
  String relative(DateTime d, DateTime today) {
    final diff = DateTime(d.year, d.month, d.day).difference(DateTime(today.year, today.month, today.day)).inDays;
    if (diff == 0) return _en ? 'Today' : 'আজ';
    if (diff == -1) return _en ? 'Yesterday' : 'গতকাল';
    if (diff == 1) return _en ? 'Tomorrow' : 'আগামীকাল';
    return '${digitsOf(d.day)} ${(_en ? monthsEnShort : monthsBnShort)[d.month - 1]}';
  }

  /// Weekday headers starting Saturday.
  List<String> weekHeaders() => List.generate(7, (i) => (_en ? weekdaysEnShort : weekdaysBnShort)[(i + 6) % 7]);

  /// Bangla calendar date (revised Bangladesh calendar, 2019): "২১ কার্তিক ১৪৩৩".
  String bangla(DateTime d) {
    final b = BanglaDate.from(d);
    return _en ? '${b.day} ${banglaMonthsEn[b.month]} ${b.year}' : '${digitsOf(b.day)} ${banglaMonthsBn[b.month]} ${digitsOf(b.year)}';
  }
}

/// Revised Bangladesh calendar (2019): year starts 14 April; Boishakh–Ashwin have 31 days,
/// Kartik–Magh and Chaitra 30, Falgun 29 (30 when the following Gregorian year is a leap
/// year). Anchors: 16 Dec = 1 Poush, 21 Feb = 8 Falgun, 26 Mar = 12 Chaitra.
/// (The kit/prototype gave Falgun 30/31, which made the year 366/367 days and put every
/// Chaitra date one day early.)
class BanglaDate {
  const BanglaDate(this.day, this.month, this.year);
  final int day; // 1-based
  final int month; // 0 = Boishakh
  final int year;

  static BanglaDate from(DateTime g) {
    final d = DateTime.utc(g.year, g.month, g.day);
    var y = g.year;
    var start = DateTime.utc(y, 4, 14);
    if (d.isBefore(start)) {
      y--;
      start = DateTime.utc(y, 4, 14);
    }
    var n = d.difference(start).inDays;
    final lens = [31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 29, 30];
    final ny = y + 1;
    if (ny % 4 == 0 && (ny % 100 != 0 || ny % 400 == 0)) lens[10] = 30;
    var m = 0;
    while (n >= lens[m]) {
      n -= lens[m];
      m++;
    }
    return BanglaDate(n + 1, m, y - 593);
  }
}
