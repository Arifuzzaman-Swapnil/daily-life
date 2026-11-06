# Daily Life — Flutter build brief

**Daily Life** (Bangla: আমার জীবন) — *Your Life. Your Money. Your Control.*
A private, offline-first Android app for personal money, salary, expenses, savings, shop credit, office work, calendar, reminders, notes, water, meals, habits, goals and documents. Bengali is the default language; English is fully supported. Light, Dark and System themes.

This folder is the hand-off from the design phase. **Your job: build the production Flutter app so it matches the prototype screen-for-screen and behaviour-for-behaviour.** The prototype is the source of truth for layout, copy, states and interactions; this file is the source of truth for architecture and rules.

## What's in this kit

| Path | What it is | How to use it |
|---|---|---|
| `prototype/index.html` | The full interactive prototype, runnable in any browser | Open it. URL params: `?start=<screen>&theme=light\|dark\|system&lang=bn\|en`. Use Playwright to compare your build against it. |
| `prototype/source/Main.dc.html` | Prototype source: template + all logic in one `<script>` | Read the `v_*` (view-model) and `a_*` (actions) methods for exact behaviour, validation and calculations. |
| `screenshots/bangla-light/`, `screenshots/english-dark/` | 72 reference screens per variant (full-page where the screen scrolls) | Visual target for every screen, sheet, dialog and empty state. |
| `design/tokens.json`, `design/DESIGN_SYSTEM.md` | The Daily Life design system (colours both themes, type, spacing, radius, shadows, sizes, principles) | Never invent values; compose from these. |
| `flutter/lib/core/theme/dl_tokens.dart` | **Generated** Dart tokens: `DLColors` (ThemeExtension, light+dark), `DLText`, `DLSpace`, `DLRadius`, `DLSize`, `DLShadows` | Drop into the app as-is. Regenerate with `tools/gen_assets.js` if tokens change. |
| `flutter/lib/core/theme/dl_theme.dart` | `DLTheme.light()` / `DLTheme.dark()` ThemeData | Wire into `MaterialApp`. |
| `flutter/lib/core/format/dl_format.dart` | Bengali/English digits, lakh grouping, taka, day-part times, dates, Bangla calendar | Use for **every** number/date a person reads. Write unit tests against the examples below. |
| `flutter/lib/l10n/app_bn.arb`, `app_en.arb`, `flutter/l10n.yaml` | All 636 UI strings in both languages (same keys as the prototype) | Use `flutter gen-l10n`. Placeholders are `{n}`, `{a}`, `{b}`, `{d}`, `{m}`, `{p}`, `{s}`. |
| `data/sample_data.json` | The prototype's seed data (today = 2026-11-06) | Use for a debug "sample data" seeder and for widget/golden tests. |
| `tools/` | Node scripts that produced the generated files | `node tools/gen_assets.js prototype/source/Main.dc.html design/tokens.json .` |

## Tech stack (decide otherwise only with a reason)

- Flutter stable, Dart 3, Material 3 with the custom theme above. Android first (minSdk 23+); keep iOS buildable.
- State: **Riverpod** (`flutter_riverpod`, codegen optional). Routing: **go_router** with a `StatefulShellRoute` for the 5 bottom tabs.
- Persistence: **drift** (SQLite) for all records; **shared_preferences** for preferences (language, digit style, date style, theme, Bangla-date toggle, notification toggles, dashboard layout, hide-amounts, PIN hash, app-lock, biometric).
- i18n: `flutter_localizations` + `intl` + gen-l10n (ARB files here). Locale switch must rebuild the whole app instantly without losing state.
- Charts: `fl_chart`. Notifications: `flutter_local_notifications` + `timezone` (Asia/Dhaka). Biometrics: `local_auth`. Files: `file_picker`, `path_provider`, `share_plus`, a PDF viewer (e.g. `pdfx`). IDs: `uuid`.
- Font: bundle **Hind Siliguri** 300–700 TTFs under `assets/fonts/` as family `HindSiliguri` (used for both scripts). Never rely on network fonts.

Suggested structure (feature-first):
```
lib/
  app.dart, router.dart, main.dart
  core/  theme/ format/ db/ (drift tables, DAOs) prefs/ notifications/ widgets/ (DL components)
  features/ onboarding/ home/ finance/ salary/ savings/ shop_credit/ work/ calendar/
            reminders/ notes/ health/ goals/ documents/ reports/ settings/
  l10n/
```

