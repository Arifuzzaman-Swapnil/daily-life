import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/dl_format.dart';
import '../../core/format/format_provider.dart';
import '../../core/prefs/app_settings.dart';
import '../../core/prefs/notification_prefs.dart';
import '../../core/prefs/privacy_prefs.dart';
import '../../core/security/biometric_service.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../privacy/pin_sheet.dart';
import 'appearance_cards.dart';
import 'data_section.dart';

/// Settings (prototype `settings`, screenshots 80–81): profile, "Language &
/// region", "Appearance", "Notifications", "Privacy & security", "Data
/// management" and "About".
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final s = ref.watch(settingsProvider);
    final ctl = ref.read(settingsProvider.notifier);
    final notif = ref.watch(notificationPrefsProvider);
    final notifCtl = ref.read(notificationPrefsProvider.notifier);
    final f = ref.watch(formatProvider);
    final today = ref.watch(clockProvider)();
    final platformDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    Widget label(String text) => Text(text, style: DLText.textLabel.copyWith(color: c.textPrimary));
    Widget sample(String text) => Text(text, style: DLText.textBodySm.copyWith(color: c.textSecondary));

    return Scaffold(
      appBar: DLAppBar(
        title: t.settings,
        onLeading: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(Routes.home);
          }
        },
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          DLSectionHeader(t.profile, first: true),
          const _ProfileCard(),
          DLSectionHeader(t.langRegion),
          DLCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label(t.language),
                const SizedBox(height: DLSpace.s2),
                LanguageCards(value: s.lang, onChanged: ctl.setLanguage),
                const SizedBox(height: DLSpace.s4),
                label(t.numFormat),
                const SizedBox(height: DLSpace.s2),
                DLSegmentedTabs<DigitStyle>(
                  value: s.digits,
                  options: [(DigitStyle.bn, t.bnDigits), (DigitStyle.en, t.enDigits)],
                  onChanged: ctl.setDigits,
                ),
                const SizedBox(height: DLSpace.s2),
                sample('${f.taka(125000)} · ${f.percent(65)}'),
                const SizedBox(height: DLSpace.s4),
                label(t.dateFmt),
                const SizedBox(height: DLSpace.s2),
                DLSegmentedTabs<DateStyle>(
                  value: s.dateStyle,
                  options: [(DateStyle.written, t.dfLong), (DateStyle.numeric, t.dfNum)],
                  onChanged: ctl.setDateStyle,
                ),
                const SizedBox(height: DLSpace.s2),
                sample('${f.dateMedium(today)} · ${f.time('09:30')}'),
              ],
            ),
          ),
          const SizedBox(height: DLSpace.s3),
          DLList(
            children: [
              DLKeyValueRow(label: t.currency, value: t.bdt),
              DLKeyValueRow(label: t.timezone, value: t.dhaka),
              DLKeyValueRow(label: t.weekStart, value: t.saturday),
              DLListRow(
                minHeight: 56,
                title: t.banglaCal,
                subtitle: f.bangla(today),
                onTap: () => ctl.setBanglaDate(!s.banglaDate),
                trailing: DLSwitch(value: s.banglaDate, onChanged: ctl.setBanglaDate, semanticLabel: t.banglaCal),
              ),
            ],
          ),
          DLSectionHeader(t.appearance),
          ThemeCards(value: s.themeMode, onChanged: ctl.setThemeMode),
          if (s.themeMode == ThemeMode.system)
            Padding(
              padding: const EdgeInsets.only(top: DLSpace.s2),
              child: sample('${t.themeNote} · ${platformDark ? t.dark : t.light}'),
            ),
          DLSectionHeader(t.notifsT),
          DLList(
            children: [
              for (final (kind, icon, tone, title) in [
                (NotifKind.general, DLIcons.bell, DLTone.warning, t.nGeneral),
                (NotifKind.water, DLIcons.drop, DLTone.accent, t.nWater),
                (NotifKind.meal, DLIcons.food, DLTone.teal, t.nMeal),
                (NotifKind.office, DLIcons.briefcase, DLTone.neutral, t.nOffice),
                (NotifKind.calendar, DLIcons.calendar, DLTone.accent, t.nCal),
              ])
                DLListRow(
                  minHeight: 56,
                  leading: DLIconChip(icon: icon, tone: tone, size: 36),
                  title: title,
                  onTap: () => notifCtl.set(kind, !notif[kind]),
                  trailing: DLSwitch(value: notif[kind], onChanged: (v) => notifCtl.set(kind, v), semanticLabel: title),
                ),
            ],
          ),
          DLSectionHeader(t.privacy),
          const _PrivacySection(),
          DLSectionHeader(t.dataMgmt),
          const DataSection(),
          DLSectionHeader(t.about),
          const AboutSection(),
        ],
      ),
    );
  }
}

