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

  /// Writes [content] to a temporary [fileName] and shares it (CSV exports).
  Future<void> shareTextFile(String fileName, String content, {required String subject});
}

final fileServiceProvider = Provider<FileService>((ref) => DeviceFileService());

class DeviceFileService implements FileService {
  @override
  Future<PickedFile?> pick(DocKind kind) async {
    final f = await FilePicker.pickFile(
      type: kind == DocKind.pdf ? FileType.custom : FileType.image,
      allowedExtensions: kind == DocKind.pdf ? const ['pdf'] : null,
    );
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
    if (path != null && File(path).existsSync()) {
      await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: text));
    } else {
      await SharePlus.instance.share(ShareParams(text: text));
    }
  }

  @override
  Future<void> shareTextFile(String fileName, String content, {required String subject}) async {
    final file = File(p.join((await getTemporaryDirectory()).path, fileName));
    await file.writeAsString(content);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'text/csv')], subject: subject));
  }
}