## Non-negotiable design rules

1. Use only `DLColors` / `DLText` / `DLSpace` / `DLRadius` / `DLShadows`. Read colours via `context.dl`. Both themes must be complete — dark is a designed theme (navy-black ground, stepped surfaces), not an inversion. Check every screen in both.
2. One navy hero per screen (the `brand` balance card or the nav bar). Cards are `surface` on `background`; sheets/dialogs `surfaceRaised`; tracks/wells `surfaceSunken`. No gradients, no left-border accent cards, no emoji.
3. Bottom nav: navy (`brand`), 5 items (হোম/Home, হিসাব/Finance, ক্যালেন্ডার/Calendar, কাজ/Work, আরও/More), active item = `brandHover` pill + `onBrandAccent` icon. Shown only on those 5 roots.
4. Blue *words* use `accentText`, never `accent`. Income amounts `success-text` with `+`, expenses `danger-text` with `−` (U+2212). Expense icons in lists stay neutral.
5. Type never below 12px; Bengali line height ≥ 1.33. Amounts use `amount*` styles (tabular figures).
6. Touch targets ≥ 48dp; buttons 52 (lg) / 44 (md) / 36 (sm); FAB 56; inputs 52 with `borderStrong` border, focus = 2px `accent`, error = 2px `danger` + message below with an icon.
7. Icons: Lucide-style outline, 1.75 stroke (use `lucide_icons` or equivalent). Icon-only buttons need a localized tooltip/semantics label.
8. Motion: 150 ms colour/press, 300 ms progress, sheets slide up, dialogs fade+scale from 96 %. Respect reduced motion.
9. Status bar and keyboard are real system UI — never draw fake ones. Use `SafeArea` and keyboard-aware scrolling on every form.

## Localization rules

- First launch: Bengali + Light. Onboarding: language → display name → theme.
- **App language** and **digit style** are separate settings. Changing language also sets digits to match (bn→Bengali digits, en→English digits); the user can then override digits in Settings. Switching never resets data.
- Bengali digits use lakh grouping: `৳১,২৫,০০০`; English digits use thousands grouping: `৳125,000`. Currency sign directly before the number.
- Times: bn `সকাল ৯:৩০`, `দুপুর ১:০০`, `বিকাল ৫:০০`, `সন্ধ্যা ৭:০০`, `রাত ৯:০০` (day-part boundaries: 4–11 সকাল, 12–14 দুপুর, 15–17 বিকাল, 18–19 সন্ধ্যা, else রাত); en `9:30 AM`.
- Dates: long `৬ নভেম্বর, শুক্রবার` / `Friday, 6 November`; medium `৬ নভে ২০২৬` / `6 Nov 2026`; numeric `০৬/১১/২০২৬`. Relative: আজ/গতকাল/আগামীকাল.
- Optional Bangla calendar line (setting, on by default): `২১ কার্তিক ১৪৩৩` for 2026-11-06. Algorithm in `dl_format.dart` (`BanglaDate`).
- Week starts **Saturday** everywhere (calendar grid, week strips, weekly stats). Timezone Asia/Dhaka. Currency BDT only.
- User-entered text is stored as typed and not translated. Seed data has `[bn, en]` pairs.
- Voice: polite আপনি, actions end in করুন (সংরক্ষণ করুন), errors say what to do. Copy is already written — use the ARB keys, don't rewrite.

## Data model (drift tables)

