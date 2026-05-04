# LexRush Project Brief

## Product Snapshot
- **Project:** LexRush
- **Current platform:** Flutter (migrated from React MVP)
- **Shipped gameplay modes:** **Antonym Rush** and **Association** (both routable from mode selection through pre-game → gameplay → shared results flow).
- **Also in catalog:** Synonym Storm, Definition Match (definitions exist; treat as product backlog unless wired end-to-end).
- **Target experience:** Fast, readable, premium-feel word gameplay with fair first-session onboarding and reusable multi-game architecture.

## Current Status
- Migration to Flutter is complete with clean architecture boundaries and Cubit/BLoC state management.
- Core app flow is implemented: splash → onboarding → mode selection → pre-game → gameplay → results.
- **Antonym Rush:** Scoring, combo, penalties, timers, replay goals, and dev-only telemetry are in place. Balloons animate upward behind the target card; escape-line presentation is coordinated with Cubit resolution.
- **Association:** Semantic “closest match” game (target word + two shuffled options). Neural-graph style UI with entry/ambient/feedback animations, context-hint pill for hard ambiguous prompts, compact feedback panel, and results screen with review (misses first, correct answer emphasized). Cubit owns session timer, round timer, feedback transitions, scoring, and review list.
- **Docs:** [docs/Testing_Tutorial.md](../Testing_Tutorial.md) describes manual QA on emulator/device (adb, screenshots, recordings, iOS Simulator basics).

## Architecture and Stack
- **State management:** `flutter_bloc` / Cubit
- **Routing:** `go_router`
- **Layering:** domain, application, presentation, data (per game under `lib/features/games/<game>/`)
- **Shared services:** scoring, replay goals, timer manager, game registry
- **Persistence:** local onboarding/progress support via shared repositories/services

## Gameplay Rules (Do Not Break)

### Antonym Rush
- Correct answer: `+100`
- Wrong answer: `-3s`
- Missed answer: `-2s` (miss penalty is skipped for rounds `1–5`)
- Results formulas and final metrics calculations must remain unchanged.

### Association
- Session length: **60s** (via shared timer manager).
- Correct: `+100`; wrong: `-3s` (combo resets); missed: `-2s` and combo resets (miss **time** penalty skipped rounds `1–5`).
- Always **two** options per round (one correct), shuffled; first **five** rounds use **beginner-safe** prompts only.
- Hard tier only when `secondsLeft ≤ 15`; first **20s** of clock (`secondsLeft ≥ 40`, post-beginner) stays **easy** regardless of `wordsSolved`. Ambiguous prompts with `contextHint` are **hard-only** in seeded data.
- Results use the same honest **`GameResult` / `GameSessionStats`** pipeline; `AssociationGameResult` adds a **review** list for learning.

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
- **Miss resolution:** When a balloon’s rise animation **completes** at the escape line, the widget calls `onBalloonEscaped` → Cubit records **`correctEscaped`** or **`allEscaped`** as appropriate. Separately, Cubit schedules **`roundTimeout`** as a **safety** net: `expectedWindowMs + 2000ms`, floored by phase/beginner minimums (stall / desync protection).
- **Presentation:** `_BalloonChoice` uses `escapeTop = 16` in the shared stack; balloon layer sits **behind** the target card so balloons read as sliding **under** the opposite-word card. `GestureDetector` uses `HitTestBehavior.opaque` for full balloon hit targets.
- **Timing floors (auto-miss minimums / beginner window):**
  - beginner rounds `1–5`: `5000ms` minimum, speed `4.0s`
  - early: `4200ms`
  - mid: `3400ms`
  - late: `2600ms`
- **First-session easing (four options always):**
  - rounds `1–5`: beginner-safe pairs only; **4** balloons; no missed **time** penalty
  - rounds `6+`: normal phase system and penalties
  - no hard-pair preference before `15s` remaining on the session clock

