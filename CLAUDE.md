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
  - `selectedMonthProvider` is the month Finance and Home show, like the prototype's shared `month`. It goes back at most 11 months and never past the current month.
  - `finFilterProvider` holds the Finance tab, search and filters.
  - "This month" and "today" come from `clockProvider` (`currentMonthFrom(ref)`, `todayFrom(ref)`).
- Categories on screen: `categoryBookProvider` plus `categoryInfo(t, book, type, id)` in `finance/categories.dart`. A built-in shows `cat_<id>`; an unknown or deleted id shows "Other" with the tag icon.
- `core/format/dl_format_more.dart` adds `takaCompact`, `monthShort`, `monthName`, `dateLongYear`, `count` and `paymentLabel()`. `dl_format.dart` stays as copied from the kit.
- Routing:
  - Sub-pages are top-level `GoRoute`s on the root navigator, made with `page()` in `router.dart`.
  - Paths come from `Routes`, e.g. `Routes.tx(id)`, `Routes.newTx(type)`, `Routes.shop(id)`.
  - Back and close use `popOr(context, fallback)`, so a page opened directly still has somewhere to go.
  - `/reports` was a placeholder until step 6 built Reports.
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
  - Use `kTallPhone` (393×1800) for behaviour tests, so long lazy lists and forms build completely.
  - `tapOn` uses `ensureVisible`, which scrolls the target to the top of its list. Scroll back up (e.g. `dragUntilVisible`) before checking anything above it: list items scrolled out of view are invisible to finders.
  - `finance_screens_test.dart` lays out every step 4 screen at 360 dp wide (2400 tall, so whole lists build) in English + Dark and Bengali + Light.
- Deliberate differences from the prototype:
  - Category usage is counted per (type, id).
  - The salary income title is `salaryFor(monthName)` ("November salary"); shop payments use `payTo`.
  - Split-bar colours follow each row's index.
  - Editing a shop payment's amount doesn't change the shop entry, as in the prototype.

## Conventions established in step 5 (Home)
- Home lives in `features/home/`:
  - `home_screen.dart` is the tab. Each section is its own `ConsumerWidget`.
  - `home_providers.dart` holds today's tasks, events, reminders, water, meals and habits, plus the 5 newest transactions, the inbox and `homeChartProvider`.
  - `customize_sheet.dart` is the customize sheet.
  - `notifications_screen.dart` is the notifications page (`Routes.notifications`).
- Month:
  - Home and Finance share `selectedMonthProvider` and `showMonthSheet` (`features/finance/month_sheet.dart`).
  - Home's chart is separate (`homeChartProvider`): 6 or 12 months up to the current one, plus the tapped bar.
- Dashboard layout: `core/prefs/dashboard_layout.dart` (`dashboardLayoutProvider`, `DashSection`).
  - Stored as section names under `pref.dash.order` and `pref.dash.hidden`. Every change is saved at once.
  - Unknown names are dropped; missing sections are added at the end.
- New preferences:
  - `AppSettings.displayName` (`pref.displayName`). Onboarding (step 7) sets it. While it is empty, the greeting has no name and the avatar shows the user icon.
  - `waterTargetProvider` (`core/prefs/health_prefs.dart`): default 3000 ml, clamped to 500–6000. Health (step 6) sets it.