Mirror `data/sample_data.json`. Amounts are whole taka (int). Dates `DateTime` (date-only where noted).
- **Transaction**: id, type (income|expense), title, categoryId, amount, date, time, paymentMethod (cash|bkash|nagad|bank|card), description, note, allocationId?, shopId? (set when it's a shop-credit payment).
- **Category**: id, type, name, isDefault, icon. Defaults — income: salary, bonus, freelance, extra (additional work), business, other; expense: food, transport, rent, shopping, family, personal, medical, ent (entertainment), mobile (mobile & internet), other; plus system category `shop` (shop credit payment, not user-selectable).
- **SalaryRecord**: id, salaryMonth (yyyy-MM), paidDate, amount, method, note. **SalarySettings**: monthlyAmount, nextExpectedDate.
- **AllocationCategory**: id, name, amount (budget), linkedExpenseCategoryId? (`savings` links to savings deposits).
- **SavingsEntry**: id, type (in|out), amount, date, note, goalId?. **SavingsGoal**: id, name, target, targetDate. Goal saved = sum of its entries.
- **Shop**: id, name. **ShopEntry**: id, shopId, type (buy|pay), amount, date, item.
- **Project**: id, name, description. **Task**: id, title, projectId, description, date, start, end, status (todo|prog|done|hold), priority (high|medium|low), note, spentMinutes. **TimerSession** (persisted so the timer survives restarts): taskId, state (idle|run|pause|stopped), accumulatedMs, startedAt.
- **Event**: id, title, category (office|meeting|personal|family|important|other), startDate, endDate, startTime?, endTime? (null = all-day), location, reminderMinutes (0|10|30|60|1440), repeat (once|daily|weekly|monthly), description.
- **Reminder**: id, title, description, date, time, priority, category (personal|office|bill|health|other), repeat (once|daily|weekly|monthly|custom), customDays (0=Sat…6=Fri), enabled, done.
- **Note**: id, title, body, category (personal|office|ideas|important|other), pinned, archived, createdAt, updatedAt.
- **WaterEntry**: id, time, ml (+ daily target pref, default 3000). **Meal**: id, type (breakfast|lunch|snack|dinner), date, time, description, note.
- **Habit**: id, name, icon, reminderTime; **HabitCheck**: habitId, date.
- **Goal**: id, title, category (financial|career|learning|health|personal), description, targetDate, achieved; **Milestone**: id, goalId, text, done.
- **Document**: id, title, category (personal|office|edu|fin|other), kind (pdf|img), description, uploadedAt, filePath, sizeBytes, pages.

## Business rules (match the prototype exactly)

- **Available / remaining balance** for a month = income − expenses − net savings deposits in that month. Savings deposits are not expenses.
- **Shop credit**: a credit purchase increases the shop balance and is **not** an expense. A payment reduces the balance **and** creates an expense transaction (category `shop`, linked `shopId`). Payment > balance is a validation error. Example: previous ৳1,200 + purchase ৳300 − payment ৳500 = ৳1,000 due. Shop detail shows previous balance (before this month), new purchases, paid, now due, plus a running balance per entry; payment that clears the balance is labelled “সম্পূর্ণ পরিশোধ / Full settlement”, otherwise “আংশিক পরিশোধ / Partial payment”. “Settle in full” asks for confirmation.
- **Salary**: adding a salary record also adds an income transaction (category salary) and updates the monthly salary amount. History shows raises versus the previous record.
- **Allocation is budget planning, not spending**. Show salary, allocated, unallocated (red + warning when over-allocated, success note when exactly allocated), % per row, and per row: spent this month (from real expenses in the linked category; for Savings, this month's deposits), left / over-budget with a bar (amber > 85 %, red > 100 %). Rows are editable in place; unlimited rows.
- **Timer**: start → run; pause keeps accumulated time; resume; stop logs `max(1, round(minutes))` to the task's spentMinutes and shows “X logged”; starting the timer on a not-started task moves it to in-progress; “Mark complete” sets done. The task can't change while running/paused.
- **Recurring events**: daily = every day from start; weekly = same weekday; monthly = same day-of-month; once = start..end range. Calendar dots show up to 3 categories per day.
- **Reminders**: tabs Today (includes overdue, flagged), Upcoming, Completed, each with a count. Snooze adds 10 minutes. Toggle enabled per reminder. Schedule real notifications for enabled reminders, event reminders, water (every 2 h 8 AM–10 PM) and meals when their settings are on.
- **Habits**: streak = consecutive checked days ending today (or yesterday if today isn't checked); best streak; month completion = checked days / days elapsed. Past days can be toggled in the habit calendar; future days can't.
- **Goals**: progress = done milestones / total (100 % when achieved). Mark achieved / reopen.
- **Water**: quick add 150/250/500 ml + custom (50–2000 ml); target 500–6000 ml.
- **Hide amounts** (privacy) masks every amount as `৳ ••••`. **App lock** requires a PIN first (4 digits, store a hash); biometric unlock via `local_auth`.
- **Dashboard customization**: show/hide and reorder sections (summary, chart, today, shop, quick, recent); persist.
- Validation messages, success toasts, confirmation dialogs and empty states all exist in the ARB files — every form validates before saving, every delete confirms, every list has an empty state with an action.

## Screens (prototype `start` id → screenshot prefix)

Onboarding: welcome (01), onboarding steps (02–04).
Home `home` (05) + month sheet (06) + customize sheet (07); notifications `notifs` (08).
Finance `finance` (10) with month nav, hero, savings/credit cards, tools grid, All/Income/Expense tabs, search, filter sheet (11: date range, category, payment method; active filters as removable chips), add sheet (12); transaction detail (13), delete dialog (14); add/edit income (15) and expense (16 shows validation); categories (17).
Salary `salary` (18), add salary (19), allocation `allocation` (20). Savings `savings` (21–23). Shop credit `shops` (24), shop detail (25), payment sheet (26).
Work `work` (30), add/edit task (31), task detail (32), timer `timer` (33–35), work history `workHist` (36: daily/weekly/monthly, search, project filter, timeline), projects (37), project detail (38).
Calendar `calendar`: month (40), week (41), day timeline (42), agenda (43); add/edit event (44); event detail (45).
More `more` (50) → Reminders `reminders` (51–54), Notebook `notes` (55–57), Health `health` water/food/habits (58–62), Goals `goals` (63–65), Documents `docs` (66–68), Reports `reports` financial/productivity/lifestyle with month/year filters and a loading skeleton (70–73), Settings `settings` (80–81).
Empty states (90–96): Settings → Data management → “Show sample data” off.

## Acceptance journeys (write integration tests for each)

1. First launch: Welcome → language → name (required) → theme → Dashboard greets by name.
2. Dashboard → Finance → Add Income → Save → appears at top of the list, Income tab active, toast shown.
3. Finance → Add Expense → details (budget category) → Save → Dashboard totals and recent list update.
4. Finance → Salary → Add Salary → income recorded → Allocate salary → edit amounts, see over-allocation warning.
5. Finance → Shop Credit → shop → Add purchase → Partial payment → balance, history and expenses update; overpay blocked.
6. Work → Add task → Start timer → Pause → Resume → Stop (time logged) → Mark complete.
7. Calendar → select a date → Add event → lands on Event details; dot appears on that date.
8. More → Reminders → Add (custom repeat days) → Save → listed under the right tab.
9. More → Notebook → Create → (opens detail) → Edit → Pin.
10. Settings → English → visit every tab → no Bengali UI text remains (user data excepted) → back to Bengali.
11. Theme Light → Dark → System; every screen, sheet, dialog, chart and input follows.
12. English + Dark together, then Bengali + Light — everything returns correctly.

Also: golden tests for the key screens in both themes × both languages at 393×852, and unit tests for `DLFormat` (`৳১,২৫,০০০`, `৳125,000`, `সকাল ৯:৩০`, `২১ কার্তিক ১৪৩৩` for 2026-11-06, Saturday-first headers).

## Build order

1. Project setup, fonts, theme, l10n, `DLFormat` + tests, router shell with bottom nav, settings/preferences (language, digits, theme) — prove instant switching first.
2. Shared DL widgets: AppBar, Card, ListRow, Chip, SegmentedTabs, TextField, Select, Switch, BalanceHero, ProgressBar/Ring, EmptyState, BottomSheet, ConfirmDialog, Toast, FAB, Tag/Badge, BarChart, Donut.
3. Drift schema + DAOs + debug seeder from `data/sample_data.json`.
4. Finance (dashboard, transactions, categories) → Salary/Allocation → Savings → Shop credit.
5. Home dashboard (summary, chart, today's overview, quick actions, customization).
6. Work + timer → Calendar → Reminders + notifications → Notes → Health → Goals → Documents → Reports.
7. Privacy (PIN, lock, biometric, hide amounts), backup/restore/export (JSON + CSV via share sheet), onboarding.
8. Run all journeys and goldens; compare against `prototype/index.html` and the screenshots; fix overflow on small phones (360 dp) and Bengali glyph clipping.

The prototype uses an in-memory fixed date (2026-11-06) and simulates file picking, PIN/biometric, backup and notifications — the app must implement them for real against the device clock.
