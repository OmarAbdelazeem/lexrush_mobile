# AI Handoff Summary

## What Changed
- Implemented multiple Antonym Rush fairness/debug passes.
- Added dev-only (`kDebugMode`) round telemetry with outcome + missed-reason attribution.
- Added dev-only tap telemetry (`AntonymTapTelemetry`) for tapped option id/word, expected correct word, full option list, outcome, score/combo before/after, and ignored taps during feedback/transition.
- Added single-resolution round safeguards to prevent duplicate resolve/missed events.
- Reworked missed lifecycle from timer-first to position-driven escape:
  - balloons animate from lower spawn position to `escapeTop = 16`
  - animation completion calls `onEscaped()` only because the balloon visually reaches the escape line
  - Cubit timeout is now a safety fallback (`expectedWindowMs + 2000ms`)
- Reworked presentation layering so balloons render in the main gameplay stack behind the target card, allowing them to slide under/behind the “Find Opposite” card instead of being clipped by a lower playfield.
- Kept all rounds at 4 options while preserving first-5-round beginner-safe word-pair selection.
- Beginner rounds use speed `4.0s`, minimum safety timeout `5.0s`, and no missed time penalty.
- Updated phase timeout floors to early `4.2s`, mid `3.4s`, late `2.6s`.

## Key Files
- `lib/features/games/antonym_rush/application/cubit/antonym_rush_cubit.dart`
- `lib/features/games/antonym_rush/application/cubit/antonym_rush_state.dart`
- `lib/features/games/antonym_rush/domain/entities/antonym_pair.dart`
- `lib/features/games/antonym_rush/domain/entities/antonym_round.dart`
- `lib/features/games/antonym_rush/data/antonym_pairs.dart`
- `lib/features/games/antonym_rush/domain/services/antonym_difficulty_service.dart`
- `lib/features/games/antonym_rush/domain/services/antonym_round_generator.dart`
- `lib/features/games/antonym_rush/presentation/screens/antonym_rush_screen.dart`
- `test/antonym_rush_cubit_test.dart`
- `tool/sim_60s_session.dart`

## Current Bugs / Gaps
- Latest manual/video feedback before the layering fix showed balloons still appeared clipped below the target card.
- The final change moved balloons behind the target card, but still needs a fresh manual/video run to confirm the visual issue is resolved.
- First-session human results still need validation after the position-driven escape and layering changes.
- Watch for ignored-tap logs (`event=tap_ignored`) if a user taps visible balloons and score does not change.

## Decisions Made
- Keep architecture, routing, scoring formulas, and results formulas unchanged.
- Keep telemetry system in code, debug-gated, and strictly log-only (no gameplay side effects).
- Keep all rounds at 4 options; do not reintroduce 3-option beginner rounds.
- Beginner easing is now through beginner-safe pair selection, slower beginner speed, missed-penalty skip for rounds `1-5`, and visual/lifecycle fairness.
- Normal misses should come from visual escape (`correctEscaped` / `allEscaped`); `roundTimeout` should be treated as a stall/safety fallback.

## Next Steps
1. Run `flutter analyze` and `flutter test test/antonym_rush_cubit_test.dart` after any further edits.
2. Record a fresh gameplay video to verify balloons slide under/behind the target card and are not clipped at the old playfield boundary.
3. Execute one full 60s run and report score, accuracy, words solved, missed words, average response, and missed-reason breakdown.
4. Use `AntonymTapTelemetry` to confirm correct taps are accepted and no visible/tappable balloon taps are ignored during active gameplay.
