আমার জীবন (Amar Jibon) is a premium, Bengali-first Android app for personal life management and money: balance, income and expense, savings goals, calendar, tasks, reminders and notes in one calm place. This system governs all ~35 screens. Build every screen from these tokens and components; when something is missing, compose it from existing tokens rather than inventing new values.

## Principles

- **Premium and minimal.** White `surface` cards on a cool `background` (#F7F8FC). One navy hero per screen (BalanceCard or NavBar); everything else stays light. No gradients, no glass, no decorative illustration.
- **Deep navy navigation, soft blue accents.** `brand` (#172554) is the identity and owns navigation; `accent` (#3B82F6) marks what is active, in progress or tappable.
- **Rounded, soft, consistent.** Cards `radius-lg`, hero and overlays `radius-xl`, controls `radius-md`, chips and bars `radius-pill`.
- **Bengali reads first.** Hind Siliguri everywhere, generous line heights, no text under 12px, Bengali digits for every number a person reads.
- **Numbers are the product.** Every amount uses an `amount-*` style: tabular, bold, ৳-prefixed, lakh-grouped.
- **Accessible in both themes.** Every text/ground pair named in a token's usage note is checked at 4.5:1 or better in light and dark (one documented exception below). Meaning is never carried by colour alone.

## Content fundamentals

- **Language.** Bengali (bn-BD) for all UI copy. English only for proper nouns that people write in English (brand names of banks, app names).
- **Voice.** Warm, plain and respectful, like a well-organised elder sibling. Address the user as **আপনি**, never তুমি/তুই. Speak about the app as **আমরা** sparingly ("আমরা মাস শেষে হিসাব গুছিয়ে দেব").
- **Actions** are polite imperatives ending in **করুন**: সংরক্ষণ করুন, পরিশোধ করুন, লেনদেন যোগ করুন. Destructive: মুছে ফেলুন. Dismiss: বাতিল.
- **Titles** are short nouns: আমার হিসাব, সাম্প্রতিক লেনদেন, আজকের কাজ. No trailing punctuation.
- **Confirmations** are questions naming the object: "লেনদেনটি মুছে ফেলবেন?" with the amount in the body.
- **Errors** say what to do: "সঠিক ১১ সংখ্যার নম্বর লিখুন", not "ভুল নম্বর".
- **Empty states** say what is missing, then what happens next: "এখনো কোনো লেনদেন নেই" / "প্রথম আয় বা খরচ যোগ করুন, আমরা মাস শেষে হিসাব গুছিয়ে দেব।"
- **Numbers.** Bengali digits (০১২৩৪৫৬৭৮৯) with Bangladeshi lakh grouping: ৳১,২৫,৪৮০ (not ৳125,480). Currency sign ৳ directly before the number, no space. Income `+৳৮৫,০০০`, expense `−৳২,৩৪০` (true minus sign U+2212). Percentages `৬৫%`. Use `AmarJibon.formatTaka()` / `toBnDigits()`; never format by hand.
- **Dates and times.** `৬ নভেম্বর, শুক্রবার`; short month in tight spaces (নভে). Times carry the day-part: সকাল ৯:৩০, দুপুর ১:০০, বিকাল ৫টা, সন্ধ্যা ৭:০০, রাত ৯:০০. Relative: এইমাত্র, ২ ঘণ্টা আগে, আজ, গতকাল, আগামীকাল. Week starts শনিবার.
- **Emoji.** None in UI chrome. Icons from the Icons group only.

## Colour

- Page ground is always `background`; cards, lists and inputs sit on `surface`; dialogs, sheets and menus on `surface-raised`; tracks, wells and neutral chips on `surface-sunken`.
- Text: `text-primary` for content and amounts; `text-secondary` for metadata. In light, `text-secondary` (#64748B, the specified value) measures 4.8:1 on `surface` but 4.48:1 on `background`, so on the page ground use it only at 15px and up, or move the text onto a card.
- `brand` + `on-brand` / `brand-muted` / `on-brand-accent` belong to the NavBar and BalanceCard. Raised fills on navy use `brand-hover`.
- `action-primary` is the primary button: navy in light, bright blue (#60A5FA) with dark label in dark so it stands off the dark ground.
- `accent` is for fills and marks (FAB, progress, focus, active underline). Blue words use `accent-text`, because `accent` on white is 3.7:1.
- Status pairs: a solid (`success`, `warning`, `danger`) for marks and fills, a `*-text` for words, a `*-soft` tint behind the words. `warning` is never text on a light ground.
- Money: `income` (= `success-text`) and `expense` (= `danger-text`) colour amount text only, always with a + / − sign; expense icons stay neutral so spending lists are calm.
- Categories: `cat-event` blue, `cat-task` teal, `cat-reminder` amber, `cat-bill` red; each always appears with a label or legend.
- Charts use `chart-1`…`chart-4` and `chart-grid`, never the income/expense pair.
- Dividers (`divider`) separate rows; control boundaries that must be seen use `border-strong` (≥3:1).
- **Dark theme** is a full theme, not an inversion: navy-black `background` (#0B1120), stepped surfaces (#131B2E → #1A2338), lightened accents and status colours, dark labels on bright fills. Test every screen in both.

## Typography

- One family: **Hind Siliguri** (`--font-bangla`, Google Fonts, weights 300–700; ship the TTFs in `res/font` on Android), with Noto Sans Bengali as fallback. Its Latin is used for the rare English word.
- Hierarchy: `text-display` (32/44 bold, once per screen at most) → `text-h1` screen titles (26/36) → `text-h2` sections, dialogs, sheets (22/32) → `text-h3` card titles (18/28) → `text-body-lg` (17/28) for inputs and task titles → `text-body` (15/24) default → `text-body-sm` (13/20) metadata → `text-caption` (12/18, weight 500) labels.
- Interface: `text-button` (15/20 semibold) for every button; `text-label` (14/20 medium) for field labels, tabs, chips.
- Numerals: `amount-hero` (36/44 bold, BalanceCard only), `amount-lg` (24/32) card totals and amount inputs, `amount-md` (16/24 semibold) list amounts, `amount-sm` (13/20 semibold) legends, percents, counts. All set `font-variant-numeric: tabular-nums` so columns of money align.
- Line heights are 1.33–1.65× size; Bengali vowel signs (ি ী ু ূ ৃ) and conjuncts need the room. Never set Bengali below 12px or tighter than 1.3.
- Sentence case for any English; no all-caps anywhere.

## Spacing and layout

- 4px base, nine steps: `space-1` 4 · `space-2` 8 · `space-3` 12 · `space-4` 16 · `space-5` 20 · `space-6` 24 · `space-8` 32 · `space-10` 40 · `space-12` 48.
- Screen gutter `space-4`. Card padding `space-4` (BalanceCard `space-5`). Gap between cards `space-3`; between sections `space-6`; section title to its content `space-3`.
- Touch targets ≥ `size-touch` (48px). Buttons `size-control-lg` 52 / `md` 44 / `sm` 36; FAB `size-fab` 56.
- Screen skeleton: app bar (64px, `text-h1` title, IconButtons) → optional SearchBar or Tabs → content on `background` → NavBar on top-level screens, with `space-12` bottom clearance so the FAB never covers the last row.

## Corner radius

`radius-sm` 8 (small buttons, menu items, small tags) · `radius-md` 12 (buttons, inputs, icon chips, calendar cells) · `radius-lg` 16 (cards, list groups, FAB) · `radius-xl` 20 (BalanceCard, dialogs, sheet and nav top corners) · `radius-pill` 999 (search, chips, badges, progress). An element inside a card uses one step smaller than the card.

## Elevation

Shadows are soft, low and navy-tinted; most separation comes from `surface` on `background`.
- `shadow-card` resting cards, lists, search bar, active segment.
- `shadow-fab` the FAB only.
- `shadow-dropdown` menus and popovers.
- `shadow-dialog` centred dialogs over `scrim`.
- `shadow-sheet` bottom sheets (cast upward).
Never stack two shadows on one element or put shadows on list rows. In dark, shadows deepen but surfaces separate by lightness.

## States and interaction

- Focus: 2px `focus-ring` outline, 2px offset, on every interactive element (≥3:1 on every surface, including navy).
- Pressed/hover: neutral rows take `surface-sunken`; tinted controls take `accent-soft`; primary takes `action-primary-hover`.
- Disabled: `surface-sunken` fill, `text-disabled` label, no shadow.
- Selected: `accent-soft` fill + `accent-text` + a check icon (chips, menu items); calendar day fills `action-primary`.
- Motion: 150ms ease for colour and transform, 300ms for progress; sheets slide up, dialogs fade and scale from 96%. Respect reduced-motion.

## Iconography

- The Amar Jibon line set (Icons asset group, and `AmarJibon.Icon` in code): 24×24 grid, 1.75px round-capped strokes, no fills. Import the SVGs as Android vector drawables and tint them by context.
- Sizes: 24 nav and app bar, 20 inside fields and buttons, 16 in meta rows, 22 inside 44px category chips, 32 in empty states.
- Icons inherit their context colour: `text-primary`, `text-secondary` in meta, the tone's `*-text` inside soft chips, `brand-muted` / `on-brand-accent` on navy.
- The asset SVGs are drawn in a single ink, `text-primary` #172033; recolour them with a tint, never by editing paths.
- Icon-only buttons always carry a Bengali `label`.

## Logo

- The mark (Logos group) is a navy rounded square holding a ¾ blue progress ring and a rising line: life in progress, money growing. Use `amar-jibon-mark.svg` for the launcher and splash, `android-adaptive-foreground.svg` over a `brand` background layer for the adaptive icon, `amar-jibon-mark-mono.svg` (single ink `brand`) on light grounds and `amar-jibon-mark-reversed.svg` (white) on `brand`.
- The wordmark is the name set in Hind Siliguri Bold, `text-primary` (or `on-brand` on navy), beside the mark at the mark's height. Don't outline, stretch or recolour the mark.

## Components

Twenty-three components cover the app; each has a live preview and guidelines. Actions: Button, IconButton. Inputs: TextField, Select, SearchBar. Finance: BalanceCard, CashflowCard, SavingsCard, ChartCard, TransactionItem. Planner: CalendarCell, EventCard, TaskCard, ReminderCard, NoteCard. Overlays: Dialog, BottomSheet. Navigation: NavBar, Tabs. Status: Tag, Badge, EmptyState, Progress. Plus Icon and the `formatTaka` / `formatNumber` / `toBnDigits` helpers.

For web prototypes, load the bundle and use `window.AmarJibon.<Component>`; for Android (Jetpack Compose), map each token to a `MaterialTheme` colour / `TextStyle` / `Dp` of the same name and each component to a composable with the same props.
