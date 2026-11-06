// Generates Flutter-ready assets from the prototype + design tokens.
// node gen_assets.js <Main.dc.html> <tokens.json> <outDir>
const fs = require('fs'), path = require('path');
const [,, mainPath, tokPath, out] = process.argv;
const src = fs.readFileSync(mainPath, 'utf8');
const script = src.match(/<script type="text\/x-dc" data-dc-script[^>]*>([\s\S]*?)<\/script>/)[1];
class DCLogic {}
const M = new Function('DCLogic', script + '\nreturn { TR, seed, CATS, PMS, HIST };')(DCLogic);
const mk = p => fs.mkdirSync(path.join(out, p), { recursive: true });

// ---------- ARB ----------
mk('flutter/lib/l10n');
const arb = { bn: { '@@locale': 'bn' }, en: { '@@locale': 'en' } };
// 'of' would clash with AppLocalizations.of(context) — renamed.
const RENAME = { of: 'ofWord' };
for (const k0 of Object.keys(M.TR)) {
  const [bn, en] = M.TR[k0], k = RENAME[k0] || k0;
  arb.bn[k] = bn; arb.en[k] = en;
  const ph = [...new Set([...(en.match(/\{(\w+)\}/g) || [])].map(x => x.slice(1, -1)))];
  arb.en['@' + k] = ph.length ? { placeholders: Object.fromEntries(ph.map(p => [p, { type: 'String' }])) } : {};
}
for (const l of ['bn', 'en']) fs.writeFileSync(path.join(out, 'flutter/lib/l10n/app_' + l + '.arb'), JSON.stringify(arb[l], null, 2) + '\n');
fs.writeFileSync(path.join(out, 'flutter/l10n.yaml'), 'arb-dir: lib/l10n\ntemplate-arb-file: app_en.arb\noutput-localization-file: app_localizations.dart\noutput-class: AppLocalizations\nnullable-getter: false\n');

// ---------- sample data ----------
mk('data');
const s = M.seed();
fs.writeFileSync(path.join(out, 'data/sample_data.json'), JSON.stringify({
  _readme: 'Seed data used by the prototype. "Today" is fixed to 2026-11-06 (Asia/Dhaka). Text fields given as [bn, en] arrays are bilingual sample content; user-entered content is a plain string. Dates are YYYY-MM-DD, times HH:mm (24h). Amounts are whole BDT.',
  today: '2026-11-06', categories: M.CATS, paymentMethods: M.PMS, ...s
}, null, 1) + '\n');

