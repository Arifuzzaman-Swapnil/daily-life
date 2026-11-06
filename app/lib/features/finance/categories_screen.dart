import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../../core/format/dl_format_more.dart';
import '../../core/format/format_provider.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import 'categories.dart';
import 'category_sheet.dart';
import 'money_providers.dart';

/// Category management (prototype `categories`, screenshot 17): income and
/// expense categories with this month's use; custom ones can be deleted.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, TxType type, String id, String label) async {
    final t = AppLocalizations.of(context);
    final ok = await showDLConfirm(context, title: '${t.del}?', body: label);
    if (!ok || !context.mounted) return;
    await ref.read(financeDaoProvider).deleteCategory(type, id);
    if (context.mounted) DLToast.show(context, t.catDeleted);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final book = ref.watch(categoryBookProvider);
    final usage = ref.watch(categoryUsageProvider).value ?? const {};

    Widget group(TxType type, String label) {
      final cats = book.pickable(type);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DLSectionHeader(label, first: true),
          if (cats.isNotEmpty)
            DLList(
              children: [
                for (final cat in cats)
                  Builder(builder: (context) {
                    final info = categoryInfo(t, book, type, cat.id);
                    return DLListRow(
                      leading: DLIconChip(icon: info.icon, tone: info.tone),
                      title: info.label,
                      subtitle: t.usedN(f.count(usage[(type, cat.id)] ?? 0)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DLTag(label: info.custom ? t.custom : t.dflt, tone: info.custom ? DLTone.accent : DLTone.neutral),
                          if (info.custom)
                            DLIconButton(
                              icon: DLIcons.trash,
                              tooltip: t.del,
                              iconSize: 20,
                              color: c.textSecondary,
                              onPressed: () => _delete(context, ref, type, cat.id, info.label),
                            ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
        ],
      );
    }

    return Scaffold(
      appBar: DLAppBar(
        title: t.categories,
        onLeading: () => popOr(context, Routes.finance),
        actions: [DLIconButton(icon: DLIcons.plus, tooltip: t.newCat, onPressed: () => showNewCategorySheet(context))],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, 0, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          group(TxType.income, t.incCats),
          group(TxType.expense, t.expCats),
        ],
      ),
    );
  }
}
