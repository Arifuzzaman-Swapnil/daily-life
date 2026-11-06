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
  - CI must export `ANDROID_USER_HOME=$HOME/.android`. Without it, the Android Gradle Plugin generates its own key.
  - A local backup of the keystore is at `~/.android/dailylife-debug.keystore`. It uses the standard debug credentials: store and key password `android`, alias `androiddebugkey`.
- A clean CI run takes about 10 minutes. The Gradle build and the NDK download are most of it.

## Conventions established in step 1
- Kit files are copied into `app/lib` unchanged, with one exception: `BanglaDate` in `core/format/dl_format.dart`. Falgun has 29 days, or 30 in a leap year, per the 2019 revision. The kit had 30/31, which put every Chaitra date one day early.
- Preferences: `core/prefs/app_settings.dart` (`settingsProvider`, shared_preferences).
- Formatting:
  - Every number or date a person reads goes through `formatProvider`.
  - "Today" comes from `clockProvider`. Tests pin it to 2026-11-06.
- Routing: `router.dart` (`routerProvider`, `Routes`), using a `StatefulShellRoute.indexedStack` for the 5 tabs. Full-screen pages go on the root navigator.
- Icons: always use `DLIcons` (`core/widgets/dl_icons.dart`, from `lucide_icons_flutter`), never `Icons.*`.
- Shared components: import `core/widgets/dl_widgets.dart` (step 2). Build screens from these; don't hand-roll cards, rows, chips, fields or overlays.
  - Every tappable component goes through `DLPressable` (`dl_motion.dart`): 97 % press scale, pressed fill, keyboard focus ring. Durations go through `DLMotion.of(context, …)`, which returns zero under reduced motion.
  - Overlays: `showDLSheet`, `showDLConfirm` (resolves to `bool`), `DLToast.show`. They use the root navigator/overlay so they cover the bottom nav.
  - Chips, the switch and the checkbox are drawn at prototype size but lay out 48dp tall for touch. In a chip `Wrap`, use `spacing: 8, runSpacing: 0`.
  - Charts (`DLBarChart`, `DLDonut`) are plain widgets and painters matching the prototype's CSS bars and SVG ring; `fl_chart` isn't used.
  - `DLSkeleton` repeats forever, so tests that show it must `pump`, not `pumpAndSettle` (or enable reduced motion).
- Widget tests for the components live in `test/widgets/`; `harness.dart` → `pumpDL()` pumps one widget in the DL theme.
- Tests: `test/helpers.dart` → `pumpApp()` pumps the whole app on a 393×852 phone with mock prefs, an empty in-memory database and the pinned clock.

## Conventions established in step 3 (database)
- Drift lives in `core/db/`:
  - `tables.dart` holds all 23 tables, `enums.dart` the enums (stored by `.name`), `converters.dart` the storage helpers.
  - `app_database.dart` is `AppDatabase`. `daos/` has one DAO per area.
- No `sqlite3_flutter_libs`: it's end-of-life. drift's `sqlite3` 3.x bundles SQLite for Android and the CI test host.
- Code generation runs only in CI (step "Generate code (drift)", about 45 s). `*.g.dart` is gitignored and excluded from analyze. After changing tables or DAOs, just push.
- Storage:
  - Ids are text: `newId()` (uuid v4). Seeded rows keep the sample ids.
  - Amounts are int taka.
  - Date-only columns use `DateOnlyConverter`: text `yyyy-MM-dd`, read back as local midnight. Filter with `DayRange` (half-open day keys), e.g. `t.date.isBiggerOrEqualValue(r.start)`.
  - Times of day are text `HH:mm`, the format `DLFormat.time` takes. Timestamps are ISO text (`build.yaml`).
- Raw SQL in `customSelect` uses snake_case names and enum names (`'income'`, `'deposit'`). List every table it reads in `readsFrom`, or streams won't update.
- Providers are in `db_providers.dart`: `appDatabaseProvider` (overridden in `main()` and in tests) and one `…DaoProvider` per DAO. Tests use `memoryDatabase()` from `test/helpers.dart`.
- Business rules live in the DAOs:
  - `FinanceDao.monthTotals`: available = income − expenses − max(0, net savings deposits).
  - `ShopDao.pay`: throws `ShopOverpayException`, otherwise writes the pay entry plus an expense in category `shop` with `shopId`.
  - `SavingsDao.addEntry`: throws `SavingsOverdrawException`.
  - `SalaryDao.addSalary`: writes the record, the income transaction and the new monthly amount.
  - Text a DAO writes for the user, such as "Payment to …" or "November salary", is passed in by the caller in the current language.
- Categories:
  - Built-ins have a null `name`; show `cat_<id>`. Their key is (type, id), since `other` exists for both types.
  - `shop` is `isSystem` and left out of pickers.