- Repeating events: `eventOccursOn` and `eventsOn` in `features/calendar/event_rules.dart` (prototype `occurs`/`evOn`). Calendar (step 6) uses these; don't write a second version.
- Step 6 rewired Home's tiles and quick actions and `inboxDestination()` to the real screens (see step 6 below).
- Routing: `Routes.tabs` lists the 5 root tabs. Open those with `go` and everything else with `push`.
- Shared widgets added:
  - `DLAppBar.root(titleWidget:)` takes a custom title block (Home's date lines). `title` then only names the bar for screen readers.
  - `TxRow(relativeDate: true)` shows "category · আজ/গতকাল/৪ নভে".
  - `DLBarChart` bars narrow below 10px when a group is too thin for them, like the prototype's flex items. Twelve two-bar months on a phone need this.
  - `DLIcons` gained `sun`, `moon`, `bell`, `sliders`, `users`, `drop`, `flame` and `chevronUp`. `byKey` now knows the inbox icon keys too.
- ARB: added `savMonthTag` ("{a} এ মাসে" / "{a} this month"), because the prototype wrote this text inline. It is the second deliberate change to kit files, after `BanglaDate`.
- Tests:
  - Widget tests render with the FlutterTest font: every glyph is 1 em wide, so text is much wider than on a phone.
    - In a row, a trailing tag or link needs a width cap. Home's `_CardRow` caps it at 45 %.
    - Long text should wrap or ellipsize, never sit in a fixed-width spot.
  - `test/home/`:
    - `kWholeHome` (393×3000) builds the whole dashboard without scrolling.
    - `home_layout_test.dart` covers 360 dp in English + Dark, Bengali + Light, and Bengali with no data.
  - Journey 3 now ends on Home: the totals and the recent list update.

## Conventions established in step 6 (planner, lifestyle, records)
- Screens live in `features/work/`, `calendar/`, `reminders/`, `notes/`, `health/`, `goals/`, `documents/`, `reports/`; `features/notifications/` plans device notifications; `features/more/` is the More tab. Each area keeps its providers in `<area>_providers.dart`.
- Routes (all in `Routes`):
  - Work: `newTask({projectId})`, `task(id)`, `editTask(id)`, `timer`, `workHistory`, `projects`, `project(id)`.
  - Calendar: `newEvent` (starts on the Calendar's selected day), `event(id)`, `editEvent(id)`.
  - `reminders`, `newReminder({landOnList})`, `reminder(id)`, `editReminder(id)`; `notes`, `newNote`, `note(id)`, `editNote(id)`.
  - `health`, `healthTab(HealthTab)`, `newMeal(type)`, `editMeal(id)`, `habit(id)`; `goals`, `newGoal`, `goal(id)`, `editGoal(id)`.
  - `documents`, `importDoc`, `document(id)`, `viewDocument(id)`; `reportsTab(ReportTab)`.
  - A new event, note or goal replaces its form with its details (`pushReplacement`); edits pop back.
- Work timer: the rules live in `work/work_timer.dart` (`workTimerProvider`) on the single `TimerSessions` row. Elapsed = accumulated + time since `startedAt`, both from `clockProvider`. `Ticking` rebuilds every second only while the timer runs. The task can't change while running or paused, also from a task's "Start timer".
- `WeekHoursChart` (`work_ui.dart`) is the week's hours on the Work tab and in the productivity report.
- Calendar state is `calendarProvider` (view, selected day, shown month). Home's meeting/event tiles call `showToday(CalView.day)`, "Agenda" `setView(CalView.agenda)`. The day view starts at 7 AM, or earlier when an event starts earlier.
- Reminders: `remTabProvider`; saving moves the list to the tab the reminder now belongs to. Home's "Add reminder" uses `newReminder(landOnList: true)`, so saving shows the list.
- Health: the tab comes from the route. Streak, best streak and month completion are in `health_providers.dart`. Water entries are removed without asking, as in the prototype.
- Documents: `FileService` (`core/files/file_service.dart`, `fileServiceProvider`) picks (file_picker), stores the copy as `<app documents>/documents/<id>.<ext>`, reads PDF pages (pdfx), deletes and shares (share_plus). Sample documents have no file: they show only the paper preview.
- Reports: `ReportPeriod` (a month back to 11 months, or this year / last). Its data providers are families per period, so the skeleton shows while a new period loads; there is no artificial delay. Export writes a CSV and opens the share sheet.
- Notifications:
  - Toggles: `notificationPrefsProvider` (`pref.notif.<kind>`); defaults as the prototype (all on except meals). Settings shows all five; Health's water and meal switches are the same values.
  - `planNotifications()` (`notification_planner.dart`) is pure: reminders (once/daily/weekly/monthly; custom = one weekly per weekday; General vs Office toggle by category), event reminders for 30 days ahead (all-day at 9 AM), water every 2 h 8 AM–10 PM, meals at 08:00 / 13:30 / 17:00 / 21:00.
  - `notificationSyncProvider` (watched in `app.dart`) replaces every pending notification when the plan changes and when the app resumes. Ids are the plan's order. Exact alarms when Android allows, else inexact. A tap opens the notification's route.
  - flutter_local_notifications stays on 22.x: 23.0 needs AGP 9.1.1 and compileSdk 37, newer than Flutter 3.47's template (AGP 9.1.0, compileSdk 36).
- Committed Android files (Flutter 3.47 template copies plus changes; re-check them when Flutter's template changes):
  - `app/android/app/build.gradle.kts`: core library desugaring.
  - `app/android/app/src/main/AndroidManifest.xml`: `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`, the plugin's two receivers, app label "Daily Life".
- Shared widgets added: `DLAvatar`, `DLLogo`, `DLChip.leading` (category dots), `DLProgressBar.trackColor`, `DLBarGroup.colors`, and more `DLIcons` (`byKey` knows the habit icons).
- Formats added (`dl_format_more.dart`): `duration`, `oneDecimal`, `dateShort`, `weekdayShort`, `stopwatch`, `banglaMonthSpan`, `fileSize`; plus `weekStartOf()` and `minutesBetween()`.
- ARB additions (kit changes 3–6): `noProjects` (the prototype had no empty projects list), `noResults` (the prototype reused Finance's "No transactions match" for notes and documents), `notifWater`, `msPerLine` (the prototype wrote it inline).
- Tests:
  - Never `await` a drift `watch…().first` in a widget test or in widget code: it doesn't complete under fake async and hangs the run. Use one-shot queries (`db.select(…).get()`, `…ById`).
  - `tester.enterText` doesn't pump after typing. If typing triggers a rebuild that inserts or removes list children (an error line), the next field can be rebuilt mid-focus and get the wrong text. Keep conditional rows in one fixed slot (`cond ? widget : const SizedBox.shrink()`).
  - Toasts sit over the lower screen for 2.4 s. Since step 7 they let taps through (`IgnorePointer`), but a toast still covers what is under it in a screenshot or a `find` by position.
  - `pumpApp` installs `FakeNotificationScheduler` (`notificationsOf(tester)`) and `FakeFileService` (`filesOf(tester)`), and takes a `clock`; `TestClock` drives the timer.
  - `export` doesn't import: a file that re-exports a provider and also uses it must import it too.
  - Records compare sets by identity: check a `Set` field with its own `expect`.
- Deliberate differences from the prototype:
  - "Start timer" on a task doesn't move a running or paused timer to it.
  - The habit calendar shows the current month (the prototype hard-coded November).
  - The day view shows hours before 7 AM when an event starts then.
  - The Android app label is "Daily Life".

## Conventions established in step 7 (onboarding, privacy, data)
- Onboarding lives in `features/onboarding/` (`welcome_screen.dart`, `onboarding_screen.dart`; `Routes.welcome`, `Routes.onboarding`).
  - `pref.onboarded` is set when onboarding is finished or skipped. The router reads it once, for `initialLocation`.
  - `pumpApp` marks onboarding done unless `onboarded: false` (first-launch tests).
  - The language and theme pickers are shared: `features/settings/appearance_cards.dart` (`LanguageCards(large:)`, `ThemeCards`).
- Profile: `AppSettings.avatar` (`pref.avatar`) is an index into `DLAvatar.tones`. "Change photo" cycles it (`cycleAvatar()`), as in the prototype. `DLAvatar(color:)` everywhere the avatar shows.
- Create a `TextEditingController` that reads `ref` in `initState`, never as a `late final` field initializer: one that was never used is first created in `dispose`, after unmount, and Riverpod throws.
- Privacy settings: `core/prefs/privacy_prefs.dart` (`privacyProvider`: `hideAmounts`, `lock`, `biometric`, `hasPin`).
  - The PIN is stored only as a salted SHA-256 hash (`setPin`, `checkPin`, `hashPin`; `pref.pin.hash`, `pref.pin.salt`).
  - The lock can only be on with a PIN (`setLock(true)` throws otherwise). Settings says `errPinFirst`, opens the PIN sheet, and turns the lock on once the PIN is saved.
  - `PrefKeys.deviceOnly` (lock, fingerprint, PIN) and `pref.lastBackup` (`PrefKeys.notBackedUp`) never go into a backup, and a restore leaves them as they are.
- Hide amounts: `formatProvider` builds `DLFormat(hideAmounts:)`. Exports use `f.unmasked` (`dl_format_more.dart`).
  - Reports computes its export figures during `build` (`report(f.unmasked)`): its builders call `ref.watch`, so never call them from a callback.
- App lock: `core/security/app_lock.dart` (`appLockProvider` is true while locked).
  - Locks on launch and on `onHide` when `privacy.locks`.
  - System screens the app opens itself don't lock it: run them through `whileOutside()`. `DeviceFileService` does this for its picker and share calls (`OutsideRunner`); the lock screen does it for the fingerprint prompt.
  - `AppLockGate` (`features/privacy/lock_screen.dart`) wraps the app in `MaterialApp.builder`. While locked, the app below stays mounted but `Offstage`, without focus, semantics or tickers, and `LockScreen` covers it. The lock screen sits outside the Navigator and Overlay: no tooltips, toasts or sheets there.
  - `MaterialApp.router` takes the GoRouter's delegate, parser and provider plus `_LockAwareBackButtonDispatcher` (`app.dart`): system back while locked leaves the app instead of popping the hidden pages.
- Fingerprint: `core/security/biometric_service.dart` (`biometricServiceProvider`, local_auth 3). The prompt's texts come from the ARB through `AndroidAuthMessages` (`local_auth_android`).
  - The lock screen prompts by itself once per lock, when the app is resumed. Settings only turns biometric unlock on when `isAvailable()`.
- PIN UI: `DLPinDots` and `DLKeypad` (`core/widgets/dl_pin_pad.dart`). `showPinSheet(context)` resolves to whether a PIN was saved; the new PIN is asked twice.
- Backup: `core/backup/backup_service.dart`.
  - The file is JSON (`format: dailylife-backup`, `version: 1`, `schema`): every table's rows as stored (`SELECT *`), plus the `pref.…` keys that back up.
  - `parse` refuses another format or a different `schemaVersion`. Once real migrations exist, migrate older backups instead.
  - `restore` replaces every table in one transaction (`PRAGMA defer_foreign_keys`), so a bad file changes nothing. A document whose file isn't on the phone keeps only its details.
  - After a restore, every preference-backed provider is invalidated (`_apply` in `features/settings/data_section.dart`). A new preference-backed provider must be added there.
- Data management (`features/settings/data_section.dart`):
  - Back up keeps `<app documents>/backups/latest.json`, sets `pref.lastBackup`, then offers the share sheet.
  - Restore uses that copy; Import picks any file (`FileService.pickTextFile`). Both ask first.
  - Export shares all transactions (`transactionsCsv`). `toCsv` (`core/files/csv.dart`) is shared with Reports. On the device, CSV files get a UTF-8 byte-order mark.
  - "Show sample data" is `sampleDataSwitchProvider` (`core/db/sample/sample_data.dart`). Off clears every record; on loads the sample data. Both ask first when records would be lost.
- `appVersionProvider` (`core/app_info.dart`, package_info_plus) is the installed version for About and More.
- Committed Android files added (Flutter 3.47 template copies plus changes):
  - `app/android/app/src/main/kotlin/com/intelleqt/dailylife/MainActivity.kt`: `FlutterFragmentActivity`, for local_auth.
  - `app/android/app/src/main/res/values/styles.xml` and `values-night/styles.xml`: AppCompat parents for `LaunchTheme` and `NormalTheme`.
  - `AndroidManifest.xml` gains `USE_BIOMETRIC`; `build.gradle.kts` gains `minSdk = maxOf(24, flutter.minSdkVersion)` and `androidx.appcompat`.
- Shared widgets added: `DLButton.trailingIcon`, `DLTextField.invalid` (error border without the line, for a field with a button beside it), `DLAppBar(titleWidget:)` on sub-pages, `DLListRow.subtitleMaxLines`, more `DLIcons` (`lock`, `hash`, `fingerprint`, `eyeOff`, `database`, `list`, `shield`, `backspace`).
- ARB additions (kit changes 7–21): `pinAgain`, `pinMismatch`, `unlockSub`, `wrongPin`, `useBiometric`, `bioHint`, `bioUnavailable`, `deleteDigit`, `noBackup`, `backupFailed`, `errBackupFile`, `sampleOffQ`, `sampleOffB`, `sampleOnQ`, `sampleOnB`. The prototype only simulated the lock, the fingerprint and backups.
- Tests:
  - `pumpApp` also installs `FakeBiometricService` (`biometricsOf(tester)`), overrides `sampleDataProvider` with the JSON read in `helpers.dart` (the asset bundle never loads under fake async) and `appVersionProvider` with `0.1.0`.
  - `FakeFileService` keeps the latest backup in `backup`, and `pickTextFile` returns `nextText()`.
  - Lifecycle: step through `inactive → hidden → inactive → resumed` (`leaveAndReturn` in `test/privacy/privacy_test.dart`). `AppLifecycleListener` asserts on jumps, and no frames run while hidden.
  - System back is `tester.binding.handlePopRoute()`. To see the app leave, mock `SystemChannels.platform` and watch for `SystemNavigator.pop`.
  - Settings builds lazily: scroll to a row before checking it.
- Deliberate differences from the prototype:
  - The PIN is asked twice.
  - The lock screen itself is new.
  - Skip also marks onboarding done.
  - Back up also opens the share sheet.
  - The sample-data switch clears or loads real records, and asks first.
  - Toasts let taps through.

## Conventions established in step 8 (acceptance journeys, goldens, prototype comparison, small-screen fixes)
- Acceptance journeys 1–12 all have tests:
  - 1 is `onboarding/onboarding_test.dart`; 2–5 `finance/finance_journeys_test.dart`; 6 `work/work_journey_test.dart`; 7 `calendar/calendar_screens_test.dart`; 8 `reminders/reminders_test.dart`; 9 `notes/notes_test.dart`.
  - 10–12 are in `test/journeys/switching_journeys_test.dart`, with the sample data loaded, so `relocalize` runs. Each walks the whole app via a shared `tour.dart`: ~60 stops (5 tabs, pages, 4 sheets, 1 dialog). The journeys check for Bengali text left after a switch to English, colours that belong to the other theme, and that a round trip leaves every row of every table unchanged.
  - Tab stops scroll back to the top first, so a stop looks the same each time it is visited.
- Goldens live in `test/goldens/`:
  - `flutter_test_config.dart` loads the real fonts and sets a tolerant comparator. Hind Siliguri is read from `assets/fonts/`; Lucide is resolved via `.dart_tool/package_config.json` (the main glyph file `lucide.ttf` maps to the family `Lucide`, and the variable weights keep their filenames).
  - `screens.dart` holds the `Screen` type, `push`/`go` helpers, `keyScreens` (13 stops for the goldens) and `prototypeScreens` (51 stops for the tour; reuses the goldens list and adds the rest).
  - `key_screens_golden_test.dart` renders the key screens at 393×852 in 4 variants (bn/en × light/dark), tagged `golden`. Baselines live in `_baselines/`.
  - `prototype_tour_test.dart` renders every kit screen at 393×full-page and 360×852, in bn-light and en-dark, tagged `tour`. Not committed; uploaded as the `prototype-tour` artifact.
  - Both tag definitions live in `dart_test.yaml` (no skip) and the workflow uses `--exclude-tags "golden,tour"` on push, `--tags golden` / `--tags tour` for the on-demand steps.
  - The comparator `_TolerantComparator` accepts up to 0.5 % drift, so a Flutter release that moves an anti-aliased pixel doesn't fail CI.
  - Flutter resolves relative golden paths against `test/` (not the test file's own folder); hence the `goldens/_baselines/…` prefix so baselines land next to the test file.
- CI workflow (`.github/workflows/build-apk.yml`) has two `workflow_dispatch` inputs:
  - `goldens`: `off` (default push), `check` (compare), `update` (regenerate; PNGs come back as the `goldens` artifact to commit).
  - `tour`: `false`/`true`; the tour renders every kit screen and uploads them as the `prototype-tour` artifact.
  - Check-mode failures upload under `app/**/failures/**` as `golden-failures`.
  - To refresh baselines after an intentional layout change: `gh workflow run build-apk.yml --ref main -f goldens=update -f tour=false`, then `gh run download <id> -n goldens -D app/test/goldens/_baselines`, commit the PNGs.
- `DLButton` gained a `maxLines` parameter (default 1). The `SizedBox(height:)` became `ConstrainedBox(minHeight:)` so a wrapping label grows the button vertically (`maxLines > 1` also adds 8 px vertical padding).
  - The shop detail's `Add purchase` button sets `maxLines: 2` and the row is wrapped in `IntrinsicHeight`, so `Payment` beside it stays the same height. This fixes the one real narrow-screen bug the prototype tour turned up ("কেনাকাটা যোগ করুন" was truncated at 360 dp).
- Prototype tour findings worth keeping as documented differences from the kit:
  - The event form's reminder chips scroll horizontally in both (kit and app); more options than fit one line.
  - The kit shows native browser date/time inputs (`11/06/2026`, `10:00 AM`); the app uses `DLFormat` (`৬ নভে ২০২৬`, `সকাল ১০:০০`).
  - The kit's allocation rows have a plain-text category name; the app also uses a plain `TextField` with `InputDecoration.collapsed` — the surrounding `DLCard` frames the whole row, which can look like a boxed input but matches the design.
- Follow-ups out of step 8's scope:
  - Editing a shop payment's amount doesn't update the shop entry.
  - The fingerprint prompt, share sheet, and the lock-on-resume path have never run on a real phone. Install the CI APK, turn on the lock + fingerprint, and check: the prompt opens by itself; after the share sheet or the file picker the app does not lock again.

## Build-order progress
- [x] 1. Setup, fonts, theme, l10n, DLFormat + tests, router shell + bottom nav, language/digit/theme settings (done 2026-11-06)
- [x] 2. Shared DL widgets (done 2026-11-06)
- [x] 3. Drift schema + DAOs + seeder (done 2026-11-06)
- [x] 4. Finance → Salary/Allocation → Savings → Shop credit (done 2026-11-06)
- [x] 5. Home dashboard (done 2026-11-06)
- [x] 6. Work/timer → Calendar → Reminders → Notes → Health → Goals → Documents → Reports (done 2026-11-06)
- [x] 7. Privacy, backup/restore/export, onboarding (done 2026-11-07)
- [x] 8. Journeys, goldens, prototype comparison, small-screen fixes (done 2026-11-07)
