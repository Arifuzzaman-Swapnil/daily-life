// Home dashboard layout (prototype `dash`): which sections show and in what
// order. Persisted in shared_preferences as section names, so it survives
// restarts and reads cleanly in backups.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings.dart';

/// Home's sections, in their default order.
enum DashSection { summary, chart, today, shop, quick, recent }

@immutable
class DashboardLayout {
  const DashboardLayout({this.order = DashSection.values, this.hidden = const {}});

  static const defaults = DashboardLayout();

  /// Every section, each once.
  final List<DashSection> order;
  final Set<DashSection> hidden;

  /// The sections Home shows, in order.
  List<DashSection> get visible => [
        for (final s in order)
          if (!hidden.contains(s)) s,
      ];

  bool isShown(DashSection s) => !hidden.contains(s);

  /// Reads stored names. Unknown names and repeats are dropped; sections
  /// missing from [order] are added at the end in default order.
  factory DashboardLayout.fromNames(List<String>? order, List<String>? hidden) {
    final byName = DashSection.values.asNameMap();
    final list = <DashSection>[];
    for (final name in order ?? const <String>[]) {
      final s = byName[name];
      if (s != null && !list.contains(s)) list.add(s);
    }
    for (final s in DashSection.values) {
      if (!list.contains(s)) list.add(s);
    }
    return DashboardLayout(
      order: List.unmodifiable(list),
      hidden: Set.unmodifiable({
        for (final name in hidden ?? const <String>[]) ?byName[name],
      }),
    );
  }

  @override
  bool operator ==(Object other) => other is DashboardLayout && listEquals(other.order, order) && setEquals(other.hidden, hidden);

  @override
  int get hashCode => Object.hash(Object.hashAll(order), Object.hashAllUnordered(hidden));
}

final dashboardLayoutProvider = NotifierProvider<DashboardLayoutController, DashboardLayout>(DashboardLayoutController.new);

/// Show/hide and reorder (the customize sheet). Every change is saved at once.
class DashboardLayoutController extends Notifier<DashboardLayout> {
  @override
  DashboardLayout build() {
    final p = ref.watch(sharedPrefsProvider);
    return DashboardLayout.fromNames(p.getStringList(PrefKeys.dashOrder), p.getStringList(PrefKeys.dashHidden));
  }

  Future<void> setShown(DashSection section, bool shown) {
    final hidden = {...state.hidden};
    if (shown) {
      hidden.remove(section);
    } else {
      hidden.add(section);
    }
    return _save(DashboardLayout(order: state.order, hidden: Set.unmodifiable(hidden)));
  }

  /// Swaps [section] with its neighbour [delta] places away (−1 up, +1 down);
  /// nothing happens past either end.
  Future<void> move(DashSection section, int delta) async {
    final order = [...state.order];
    final i = order.indexOf(section);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= order.length) return;
    order[i] = order[j];
    order[j] = section;
    await _save(DashboardLayout(order: List.unmodifiable(order), hidden: state.hidden));
  }

  Future<void> _save(DashboardLayout layout) async {
    state = layout;
    final p = ref.read(sharedPrefsProvider);
    await p.setStringList(PrefKeys.dashOrder, [for (final s in layout.order) s.name]);
    await p.setStringList(PrefKeys.dashHidden, [for (final s in DashSection.values) if (layout.hidden.contains(s)) s.name]);
  }
}