- Deleting a shop payment's expense deletes the payment entry (FK cascade). Deleting a shop keeps its expenses, unlinked.
- Schema changes before the first real release: bump `schemaVersion`, and `onUpgrade` drops and recreates every table. From the first release, write real migrations.
- Sample data:
  - `assets/sample_data.json` is the kit file, unchanged; a test checks this.
  - `SampleSeeder.seed(lang)` writes the current language. `relocalize` runs on language switch (wired in `app.dart`, only while `pref.sampleData` is true) and swaps only untouched text.
  - CI builds with `--dart-define=DL_SAMPLE_DATA=true` (`kSampleDataBuild`), so an empty database is seeded once at startup. `pref.sampleData` = false means the person turned it off.
  - Step 7's "Show sample data" toggle uses `SampleDataService.load` and `clear`.
  - Seeded dates are absolute, anchored to 2026-11-06.

## Conventions established in step 4 (money screens)
- Screens live in `features/<area>/` (`finance/`, `salary/`, `savings/`, `shop_credit/`).
- Money data comes from `features/finance/money_providers.dart`: one `StreamProvider` per DAO stream, `.family` per month or id.
  - `selectedMonthProvider` is the month Finance shows. Home (step 5) should use it too, like the prototype's shared `month`. It goes back at most 11 months and never past the current month.
  - `finFilterProvider` holds the Finance tab, search and filters.
  - "This month" and "today" come from `clockProvider` (`currentMonthFrom(ref)`, `todayFrom(ref)`).
- Categories on screen: `categoryBookProvider` plus `categoryInfo(t, book, type, id)` in `finance/categories.dart`. A built-in shows `cat_<id>`; an unknown or deleted id shows "Other" with the tag icon.
- `core/format/dl_format_more.dart` adds `takaCompact`, `monthShort`, `monthName`, `dateLongYear`, `count` and `paymentLabel()`. `dl_format.dart` stays as copied from the kit.
- Routing:
  - Sub-pages are top-level `GoRoute`s on the root navigator, made with `page()` in `router.dart`.
  - Paths come from `Routes`, e.g. `Routes.tx(id)`, `Routes.newTx(type)`, `Routes.shop(id)`.
  - Back and close use `popOr(context, fallback)`, so a page opened directly still has somewhere to go.
  - `/reports` is a titled placeholder until step 6.
- Forms:
  - Errors are a map keyed by field. On a failed save, show `DLToast.show(context, t.errForm, error: true)`. Typing in a field clears that field's error.
  - Amounts go through `DLFormat.parseAmount(...)?.round()`, which accepts Bengali digits; ≤ 0 is `errAmount`.
  - Dates and times use `DLPickerField` with `pickDate`/`pickTime` (`core/widgets/dl_pickers.dart`). Payment methods use chips in sheets and `DLSelect` on full forms, as in the prototype.
  - Show the toast before `pop`. It lives in the root overlay and outlives the page.
- Never set a `TextEditingController`'s text in `build`. Prefill in `initState` (e.g. from a DAO future) or in a listener.
- Sheets are `showDLSheet` with a private `Consumer(Stateful)Widget` body. They close with `Navigator.of(context).pop()`.
- Allocation rows save as you type: one controller pair per row id, created once. Save only removes empty rows. Removing a row that has a name or amount asks first.
- Shared widgets added:
  - `DLCard`/`DLList` `outlined` (inside sheets), `DLNote` (tinted note), `DLAddButton` (dashed "add another").
  - `DLPickerField`, a second action on `DLEmptyState`, `DLTextField.prefixText`.
  - More `DLIcons`, plus `DLIcons.byKey` for stored category icon keys.
- Tests:
  - `pumpApp(tester, sampleData: true)` seeds the sample data in the prefs' language and returns the database.
  - `memoryDatabase()` uses `closeStreamsSynchronously`, so drift leaves no timer pending when a widget test ends.
  - Helpers: `openRoute`, `tapOn`, `typeInto`, `fieldLabelled` (finds a `DLField` by its label), `scrollTo`.
  - `finance_screens_test.dart` lays out every step 4 screen at 360 dp wide (2400 tall, so whole lists build) in English + Dark and Bengali + Light.
- Deliberate differences from the prototype:
  - Category usage is counted per (type, id).
  - The salary income title is `salaryFor(monthName)` ("November salary"); shop payments use `payTo`.
  - Split-bar colours follow each row's index.
  - Editing a shop payment's amount doesn't change the shop entry, as in the prototype.

## Build-order progress
- [x] 1. Setup, fonts, theme, l10n, DLFormat + tests, router shell + bottom nav, language/digit/theme settings (done 2026-11-06)
- [x] 2. Shared DL widgets (done 2026-11-06)
- [x] 3. Drift schema + DAOs + seeder (done 2026-11-06)
- [ ] 4. Finance → Salary/Allocation → Savings → Shop credit
- [ ] 5. Home dashboard
- [ ] 6. Work/timer → Calendar → Reminders → Notes → Health → Goals → Documents → Reports
- [ ] 7. Privacy, backup/restore/export, onboarding
- [ ] 8. Journeys, goldens, prototype comparison, small-screen fixes
