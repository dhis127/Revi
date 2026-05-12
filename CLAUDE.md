# Revi — CLAUDE.md

## What This App Does
Revi is an iOS book archiving app. Users scan pages from physical books using the camera, extract quotes, and store them in a personal digital library organized by book. Core philosophy: keep physical books clean while preserving every meaningful sentence digitally.

---

## Tech Stack
- **Framework**: Flutter (Dart)
- **State Management**: Provider
- **Local Storage**: path_provider (no backend, no cloud sync)
- **Image Input**: image_picker
- **Fonts**: google_fonts
- **Icons**: cupertino_icons

---

## Project Structure
```
lib/
├── config/        # App-wide constants, theme, colors
├── models/        # Data models (Book, Quote, etc.)
├── pages/
│   ├── home_page.dart       # Main landing screen
│   ├── add_book_page.dart   # Add a new book
│   ├── archive_page.dart    # Book library / shelf view
│   ├── quotes_page.dart     # Saved quotes list
│   ├── scan_page.dart       # Camera scan (OCR not yet integrated)
│   ├── search_page.dart     # Search across books and quotes
│   ├── login_page.dart      # Login screen
│   └── settings_page.dart   # App settings
├── providers/     # Provider state classes
├── widgets/       # Reusable UI components
└── main.dart      # App entry point
```

---

## Architecture Rules
- State management: **Provider only**. Do not introduce Riverpod or Bloc.
- Storage: **local only** via path_provider. No Supabase or cloud backend until explicitly requested.
- OCR: **not yet integrated**. scan_page uses image_picker only.
- Platform priority: **iOS first**. Test on iOS Simulator.

---

## Key Decisions (Do Not Override)
- No Figma. Layout is iterated directly in code.
- No FlutterFlow. Pure Flutter/Dart.
- Minimal dependencies. Do not add packages without explicit approval.
- Do not create new files without checking existing structure first.
- Do not switch state management pattern.
- Do not introduce backend/cloud until explicitly requested.

---

## Common Commands
```bash
flutter run                      # Run on simulator
flutter analyze                  # Static analysis
flutter clean && flutter pub get # Clean rebuild
```

---

## Current Status
All 8 pages scaffolded. Currently refining feature implementation across individual pages.
