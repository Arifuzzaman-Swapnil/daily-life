# Daily Life: repo guide

The build brief, covering stack, design rules, data model, business rules, screens and build order:

@daily-life-kit/CLAUDE.md

## Layout
- `daily-life-kit/` is the design hand-off kit: read-only reference. Paths in the brief (`prototype/`, `screenshots/`, `design/`, `data/`, `flutter/`, `tools/`) are relative to it.
- `app/` is the Flutter app. Dart package `dailylife`, Android id `com.intelleqt.dailylife`.
- `.github/workflows/build-apk.yml` is the CI build.

## No local Flutter or Android SDK: CI is the build machine
- Every push runs `flutter analyze`, `flutter test` and `flutter build apk --release` on GitHub Actions. That workflow is the only place code compiles.
- Loop:
  1. Commit to `main` and push.
  2. Run `gh run watch <id> --exit-status`, in the background.
  3. On failure, run `gh run view <id> --log-failed`.
  4. Fix and push again until green.
- `app/android/` is not committed. CI runs `flutter create --platforms=android --org com.intelleqt --project-name dailylife .`, which writes only missing files. To customise an Android file, commit it under `app/android/` and CI keeps it. Examples:
  - manifest permissions
  - `MainActivity` → `FlutterFragmentActivity` for `local_auth`
  - core library desugaring for notifications
  - app label and icon
- The generated l10n (`app/lib/l10n/app_localizations*.dart`) is not committed. CI runs `flutter gen-l10n`. `flutter analyze` treats infos as errors.
- The APK is signed with a stable debug key from the `DEBUG_KEYSTORE_B64` repo secret, so updates install over earlier builds. CI checks the certificate SHA-256 against `EXPECTED_CERT_SHA256`.

## Conventions established in step 1
- Kit files are copied into `app/lib` unchanged, with one exception: `BanglaDate` in `core/format/dl_format.dart`. Falgun has 29 days, or 30 in a leap year, per the 2019 revision. The kit had 30/31, which put every Chaitra date one day early.
- Preferences: `core/prefs/app_settings.dart` (`settingsProvider`, shared_preferences).
- Formatting:
  - Every number or date a person reads goes through `formatProvider`.
  - "Today" comes from `clockProvider`. Tests pin it to 2026-11-06.
- Routing: `router.dart` (`routerProvider`, `Routes`), using a `StatefulShellRoute.indexedStack` for the 5 tabs. Full-screen pages go on the root navigator.
- Icons: always use `DLIcons` (`core/widgets/dl_icons.dart`, from `lucide_icons_flutter`), never `Icons.*`.
- `core/widgets/dl_basics.dart` holds provisional step-1 widgets. Step 2 replaces them with the shared DL components.
- Tests: `test/helpers.dart` → `pumpApp()` pumps the whole app on a 393×852 phone with mock prefs and the pinned clock.

## Build-order progress
- [ ] 1. Setup, fonts, theme, l10n, DLFormat + tests, router shell + bottom nav, language/digit/theme settings
- [ ] 2. Shared DL widgets
- [ ] 3. Drift schema + DAOs + seeder
- [ ] 4. Finance → Salary/Allocation → Savings → Shop credit
- [ ] 5. Home dashboard
- [ ] 6. Work/timer → Calendar → Reminders → Notes → Health → Goals → Documents → Reports
- [ ] 7. Privacy, backup/restore/export, onboarding
- [ ] 8. Journeys, goldens, prototype comparison, small-screen fixes
