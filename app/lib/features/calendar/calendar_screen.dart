import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/format/dl_format.dart';
import '../../core/format/dl_format_more.dart';
import '../../core/format/format_provider.dart';
import '../../core/prefs/app_settings.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import 'calendar_providers.dart';
import 'calendar_ui.dart';
import 'event_rules.dart';

/// The Calendar tab (prototype `calendar`, screenshots 40–43): month, week,
/// day and agenda views over the same selected day. Weeks start on Saturday.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cal = ref.watch(calendarProvider);
    final ctl = ref.read(calendarProvider.notifier);
    final events = ref.watch(eventsProvider).value;
    final bottom = MediaQuery.paddingOf(context).bottom;
    void add() => context.push(Routes.newEvent);

    final all = events ?? const <Event>[];
    final body = switch (cal.view) {
      CalView.month => [_MonthView(events: all), _DayList(events: events, onAdd: add)],
      CalView.week => [_WeekView(events: all), _DayList(events: events, onAdd: add)],
      CalView.day => [_DayView(events: all)],
      CalView.agenda => [_AgendaView(events: events, onAdd: add)],
    };

    return Stack(
      children: [
        Column(
          children: [
            DLAppBar.root(
              title: t.calendar,
              actions: [DLButton(label: t.today, size: DLButtonSize.sm, variant: DLButtonVariant.tonal, onPressed: ctl.today)],
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, bottom + DLSize.fab + DLSpace.s8),
                children: [
                  DLSegmentedTabs<CalView>(
                    value: cal.view,
                    options: [(CalView.month, t.month), (CalView.week, t.week), (CalView.day, t.day), (CalView.agenda, t.agenda)],
                    onChanged: ctl.setView,
                  ),
                  ...body,
                ],
              ),
            ),
          ],
        ),
        Positioned(right: DLSpace.s4, bottom: bottom + DLSpace.s4, child: DLFab(tooltip: t.addEvent, onPressed: add)),
      ],
    );
  }
}

/// "আজ · ৬ নভেম্বর, শুক্রবার" for today, else the long date.
String _selectedLabel(AppLocalizations t, DLFormat f, DateTime day, DateTime today) =>
    dayKey(day) == dayKey(today) ? '${t.today} · ${f.dateLong(day)}' : f.dateLong(day);

/// Month grid (screen 40): 6 weeks at most, Saturday first, dots for up to 3
/// categories a day, and the category legend.
class _MonthView extends ConsumerWidget {
  const _MonthView({required this.events});

