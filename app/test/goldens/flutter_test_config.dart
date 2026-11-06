// Golden tests in this folder: real fonts so Bengali reads properly, and a
// tolerant comparator so anti-aliasing drift or a Flutter release moving a
// pixel by one shade doesn't fail the build.
//
// Baselines are generated on CI by running the workflow with "goldens=update"
// (which passes --update-goldens): the workflow uploads the PNGs as an artifact
// and I commit them. Normal pushes skip the `golden` tag; "goldens=check" runs
// the goldens and uploads failure diffs.
import 'dart:async';
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
  final loader = FontLoader('HindSiliguri');
  for (final weight in weights) {
    loader.addFont(Future.value(ByteData.view(
      (await File('assets/fonts/HindSiliguri-$weight.ttf').readAsBytes()).buffer,
    )));
  }
  await loader.load();

  // A little room for anti-aliasing and Flutter version drift: at most 0.5 %
  // of the pixels may differ. A real layout change easily exceeds that.
  goldenFileComparator = _TolerantComparator(Uri.parse('${Directory.current.path}/'));

  await testMain();
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
