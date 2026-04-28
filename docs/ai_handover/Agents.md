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
- A round-lifecycle fairness instrumentation pass was implemented with dev-only telemetry.

## Architecture and Stack
- **State management:** `flutter_bloc` / Cubit
- **Routing:** `go_router`
- **Layering:** domain, application, presentation, data
- **Shared services:** scoring, replay goals, timer manager, game registry
- **Persistence:** local onboarding/progress support via shared repositories/services

## Gameplay Rules (Do Not Break)
- Correct answer: `+100`
- Wrong answer: `-3s`
- Missed answer: `-2s` (with early-round grace currently applied for first 5 rounds)
- Results formulas and final metrics calculations must remain unchanged.

## Antonym Rush Fairness Work (Latest)
- Added debug-gated round telemetry (`kDebugMode`) to track:
  - round identity, phase, difficulty, speed, tappable window, timeout values
  - outcome and missed reason attribution (`correctEscaped`, `allEscaped`, `watchdog`, `roundTimeout`)
  - response times and `timeLeft` before/after penalties
- Added round single-resolution safeguards to prevent duplicate misses/outcomes.
- Enforced minimum auto-miss lifetimes by phase:
  - early: `3.4s`
  - mid: `2.8s`
  - late: `2.2s`
- Applied first-session easing:
  - softer first-5-round pace
  - no hard-pair preference before `15s` remaining
  - missed penalty grace expanded to first 5 rounds

## Validation Snapshot
- `flutter analyze`: passing
- `flutter test test/antonym_rush_cubit_test.dart`: passing
- Most recent 60s run still reports missed-heavy outcomes, with misses dominated by `roundTimeout`.

## Immediate Priorities
1. Use telemetry to reduce `roundTimeout` misses in early/mid phases without changing UI structure.
2. Keep gameplay feel aligned with React MVP readability and fairness.
3. Preserve architecture, scoring, results formulas, and route flow while tuning.

## Key Paths
- `lib/features/games/antonym_rush/application/cubit/antonym_rush_cubit.dart`
- `lib/features/games/antonym_rush/application/cubit/antonym_rush_state.dart`
- `lib/features/games/antonym_rush/domain/services/antonym_difficulty_service.dart`
- `lib/features/games/antonym_rush/domain/services/antonym_round_generator.dart`
- `lib/features/games/antonym_rush/presentation/screens/antonym_rush_screen.dart`

## Notes for Next Contributors
- Keep telemetry in place and debug-only; it should remain log-only with no gameplay side effects.
- Prioritize first-session fairness metrics (accuracy, solved count, missed count) before visual polish.
- Any tuning should be narrow, measurable, and validated by a full 60-second run.
