// Files on the device: picking a PDF or image, keeping a private copy in the
// app's storage, reading a PDF's page count, deleting, and sharing through
// the system share sheet. Widget tests replace it with a fake.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../db/app_database.dart';
import '../security/app_lock.dart';

/// A file the person picked, before it is copied into the app.
@immutable
class PickedFile {
  const PickedFile({required this.path, required this.name, required this.size});

  final String path;
  final String name;
  final int size;
}

abstract class FileService {
  /// Opens the system picker for a PDF or an image; null when cancelled.
  Future<PickedFile?> pick(DocKind kind);

  /// Copies [file] into the app's private storage as [id]; returns the copy's
  /// path and page count (1 for images).
  Future<({String path, int pages})> store(PickedFile file, String id, DocKind kind);

  /// Removes a stored copy (no-op for null or a missing file).
  Future<void> delete(String? path);

  /// The system share sheet with a file, or just [text] when there is none.
  Future<void> share({String? path, required String text});

  /// Writes [content] to a temporary [fileName] and shares it (CSV exports,
  /// backups).
  Future<void> shareTextFile(String fileName, String content, {required String subject, String mimeType = 'text/csv'});

  /// Whether a stored file is on this phone (a restored document's copy may
  /// not be).
  Future<bool> exists(String path);

  /// Keeps [content] as the latest backup in the app's private storage.
  Future<void> saveBackup(String content);

  /// The latest backup kept by [saveBackup]; null when there is none.
  Future<String?> readBackup();

  /// Opens the system picker for any file and reads it as text; null when
  /// cancelled. Throws [FormatException] for a file too big to be a backup.
  Future<String?> pickTextFile();
}

final fileServiceProvider = Provider<FileService>((ref) => DeviceFileService(outside: ref.read(appLockProvider.notifier).whileOutside));

/// Runs a call that shows a system screen (picker, share sheet) without
/// triggering the app lock; see [AppLockController.whileOutside].
typedef OutsideRunner = Future<T> Function<T>(Future<T> Function() action);

class DeviceFileService implements FileService {
  DeviceFileService({required this.outside});

  final OutsideRunner outside;

  @override
  Future<PickedFile?> pick(DocKind kind) async {
    final f = await outside(() => FilePicker.pickFile(
      type: kind == DocKind.pdf ? FileType.custom : FileType.image,
      allowedExtensions: kind == DocKind.pdf ? const ['pdf'] : null,
    ));
    final path = f?.path;
    if (f == null || path == null) return null;
    return PickedFile(path: path, name: f.name, size: f.lengthSync() ?? await f.length() ?? 0);
  }

  @override
  Future<({String path, int pages})> store(PickedFile file, String id, DocKind kind) async {
    final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'documents'));
    await dir.create(recursive: true);
    final ext = p.extension(file.name).isNotEmpty ? p.extension(file.name) : (kind == DocKind.pdf ? '.pdf' : '.jpg');
    final dest = p.join(dir.path, '$id$ext');
    await File(file.path).copy(dest);
    var pages = 1;
    if (kind == DocKind.pdf) {
      try {
        final doc = await PdfDocument.openFile(dest);
        pages = doc.pagesCount;
        await doc.close();
      } catch (e) {
        debugPrint('Could not read the PDF page count: $e');
      }
    }
    return (path: dest, pages: pages);
  }

  @override
  Future<void> delete(String? path) async {
    if (path == null) return;
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<void> share({String? path, required String text}) async {
    final params = path != null && File(path).existsSync() ? ShareParams(files: [XFile(path)], text: text) : ShareParams(text: text);
    await outside(() => SharePlus.instance.share(params));
  }

  @override
  Future<void> shareTextFile(String fileName, String content, {required String subject, String mimeType = 'text/csv'}) async {
    final file = File(p.join((await getTemporaryDirectory()).path, fileName));
    // A byte-order mark, so spreadsheet apps read Bengali CSV text as UTF-8.
    await file.writeAsString(mimeType == 'text/csv' ? '\uFEFF$content' : content);
    await outside(() => SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: mimeType)], subject: subject)));
  }

  @override
  Future<bool> exists(String path) => File(path).exists();

  Future<File> _backupFile() async => File(p.join((await getApplicationDocumentsDirectory()).path, 'backups', 'latest.json'));

  @override
  Future<void> saveBackup(String content) async {
    final file = await _backupFile();
    await file.parent.create(recursive: true);
    // Written next to it first, so a failed write never leaves half a backup.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(content, flush: true);
    await temp.rename(file.path);
  }

  @override
  Future<String?> readBackup() async {
    final file = await _backupFile();
    return await file.exists() ? file.readAsString() : null;
  }

  /// Larger than any backup this app makes (records only, no document files).
  static const _maxBackupBytes = 50 << 20;

  @override
  Future<String?> pickTextFile() async {
    final f = await outside(() => FilePicker.pickFile(type: FileType.any));
    final path = f?.path;
    if (f == null || path == null) return null;
    final file = File(path);
    if (await file.length() > _maxBackupBytes) throw const FormatException('File too large');
    return file.readAsString();
  }
}
