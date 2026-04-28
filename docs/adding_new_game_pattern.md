# Adding a New Game Pattern

This guide defines the standard flow for adding a new LexRush game without changing shared architecture.

## 1) Register the game

- Add a `GameDefinition` entry in `lib/shared/domain/entities/game_catalog.dart`.
- Set:
  - unique `id`
  - `mode`
  - `title`
  - `description`
  - `category`

If the mode is new, also update `lib/shared/domain/entities/game_mode.dart` and `lib/shared/domain/entities/game_mode_codec.dart`.

## 2) Add feature folders

Create:

- `lib/features/games/<new_game>/domain/`
- `lib/features/games/<new_game>/application/`
- `lib/features/games/<new_game>/presentation/`
- `lib/features/games/<new_game>/data/` (if needed)

Keep rules in domain/application, never in widgets.

## 3) Implement game controller contract

Your game Cubit must satisfy `LexRushGameController`:

- `start`
- `pause`
- `resume`
- `restart`
- `submitAnswer`
- `finish`

Own timer/round/result lifecycle inside Cubit.

## 4) Reuse shared systems first

Use shared services/widgets before creating custom ones:

- `GameShell`, `GameTimer`, `ScoreDisplay`, `ComboMeter`
- `ScoringService`, `ReplayGoalService`
- integration ports (`AnalyticsPort`, `AudioFeedbackPort`, `HapticsPort`)

## 5) Wire route dispatch

In `lib/app/router/app_router.dart`:

- decode `:mode` with `GameModeCodec.fromPath`
- map mode -> screen
- fallback safely to a known screen if mode is invalid

## 6) Verify acceptance baseline

Before merging a new game:

- no rule logic in presentation widgets
- pause/resume/restart/end are stable
- no stale timers/duplicate round resolution
- results route receives a real `GameResult`
- mode appears from registry (not hardcoded in UI)
