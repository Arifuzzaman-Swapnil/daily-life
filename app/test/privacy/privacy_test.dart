// Step 7.2: hide amounts, the PIN sheet (hash only), app lock on launch and
// on return, and fingerprint unlock.
import 'dart:async';

import 'package:dailylife/core/prefs/app_settings.dart';
import 'package:dailylife/core/prefs/privacy_prefs.dart';
import 'package:dailylife/core/security/app_lock.dart';
import 'package:dailylife/core/widgets/dl_card.dart';
import 'package:dailylife/core/widgets/dl_icons.dart';
import 'package:dailylife/core/widgets/dl_pin_pad.dart';
import 'package:dailylife/features/home/home_screen.dart';
import 'package:dailylife/features/privacy/lock_screen.dart';
import 'package:dailylife/features/settings/settings_screen.dart';
import 'package:dailylife/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const _salt = 'test-salt';

/// Preferences with the PIN 1234 and the app lock on.
final lockedPrefs = <String, Object>{
  PrefKeys.pinSalt: _salt,
  PrefKeys.pinHash: PrivacyController.hashPin('1234', _salt),
  PrefKeys.appLock: true,
};

/// Types [pin] on the visible number pad (Bengali digits by default).
Future<void> enterPin(WidgetTester tester, String pin, {bool bengali = true}) async {
  const bn = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
  for (final ch in pin.split('')) {
    final label = bengali ? bn[int.parse(ch)] : ch;
    await tester.tap(find.descendant(of: find.byType(DLKeypad), matching: find.text(label)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// The app goes to the background and comes back.
Future<void> leaveAndReturn(WidgetTester tester) async {
  final binding = tester.binding;
  binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  await tester.pump();
  binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();
}

bool locked(WidgetTester tester) => containerOf(tester).read(appLockProvider);

/// Any text that shows a real taka amount (`৳` right before a digit).
final realAmount = find.byWidgetPredicate((w) {
  final text = w is Text ? (w.data ?? w.textSpan?.toPlainText()) : (w is RichText ? w.text.toPlainText() : null);
  return text != null && RegExp(r'৳[০-৯0-9]').hasMatch(text);
});

Future<void> openSettingsRow(WidgetTester tester, String title) => tapOn(tester, find.widgetWithText(DLListRow, title));

void main() {
  testWidgets('hide amounts masks every amount on screen; the report export keeps the real figures', (tester) async {
    await pumpApp(tester, sampleData: true, size: kTallPhone);
    expect(realAmount, findsWidgets);

    await openRoute(tester, Routes.settings);
    await openSettingsRow(tester, 'টাকার অঙ্ক লুকান');
    expect(containerOf(tester).read(privacyProvider).hideAmounts, isTrue);
    expect(containerOf(tester).read(sharedPrefsProvider).getBool(PrefKeys.hideAmounts), isTrue);
    await tester.tap(find.byTooltip('পেছনে যান'));
    await tester.pumpAndSettle();

    // Home: the hero, savings, outstanding and recent transactions.
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(realAmount, findsNothing);
    expect(find.text('৳ ••••'), findsWidgets);
    // Finance too.
    await tester.tap(navLabel('হিসাব'));
    await tester.pumpAndSettle();
    expect(realAmount, findsNothing);
    expect(find.text('৳ ••••'), findsWidgets);

    // The financial report's CSV still has the real amounts.
    await openRoute(tester, Routes.reports);
    expect(realAmount, findsNothing);
    await tester.tap(find.byTooltip('এক্সপোর্ট করুন'));
    await tester.pumpAndSettle();
    final csv = filesOf(tester).shared.last;
    expect(csv, isNot(contains('••')));
    expect(RegExp(r'৳[০-৯]').hasMatch(csv), isTrue, reason: csv);
  });

  testWidgets('the PIN sheet asks twice, starts over on a mismatch, and stores only a hash', (tester) async {
    await pumpApp(tester, size: kTallPhone);
    await openRoute(tester, Routes.settings);
    expect(find.text('পিন সেট করা হয়নি'), findsOneWidget);
    await openSettingsRow(tester, 'পিন সেট করুন');
    expect(find.byType(DLKeypad), findsOneWidget);
    expect(find.text('৪ সংখ্যার পিন দিন'), findsOneWidget);

    // Backspace removes the last digit.
    await enterPin(tester, '9');
    expect(tester.widget<DLPinDots>(find.byType(DLPinDots)).filled, 1);
    await tester.tap(find.byIcon(DLIcons.backspace));
    await tester.pumpAndSettle();
    expect(tester.widget<DLPinDots>(find.byType(DLPinDots)).filled, 0);
    await enterPin(tester, '1234');
    expect(find.text('পিনটি আবার দিন'), findsOneWidget);
    await enterPin(tester, '1235');
    expect(find.text('পিন মেলেনি। আবার চেষ্টা করুন।'), findsOneWidget);
    expect(find.text('৪ সংখ্যার পিন দিন'), findsOneWidget);
    expect(containerOf(tester).read(privacyProvider).hasPin, isFalse);

    await enterPin(tester, '1234');
    expect(find.text('পিন মেলেনি। আবার চেষ্টা করুন।'), findsNothing);
    await enterPin(tester, '1234');
    expect(find.byType(DLKeypad), findsNothing);
    expect(find.text('পিন সেট হয়েছে'), findsOneWidget);

    final prefs = containerOf(tester).read(sharedPrefsProvider);
    final hash = prefs.getString(PrefKeys.pinHash)!;
    expect(hash, hasLength(64));
    expect(prefs.getKeys().map(prefs.get).whereType<String>().any((v) => v.contains('1234')), isFalse);
    final ctl = containerOf(tester).read(privacyProvider.notifier);
    expect(ctl.checkPin('1234'), isTrue);
    expect(ctl.checkPin('1235'), isFalse);
    expect(find.text('পিন বদলান'), findsOneWidget);
    expect(find.text('পিন সেট আছে'), findsOneWidget);
    // Setting the PIN alone doesn't turn the lock on.
    expect(containerOf(tester).read(privacyProvider).lock, isFalse);
  });

  testWidgets('app lock needs a PIN first: it says so, opens the PIN sheet, and saving turns the lock on', (tester) async {
    await pumpApp(tester, size: kTallPhone);
    await openRoute(tester, Routes.settings);
    await openSettingsRow(tester, 'অ্যাপ লক');
    expect(find.text('আগে পিন সেট করুন'), findsOneWidget);
    expect(find.byType(DLKeypad), findsOneWidget);
    expect(containerOf(tester).read(privacyProvider).lock, isFalse);

    // The toast doesn't block the pad under it.
    await enterPin(tester, '2468');
    await enterPin(tester, '2468');
    final privacy = containerOf(tester).read(privacyProvider);
    expect(privacy.hasPin, isTrue);
    expect(privacy.lock, isTrue);
    expect(containerOf(tester).read(sharedPrefsProvider).getBool(PrefKeys.appLock), isTrue);
    // Turning the lock on doesn't lock the app straight away.
    expect(locked(tester), isFalse);

    // Off again, without asking.
    await tester.pump(const Duration(seconds: 3));
    await openSettingsRow(tester, 'অ্যাপ লক');
    expect(containerOf(tester).read(privacyProvider).lock, isFalse);
    expect(containerOf(tester).read(privacyProvider).hasPin, isTrue);
  });

  testWidgets('locked on launch: the app is hidden, a wrong PIN is refused, the right one opens it', (tester) async {
    await pumpApp(tester, prefs: lockedPrefs);
    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
    expect(find.text('চালিয়ে যেতে আপনার পিন দিন'), findsOneWidget);
    // No fingerprint button unless biometric unlock is on.
    expect(find.text('আঙুলের ছাপ ব্যবহার করুন'), findsNothing);

    await enterPin(tester, '1111');
    expect(find.text('ভুল পিন। আবার চেষ্টা করুন।'), findsOneWidget);
    expect(locked(tester), isTrue);

    await enterPin(tester, '1234');
    expect(find.byType(LockScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('শুভ সকাল!'), findsOneWidget);
  });

  testWidgets('system back on the lock screen leaves the app instead of popping the pages under it', (tester) async {
    await pumpApp(tester, prefs: lockedPrefs);
    await openRoute(tester, Routes.settings);
    var leftApp = false;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') leftApp = true;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(leftApp, isTrue);
    await enterPin(tester, '1234');
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('the app locks again when it comes back, but not after its own picker or share sheet', (tester) async {
    await pumpApp(tester, prefs: lockedPrefs);
    await enterPin(tester, '1234');
    expect(locked(tester), isFalse);

    // A system screen the app opened itself (file picker, share sheet).
    final lock = containerOf(tester).read(appLockProvider.notifier);
    final picker = Completer<void>();
    final pick = lock.whileOutside(() => picker.future);
    await leaveAndReturn(tester);
    picker.complete();
    await pick;
    expect(locked(tester), isFalse);

    // Leaving for anything else locks.
    await leaveAndReturn(tester);
    expect(locked(tester), isTrue);
    expect(find.byType(LockScreen), findsOneWidget);
    await enterPin(tester, '1234');
    expect(locked(tester), isFalse);

    // No lock without the setting.
    await containerOf(tester).read(privacyProvider.notifier).setLock(false);
    await leaveAndReturn(tester);
    expect(locked(tester), isFalse);
  });

  testWidgets('fingerprint: the prompt opens by itself when locked, and the button tries again', (tester) async {
    await pumpApp(tester, prefs: {...lockedPrefs, PrefKeys.biometric: true});
    final bio = biometricsOf(tester);
    // On launch: prompted once, recognised.
    expect(bio.prompts, 1);
    expect(locked(tester), isFalse);

    // Back from the background: prompted again; not recognised → still locked.
    bio.result = false;
    await leaveAndReturn(tester);
    expect(bio.prompts, 2);
    expect(locked(tester), isTrue);
    await tester.tap(find.text('আঙুলের ছাপ ব্যবহার করুন'));
    await tester.pumpAndSettle();
    expect(bio.prompts, 3);
    expect(locked(tester), isTrue);
    bio.result = true;
    await tester.tap(find.text('আঙুলের ছাপ ব্যবহার করুন'));
    await tester.pumpAndSettle();
    expect(locked(tester), isFalse);
  });

  testWidgets('biometric lock can only be turned on when the phone has a fingerprint set up', (tester) async {
    await pumpApp(tester, size: kTallPhone);
    await openRoute(tester, Routes.settings);
    biometricsOf(tester).available = false;
    await openSettingsRow(tester, 'বায়োমেট্রিক লক');
    expect(find.text('এই ফোনে আঙুলের ছাপ চালু করা নেই'), findsOneWidget);
    expect(containerOf(tester).read(privacyProvider).biometric, isFalse);

    biometricsOf(tester).available = true;
    await openSettingsRow(tester, 'বায়োমেট্রিক লক');
    expect(containerOf(tester).read(privacyProvider).biometric, isTrue);
    await openSettingsRow(tester, 'বায়োমেট্রিক লক');
    expect(containerOf(tester).read(privacyProvider).biometric, isFalse);
  });

  for (final (name, prefs, en) in [
    ('English + Dark', {PrefKeys.lang: 'en', PrefKeys.digits: 'en', PrefKeys.themeMode: 'dark'}, true),
    ('Bengali + Light', <String, Object>{}, false),
  ]) {
    testWidgets('the lock screen and PIN sheet lay out on a 360×640 phone ($name)', (tester) async {
      await pumpApp(tester, prefs: {...prefs, ...lockedPrefs, PrefKeys.biometric: true}, size: const Size(360, 640));
      // Fingerprint recognised on launch; lock again with it failing, to see
      // the whole lock screen.
      biometricsOf(tester).result = false;
        await leaveAndReturn(tester);
      expect(find.byType(LockScreen), findsOneWidget);
      await enterPin(tester, '0000', bengali: !en);
      expect(find.text(en ? 'Wrong PIN. Try again.' : 'ভুল পিন। আবার চেষ্টা করুন।'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await enterPin(tester, '1234', bengali: !en);

      await openRoute(tester, Routes.settings);
      await openSettingsRow(tester, en ? 'Change PIN' : 'পিন বদলান');
      await enterPin(tester, '1234', bengali: !en);
      await enterPin(tester, '4321', bengali: !en);
      expect(find.text(en ? "The PINs don't match. Try again." : 'পিন মেলেনি। আবার চেষ্টা করুন।'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
