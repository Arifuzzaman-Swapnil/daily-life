// How a transaction category looks on screen: its label, icon and tone.
import 'package:flutter/widgets.dart';

import '../../core/db/app_database.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';

/// Every category of both types (system `shop` included), looked up by (type, id).
class CategoryBook {
  CategoryBook(Iterable<TxCategory> all)
      : _all = List.unmodifiable(all),
        _byKey = {for (final c in all) (c.type, c.id): c};

  static final empty = CategoryBook(const []);

  final List<TxCategory> _all;
  final Map<(TxType, String), TxCategory> _byKey;

  bool get isEmpty => _all.isEmpty;

  /// Picker order (built-ins, then custom), without the system `shop` category.
  List<TxCategory> pickable(TxType type) => [for (final c in _all) if (c.type == type && !c.isSystem) c];

  TxCategory? find(TxType type, String id) => _byKey[(type, id)];
}

/// What a category shows: label, icon and the tone of its icon tile.
class CategoryInfo {
  const CategoryInfo({required this.label, required this.icon, required this.tone, required this.custom});

  final String label;
  final IconData icon;
  final DLTone tone;

  /// Made by the person (deletable), not built in.
  final bool custom;
}

/// The prototype's `catInfo`: a built-in shows its `cat_<id>` string, a custom
/// one its name; an unknown (deleted) one shows as "Other" with the tag icon.
CategoryInfo categoryInfo(AppLocalizations t, CategoryBook book, TxType type, String id) {
  final c = book.find(type, id);
  if (c == null) return CategoryInfo(label: t.cat_other, icon: DLIcons.tag, tone: DLTone.accent, custom: true);
  return CategoryInfo(
    label: c.name ?? builtinCategoryLabel(t, c.id),
    icon: DLIcons.byKey(c.icon),
    tone: DLTone.values.asNameMap()[c.tone] ?? DLTone.neutral,
    custom: !c.isDefault,
  );
}

/// `cat_<id>` for a built-in category id.
String builtinCategoryLabel(AppLocalizations t, String id) => switch (id) {
      'salary' => t.cat_salary,
      'bonus' => t.cat_bonus,
      'freelance' => t.cat_freelance,
      'extra' => t.cat_extra,
      'business' => t.cat_business,
      'food' => t.cat_food,
      'transport' => t.cat_transport,
      'rent' => t.cat_rent,
      'shopping' => t.cat_shopping,
      'family' => t.cat_family,
      'personal' => t.cat_personal,
      'medical' => t.cat_medical,
      'ent' => t.cat_ent,
      'mobile' => t.cat_mobile,
      'shop' => t.cat_shop,
      'savings' => t.cat_savings,
      _ => t.cat_other,
    };

/// The icon tile of a transaction row (prototype `txView`): income always shows
/// the incoming arrow in green; an expense shows its category's icon and tone.
({IconData icon, DLTone tone}) txIcon(Txn x, CategoryInfo info) =>
    x.type == TxType.income ? (icon: DLIcons.income, tone: DLTone.success) : (icon: info.icon, tone: info.tone);
