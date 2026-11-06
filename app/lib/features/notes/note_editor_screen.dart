import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../../core/format/dl_format_more.dart';
import '../../core/format/format_provider.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import 'notes_providers.dart';
import 'notes_screen.dart';

/// New / edit note (prototype `noteEdit`, screenshot 56): category, pin, a
/// borderless title and body, the word count. A title or some text is needed;
/// a new note opens on its details.
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key}) : editId = null;

  const NoteEditorScreen.edit({super.key, required String id}) : editId = id;

  final String? editId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  NoteCategory _category = NoteCategory.personal;
  bool _pinned = false;
  Note? _original;
  late bool _loading = widget.editId != null;
  String? _error;

  @override
  void initState() {
    super.initState();
    _body.addListener(_onBody);
    if (widget.editId != null) _load(widget.editId!);
  }

  // The word count follows the body.
  void _onBody() => setState(() {});

  Future<void> _load(String id) async {
    final n = await ref.read(notesDaoProvider).noteById(id);
    if (!mounted) return;
    if (n != null) {
      _title.text = n.title;
      _body.text = n.body; // the listener rebuilds
    }
    setState(() {
      _loading = false;
      if (n == null) return;
      _original = n;
      _category = n.category;
      _pinned = n.pinned;
    });
  }

  @override
  void dispose() {
    _body.removeListener(_onBody);
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final title = _title.text.trim();
    final body = _body.text;
    if (title.isEmpty && body.trim().isEmpty) {
      setState(() => _error = t.errNote);
      DLToast.show(context, t.errForm, error: true);
      return;
    }
    final dao = ref.read(notesDaoProvider);
    final now = ref.read(clockProvider)();
    final original = _original;
    String? newId;
    if (original != null) {
      await dao.updateNote(original.copyWith(title: title, body: body, category: _category, pinned: _pinned), now: now);
    } else {
      newId = await dao.addNote(NotesCompanion.insert(
        title: Value(title),
        body: Value(body),
        category: _category,
        pinned: Value(_pinned),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));
    }
    if (!mounted) return;
    DLToast.show(context, t.noteSaved);
    if (newId != null) {
      // Like the prototype: the new note shows in the notebook, not the archive.
      ref.read(noteFilterProvider.notifier).showNotebook();
      context.pushReplacement(Routes.note(newId));
    } else {
      popOr(context, Routes.notes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final today = ref.watch(clockProvider)();
    final original = _original;
    final words = _body.text.trim().isEmpty ? 0 : _body.text.trim().split(RegExp(r'\s+')).length;

    final appBar = DLAppBar(
      title: widget.editId != null ? t.editNote : t.newNote,
      leading: DLAppBarLeading.close,
      onLeading: () => popOr(context, Routes.notes),
      actions: [
        DLIconButton(
          icon: DLIcons.pin,
          tooltip: _pinned ? t.unpin : t.pin,
          tonal: _pinned,
          onPressed: () => setState(() => _pinned = !_pinned),
        ),
        DLButton(label: t.save, size: DLButtonSize.sm, onPressed: _loading ? null : _save),
      ],
    );
    if (_loading) return Scaffold(appBar: appBar, body: const SizedBox.shrink());

    // The prototype's borderless editor (`.ed`), not a boxed field.
    InputDecoration plain(String hint, TextStyle style) => InputDecoration(
          hintText: hint,
          hintStyle: style.copyWith(color: c.textSecondary),
          isDense: true,
          filled: false,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        );

    final titleStyle = DLText.textH2.copyWith(color: c.textPrimary);
    final bodyStyle = DLText.textBodyLg.copyWith(height: 30 / 17, color: c.textPrimary);

    return Scaffold(
      appBar: appBar,
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s6 + MediaQuery.paddingOf(context).bottom),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (i, cat) in NoteCategory.values.indexed) ...[
                  if (i > 0) const SizedBox(width: DLSpace.s2),
                  DLChip(label: noteCategoryLabel(t, cat), selected: cat == _category, onTap: () => setState(() => _category = cat)),
                ],
              ],
            ),
          ),
          const SizedBox(height: DLSpace.s3),
          TextField(
            controller: _title,
            style: titleStyle,
            cursorColor: c.accent,
            textInputAction: TextInputAction.next,
            decoration: plain(t.noteTitlePh, titleStyle),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          // One fixed slot, so showing or clearing the error never shifts the
          // body field to a new place in the list (which would rebuild it).
          _error == null ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(top: DLSpace.s1), child: DLErrorText(_error!)),
          const SizedBox(height: DLSpace.s3),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 360),
            child: TextField(
              controller: _body,
              style: bodyStyle,
              cursorColor: c.accent,
              maxLines: null,
              minLines: 12,
              keyboardType: TextInputType.multiline,
              decoration: plain(t.noteBodyPh, bodyStyle),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: DLSpace.s2),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.divider))),
            child: Row(
              children: [
                Expanded(child: Text(t.words(f.count(words)), style: DLText.textCaption.copyWith(color: c.textSecondary))),
                Text(
                  original != null ? '${t.created} ${f.dateMedium(original.createdAt)}' : f.dateMedium(today),
                  style: DLText.textCaption.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
