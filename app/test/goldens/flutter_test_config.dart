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
  if (!config.existsSync()) {
    debugPrint('[goldens] .dart_tool/package_config.json missing at ${Directory.current.path}');
    return;
  }
  final decoded = jsonDecode(await config.readAsString()) as Map<String, Object?>;
  final packages = (decoded['packages'] as List).cast<Map<String, Object?>>();
  final pkg = packages.firstWhere((p) => p['name'] == 'lucide_icons_flutter', orElse: () => const <String, Object?>{});
  if (pkg.isEmpty) {
    debugPrint('[goldens] lucide_icons_flutter not in package_config.json');
    return;
  }
  // rootUri is relative to the config file; it has no trailing slash, so
  // resolving another relative URI against it would drop its last segment.
  var rootField = pkg['rootUri'] as String;
  if (!rootField.endsWith('/')) rootField += '/';
  final rootUri = Uri.parse(rootField);
  final configDirUri = config.absolute.parent.uri;
  final absRoot = rootUri.isAbsolute ? rootUri : configDirUri.resolveUri(rootUri);
  // Search the whole package, not only lib/ — this package keeps its font
  // outside lib/ in 4.x.
  final root = Directory.fromUri(absRoot);
  if (!root.existsSync()) {
    debugPrint('[goldens] lucide root missing: ${root.path}');
    return;
  }
  final fontFiles = root.listSync(recursive: true).whereType<File>().where((f) => f.path.toLowerCase().endsWith('.ttf')).toList();
  if (fontFiles.isEmpty) {
    debugPrint('[goldens] no .ttf under ${root.path}');
    return;
  }
  // Map the TTF filename to the font family the IconData expects. The base
  // glyphs live in `lucide.ttf` but the package declares them under the
  // family `Lucide` (capital L); the weight variants keep their filenames.
  String familyOf(String file) {
    final stem = file.substring(0, file.length - 4); // strip .ttf
    return stem == 'lucide' ? 'Lucide' : stem;
  }

  final fonts = <String, List<File>>{};
  for (final f in fontFiles) {
    fonts.putIfAbsent(familyOf(f.uri.pathSegments.last), () => []).add(f);
  }
  for (final e in fonts.entries) {
    final loader = FontLoader('packages/lucide_icons_flutter/${e.key}');
    for (final f in e.value) {
      loader.addFont(_fontFromFile(f.path));
    }
    await loader.load();
  }
  debugPrint('[goldens] loaded Lucide families: ${fonts.keys.join(", ")}');
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
