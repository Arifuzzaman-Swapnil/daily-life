// Golden tests in this folder: real fonts so Bengali reads properly, and a
// tolerant comparator so anti-aliasing drift or a Flutter release moving a
// pixel by one shade doesn't fail the build.
//
// Baselines are generated on CI by running the workflow with "goldens=update"
// (which passes --update-goldens): the workflow uploads the PNGs as an artifact
// and I commit them. Normal pushes skip the `golden` tag; "goldens=check" runs
// the goldens and uploads failure diffs.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Real Bengali and Latin letters: load every Hind Siliguri weight bundled
  // in assets/fonts/ so chrome and amounts render as they do on a phone. The
  // fonts are declared under flutter.fonts in pubspec.yaml, so they don't
  // show up in the asset bundle; read them from disk. The test runner starts
  // in the app/ working directory, where assets/fonts/ lives.
  const weights = ['Light', 'Regular', 'Medium', 'SemiBold', 'Bold'];
  final hind = FontLoader('HindSiliguri');
  for (final weight in weights) {
    hind.addFont(_fontFromFile('assets/fonts/HindSiliguri-$weight.ttf'));
  }
  await hind.load();

  // Lucide icons: the package ships one or more TTFs under its own lib/
  // folder. The pub cache path isn't predictable, so find the package root
  // via Isolate.resolvePackageUri.
  await _loadLucideIfFound();

  // A little room for anti-aliasing and Flutter version drift: at most 0.5 %
  // of the pixels may differ. A real layout change easily exceeds that.
  // Keep the default comparator's base directory (the test file's folder) so
  // goldens land next to the test, not in the cwd.
  final existing = goldenFileComparator as LocalFileComparator;
  goldenFileComparator = _TolerantComparator(existing.basedir);

  await testMain();
}

Future<ByteData> _fontFromFile(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
}

Future<void> _loadLucideIfFound() async {
  // Isolate.resolvePackageUri is unsupported in the Flutter test VM. Read
  // the package's lib directory from .dart_tool/package_config.json instead.
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) return;
  final decoded = jsonDecode(await config.readAsString()) as Map<String, Object?>;
  final packages = (decoded['packages'] as List).cast<Map<String, Object?>>();
  final pkg = packages.firstWhere((p) => p['name'] == 'lucide_icons_flutter', orElse: () => const <String, Object?>{});
  if (pkg.isEmpty) return;
  final rootUri = Uri.parse(pkg['rootUri'] as String);
  final root = rootUri.isAbsolute ? Directory.fromUri(rootUri) : Directory.fromUri(config.parent.uri.resolveUri(rootUri));
  final libDir = Directory.fromUri(root.uri.resolveUri(Uri.parse(pkg['packageUri'] as String? ?? 'lib/')));
  if (!libDir.existsSync()) return;
  final fontFiles = libDir.listSync(recursive: true).whereType<File>().where((f) => f.path.toLowerCase().endsWith('.ttf')).toList();
  if (fontFiles.isEmpty) return;
  // IconData from the package carries `fontPackage: lucide_icons_flutter`;
  // the loader family for a packaged font is `packages/<pkg>/<family>`.
  final lucide = FontLoader('packages/lucide_icons_flutter/LucideIcons');
  for (final f in fontFiles) {
    lucide.addFont(_fontFromFile(f.path));
  }
  await lucide.load();
}

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.baseDir);

  static const _maxPixelFraction = 0.005;

  @override
  Future<bool> compare(Uint8List actualBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(actualBytes, await getGoldenBytes(golden));
    if (result.passed) return true;
    if (result.diffPercent <= _maxPixelFraction) return true;
    final error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError('$error\nDiff: ${(result.diffPercent * 100).toStringAsFixed(2)} % of pixels.');
  }
}
