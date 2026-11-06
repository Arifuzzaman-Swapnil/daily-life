// Settings → "Data management" and "About" (prototype `a_set`, screenshot 80).
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_info.dart';
import '../../core/backup/backup_service.dart';
import '../../core/db/app_database.dart';
import '../../core/db/db_providers.dart';
import '../../core/db/sample/sample_data.dart';
import '../../core/files/csv.dart';
import '../../core/files/file_service.dart';
import '../../core/format/dl_format_more.dart';
import '../../core/format/format_provider.dart';
import '../../core/prefs/app_settings.dart';
import '../../core/prefs/dashboard_layout.dart';
import '../../core/prefs/health_prefs.dart';
import '../../core/prefs/notification_prefs.dart';
import '../../core/prefs/privacy_prefs.dart';
import '../../core/theme/dl_tokens.dart';
import '../../core/widgets/dl_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../finance/categories.dart';

/// Back up (a JSON file kept on the phone and offered to the share sheet),
/// restore from that file, export transactions as CSV, import a backup file,
/// and the sample-data switch. Restore, import and the sample-data switch ask
/// first whenever data would be replaced or removed.
class DataSection extends ConsumerStatefulWidget {
  const DataSection({super.key});

  @override
  ConsumerState<DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends ConsumerState<DataSection> {
  bool _busy = false;

  AppLocalizations get _t => AppLocalizations.of(context);
  FileService get _files => ref.read(fileServiceProvider);
  BackupService get _service => BackupService(ref.read(appDatabaseProvider), ref.read(sharedPrefsProvider));

  void _toast(String message, {bool error = false}) {
    if (mounted) DLToast.show(context, message, error: error);
  }

  Future<void> _backup() async {
    final t = _t;
    setState(() => _busy = true);
    try {
      final now = ref.read(clockProvider)();
      final json = await _service.export(now);
      await _files.saveBackup(json);
      await ref.read(sharedPrefsProvider).setString(PrefKeys.lastBackup, now.toIso8601String());
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(t.backupDone);
      // A copy only on the phone is lost with the app: offer to keep one elsewhere.
      await _files.shareTextFile('daily-life-backup-${dayKey(now)}.json', json, subject: t.backup, mimeType: 'application/json');
    } catch (e, st) {
      debugPrint('Backup failed: $e\n$st');
      _toast(t.backupFailed, error: true);
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final t = _t;
    final json = await _files.readBackup();
    if (!mounted) return;
    if (json == null) return _toast(t.noBackup, error: true);
    final ok = await showDLConfirm(context, title: t.restoreQ, body: t.restoreB, confirmLabel: t.restore, safe: true);
    if (!ok) return;
    await _apply(json, t.restoreDone);
  }

  Future<void> _import() async {
    final t = _t;
    final String? json;
    try {
      json = await _files.pickTextFile();
    } catch (e) {
      debugPrint('Import: could not read the file: $e');
      return _toast(t.errBackupFile, error: true);
    }
    if (json == null || !mounted) return;
    try {
      _service.parse(json);
    } on BackupFormatException catch (e) {
      debugPrint('Import: $e');
      return _toast(t.errBackupFile, error: true);
    }
    final ok = await showDLConfirm(context, title: '${t.importD}?', body: t.restoreB, confirmLabel: t.importD, safe: true);
    if (!ok) return;
    await _apply(json, t.importDone);
  }

  /// Replaces the data and preferences with the backup in [json].
  Future<void> _apply(String json, String done) async {
    final t = _t;
    final service = _service;
    try {
      await service.restore(service.parse(json), fileExists: _files.exists);
    } catch (e, st) {
      debugPrint('Restore failed: $e\n$st');
      return _toast(t.errBackupFile, error: true);
    }
    // Everything read from the preferences follows the restored values.
    ref.invalidate(settingsProvider);
    ref.invalidate(notificationPrefsProvider);
    ref.invalidate(dashboardLayoutProvider);
    ref.invalidate(waterTargetProvider);
    ref.invalidate(privacyProvider);
    ref.invalidate(sampleDataSwitchProvider);
    _toast(done);
  }

  Future<void> _export() async {
    final t = _t;
    final db = ref.read(appDatabaseProvider);
    final txs = await (db.select(db.transactions)..orderBy([(x) => OrderingTerm.desc(x.date), (x) => OrderingTerm.desc(x.time)])).get();
    final book = CategoryBook(await db.select(db.categories).get());
    final today = ref.read(clockProvider)();
    await _files.shareTextFile('daily-life-transactions-${dayKey(today)}.csv', transactionsCsv(t, book, txs), subject: t.exportD);
    _toast(t.exportDone);
  }

  Future<void> _toggleSample() async {
    final t = _t;
    final on = ref.read(sampleDataSwitchProvider);
    final lang = ref.read(settingsProvider).lang;
    final hasData = await ref.read(appDatabaseProvider).hasAnyData();
    if (!mounted) return;
    if (hasData) {
      final ok = on
          ? await showDLConfirm(context, title: t.sampleOffQ, body: t.sampleOffB, confirmLabel: t.del)
          : await showDLConfirm(context, title: t.sampleOnQ, body: t.sampleOnB, confirmLabel: t.confirm);
      if (!ok) return;
    }
    final ctl = ref.read(sampleDataSwitchProvider.notifier);
    await (on ? ctl.turnOff() : ctl.turnOn(lang));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final sample = ref.watch(sampleDataSwitchProvider);
    final last = DateTime.tryParse(ref.read(sharedPrefsProvider).getString(PrefKeys.lastBackup) ?? '');
    final today = ref.watch(clockProvider)();
    DLIconChip chip(IconData icon, DLTone tone) => DLIconChip(icon: icon, tone: tone, size: 36);
    return DLList(
      children: [
        DLListRow(
          leading: chip(DLIcons.database, DLTone.accent),
          title: _busy ? t.backingUp : t.backup,
          subtitle: last == null ? t.noBackup : t.lastBackup(f.relative(last, today)),
          onTap: _busy ? null : _backup,
        ),
        DLListRow(leading: chip(DLIcons.undo, DLTone.neutral), title: t.restore, onTap: _restore),
        DLListRow(
          leading: chip(DLIcons.download, DLTone.neutral),
          title: t.exportD,
          trailing: Text('CSV', style: DLText.textCaption.copyWith(color: c.textSecondary)),
          onTap: _export,
        ),
        DLListRow(leading: chip(DLIcons.upload, DLTone.neutral), title: t.importD, onTap: _import),
        DLListRow(
          leading: chip(DLIcons.list, DLTone.success),
          title: t.sampleData,
          subtitle: t.sampleSub,
          subtitleMaxLines: 2,
          onTap: _toggleSample,
          trailing: DLSwitch(value: sample, onChanged: (_) => _toggleSample(), semanticLabel: t.sampleData),
        ),
      ],
    );
  }
}

/// All transactions as CSV in the app's language: dates as `yyyy-MM-dd`,
/// amounts as plain whole taka so spreadsheets can add them up.
String transactionsCsv(AppLocalizations t, CategoryBook book, List<Txn> txs) => toCsv([
      [t.date, t.time, t.type, t.title, t.category, t.amount, t.method, t.desc, t.note],
      for (final x in txs)
        [
          dayKey(x.date),
          x.time,
          x.type == TxType.income ? t.income : t.expense,
          x.title,
          categoryInfo(t, book, x.type, x.categoryId).label,
          '${x.amount}',
          paymentLabel(t, x.paymentMethod),
          x.description,
          x.note,
        ],
    ]);

/// The app, its version and what it is for; then the privacy promise.
class AboutSection extends ConsumerWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.dl;
    final f = ref.watch(formatProvider);
    final version = ref.watch(appVersionProvider).value ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DLCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const DLLogo(size: 48),
                  const SizedBox(width: DLSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Daily Life', style: DLText.textH3.copyWith(color: c.textPrimary)),
                        Text('${t.version} ${f.digitsOf(version)}', style: DLText.textBodySm.copyWith(color: c.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DLSpace.s3),
              Text(t.aboutText, style: DLText.textBody.copyWith(color: c.textSecondary)),
              const SizedBox(height: DLSpace.s3),
              Text(t.tagline, style: DLText.textCaption.copyWith(color: c.accentText)),
            ],
          ),
        ),
        const SizedBox(height: DLSpace.s3),
        DLCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DLIconChip(icon: DLIcons.shield, tone: DLTone.success, size: 36),
              const SizedBox(width: DLSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.privacyInfo, style: DLText.textBody.copyWith(fontWeight: FontWeight.w600, color: c.textPrimary)),
                    Text(t.privacyText, style: DLText.textBodySm.copyWith(color: c.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
