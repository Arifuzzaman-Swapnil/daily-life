import 'package:dailylife/core/format/dl_format.dart';
import 'package:dailylife/core/format/dl_format_more.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const bn = DLFormat(lang: AppLang.bn, digits: DigitStyle.bn);
  const en = DLFormat(lang: AppLang.en, digits: DigitStyle.en);
  final today = DateTime(2026, 11, 6); // Friday, the prototype's fixed "today"

  group('digits & amounts', () {
    test('Bengali digits use lakh grouping', () {
      expect(bn.taka(125000), '৳১,২৫,০০০');
      expect(bn.group(1234567), '১২,৩৪,৫৬৭');
      expect(bn.group(999), '৯৯৯');
      expect(bn.group(1000), '১,০০০');
    });

    test('English digits use thousands grouping', () {
      expect(en.taka(125000), '৳125,000');
      expect(en.group(1234567), '1,234,567');
    });

    test('signs: + for income, true minus (U+2212) for expense', () {
      expect(en.taka(1200, sign: '+'), '+৳1,200');
      expect(en.taka(1200, sign: '-'), '−৳1,200');
      expect(en.taka(-500), '−৳500');
      expect(bn.taka(500, sign: '-'), '−৳৫০০');
    });

    test('language and digits are independent', () {
      const enWords = DLFormat(lang: AppLang.en, digits: DigitStyle.bn);
      expect(enWords.taka(125000), '৳১,২৫,০০০');
      expect(enWords.time('09:30'), '৯:৩০ AM');
    });

    test('hide amounts masks every amount', () {
      const hidden = DLFormat(lang: AppLang.bn, digits: DigitStyle.bn, hideAmounts: true);
      expect(hidden.taka(125000), '৳ ••••');
      expect(hidden.taka(5, sign: '+'), '৳ ••••');
    });

    test('percent', () {
      expect(bn.percent(65), '৬৫%');
      expect(en.percent(64.6), '65%');
    });

    test('parseAmount accepts Bengali digits and commas', () {
      expect(DLFormat.parseAmount('১,২৫,০০০'), 125000);
      expect(DLFormat.parseAmount('125,000'), 125000);
      expect(DLFormat.parseAmount(''), isNull);
      expect(DLFormat.parseAmount('abc'), isNull);
    });
  });

  group('times', () {
    test('Bengali day-parts', () {
      expect(bn.time('09:30'), 'সকাল ৯:৩০');
      expect(bn.time('13:00'), 'দুপুর ১:০০');
      expect(bn.time('17:00'), 'বিকাল ৫:০০');
      expect(bn.time('19:00'), 'সন্ধ্যা ৭:০০');
      expect(bn.time('21:00'), 'রাত ৯:০০');
    });

    test('day-part boundaries: 4–11 সকাল, 12–14 দুপুর, 15–17 বিকাল, 18–19 সন্ধ্যা, else রাত', () {
      expect(bn.time('03:59'), 'রাত ৩:৫৯');
      expect(bn.time('04:00'), 'সকাল ৪:০০');
      expect(bn.time('11:59'), 'সকাল ১১:৫৯');
      expect(bn.time('12:00'), 'দুপুর ১২:০০');
      expect(bn.time('14:59'), 'দুপুর ২:৫৯');
      expect(bn.time('15:00'), 'বিকাল ৩:০০');
      expect(bn.time('17:59'), 'বিকাল ৫:৫৯');
      expect(bn.time('18:00'), 'সন্ধ্যা ৬:০০');
      expect(bn.time('19:59'), 'সন্ধ্যা ৭:৫৯');
      expect(bn.time('20:00'), 'রাত ৮:০০');
      expect(bn.time('00:15'), 'রাত ১২:১৫');
    });

    test('English AM/PM', () {
      expect(en.time('09:30'), '9:30 AM');
      expect(en.time('00:15'), '12:15 AM');
      expect(en.time('12:00'), '12:00 PM');
      expect(en.time('21:05'), '9:05 PM');
    });
  });

  group('dates', () {
    test('long', () {
      expect(bn.dateLong(today), '৬ নভেম্বর, শুক্রবার');
      expect(en.dateLong(today), 'Friday, 6 November');
    });

    test('medium', () {
      expect(bn.dateMedium(today), '৬ নভে ২০২৬');
      expect(en.dateMedium(today), '6 Nov 2026');
    });

    test('numeric', () {
      expect(bn.dateNumeric(today), '০৬/১১/২০২৬');
      expect(en.dateNumeric(today), '06/11/2026');
    });

    test('numeric date style applies to long and medium dates', () {
      const numeric = DLFormat(lang: AppLang.bn, digits: DigitStyle.bn, dateStyle: DateStyle.numeric);
      expect(numeric.dateLong(today), '০৬/১১/২০২৬');
      expect(numeric.dateMedium(today), '০৬/১১/২০২৬');
    });

    test('month + year', () {
      expect(bn.monthYear(today), 'নভেম্বর ২০২৬');
      expect(en.monthYear(today), 'November 2026');
    });

    test('relative: আজ / গতকাল / আগামীকাল', () {
      expect(bn.relative(today, today), 'আজ');
      expect(bn.relative(DateTime(2026, 11, 5), today), 'গতকাল');
      expect(bn.relative(DateTime(2026, 11, 7), today), 'আগামীকাল');
      expect(bn.relative(DateTime(2026, 11, 9), today), '৯ নভে');
      expect(en.relative(today, today), 'Today');
      expect(en.relative(DateTime(2026, 11, 5, 23, 59), today), 'Yesterday');
      expect(en.relative(DateTime(2026, 11, 7), DateTime(2026, 11, 6, 22)), 'Tomorrow');
    });

    test('week headers start on Saturday', () {
      expect(bn.weekHeaders(), ['শনি', 'রবি', 'সোম', 'মঙ্গল', 'বুধ', 'বৃহঃ', 'শুক্র']);
      expect(en.weekHeaders(), ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri']);
    });
  });

  group('Bangla calendar (revised 2019)', () {
    test('2026-11-06 is ২১ কার্তিক ১৪৩৩', () {
      expect(bn.bangla(today), '২১ কার্তিক ১৪৩৩');
      expect(en.bangla(today), '21 Kartik 1433');
    });

    String b(int y, int m, int d) => bn.bangla(DateTime(y, m, d));

    test('national anchor dates', () {
      expect(b(2026, 4, 14), '১ বৈশাখ ১৪৩৩'); // Pohela Boishakh
      expect(b(2025, 12, 16), '১ পৌষ ১৪৩২'); // Victory Day
      expect(b(2026, 2, 21), '৮ ফাল্গুন ১৪৩২'); // Language Martyrs' Day
      expect(b(2026, 3, 26), '১২ চৈত্র ১৪৩২'); // Independence Day
      expect(b(2026, 4, 13), '৩০ চৈত্র ১৪৩২'); // last day of the year
    });

    test('leap years give Falgun 30 days and keep the anchors', () {
      expect(b(2028, 2, 21), '৮ ফাল্গুন ১৪৩৪');
      expect(b(2028, 2, 29), '১৬ ফাল্গুন ১৪৩৪');
      expect(b(2028, 3, 14), '৩০ ফাল্গুন ১৪৩৪');
      expect(b(2028, 3, 26), '১২ চৈত্র ১৪৩৪');
      expect(b(2028, 4, 13), '৩০ চৈত্র ১৪৩৪');
      expect(b(2028, 4, 14), '১ বৈশাখ ১৪৩৫');
    });

    test('every year has 365 or 366 days and ends on 30 Chaitra', () {
      for (var y = 2020; y <= 2040; y++) {
        final last = BanglaDate.from(DateTime(y + 1, 4, 13));
        expect(last.month, 11, reason: 'year starting $y');
        expect(last.day, 30, reason: 'year starting $y');
      }
    });
  });

  group('work formats (step 6)', () {
    test('durations: hours and minutes, as the prototype writes them', () {
      expect(bn.duration(135), '২ ঘ ১৫ মি');
      expect(en.duration(135), '2h 15m');
      expect(bn.duration(45), '৪৫ মি');
      expect(en.duration(120), '2h');
      expect(en.duration(0), '0m');
      expect(bn.duration(1725), '২৮ ঘ ৪৫ মি');
    });

    test('one decimal, short dates and weekdays, stopwatch', () {
      expect(bn.oneDecimal(7.5), '৭.৫');
      expect(en.oneDecimal(6), '6');
      expect(en.oneDecimal(2.25), '2.3');
      expect(bn.dateShort(today), '৬ নভে');
      expect(en.dateShort(today), '6 Nov');
      expect(bn.weekdayShort(today), 'শুক্র');
      expect(en.weekdayShort(DateTime(2026, 10, 31)), 'Sat');
      expect(bn.stopwatch(2723), '০০:৪৫:২৩');
      expect(en.stopwatch(3600 * 10 + 61), '10:01:01');
    });

    test('weeks start on Saturday; minutes between HH:mm times', () {
      expect(weekStartOf(today), DateTime(2026, 10, 31));
      expect(weekStartOf(DateTime(2026, 10, 31)), DateTime(2026, 10, 31));
      expect(weekStartOf(DateTime(2026, 11, 1)), DateTime(2026, 10, 31));
      expect(minutesBetween('10:00', '11:30'), 90);
      expect(minutesBetween('11:00', '10:00'), -60);
    });
  });
}
