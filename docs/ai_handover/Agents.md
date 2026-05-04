# LexRush Project Brief

## Product Snapshot
- **Project:** LexRush
- **Current platform:** Flutter (migrated from React MVP)
- **Primary game shipped:** Antonym Rush
- **Target experience:** Fast, readable, premium-feel word gameplay with fair first-session onboarding and reusable multi-game architecture.

## Current Status
- Migration to Flutter is complete with clean architecture boundaries and Cubit/BLoC state management.
- Core app flow is implemented: splash -> onboarding -> mode selection -> pre-game -> gameplay -> results.
- Antonym Rush gameplay loop is live with scoring, combo, penalties, timers, and replay goals.
- Antonym Rush now uses position-driven balloon escape: balloons animate upward behind the target card and misses are normally triggered when the correct balloon reaches the escape line.
- Dev-only round and tap telemetry is in place for lifecycle, option identity, ignored taps, and scoring transitions.

## Architecture and Stack
- **State management:** `flutter_bloc` / Cubit
- **Routing:** `go_router`
- **Layering:** domain, application, presentation, data
- **Shared services:** scoring, replay goals, timer manager, game registry
- **Persistence:** local onboarding/progress support via shared repositories/services

## Gameplay Rules (Do Not Break)
- Correct answer: `+100`
- Wrong answer: `-3s`
- Missed answer: `-2s` (miss penalty is skipped for rounds `1-5`)
- Results formulas and final metrics calculations must remain unchanged.

## Antonym Rush Fairness Work (Latest)
- Added debug-gated round telemetry (`kDebugMode`) to track:
  - round identity, phase, difficulty, speed, tappable window, timeout values
  - outcome and missed reason attribution (`correctEscaped`, `allEscaped`, `watchdog`, `roundTimeout`)
  - response times and `timeLeft` before/after penalties
- Added debug-gated tap telemetry (`AntonymTapTelemetry`) to track:
  - tapped option id, displayed word, expected correct word, and full option list
  - outcome recorded by the Cubit, score/combo before and after
  - ignored taps during feedback/transition or already-resolved rounds
- Added round single-resolution safeguards to prevent duplicate misses/outcomes.
- Reworked balloon lifecycle:
  - `_BalloonChoice` animates from lower spawn position to `escapeTop = 16` in the main gameplay stack
  - animation completion calls `onEscaped()` because the balloon has visually reached the escape line
  - target card is layered above the balloon layer, so balloons slide under/behind it instead of being clipped by a lower playfield
  - Cubit timeout is now a safety fallback (`expectedWindowMs + 2000ms`) rather than the normal miss mechanism
- Current timing floors:
  - beginner rounds `1-5`: `5.0s` minimum safety timeout, speed `4.0s`
  - early: `4.2s`
  - mid: `3.4s`
  - late: `2.6s`
- Applied first-session easing while keeping 4 options:
  - first 5 rounds use beginner-safe word pairs
  - all rounds now show 4 balloons/options
  - no hard-pair preference before `15s` remaining
  - missed penalty skipped for first 5 rounds

## Validation Snapshot
- `flutter analyze`: passing
- `flutter test test/antonym_rush_cubit_test.dart`: passing
- Deterministic first-5-correct Cubit test passes: 5 solved, 0 missed, 100% accuracy, score `700` with existing combo scoring.
- Latest headless 60s simulation before the final visual layering pass reported: Score `2600`, Accuracy `80%`, Solved `20`, Missed `2`, Avg response `1943ms`, missed reasons `roundTimeout=2`.

## Immediate Priorities
1. Run a fresh real-device/video session after the target-card layering change to verify balloons now visually slide under the card and miss only at the escape line.
2. Use `AntonymTapTelemetry` to confirm human taps are not ignored during visible/tappable moments.
3. Preserve architecture, scoring, results formulas, and route flow while tuning.

## Key Paths
- `lib/features/games/antonym_rush/application/cubit/antonym_rush_cubit.dart`
- `lib/features/games/antonym_rush/application/cubit/antonym_rush_state.dart`
- `lib/features/games/antonym_rush/domain/services/antonym_difficulty_service.dart`
- `lib/features/games/antonym_rush/domain/services/antonym_round_generator.dart`
- `lib/features/games/antonym_rush/presentation/screens/antonym_rush_screen.dart`

## Notes for Next Contributors
- Keep telemetry in place and debug-only; it should remain log-only with no gameplay side effects.
- Preserve position-driven escape. Avoid reintroducing normal timer-based misses unless it is only a true safety fallback.
- Prioritize first-session fairness metrics (accuracy, solved count, missed count), then visual polish.
- Any tuning should be narrow, measurable, and validated by a full 60-second run.
