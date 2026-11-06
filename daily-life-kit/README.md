# Daily Life — design hand-off kit

Unzip this folder into your project (or next to it) and start Claude Code there. `CLAUDE.md` is loaded automatically and tells Claude Code how to build the Flutter app.

Suggested first prompt:

> Read CLAUDE.md, open prototype/index.html and the screenshots, then scaffold the Flutter project and complete build-order step 1. Show me the plan before writing code.

Contents:
- `CLAUDE.md` — the build brief (stack, design rules, localization, data model, business rules, screens, acceptance journeys, build order)
- `prototype/index.html` — the interactive prototype; open in a browser (`?start=finance&theme=dark&lang=en`)
- `screenshots/` — every screen in Bangla-Light and English-Dark
- `design/` — design system tokens and principles
- `flutter/` — ready-to-use Dart theme tokens, ThemeData, Bengali/English formatting utilities, ARB translations and `l10n.yaml`
- `data/sample_data.json` — seed data
- `tools/` — scripts that regenerate the prototype and Flutter assets