  final List<Event> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final showBangla = ref.watch(settingsProvider.select((s) => s.banglaDate));
    final today = dateOnly(ref.watch(clockProvider)());
    final cal = ref.watch(calendarProvider);
    final ctl = ref.read(calendarProvider.notifier);
    final month = cal.month;
    final first = weekStartOf(month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = (month.weekday % 7 + 1) % 7; // days before the 1st, back to Saturday
    final rows = ((lead + daysInMonth) / 7).ceil();

    return Padding(
      padding: const EdgeInsets.only(top: DLSpace.s3),
      child: DLCard(
        padding: const EdgeInsets.all(DLSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PagerHeader(
              prevTooltip: t.prevMonth,
              nextTooltip: t.nextMonth,
              onPrev: () => ctl.shiftMonth(-1),
              onNext: () => ctl.shiftMonth(1),
              title: f.monthYear(month),
              subtitle: showBangla ? f.banglaMonthSpan(month) : null,
            ),
            const SizedBox(height: DLSpace.s2),
            Row(
              children: [
                for (final w in f.weekHeaders())
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: DLSpace.s1),
                      child: Text(w, textAlign: TextAlign.center, maxLines: 1, style: DLText.textCaption.copyWith(color: c.textSecondary)),
                    ),
                  ),
              ],
            ),
            for (var r = 0; r < rows; r++) ...[
              if (r > 0) const SizedBox(height: DLSpace.s1),
              Row(
                children: [
                  for (var i = 0; i < 7; i++) ...[
                    if (i > 0) const SizedBox(width: DLSpace.s1),
                    Expanded(
                      child: Builder(builder: (context) {
                        final d = DateTime(first.year, first.month, first.day + r * 7 + i);
                        return _DayCell(
                          day: d,
                          events: events,
                          selected: dayKey(d) == dayKey(cal.selected),
                          today: dayKey(d) == dayKey(today),
                          outside: d.month != month.month,
                          onTap: () => ctl.select(d),
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: DLSpace.s2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DLSpace.s1),
              child: Wrap(
                spacing: 10,
                runSpacing: DLSpace.s1,
                children: [
                  for (final cat in EventCategory.values)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DLDot(color: eventColor(c, cat)),
                        const SizedBox(width: 6),
                        Text(eventCategoryLabel(t, cat), style: DLText.textCaption.copyWith(color: c.textSecondary)),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The week strip (screen 41): the selected day's Saturday-to-Friday week.
class _WeekView extends ConsumerWidget {
  const _WeekView({required this.events});

  final List<Event> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final f = ref.watch(formatProvider);
    final today = dateOnly(ref.watch(clockProvider)());
    final cal = ref.watch(calendarProvider);
    final ctl = ref.read(calendarProvider.notifier);
    final start = weekStartOf(cal.selected);
    final end = DateTime(start.year, start.month, start.day + 6);

    return Padding(
      padding: const EdgeInsets.only(top: DLSpace.s3),
      child: DLCard(
        padding: const EdgeInsets.all(DLSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PagerHeader(
              prevTooltip: t.prevMonth,
              nextTooltip: t.nextMonth,
              onPrev: () => ctl.shiftDays(-7),
              onNext: () => ctl.shiftDays(7),
              title: '${f.dateShort(start)} – ${f.dateMedium(end)}',
              small: true,
            ),
            const SizedBox(height: DLSpace.s1),
            Row(
              children: [
                for (var i = 0; i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: DLSpace.s1),
                  Expanded(
                    child: Builder(builder: (context) {
                      final d = DateTime(start.year, start.month, start.day + i);
                      return _DayCell(
                        day: d,
                        events: events,
                        selected: dayKey(d) == dayKey(cal.selected),
                        today: dayKey(d) == dayKey(today),
                        weekday: f.weekdayShort(d),
                        onTap: () => ctl.select(d),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ‹ title / subtitle ›, the month and week pagers.
class _PagerHeader extends StatelessWidget {
  const _PagerHeader({
    required this.prevTooltip,
    required this.nextTooltip,
    required this.onPrev,
    required this.onNext,
    required this.title,
    this.subtitle,
    this.small = false,
  });

  final String prevTooltip;
  final String nextTooltip;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final String title;
  final String? subtitle;

  /// A label-size title (the week range) instead of h3.
  final bool small;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    return Row(
      children: [
        DLIconButton(icon: DLIcons.chevronLeft, tooltip: prevTooltip, onPressed: onPrev),
        Expanded(
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: (small ? DLText.textLabel : DLText.textH3).copyWith(color: c.textPrimary),
              ),
              if (subtitle != null)
                Text(subtitle!, textAlign: TextAlign.center, style: DLText.textCaption.copyWith(color: c.textSecondary)),
            ],
          ),
        ),
        DLIconButton(icon: DLIcons.chevronRight, tooltip: nextTooltip, onPressed: onNext),
      ],
    );
  }
}

/// A day in the month grid or week strip (prototype `.cal button`): the
/// selected day is filled `actionPrimary`, today `accentSoft`, days outside the
/// month are dimmed; up to 3 category dots below the number.
class _DayCell extends ConsumerWidget {
  const _DayCell({
    required this.day,
    required this.events,
    required this.selected,
    required this.today,
    required this.onTap,
    this.outside = false,
    this.weekday,
  });

  final DateTime day;
  final List<Event> events;
  final bool selected;
  final bool today;
  final bool outside;

  /// The weekday above the number (week strip).
  final String? weekday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final dots = dayDots(c, events, day);
    final count = eventsOn(events, day).length;
    final fg = selected
        ? c.onActionPrimary
        : today
            ? c.accentText
            : outside
                ? c.textDisabled
                : c.textPrimary;
    final bg = selected
        ? c.actionPrimary
        : today
            ? c.accentSoft
            : c.accentSoft.withValues(alpha: 0);
    const shape = BorderRadius.all(Radius.circular(DLRadius.md));
    return DLPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: count > 0 ? '${f.dateLong(day)}, ${f.count(count)} ${t.ovEvents}' : f.dateLong(day),
      excludeSemantics: true,
      borderRadius: shape,
      decoration: BoxDecoration(color: bg, borderRadius: shape),
      child: SizedBox(
        height: weekday == null ? DLSize.touch : 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (weekday != null) Text(weekday!, maxLines: 1, style: DLText.textCaption.copyWith(color: fg)),
            Text(f.count(day.day), maxLines: 1, style: DLText.amountSm.copyWith(fontSize: 14, height: 20 / 14, color: fg)),
            const SizedBox(height: 2),
            SizedBox(
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final (i, col) in dots.indexed) ...[
                    if (i > 0) const SizedBox(width: 2),
                    DLDot(color: col, size: 5),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The selected day's events under the month and week views.
class _DayList extends ConsumerWidget {
  const _DayList({required this.events, required this.onAdd});

  final List<Event>? events;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final showBangla = ref.watch(settingsProvider.select((s) => s.banglaDate));
    final today = dateOnly(ref.watch(clockProvider)());
    final selected = ref.watch(calendarProvider.select((s) => s.selected));
    final list = eventsOn(events ?? const [], selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: DLSpace.s6, bottom: DLSpace.s3),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(_selectedLabel(t, f, selected, today), style: DLText.textH3.copyWith(color: c.textPrimary)),
                    ),
                    if (showBangla) Text(f.bangla(selected), style: DLText.textCaption.copyWith(color: c.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: DLSpace.s2),
              DLLinkButton(label: t.add, onPressed: onAdd, chevron: false),
            ],
          ),
        ),
        if (events != null && list.isEmpty)
          DLEmptyState(
            inCard: true,
            icon: DLIcons.calendar,
            title: t.noEvents,
            body: t.noEventsSub,
            actionLabel: t.addEvent,
            onAction: onAdd,
          ),
        for (final (i, e) in list.indexed) ...[
          if (i > 0) const SizedBox(height: DLSpace.s2),
          _EventCard(event: e),
        ],
      ],
    );
  }
}

/// An event in the day list: start / end, title, place, category tag.
class _EventCard extends ConsumerWidget {
  const _EventCard({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final e = event;
    final start = e.startTime;
    final end = e.endTime;
    final allDay = start == null || start.isEmpty;
    Widget fit(Text text) => FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: text);

    return DLCard(
      onTap: () => context.push(Routes.event(e.id)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                fit(Text(allDay ? t.allDay : f.time(start!), maxLines: 1, style: DLText.amountSm.copyWith(color: c.textPrimary))),
                if (!allDay && end != null && end.isNotEmpty)
                  fit(Text(f.time(end), maxLines: 1, style: DLText.textCaption.copyWith(color: c.textSecondary))),
              ],
            ),
          ),
          const SizedBox(width: DLSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title, style: DLText.textBody.copyWith(fontWeight: FontWeight.w600, color: c.textPrimary)),
                if (e.location.isNotEmpty) ...[
                  const SizedBox(height: DLSpace.s1),
                  Row(
                    children: [
                      Icon(DLIcons.mapPin, size: 16, color: c.textSecondary),
                      const SizedBox(width: DLSpace.s1),
                      Expanded(
                        child: Text(e.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: DLText.textBodySm.copyWith(color: c.textSecondary)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: DLSpace.s1),
                DLTag(label: eventCategoryLabel(t, e.category), tone: eventTone(e.category)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The day timeline (screen 42): all-day events, then one row per hour from
/// 7 AM to 11 PM (earlier hours appear when something starts in them).
class _DayView extends ConsumerWidget {
  const _DayView({required this.events});

  final List<Event> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final showBangla = ref.watch(settingsProvider.select((s) => s.banglaDate));
    final today = dateOnly(ref.watch(clockProvider)());
    final selected = ref.watch(calendarProvider.select((s) => s.selected));
    final ctl = ref.read(calendarProvider.notifier);
    final list = eventsOn(events, selected);
    final allDay = [for (final e in list) if (e.startTime == null || e.startTime!.isEmpty) e];
    int? hourOf(Event e) => (e.startTime == null || e.startTime!.isEmpty) ? null : int.tryParse(e.startTime!.split(':').first);
    final earliest = list.map(hourOf).whereType<int>().fold<int>(7, (a, h) => h < a ? h : a);

    Widget row(String label, List<Event> items) => Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.divider))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 64,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(label, style: DLText.textCaption.copyWith(color: c.textSecondary)),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, e) in items.indexed) ...[
                      if (i > 0) const SizedBox(height: DLSpace.s1),
                      DLCard(
                        onTap: () => context.push(Routes.event(e.id)),
                        padding: const EdgeInsets.symmetric(horizontal: DLSpace.s3, vertical: DLSpace.s2),
                        child: Row(
                          children: [
                            DLDot(color: eventColor(c, e.category)),
                            const SizedBox(width: DLSpace.s2),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: DLText.textLabel.copyWith(color: c.textPrimary)),
                                  Text(eventTime(t, f, e), style: DLText.textCaption.copyWith(color: c.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: DLSpace.s3),
        Row(
          children: [
            DLIconButton(icon: DLIcons.chevronLeft, tooltip: t.yesterday, onPressed: () => ctl.shiftDays(-1)),
            Expanded(
              child: Column(
                children: [
                  Text(_selectedLabel(t, f, selected, today), textAlign: TextAlign.center, style: DLText.textH3.copyWith(color: c.textPrimary)),
                  if (showBangla)
                    Text(f.bangla(selected), textAlign: TextAlign.center, style: DLText.textCaption.copyWith(color: c.textSecondary)),
                ],
              ),
            ),
            DLIconButton(icon: DLIcons.chevronRight, tooltip: t.tomorrow, onPressed: () => ctl.shiftDays(1)),
          ],
        ),
        const SizedBox(height: DLSpace.s2),
        if (allDay.isNotEmpty) row(t.allDay, allDay),
        for (var h = earliest; h <= 23; h++)
          row(f.time('${h.toString().padLeft(2, '0')}:00'), [for (final e in list) if (hourOf(e) == h) e]),
      ],
    );
  }
}

/// The next 30 days with events, grouped by day (screen 43).
class _AgendaView extends ConsumerWidget {
  const _AgendaView({required this.events, required this.onAdd});

  final List<Event>? events;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final today = dateOnly(ref.watch(clockProvider)());
    // (days from today, day, its events)
    final days = <(int, DateTime, List<Event>)>[];
    for (var i = 0; i < 30; i++) {
      final d = DateTime(today.year, today.month, today.day + i);
      final list = eventsOn(events ?? const [], d);
      if (list.isNotEmpty) days.add((i, d, list));
    }

    if (events != null && days.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: DLSpace.s3),
        child: DLEmptyState(
          inCard: true,
          icon: DLIcons.calendar,
          title: t.noEvents,
          body: t.noEventsSub,
          actionLabel: t.addEvent,
          onAction: onAdd,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (n, d, list) in days) ...[
          DLSectionHeader(
            n < 2 ? '${f.relative(d, today)} · ${f.dateLong(d)}' : f.dateLong(d),
            first: true,
          ),
          for (final (i, e) in list.indexed) ...[
            if (i > 0) const SizedBox(height: DLSpace.s2),
            DLCard(
              onTap: () => context.push(Routes.event(e.id)),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(DLRadius.md)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(f.count(d.day), style: DLText.amountSm.copyWith(fontSize: 16, height: 20 / 16, color: c.accentText)),
                        Text(f.monthShort(d), maxLines: 1, style: DLText.textCaption.copyWith(color: c.accentText)),
                      ],
                    ),
                  ),
                  const SizedBox(width: DLSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DLText.textBody.copyWith(fontWeight: FontWeight.w600, color: c.textPrimary),
                        ),
                        Text(eventTime(t, f, e), maxLines: 1, overflow: TextOverflow.ellipsis, style: DLText.textBodySm.copyWith(color: c.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: DLSpace.s3),
                  DLDot(color: eventColor(c, e.category)),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}