## Association Work (Latest)
- **Feature root:** `lib/features/games/association/` (entities, round generator, difficulty service, seeded prompts, cubit, `AssociationScreen`, `AssociationResultsScreen`).
- **Telemetry:** `[AssociationTelemetry]` prefix, `kDebugMode` only — session, rounds, taps, misses, feedback timers, pause/resume (log-only).
- **UI polish:** Stateful graph with `_entry` / `_ambient` / `_correct` / `_wrong` animation controllers (disposed in `dispose`); incremental link paint, energy-on-correct, wrong flash; floating `+100`; hint **pill** under target when `contextHint` is set.
- **Data:** `association_prompts.dart` — e.g. `assist` beginner-safe; borderline items like `attack → accuse` tiered **hard** with hint; contextual words (`season`, `object`, `fine`, …) hard + hinted.
- **Tests / tools:** `test/association_cubit_test.dart`, `tool/sim_association_60s_session.dart`.

## Validation Snapshot
Run after substantive changes:
- `flutter analyze`
- `flutter test test/antonym_rush_cubit_test.dart`
- `flutter test test/association_cubit_test.dart`
- Optional regression: `flutter test tool/sim_association_60s_session.dart` (longer wall-clock)

Antonym Cubit tests include first-five correct path (e.g. score `700`, accuracy `100%`, `wordsSolved=5`, `missed=0`). Re-run a **60s simulation or real session** when tuning timing or presentation; capture telemetry if behavior disagrees with expectations.

## Immediate Priorities
1. Keep **Antonym** and **Association** scoring, results math, routing, and review contracts stable; tune inside game modules only unless explicitly migrating shared code.
2. **Antonym:** Occasional real-device/video pass to confirm escape animation + `roundTimeout` never disagree with “still tappable” in production builds; mine `AntonymTapTelemetry` for ignored taps during play.
3. **Association:** Further content QA on prompt fairness; optional integration/`integration_test` later for stable flows.
4. Use [docs/Testing_Tutorial.md](../Testing_Tutorial.md) for reproducible manual passes (emulator, adb, screenshots).

## Key Paths

### Antonym Rush
- `lib/features/games/antonym_rush/application/cubit/antonym_rush_cubit.dart`
- `lib/features/games/antonym_rush/application/cubit/antonym_rush_state.dart`
- `lib/features/games/antonym_rush/domain/services/antonym_difficulty_service.dart`
- `lib/features/games/antonym_rush/domain/services/antonym_round_generator.dart`
- `lib/features/games/antonym_rush/presentation/screens/antonym_rush_screen.dart`

### Association
- `lib/features/games/association/application/cubit/association_cubit.dart`
- `lib/features/games/association/application/cubit/association_state.dart`
- `lib/features/games/association/domain/services/association_round_generator.dart`
- `lib/features/games/association/domain/services/association_difficulty_service.dart`
- `lib/features/games/association/data/association_prompts.dart`
- `lib/features/games/association/presentation/screens/association_screen.dart`
- `lib/features/games/association/presentation/screens/association_results_screen.dart`

### Shared routing / catalog
- `lib/app/router/app_router.dart`
- `lib/shared/domain/entities/game_catalog.dart`
- `lib/shared/domain/entities/game_mode.dart`

## Notes for Next Contributors
- Keep **Antonym** telemetry (`AntonymRoundTelemetry`, `AntonymTapTelemetry`) and **Association** telemetry (`[AssociationTelemetry]`) **debug-only** and **log-only** — no gameplay side effects from logging.
- **Antonym:** Preserve escape-line + safety timeout modeling; avoid re-tightening auto-miss below visual tappability without a measured session.
- **Association:** Preserve Cubit-owned timers and pause/resume behavior; do not move scoring or `GameResult` computation into widgets.
- Prioritize **first-session fairness** (accuracy, solved count, missed count), then visual polish.
- Any tuning should be narrow, measurable, and validated by analyzer + targeted tests + a full **60s** run where relevant.
