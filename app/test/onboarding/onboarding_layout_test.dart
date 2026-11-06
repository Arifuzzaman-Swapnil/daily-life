// Welcome, the onboarding steps and Settings on a small 360dp phone, in
// English + Dark and Bengali + Light. Any overflow fails the test.
import 'package:dailylife/core/prefs/app_settings.dart';
import 'package:dailylife/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  for (final (name, prefs, en) in [
    ('English + Dark', {PrefKeys.lang: 'en', PrefKeys.digits: 'en', PrefKeys.themeMode: 'dark'}, true),
    ('Bengali + Light', <String, Object>{}, false),
  ]) {
    testWidgets('Welcome and onboarding lay out on a 360×640 phone ($name)', (tester) async {
      await pumpApp(tester, prefs: prefs, onboarded: false, size: const Size(360, 640));
      expect(tester.takeException(), isNull, reason: 'welcome');
      await tapOn(tester, find.text(en ? 'Get started' : 'শুরু করুন'));
      expect(tester.takeException(), isNull, reason: 'language');
      await tapOn(tester, find.text(en ? 'Next' : 'পরবর্তী'));
      await tapOn(tester, find.text(en ? 'Next' : 'পরবর্তী')); // empty name → error line
      expect(find.text(en ? 'Enter your name' : 'নাম লিখুন'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'name');
      await typeInto(tester, en ? 'Display name' : 'প্রদর্শিত নাম', 'Swapnil');
      await tapOn(tester, find.text(en ? 'Next' : 'পরবর্তী'));
      expect(tester.takeException(), isNull, reason: 'theme');
    });

    testWidgets('Settings lays out on a 360dp phone ($name)', (tester) async {
      await pumpApp(tester, prefs: {...prefs, PrefKeys.displayName: 'Swapnil'}, size: const Size(360, 3000));
      await openRoute(tester, Routes.settings);
      expect(tester.takeException(), isNull);
      // The name error under the field with the Save button beside it.
      await typeInto(tester, en ? 'Display name' : 'প্রদর্শিত নাম', '');
      await tapOn(tester, find.text(en ? 'Save' : 'সংরক্ষণ করুন'));
      expect(find.text(en ? 'Enter your name' : 'নাম লিখুন'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
