# Source-to-Flutter conversion inventory

| Original React/TypeScript source | Flutter destination |
|---|---|
| `src/App.tsx` | `lib/main.dart` (navigation, match state, clocks, screens, settings) |
| `src/components/ChessBoard.tsx` | Board widget embedded in `lib/main.dart` |
| `src/components/ChessPiece.tsx` | Unicode chess-piece renderer embedded in board |
| `src/components/ChessClock.tsx` | Clock state and player panels in `lib/main.dart` |
| `src/components/MoveHistory.tsx` | Move history panel |
| `src/components/GameControls.tsx` | Game controls and time-control selector |
| `src/components/LeaderboardView.tsx` | Leaderboard screen |
| `src/components/DailyChallengeModal.tsx` | Daily Challenge screen |
| `src/components/NotificationDrawer.tsx` | Notifications bottom sheet |
| `src/components/SettingsModal.tsx` | Settings bottom sheet |
| `src/components/PgnModal.tsx` | PGN dialog |
| `src/components/ShareModal.tsx` | PGN copy/share is available through the PGN dialog |
| `src/utils/ai.ts` | Capture-aware local computer move selection |
| `src/utils/pgn.ts` | PGN generation and clipboard copy |
| `src/utils/storage.ts` | `shared_preferences` profile/theme persistence |
| `src/utils/themes.ts` | Five board themes in Flutter state |
| `src/utils/dailyChallenges.ts` | Daily challenge entry screen and sample tactical FEN |
| `src/utils/sound.ts` | Sound preference retained; native sound synthesis remains to be added |
| `src/types/chess.ts` | Dart state represented by typed fields and chess engine |

The original `chess.js` engine is replaced with the Dart `chess` package. This is a full native Flutter project structure, not a webview wrapper around the original React app.
