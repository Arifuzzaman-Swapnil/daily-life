import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/format_provider.dart';
import '../../core/prefs/privacy_prefs.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';

/// The PIN sheet (prototype `sh.pin`, screenshot 81): "Set PIN" / "Change PIN",
/// four dots and a number pad. The new PIN is asked twice (a deliberate change
/// from the prototype, so a typo can't lock the person out); a mismatch starts
/// over. Saves only the PIN's hash, shows "PIN set" and resolves to true.
Future<bool> showPinSheet(BuildContext context) async {
  final saved = await showDLSheet<bool>(context, builder: (_) => const _PinSheet());
  return saved ?? false;
}

class _PinSheet extends ConsumerStatefulWidget {
  const _PinSheet();

  @override
  ConsumerState<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends ConsumerState<_PinSheet> {
  String _entered = '';

  /// The first entry, while the second one confirms it.
  String? _first;
  bool _mismatch = false;
  bool _saving = false;

  Future<void> _digit(int d) async {
    if (_saving || _entered.length >= kPinLength) return;
    setState(() {
      _entered += '$d';
      _mismatch = false;
    });
    if (_entered.length < kPinLength) return;
    final first = _first;
    if (first == null) {
      setState(() {
        _first = _entered;
        _entered = '';
      });
    } else if (first != _entered) {
      HapticFeedback.mediumImpact();
      setState(() {
        _first = null;
        _entered = '';
        _mismatch = true;
      });
    } else {
      _saving = true;
      await ref.read(privacyProvider.notifier).setPin(first);
      if (!mounted) return;
      DLToast.show(context, AppLocalizations.of(context).pinSaved);
      Navigator.of(context).pop(true);
    }
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
    final hasPin = ref.watch(privacyProvider.select((p) => p.hasPin));
    final title = hasPin ? t.pinChange : t.pinSet;
    return Semantics(
      label: title,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: DLText.textH2.copyWith(color: c.textPrimary))),
          const SizedBox(height: DLSpace.s1),
          Text(_first == null ? t.enterPin : t.pinAgain, textAlign: TextAlign.center, style: DLText.textBodySm.copyWith(color: c.textSecondary)),
          const SizedBox(height: DLSpace.s4),
          DLPinDots(filled: _entered.length, length: kPinLength),
          // One fixed slot for the mismatch line, so the pad never jumps.
          SizedBox(
            height: 32,
            child: Center(
              child: _mismatch
                  ? Text(t.pinMismatch, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: DLText.textBodySm.copyWith(color: c.dangerText))
                  : const SizedBox.shrink(),
            ),
          ),
          DLKeypad(onDigit: _digit, onDelete: _delete, digitLabel: f.digitsOf, deleteLabel: t.deleteDigit),
        ],
      ),
    );
  }
}
