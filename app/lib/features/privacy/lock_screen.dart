import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/format_provider.dart';
import '../../core/prefs/privacy_prefs.dart';
import '../../core/security/app_lock.dart';
import '../../core/security/biometric_service.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';

/// Wraps the whole app (in `MaterialApp.builder`): while locked, the app below
/// stays alive but is hidden, unfocusable and silent to screen readers, and
/// the [LockScreen] covers it.
class AppLockGate extends ConsumerWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(appLockProvider);
    return Stack(
      children: [
        ExcludeFocus(
          excluding: locked,
          child: ExcludeSemantics(
            excluding: locked,
            child: TickerMode(enabled: !locked, child: Offstage(offstage: locked, child: child)),
          ),
        ),
        if (locked) const Positioned.fill(child: LockScreen()),
      ],
    );
  }
}

/// The lock screen (not in the prototype, which only simulated the lock): the
/// logo, the PIN dots and number pad, and the fingerprint button when
/// biometric unlock is on. The fingerprint prompt opens by itself once each
/// time the app locks.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _entered = '';
  bool _wrong = false;
  bool _autoTried = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Locking happens while the app is hidden: prompt once it is back.
    _lifecycle = AppLifecycleListener(onResume: _autoBiometric);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = WidgetsBinding.instance.lifecycleState;
      if (state == null || state == AppLifecycleState.resumed) _autoBiometric();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _autoBiometric() {
    if (_autoTried || !mounted || !ref.read(privacyProvider).biometric) return;
    _autoTried = true;
    _biometric();
  }

  Future<void> _biometric() async {
    final t = AppLocalizations.of(context);
    final lock = ref.read(appLockProvider.notifier);
    final service = ref.read(biometricServiceProvider);
    final ok = await lock.whileOutside(
      () => service.authenticate(reason: t.biometricSub, title: t.appName, hint: t.bioHint, cancel: t.cancel),
    );
    if (ok && mounted) lock.unlock();
  }

  void _digit(int d) {
    if (_entered.length >= kPinLength) return;
    final entered = '$_entered$d';
    if (entered.length < kPinLength) {
      setState(() {
        _entered = entered;
        _wrong = false;
      });
      return;
    }
    if (ref.read(privacyProvider.notifier).checkPin(entered)) {
      ref.read(appLockProvider.notifier).unlock();
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _entered = '';
      _wrong = true;
    });
  }

  void _delete() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final biometric = ref.watch(privacyProvider.select((p) => p.biometric));
    return Material(
      color: c.background,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: DLSpace.s6, vertical: DLSpace.s6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: DLLogo(size: 56)),
                  const SizedBox(height: DLSpace.s4),
                  Semantics(
                    header: true,
                    child: Text(t.appName, textAlign: TextAlign.center, style: DLText.textH2.copyWith(color: c.textPrimary)),
                  ),
                  const SizedBox(height: DLSpace.s1),
                  Text(t.unlockSub, textAlign: TextAlign.center, style: DLText.textBodySm.copyWith(color: c.textSecondary)),
                  const SizedBox(height: DLSpace.s6),
                  DLPinDots(filled: _entered.length, length: kPinLength),
                  // One fixed slot for the error line, so the pad never jumps.
                  SizedBox(
                    height: 40,
                    child: Center(
                      child: _wrong
                          ? Semantics(
                              liveRegion: true,
                              child: Text(
                                t.wrongPin,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DLText.textBodySm.copyWith(color: c.dangerText),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  DLKeypad(onDigit: _digit, onDelete: _delete, digitLabel: f.digitsOf, deleteLabel: t.deleteDigit),
                  biometric
                      ? Padding(
                          padding: const EdgeInsets.only(top: DLSpace.s4),
                          child: DLButton(
                            label: t.useBiometric,
                            icon: DLIcons.fingerprint,
                            variant: DLButtonVariant.tonal,
                            size: DLButtonSize.md,
                            onPressed: _biometric,
                          ),
                        )
                      : const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
