// Step 7.1: first launch (acceptance journey 1), onboarding's back/skip
// behaviour, and Settings → Profile.
import 'package:dailylife/core/prefs/app_settings.dart';
import 'package:dailylife/core/widgets/dl_bottom_nav.dart';
import 'package:dailylife/core/widgets/dl_inputs.dart';
import 'package:dailylife/features/home/home_screen.dart';
import 'package:dailylife/features/onboarding/onboarding_screen.dart';
import 'package:dailylife/features/onboarding/welcome_screen.dart';
import 'package:dailylife/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('journey 1: Welcome → language → name (required) → theme → Home greets by name', (tester) async {
    await pumpApp(tester, onboarded: false);

    // First launch: Welcome in Bengali + Light, without the bottom nav.
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('ডেইলি লাইফে স্বাগতম'), findsOneWidget);
    expect(find.byType(DLBottomNav), findsNothing);
    expect(Theme.of(tester.element(find.byType(WelcomeScreen))).brightness, Brightness.light);

    await tapOn(tester, find.text('শুরু করুন'));
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('ধাপ ১/৩'), findsOneWidget);

    // Step 1: English applies at once.
    await tapOn(tester, find.text('English'));
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.text('Choose your language'), findsOneWidget);
    await tapOn(tester, find.text('Next'));

    // Step 2: the name is required.
    expect(find.text('What should we call you?'), findsOneWidget);
    await tapOn(tester, find.text('Next'));
    expect(find.text('Enter your name'), findsOneWidget);
    expect(find.text('Step 2 of 3'), findsOneWidget);
    await typeInto(tester, 'Display name', '  Swapnil ');
    expect(find.text('Enter your name'), findsNothing);
    await tapOn(tester, find.text('Next'));

    // Step 3: Dark applies at once.
    expect(find.text('Pick a look'), findsOneWidget);
    await tapOn(tester, find.text('Dark'));
    expect(Theme.of(tester.element(find.byType(OnboardingScreen))).brightness, Brightness.dark);
    await tapOn(tester, find.text('Start using Daily Life'));

    // Home greets by name, with the bottom nav; onboarding is remembered.
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Good morning, Swapnil!'), findsOneWidget);
    expect(find.byType(DLBottomNav), findsOneWidget);
    final settings = containerOf(tester).read(settingsProvider);
    expect(settings.displayName, 'Swapnil');
    expect(settings.themeMode, ThemeMode.dark);
    expect(containerOf(tester).read(sharedPrefsProvider).getBool(PrefKeys.onboarded), isTrue);

    // Nothing to go back to: onboarding is gone from the stack.
    expect(containerOf(tester).read(routerProvider).canPop(), isFalse);
  });

  testWidgets('back steps back through onboarding, then returns to Welcome', (tester) async {
    await pumpApp(tester, onboarded: false);
    await tapOn(tester, find.text('শুরু করুন'));
    await tapOn(tester, find.text('পরবর্তী'));
    expect(find.text('ধাপ ২/৩'), findsOneWidget);

    // The app bar's back button and the system back both step back.
    await typeInto(tester, 'প্রদর্শিত নাম', 'রিনা');
    await tapOn(tester, find.text('পরবর্তী'));
    expect(find.text('ধাপ ৩/৩'), findsOneWidget);
    await tester.tap(find.byTooltip('পেছনে যান'));
    await tester.pumpAndSettle();
    expect(find.text('ধাপ ২/৩'), findsOneWidget);
    // The name typed on step 2 is still there.
    expect(find.descendant(of: find.byType(DLField), matching: find.text('রিনা')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('ধাপ ১/৩'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(containerOf(tester).read(sharedPrefsProvider).getBool(PrefKeys.onboarded), isNull);
  });

  testWidgets('Skip goes straight to Home and is remembered', (tester) async {
    await pumpApp(tester, onboarded: false);
    // The Welcome screen's own language switch.
    await tapOn(tester, find.text('English'));
    expect(find.text('Welcome to Daily Life'), findsOneWidget);
    await tapOn(tester, find.text('Get started'));
    await tapOn(tester, find.text('Skip'));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Good morning!'), findsOneWidget);
    expect(containerOf(tester).read(sharedPrefsProvider).getBool(PrefKeys.onboarded), isTrue);
  });

  testWidgets('a finished onboarding opens on Home', (tester) async {
    await pumpApp(tester, prefs: {PrefKeys.displayName: 'Swapnil'});
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
    expect(find.text('শুভ সকাল, Swapnil!'), findsOneWidget);
  });

  testWidgets('Settings → Profile: the name is required and saved; Change photo cycles the avatar colour', (tester) async {
    await pumpApp(tester, prefs: {PrefKeys.displayName: 'Swapnil'});
    await openRoute(tester, Routes.settings);
    expect(find.text('ব্যক্তিগত তথ্য'), findsOneWidget);
    expect(find.text('Swapnil'), findsNWidgets(2)); // heading and field

    await typeInto(tester, 'প্রদর্শিত নাম', '   ');
    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(find.text('নাম লিখুন'), findsOneWidget);
    expect(find.text('লাল চিহ্নিত ঘরগুলো ঠিক করুন'), findsOneWidget);
    expect(containerOf(tester).read(settingsProvider).displayName, 'Swapnil');
    await tester.pump(const Duration(seconds: 3)); // the toast leaves

    await typeInto(tester, 'প্রদর্শিত নাম', ' স্বপ্নিল ');
    expect(find.text('নাম লিখুন'), findsNothing);
    await tapOn(tester, find.text('সংরক্ষণ করুন'));
    expect(find.text('নাম সংরক্ষণ হয়েছে'), findsOneWidget);
    expect(containerOf(tester).read(settingsProvider).displayName, 'স্বপ্নিল');
    expect(containerOf(tester).read(sharedPrefsProvider).getString(PrefKeys.displayName), 'স্বপ্নিল');
    await tester.pump(const Duration(seconds: 3));

    await tapOn(tester, find.text('ছবি বদলান'));
    expect(find.text('প্রোফাইল ছবির রং বদলানো হয়েছে'), findsOneWidget);
    expect(containerOf(tester).read(settingsProvider).avatar, 1);
    expect(containerOf(tester).read(sharedPrefsProvider).getInt(PrefKeys.avatar), 1);
    await tester.pump(const Duration(seconds: 3));
    for (var i = 0; i < 3; i++) {
      await tapOn(tester, find.text('ছবি বদলান'));
    }
    expect(containerOf(tester).read(settingsProvider).avatar, 0); // four colours, then around again
    await tester.pump(const Duration(seconds: 3));

    // Home greets with the new name.
    await tester.tap(find.byTooltip('পেছনে যান'));
    await tester.pumpAndSettle();
    expect(find.text('শুভ সকাল, স্বপ্নিল!'), findsOneWidget);
  });
}
