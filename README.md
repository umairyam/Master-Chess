# Master Chess Game — Flutter / Dart

This folder is a Flutter reimplementation of the supplied React + TypeScript Master Chess Game.

## Run

1. Install the Flutter SDK and configure Android Studio / VS Code.
2. Open this folder in VS Code.
3. Run `flutter pub get`.
4. Run `flutter run` (or choose an Android, Windows, or Chrome target).

## Implemented in this conversion

- Responsive dark chess application layout for narrow and wide screens
- Legal chess move validation using the Dart `chess` package
- Board orientation flip, legal destination hints, queen promotion
- Computer opponent with selectable five-level move-selection difficulty
- Local two-player and analysis modes
- New game, undo, resign, move history, PGN display/copy
- Time controls (unlimited, bullet, blitz, rapid, classical), increment and clocks
- Board themes (Tournament, Wood, Slate, Cyber, Ice)
- Daily tactical challenge entry point
- Player rating and W/L/D profile stats persisted locally
- Leaderboard screen, game archive screen, notifications panel
- Settings for theme, difficulty, sound toggle and appearance
- Shared-preferences persistence

## Important conversion notes

The supplied source was a Vite/React web application, not an existing Flutter project. This is a Dart/Flutter reimplementation of its core experience and game flow. The original React app included browser-specific behaviors and simulated/community data. Those have been represented with local Flutter screens and local persistence; they are not connected to a real online multiplayer service, cloud leaderboard, push-notification backend, or Google Gemini service. The original AI's full minimax search and every original modal/notification workflow have not been ported one-for-one. The computer opponent in this initial conversion uses legal moves with capture-aware selection and difficulty variation.

The `chess` package provides the actual legal chess rules engine (castling, en passant, check, checkmate, stalemate and promotion). Internet access is not needed for gameplay after dependencies are installed.