/// Avatar, name and "Change photo" (which cycles the avatar colour, as in the
/// prototype), plus the display-name field with Save.
class _ProfileCard extends ConsumerStatefulWidget {
  const _ProfileCard();

  @override
  ConsumerState<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<_ProfileCard> with AutomaticKeepAliveClientMixin {
  late final TextEditingController _name;
  bool _error = false;

  // A typed name survives scrolling the card out of the list and back.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: ref.read(settingsProvider).displayName);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() async {
    await ref.read(settingsProvider.notifier).cycleAvatar();
    if (mounted) DLToast.show(context, AppLocalizations.of(context).photoUpdated);
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = true);
      DLToast.show(context, t.errForm, error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    _name.text = name;
    await ref.read(settingsProvider.notifier).setDisplayName(name);
    if (mounted) DLToast.show(context, t.nameSaved);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final (name, avatar) = ref.watch(settingsProvider.select((s) => (s.displayName, s.avatar)));
    const size = 56.0;
    return DLCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DLPressable(
                onTap: _changePhoto,
                semanticLabel: t.changePhoto,
                excludeSemantics: true,
                borderRadius: const BorderRadius.all(Radius.circular(size / 2)),
                child: DLAvatar(name: name, color: avatar, size: size),
              ),
              const SizedBox(width: DLSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? t.profile : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DLText.textH3.copyWith(color: c.textPrimary),
                    ),
                    DLLinkButton(label: t.changePhoto, chevron: false, onPressed: _changePhoto),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DLSpace.s3),
          DLField(
            label: t.displayName,
            error: _error ? t.errName : null,
            bottomGap: 0,
            child: Row(
              children: [
                Expanded(
                  child: DLTextField(
                    controller: _name,
                    hint: t.namePh,
                    invalid: _error,
                    bottomGap: 0,
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      if (_error) setState(() => _error = false);
                    },
                    onSubmitted: (_) => _save(),
                  ),
                ),
                const SizedBox(width: DLSpace.s2),
                DLButton(label: t.save, size: DLButtonSize.md, expand: false, onPressed: _save),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// App lock, PIN, biometric unlock and hide amounts (prototype `a_set`). The
/// lock needs a PIN first: without one, it says so and opens the PIN sheet,
/// and saving the PIN turns the lock on.
class _PrivacySection extends ConsumerWidget {
  const _PrivacySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final p = ref.watch(privacyProvider);
    final ctl = ref.read(privacyProvider.notifier);

    Future<void> toggleLock() async {
      if (p.lock) return ctl.setLock(false);
      if (p.hasPin) return ctl.setLock(true);
      DLToast.show(context, t.errPinFirst, error: true);
      if (await showPinSheet(context)) await ctl.setLock(true);
    }

    Future<void> toggleBiometric() async {
      if (p.biometric) return ctl.setBiometric(false);
      final available = await ref.read(biometricServiceProvider).isAvailable();
      if (!context.mounted) return;
      if (!available) {
        DLToast.show(context, t.bioUnavailable, error: true);
        return;
      }
      await ctl.setBiometric(true);
    }

    DLListRow row(IconData icon, DLTone tone, String title, String subtitle, VoidCallback onTap, Widget trailing) => DLListRow(
          leading: DLIconChip(icon: icon, tone: tone, size: 36),
          title: title,
          subtitle: subtitle,
          onTap: onTap,
          trailing: trailing,
        );
    DLSwitch toggle(bool value, VoidCallback onTap, String label) => DLSwitch(value: value, onChanged: (_) => onTap(), semanticLabel: label);

    return DLList(
      children: [
        row(DLIcons.lock, DLTone.accent, t.appLock, t.appLockSub, toggleLock, toggle(p.lock, toggleLock, t.appLock)),
        row(
          DLIcons.hash,
          DLTone.neutral,
          p.hasPin ? t.pinChange : t.pinSet,
          p.hasPin ? t.pinOn : t.pinOff,
          () => showPinSheet(context),
          Icon(DLIcons.chevronRight, size: 20, color: c.textSecondary),
        ),
        row(DLIcons.fingerprint, DLTone.teal, t.biometric, t.biometricSub, toggleBiometric, toggle(p.biometric, toggleBiometric, t.biometric)),
        row(
          DLIcons.eyeOff,
          DLTone.warning,
          t.hideAmounts,
          t.hideSub,
          () => ctl.setHideAmounts(!p.hideAmounts),
          toggle(p.hideAmounts, () => ctl.setHideAmounts(!p.hideAmounts), t.hideAmounts),
        ),
      ],
    );
  }
}
