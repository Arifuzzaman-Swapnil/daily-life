import 'package:dailylife/core/prefs/app_settings.dart';
import 'package:dailylife/core/prefs/dashboard_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> container([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('DashboardLayout.fromNames', () {
    test('nothing stored: every section in the prototype order', () {
      final l = DashboardLayout.fromNames(null, null);
      expect(l, DashboardLayout.defaults);
      expect(l.visible, [DashSection.summary, DashSection.chart, DashSection.today, DashSection.shop, DashSection.quick, DashSection.recent]);
    });

    test('drops unknown names and repeats; appends missing sections', () {
      final l = DashboardLayout.fromNames(['recent', 'weather', 'recent', 'chart'], ['shop', 'nope']);
      expect(l.order, [DashSection.recent, DashSection.chart, DashSection.summary, DashSection.today, DashSection.shop, DashSection.quick]);
      expect(l.hidden, {DashSection.shop});
      expect(l.visible, isNot(contains(DashSection.shop)));
    });
  });

  group('DashboardLayoutController', () {
    test('show/hide and move are saved at once', () async {
      final c = await container();
      final edit = c.read(dashboardLayoutProvider.notifier);
      await edit.setShown(DashSection.chart, false);
      await edit.move(DashSection.recent, -1);
      await edit.move(DashSection.summary, 1);

      // Order: chart, summary, today, shop, recent, quick; the chart is hidden.
      expect(c.read(dashboardLayoutProvider).visible, [DashSection.summary, DashSection.today, DashSection.shop, DashSection.recent, DashSection.quick]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(PrefKeys.dashOrder), ['chart', 'summary', 'today', 'shop', 'recent', 'quick']);
      expect(prefs.getStringList(PrefKeys.dashHidden), ['chart']);

      await edit.setShown(DashSection.chart, true);
      expect(prefs.getStringList(PrefKeys.dashHidden), isEmpty);
    });

    test('moving past either end changes nothing', () async {
      final c = await container();
      final edit = c.read(dashboardLayoutProvider.notifier);
      await edit.move(DashSection.summary, -1);
      await edit.move(DashSection.recent, 1);
      expect(c.read(dashboardLayoutProvider), DashboardLayout.defaults);
    });

    test('reads the saved layout', () async {
      final c = await container({
        PrefKeys.dashOrder: ['quick', 'summary', 'chart', 'today', 'shop', 'recent'],
        PrefKeys.dashHidden: ['recent'],
      });
      expect(c.read(dashboardLayoutProvider).visible, [DashSection.quick, DashSection.summary, DashSection.chart, DashSection.today, DashSection.shop]);
    });
  });
}
