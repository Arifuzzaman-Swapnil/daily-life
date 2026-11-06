import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../../core/files/file_service.dart';
import '../../core/format/dl_format_more.dart';
import '../../core/format/format_provider.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import 'documents_providers.dart';

String docCategoryLabel(AppLocalizations t, DocCategory c) => switch (c) {
      DocCategory.personal => t.dc_personal,
      DocCategory.office => t.dc_office,
      DocCategory.edu => t.dc_edu,
      DocCategory.fin => t.dc_fin,
      DocCategory.other => t.dc_other,
    };

(IconData, DLTone) docCategoryIcon(DocCategory c) => switch (c) {
      DocCategory.personal => (DLIcons.user, DLTone.teal),
      DocCategory.office => (DLIcons.briefcase, DLTone.accent),
      DocCategory.edu => (DLIcons.graduation, DLTone.warning),
      DocCategory.fin => (DLIcons.cash, DLTone.success),
      DocCategory.other => (DLIcons.folder, DLTone.neutral),
    };

/// Documents (prototype `docs`, screenshot 66; empty 95): search, category
/// cards with counts, and the list.
class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  late final _search = TextEditingController(text: ref.read(docFilterProvider).search);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final filter = ref.watch(docFilterProvider);
    final ctl = ref.read(docFilterProvider.notifier);
    final docs = ref.watch(documentsProvider).value;
    final counts = ref.watch(docCountsProvider).value ?? const <DocCategory, int>{};
    final anyDocs = counts.values.any((n) => n > 0);
    final bottom = MediaQuery.paddingOf(context).bottom;
    void importDoc() => context.push(Routes.importDoc);

    Widget categoryCard(DocCategory cat) {
      final (icon, tone) = docCategoryIcon(cat);
      final on = filter.category == cat;
      return DLSelectableCard(
        selected: on,
        selectedFill: c.accentSoft,
        padding: const EdgeInsets.all(10),
        onTap: () => ctl.toggleCategory(cat),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DLIconChip(icon: icon, tone: tone, size: 36),
            const SizedBox(height: DLSpace.s2),
            Text(docCategoryLabel(t, cat), maxLines: 1, overflow: TextOverflow.ellipsis, style: DLText.textLabel.copyWith(color: c.textPrimary)),
            Text(f.count(counts[cat] ?? 0), style: DLText.textCaption.copyWith(color: c.textSecondary)),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: DLAppBar(title: t.docs, onLeading: () => popOr(context, Routes.more)),
      floatingActionButton: DLFab(icon: DLIcons.upload, tooltip: t.importDoc, onPressed: importDoc),
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, bottom + DLSize.fab + DLSpace.s8),
        children: [
          DLSearchBar(hint: t.searchDocs, controller: _search, onChanged: ctl.setSearch),
          const SizedBox(height: DLSpace.s3),
          for (var r = 0; r < 2; r++) ...[
            if (r > 0) const SizedBox(height: DLSpace.s3),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: DLSpace.s3),
                    Expanded(child: r * 3 + i < DocCategory.values.length ? categoryCard(DocCategory.values[r * 3 + i]) : const SizedBox()),
                  ],
                ],
              ),
            ),
          ],
          DLSectionTitle(
            filter.category == null ? t.all : docCategoryLabel(t, filter.category!),
            trailing: Text(t.docsN(f.count(docs?.length ?? 0)), style: DLText.textBodySm.copyWith(color: c.textSecondary)),
          ),
          if (docs != null && docs.isEmpty)
            DLEmptyState(
              inCard: true,
              icon: DLIcons.folder,
              title: anyDocs ? t.noResults : t.noDocs,
              body: anyDocs ? t.noMatchSub : t.noDocsSub,
              actionLabel: t.importDoc,
              onAction: importDoc,
            )
          else if (docs != null)
            DLList(
              children: [
                for (final d in docs)
                  DLListRow(
                    leading: DLIconChip(
                      icon: d.kind == DocKind.pdf ? DLIcons.file : DLIcons.image,
                      tone: d.kind == DocKind.pdf ? DLTone.danger : DLTone.accent,
                    ),
                    title: d.title,
                    subtitle: '${docCategoryLabel(t, d.category)} · ${f.dateMedium(d.uploadedAt)} · ${f.fileSize(d.sizeBytes)}',
                    trailing: Icon(DLIcons.chevronRight, size: 20, color: c.textSecondary),
                    onTap: () => context.push(Routes.document(d.id)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Import a document (prototype `docImport`, screenshot 68): choose a PDF or
/// an image, give it a title (required), a category and a description.
class ImportDocumentScreen extends ConsumerStatefulWidget {
  const ImportDocumentScreen({super.key});

  @override
  ConsumerState<ImportDocumentScreen> createState() => _ImportDocumentScreenState();
}

class _ImportDocumentScreenState extends ConsumerState<ImportDocumentScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  DocCategory _category = DocCategory.personal;
  DocKind? _kind;
  PickedFile? _file;
  bool _saving = false;
  Map<String, String> _errors = const {};

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _clearError(String key) {
    if (_errors.containsKey(key)) setState(() => _errors = {..._errors}..remove(key));
  }

  Future<void> _pick(DocKind kind) async {
    final picked = await ref.read(fileServiceProvider).pick(kind);
    if (picked == null || !mounted) return;
    setState(() {
      _kind = kind;
      _file = picked;
    });
    _clearError('file');
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final title = _title.text.trim();
    final file = _file, kind = _kind;
    final errors = {
      if (file == null || kind == null) 'file': t.errFile,
      if (title.isEmpty) 'title': t.errTitle,
    };
    setState(() => _errors = errors);
    if (errors.isNotEmpty || file == null || kind == null) {
      DLToast.show(context, t.errForm, error: true);
      return;
    }
    setState(() => _saving = true);
    final id = newId();
    final stored = await ref.read(fileServiceProvider).store(file, id, kind);
    await ref.read(documentsDaoProvider).addDocument(DocumentsCompanion.insert(
      id: Value(id),
      title: title,
      category: _category,
      kind: kind,
      description: Value(_desc.text.trim()),
      uploadedAt: Value(ref.read(clockProvider)()),
      filePath: Value(stored.path),
      sizeBytes: Value(file.size),
      pages: Value(stored.pages),
    ));
    if (!mounted) return;
    ref.read(docFilterProvider.notifier).reset();
    DLToast.show(context, t.docSaved);
    popOr(context, Routes.documents);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final file = _file;

    Widget kindCard(DocKind kind) => Expanded(
          child: DLSelectableCard(
            selected: _kind == kind,
            selectedFill: c.accentSoft,
            padding: const EdgeInsets.all(DLSpace.s3),
            onTap: () => _pick(kind),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DLIconChip(
                  icon: kind == DocKind.pdf ? DLIcons.file : DLIcons.image,
                  tone: kind == DocKind.pdf ? DLTone.danger : DLTone.accent,
                ),
                const SizedBox(height: DLSpace.s2),
                Text(
                  '${t.chooseFile} · ${kind == DocKind.pdf ? 'PDF' : t.image}',
                  style: DLText.textLabel.copyWith(color: c.textPrimary),
                ),
              ],
            ),
          ),
        );

    return Scaffold(
      appBar: DLAppBar(title: t.importDoc, leading: DLAppBarLeading.close, onLeading: () => popOr(context, Routes.documents)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [kindCard(DocKind.pdf), const SizedBox(width: DLSpace.s3), kindCard(DocKind.img)],
            ),
          ),
          const SizedBox(height: DLSpace.s2),
          if (file != null) ...[
            DLNote(file.name, tone: DLTone.success, icon: DLIcons.checkCircle),
            const SizedBox(height: DLSpace.s2),
          ],
          Text(t.fileHint, style: DLText.textBodySm.copyWith(color: c.textSecondary)),
          // A fixed slot, so the fields below keep their place when it clears.
          switch (_errors['file']) {
            final e? => Padding(padding: const EdgeInsets.only(top: DLSpace.s2), child: DLErrorText(e)),
            null => const SizedBox.shrink(),
          },
          const SizedBox(height: DLSpace.s4),
          DLTextField(
            controller: _title,
            label: t.title,
            hint: t.phDocT,
            error: _errors['title'],
            onChanged: (_) => _clearError('title'),
          ),
          DLField(
            label: t.category,
            child: Wrap(
              spacing: DLSpace.s2,
              runSpacing: 0,
              children: [
                for (final cat in DocCategory.values)
                  DLChip(label: docCategoryLabel(t, cat), selected: cat == _category, onTap: () => setState(() => _category = cat)),
              ],
            ),
          ),
          DLTextField(controller: _desc, label: t.desc, hint: t.phDesc, multiline: true),
          const SizedBox(height: DLSpace.s2),
          Row(
            children: [
              Expanded(
                child: DLButton(label: t.cancel, variant: DLButtonVariant.secondary, onPressed: () => popOr(context, Routes.documents)),
              ),
              const SizedBox(width: DLSpace.s2),
              Expanded(child: DLButton(label: t.save, onPressed: _saving ? null : _save)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Document details (prototype `docDetail`, screenshot 67): a preview (tap to
/// open the file), the facts, share and delete.
class DocumentDetailScreen extends ConsumerWidget {
  const DocumentDetailScreen({super.key, required this.id});

  final String id;

  Future<void> _delete(BuildContext context, WidgetRef ref, Document d) async {
    final t = AppLocalizations.of(context);
    final ok = await showDLConfirm(context, title: t.delDocQ, body: d.title);
    if (!ok || !context.mounted) return;
    await ref.read(documentsDaoProvider).deleteDocument(d.id);
    await ref.read(fileServiceProvider).delete(d.filePath);
    if (!context.mounted) return;
    DLToast.show(context, t.docDeleted);
    popOr(context, Routes.documents);
  }

  Future<void> _share(WidgetRef ref, Document d) =>
      ref.read(fileServiceProvider).share(path: d.filePath, text: d.description.isEmpty ? d.title : '${d.title}\n${d.description}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final d = ref.watch(documentProvider(id)).value;
    final actions = d == null
        ? const <Widget>[]
        : [
            DLIconButton(icon: DLIcons.share, tooltip: t.share, onPressed: () => _share(ref, d)),
            DLIconButton(icon: DLIcons.trash, tooltip: t.del, onPressed: () => _delete(context, ref, d)),
          ];
    final appBar = DLAppBar(title: t.docDetail, actions: actions, onLeading: () => popOr(context, Routes.documents));
    if (d == null) return Scaffold(appBar: appBar, body: const SizedBox.shrink());

    final pdf = d.kind == DocKind.pdf;
    final hasFile = d.filePath != null && File(d.filePath!).existsSync();
    final rows = <(String, String)>[
      (t.category, docCategoryLabel(t, d.category)),
      (t.fileType, pdf ? 'PDF' : t.image),
      (t.size, f.fileSize(d.sizeBytes)),
      (t.uploaded, f.dateMedium(d.uploadedAt)),
      if (d.description.isNotEmpty) (t.desc, d.description),
    ];

    return Scaffold(
      appBar: appBar,
      body: ListView(
        padding: EdgeInsets.fromLTRB(DLSpace.s4, DLSpace.s1, DLSpace.s4, DLSpace.s12 + MediaQuery.paddingOf(context).bottom),
        children: [
          Semantics(
            label: t.preview,
            button: hasFile,
            child: DLCard(
              color: c.surfaceSunken,
              padding: const EdgeInsets.all(DLSpace.s5),
              onTap: hasFile ? () => context.push(Routes.viewDocument(d.id)) : null,
              child: Center(child: _DocPreview(title: d.title, pdf: pdf, pages: t.pagesN(f.count(d.pages)))),
            ),
          ),
          const SizedBox(height: DLSpace.s4),
          Text(d.title, style: DLText.textH2.copyWith(color: c.textPrimary)),
          const SizedBox(height: DLSpace.s3),
          DLList(children: [for (final (k, v) in rows) DLKeyValueRow(label: k, value: v)]),
          const SizedBox(height: DLSpace.s4),
          Row(
            children: [
              Expanded(
                child: DLButton(
                  label: t.del,
                  icon: DLIcons.trash,
                  variant: DLButtonVariant.secondary,
                  onPressed: () => _delete(context, ref, d),
                ),
              ),
              const SizedBox(width: DLSpace.s2),
              Expanded(child: DLButton(label: t.share, icon: DLIcons.share, onPressed: () => _share(ref, d))),
            ],
          ),
        ],
      ),
    );
  }
}

/// The prototype's paper preview (`.prev`): a page with lines and the page
/// count for a PDF, a tinted square with the image icon for a picture. It is
/// paper, so it keeps its light colours in both themes.
class _DocPreview extends StatelessWidget {
  const _DocPreview({required this.title, required this.pdf, required this.pages});

  final String title;
  final bool pdf;
  final String pages;

  @override
  Widget build(BuildContext context) {
    const paper = DLColors.light;
    final shadow = DLShadows.card(Theme.of(context).brightness);
    if (!pdf) {
      return Container(
        width: 220,
        height: 220,
        padding: const EdgeInsets.all(DLSpace.s5),
        decoration: BoxDecoration(color: paper.accentSoft, borderRadius: BorderRadius.circular(DLRadius.md)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(DLIcons.image, size: 56, color: paper.accentText),
            const SizedBox(height: DLSpace.s2),
            Text(title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: DLText.textCaption.copyWith(fontWeight: FontWeight.w600, color: paper.accentText)),
          ],
        ),
      );
    }
    Widget line(double w, {double top = 0}) => Padding(
          padding: EdgeInsets.only(top: top),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: w,
            child: Container(height: 8, decoration: BoxDecoration(color: paper.divider, borderRadius: BorderRadius.circular(4))),
          ),
        );
    return Container(
      width: 200,
      height: 260,
      padding: const EdgeInsets.all(DLSpace.s5),
      decoration: BoxDecoration(
        color: paper.surface,
        borderRadius: BorderRadius.circular(DLRadius.md),
        border: Border.all(color: paper.divider),
        boxShadow: shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: DLText.textCaption.copyWith(fontWeight: FontWeight.w700, color: paper.brand)),
          for (final (i, w) in const [0.9, 0.75, 0.85, 0.6, 0.8, 0.7, 0.88, 0.5].indexed) line(w, top: i == 4 ? 20 : 8),
          const Spacer(),
          Text(pages, style: DLText.textCaption.copyWith(color: paper.textSecondary)),
        ],
      ),
    );
  }
}

/// The stored file, full screen: pinch-zoomable PDF pages or the image.
class DocumentViewerScreen extends ConsumerStatefulWidget {
  const DocumentViewerScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  PdfControllerPinch? _pdf;

  @override
  void dispose() {
    _pdf?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(documentProvider(widget.id)).value;
    final path = d?.filePath;
    final appBar = DLAppBar(title: d?.title ?? '', onLeading: () => popOr(context, Routes.document(widget.id)));
    if (d == null || path == null || !File(path).existsSync()) return Scaffold(appBar: appBar, body: const SizedBox.shrink());
    final Widget body;
    if (d.kind == DocKind.pdf) {
      final controller = _pdf ??= PdfControllerPinch(document: PdfDocument.openFile(path));
      body = PdfViewPinch(controller: controller);
    } else {
      body = InteractiveViewer(maxScale: 5, child: Center(child: Image.file(File(path))));
    }
    return Scaffold(appBar: appBar, body: SafeArea(top: false, child: body));
  }
}
