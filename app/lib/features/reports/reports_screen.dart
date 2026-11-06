import 'package:flutter/material.dart';

import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';

/// Reports (prototype `reports`). A titled stand-in until build step 6, so the
/// Finance shortcuts already lead somewhere.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: DLAppBar(title: t.reports, onLeading: () => popOr(context, Routes.finance)),
      body: const SizedBox.shrink(),
    );
  }
}
