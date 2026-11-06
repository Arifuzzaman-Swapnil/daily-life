import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/dl_tokens.dart';
import 'dl_buttons.dart';
import 'dl_icons.dart';

/// What sits before the title of a sub-page bar.
enum DLAppBarLeading { back, close, none }

/// Top app bar. Use it as `Scaffold.appBar` or at the top of a column; it pads
/// itself below the real status bar.
/// - `DLAppBar.root` is prototype `.ab.top`: root tabs, 26px bold title from 16.
/// - `DLAppBar` is `.ab`: sub-pages and forms, a back (or close) button, 22px title.
///
/// Both are 64 tall with 48dp icon buttons 4 apart.
class DLAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DLAppBar({
    super.key,
    required this.title,
    this.leading = DLAppBarLeading.back,
    this.onLeading,
    this.actions = const [],
    this.titleWidget,
  }) : root = false;

  /// [titleWidget] replaces the title text, e.g. Home's date over the Bangla
  /// date or onboarding's "Step 1 of 3"; [title] then only names the bar for
  /// screen readers.
  const DLAppBar.root({super.key, required this.title, this.actions = const [], this.titleWidget})
      : root = true,
        leading = DLAppBarLeading.none,
        onLeading = null;

  static const double height = 64;

  final String title;
  final Widget? titleWidget;
  final DLAppBarLeading leading;

  /// Defaults to popping the current route.
  final VoidCallback? onLeading;
  final List<Widget> actions;
  final bool root;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final t = AppLocalizations.of(context);
    final items = <Widget>[
      if (leading != DLAppBarLeading.none)
        DLIconButton(
          icon: leading == DLAppBarLeading.close ? DLIcons.close : DLIcons.back,
          tooltip: leading == DLAppBarLeading.close ? t.close : t.back,
          onPressed: onLeading ?? () => Navigator.maybePop(context),
        ),
      Expanded(
        child: Padding(
          padding: EdgeInsets.only(left: root ? 0 : DLSpace.s1),
          child: Semantics(
            header: true,
            label: titleWidget != null ? title : null,
            child: titleWidget ??
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (root ? DLText.textH1 : DLText.textH2).copyWith(color: c.textPrimary),
                ),
          ),
        ),
      ),
      ...actions,
    ];
    return ColoredBox(
      color: c.background,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: EdgeInsets.only(left: root ? DLSpace.s4 : DLSpace.s1, right: DLSpace.s2),
            child: Row(
              children: [
                for (final (i, item) in items.indexed) ...[
                  if (i > 0) const SizedBox(width: DLSpace.s1),
                  item,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
