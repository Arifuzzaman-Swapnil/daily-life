import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../theme/dl_tokens.dart';
import 'dl_icons.dart';

/// Navy bottom navigation for the 5 root tabs (prototype `.nav`):
/// 76 tall, `brand` ground with 20 top corners, items stacked icon-over-label,
/// the active item gets a 56×32 `brandHover` pill with an `onBrandAccent` icon.
class DLBottomNav extends StatelessWidget {
  const DLBottomNav({super.key, required this.currentIndex, required this.onSelect});

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    final t = AppLocalizations.of(context);
    final items = [
      (DLIcons.home, t.home),
      (DLIcons.wallet, t.finance),
      (DLIcons.calendar, t.calendar),
      (DLIcons.briefcase, t.work),
      (DLIcons.grid, t.more),
    ];
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The system navigation bar sits on the navy bar, so its icons are light.
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Semantics(
        container: true,
        label: t.mainNav,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: c.brand,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(DLRadius.xl)),
          ),
          padding: EdgeInsets.fromLTRB(DLSpace.s1, DLSpace.s2, DLSpace.s1, DLSpace.s2 + bottomInset),
          child: SizedBox(
            height: 76 - DLSpace.s2 * 2,
            // Transparent Material so press feedback paints above the navy ground.
            child: Material(
              type: MaterialType.transparency,
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _NavItem(
                        icon: items[i].$1,
                        label: items[i].$2,
                        selected: i == currentIndex,
                        onTap: () => onSelect(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dl;
    const fast = Duration(milliseconds: 150);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        borderRadius: const BorderRadius.all(Radius.circular(DLRadius.md)),
        splashColor: c.brandHover,
        highlightColor: c.brandHover.withValues(alpha: 0.5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 32,
              decoration: BoxDecoration(
                color: selected ? c.brandHover : c.brandHover.withValues(alpha: 0),
                borderRadius: const BorderRadius.all(Radius.circular(DLRadius.pill)),
              ),
              alignment: Alignment.center,
              child: TweenAnimationBuilder<Color?>(
                duration: fast,
                tween: ColorTween(end: selected ? c.onBrandAccent : c.brandMuted),
                builder: (context, color, _) => Icon(icon, size: DLSize.icon, color: color),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: fast,
              style: DLText.textCaption.copyWith(color: selected ? c.onBrand : c.brandMuted),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}
