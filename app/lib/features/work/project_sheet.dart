import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/db_providers.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';

/// The "new project" sheet (prototype `projNew`). Resolves to the new
/// project's id, or null when cancelled.
Future<String?> showNewProjectSheet(BuildContext context) {
  final t = AppLocalizations.of(context);
  return showDLSheet<String>(context, title: t.newProject, builder: (_) => const _NewProjectSheet());
}

class _NewProjectSheet extends ConsumerStatefulWidget {
  const _NewProjectSheet();

  @override
  ConsumerState<_NewProjectSheet> createState() => _NewProjectSheetState();
}

class _NewProjectSheetState extends ConsumerState<_NewProjectSheet> {
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = t.errTitle);
      return;
    }
    final id = await ref.read(workDaoProvider).addProject(name);
    if (!mounted) return;
    DLToast.show(context, t.projSaved);
    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DLTextField(
          controller: _name,
          label: t.project,
          hint: t.phProject,
          error: _error,
          autofocus: true,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _save(),
        ),
        Row(
          children: [
            Expanded(child: DLButton(label: t.cancel, variant: DLButtonVariant.secondary, onPressed: () => Navigator.of(context).pop())),
            const SizedBox(width: DLSpace.s2),
            Expanded(child: DLButton(label: t.add, onPressed: _save)),
          ],
        ),
      ],
    );
  }
}