// ---------- Dart tokens ----------
const T = JSON.parse(fs.readFileSync(tokPath, 'utf8'));
const camel = n => n.replace(/-([a-z0-9])/g, (m, c) => c.toUpperCase());
const byName = Object.fromEntries(T.color.tokens.map(t => [t.name, t]));
const resolve = (name, theme) => { let v = byName[name].value; if (typeof v === 'string' && /^\{.+\}$/.test(v)) return resolve(v.slice(1, -1), theme); return typeof v === 'object' ? v[theme] : v; };
const dartColor = v => { v = v.trim(); if (v[0] === '#') return 'Color(0xFF' + v.slice(1).toUpperCase() + ')'; const m = v.match(/rgba?\(([^)]+)\)/); const [r, g, b, a = '1'] = m[1].split(',').map(x => x.trim()); return 'Color.fromRGBO(' + r + ', ' + g + ', ' + b + ', ' + a + ')'; };
const names = T.color.tokens.map(t => t.name);
const shadow = str => str.split(/,(?![^(]*\))/).map(p => { const m = p.trim().match(/^(-?\d+)(?:px)?\s+(-?\d+)(?:px)?\s+(\d+)px\s+(rgba?\([^)]+\))$/); return `BoxShadow(offset: Offset(${m[1]}, ${m[2]}), blurRadius: ${m[3]}, color: ${dartColor(m[4])})`; }).join(', ');
let d = `// GENERATED from design/tokens.json (Daily Life design system). Do not edit by hand —
// re-run tools/gen_assets.js if tokens change.
// ignore_for_file: lines_longer_than_80_chars
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';

/// Colour tokens as a ThemeExtension. Read with \`Theme.of(context).extension<DLColors>()!\`
/// or the \`context.dl\` extension below. Every token has a light and a dark value.
@immutable
class DLColors extends ThemeExtension<DLColors> {
  const DLColors({${names.map(n => 'required this.' + camel(n)).join(', ')}});
${T.color.tokens.map(t => '  /// ' + t.usage.replace(/\n/g, ' ') + '\n  final Color ' + camel(t.name) + ';').join('\n')}

  static const light = DLColors(${names.map(n => '\n    ' + camel(n) + ': ' + dartColor(resolve(n, 'light'))).join(',')},
  );
  static const dark = DLColors(${names.map(n => '\n    ' + camel(n) + ': ' + dartColor(resolve(n, 'dark'))).join(',')},
  );

  @override
  DLColors copyWith({${names.map(n => 'Color? ' + camel(n)).join(', ')}}) => DLColors(${names.map(n => camel(n) + ': ' + camel(n) + ' ?? this.' + camel(n)).join(', ')});

  @override
  DLColors lerp(ThemeExtension<DLColors>? other, double t) {
    if (other is! DLColors) return this;
    return DLColors(${names.map(n => camel(n) + ': Color.lerp(' + camel(n) + ', other.' + camel(n) + ', t)!').join(', ')});
  }
}

extension DLContext on BuildContext {
  DLColors get dl => Theme.of(this).extension<DLColors>()!;
}

/// Type scale. One family: Hind Siliguri (bundle the TTFs under assets/fonts, family name 'HindSiliguri').
/// Amount styles use tabular figures so columns of money align.
class DLText {
  static const family = 'HindSiliguri';
  static const _tab = [FontFeature.tabularFigures()];
${T.type.groups.flatMap(g => g.styles).map(st => { const fs_ = parseFloat(st.fontSize), lh = parseFloat(st.lineHeight); return `  /// ${st.usage}\n  static const ${camel(st.name)} = TextStyle(fontFamily: family, fontSize: ${fs_}, height: ${(lh / fs_).toFixed(4)}, fontWeight: FontWeight.w${st.fontWeight}${st.letterSpacing ? ', letterSpacing: ' + (parseFloat(st.letterSpacing) * fs_).toFixed(2) : ''}${st.name.startsWith('amount') ? ', fontFeatures: _tab' : ''});`; }).join('\n')}
}

/// Spacing (4px base). ${T.spacing.note}
class DLSpace {
${T.spacing.tokens.map(t => `  /// ${t.usage}\n  static const double ${camel(t.name.replace('space-', 's'))} = ${parseFloat(t.value)};`).join('\n')}
}

/// Corner radius. ${T.radius.note}
class DLRadius {
${T.radius.tokens.map(t => `  /// ${t.usage}\n  static const double ${camel(t.name.replace('radius-', ''))} = ${parseFloat(t.value)};`).join('\n')}
}

/// Component sizes. ${T.size.note}
class DLSize {
${T.size.tokens.map(t => `  /// ${t.usage}\n  static const double ${camel(t.name.replace('size-', ''))} = ${parseFloat(t.value)};`).join('\n')}
}

/// Elevation. ${T.shadow.note}
class DLShadows {
${T.shadow.tokens.map(t => `  /// ${t.usage}\n  static List<BoxShadow> ${camel(t.name.replace('shadow-', ''))}(Brightness b) => b == Brightness.dark ? const [${shadow(t.value.dark)}] : const [${shadow(t.value.light)}];`).join('\n')}
}
`;
mk('flutter/lib/core/theme');
fs.writeFileSync(path.join(out, 'flutter/lib/core/theme/dl_tokens.dart'), d);
console.log('ARB keys:', Object.keys(M.TR).length, '| colour tokens:', names.length, '| tx:', s.tx.length);
