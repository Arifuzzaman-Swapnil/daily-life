import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/format_provider.dart';
import '../../core/prefs/app_settings.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../settings/appearance_cards.dart';

/// The three onboarding steps (prototype `onboard`, screenshots 02–04):
/// language, display name (required), theme. Language and theme apply as soon
/// as they are picked. Finishing or skipping marks onboarding done and opens
/// Home; back steps back (from the first step, to Welcome).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  static const steps = 3;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  late final _name = TextEditingController(text: ref.read(settingsProvider).displayName);
  bool _nameError = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      popOr(context, Routes.welcome);
    }
  }

  Future<void> _done() async {
    await ref.read(settingsProvider.notifier).completeOnboarding();
    if (mounted) context.go(Routes.home);
  }

  Future<void> _next() async {
    if (_step == 1) {
      final name = _name.text.trim();
      if (name.isEmpty) {
        setState(() => _nameError = true);
        return;
      }
      FocusScope.of(context).unfocus();
      await ref.read(settingsProvider.notifier).setDisplayName(name);
    }
    if (_step < OnboardingScreen.steps - 1) {
      setState(() => _step++);
    } else {
      await _done();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final s = ref.watch(settingsProvider);
    final ctl = ref.read(settingsProvider.notifier);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final stepLabel = t.stepOf(f.digitsOf('${_step + 1}'), f.digitsOf('${OnboardingScreen.steps}'));
    final (title, subtitle) = switch (_step) {
      0 => (t.ob1, t.ob1s),
      1 => (t.ob2, t.ob2s),
      _ => (t.ob3, t.ob3s),
    };
    final content = switch (_step) {
      0 => LanguageCards(value: s.lang, onChanged: ctl.setLanguage, large: true),
      1 => DLTextField(
          controller: _name,
          label: t.displayName,
          hint: t.namePh,
          error: _nameError ? t.errName : null,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.done,
          bottomGap: 0,
          onChanged: (_) {
            if (_nameError) setState(() => _nameError = false);
          },
          onSubmitted: (_) => _next(),
        ),
      _ => ThemeCards(value: s.themeMode, onChanged: ctl.setThemeMode),
    };

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: DLAppBar(
          title: stepLabel,
          titleWidget: Text(stepLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: DLText.textLabel.copyWith(color: c.textSecondary)),
          onLeading: _back,
          actions: [DLButton(label: t.skip, variant: DLButtonVariant.tonal, size: DLButtonSize.sm, onPressed: _done)],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DLSpace.s4),
              child: DLProgressBar(value: (_step + 1) / OnboardingScreen.steps, height: 6, semanticLabel: stepLabel),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s6, DLSpace.s4, DLSpace.s6 + bottom),
                    sliver: SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(header: true, child: Text(title, style: DLText.textH1.copyWith(color: c.textPrimary))),
                          const SizedBox(height: DLSpace.s2),
                          Text(subtitle, style: DLText.textBody.copyWith(color: c.textSecondary)),
                          const SizedBox(height: DLSpace.s6),
                          KeyedSubtree(key: ValueKey(_step), child: content),
                          const Spacer(),
                          const SizedBox(height: DLSpace.s6),
                          DLButton(label: _step == OnboardingScreen.steps - 1 ? t.finish : t.next, onPressed: _next),
                        ],
                      ),
                    ),
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
