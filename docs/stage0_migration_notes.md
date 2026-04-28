# LexRush Flutter Migration - Stage 0 Notes

This file captures the Stage 0 preparation and mapping outputs for migrating LexRush from the React MVP to Flutter.

## Scope

- Completed only Stage 0 (Preparation and Mapping).
- No Flutter feature implementation was started.
- React implementation was treated as source of truth when docs and code differ.

## React Behavior Baseline

### Screen Flow

- First launch: `splash -> onboarding -> modeSelection -> preGame -> gameplay -> results`.
- Returning launch: `splash -> modeSelection -> preGame -> gameplay -> results`.
- Onboarding completion is persisted via local storage flag (`lexrush_has_seen_onboarding`).
- Results screen appears only after in-memory game completion state.

### Gameplay Loop (Antonym Rush)

- Session duration: 60 seconds.
- Each round has 4 balloons: exactly 1 correct antonym + 3 distractors.
- Correct tap:
  - locks round
  - records response time
  - increases score and combo
  - schedules next round
- Wrong tap:
  - locks round
  - applies `-3s`
  - resets combo
  - records response time
  - schedules next round
- Missed round:
  - locks round
  - resets combo
  - increments missed words
  - first 3 rounds: no time penalty
  - from round 4 onward: `-2s`
  - schedules next round

### Difficulty and Tuning

- Phase by remaining time:
  - `>40s`: early
  - `>15s`: mid
  - `<=15s`: late
- Tier eligibility:
  - early: easy + medium (easy-heavy preference)
  - mid: easy + medium (medium-heavy preference)
  - late: medium + hard (hard appears late)
- Spawn fairness:
  - lane-based x positions with slight jitter
  - spacing constraints
  - edge clamping
  - fallback default positions on retry exhaustion

### Results and Replay Goal

- Accuracy = `correct / (correct + wrong + missed)` as percent.
- Average response time uses tapped rounds only.
- XP formula implemented in React:
  - `wordsSolved * 10`
  - `+ bestCombo * 5`
  - `+50` if accuracy >= 90
  - `+25` if bestCombo >= 10
- Replay-goal priority:
  - if accuracy < 75: `Reach 75% accuracy`
  - else if bestCombo < 12: `Beat your {bestCombo}x combo`
  - else if wordsSolved < 20: `Solve 20 words`
  - else: `Reach 80% accuracy`

## Shared Concepts Needed From Day One

- App shell and stage routes.
- Game timer lifecycle contract.
- Shared session stats and game result contracts.
- Difficulty phase contract and resolver.
- Replay-goal policy service.
- Shared game controller contract (`start`, `pause`, `resume`, `restart`, `submitAnswer`, `finish`).
- Game registry service for scalable multi-game mode listing.

## Layer Ownership for Flutter

### Domain

- Pure entities/value objects:
  - `WordPair`, `Round`, `BalloonOption`, `SessionStats`, `GameResult`, `DifficultyPhase`.
- Pure rule services:
  - difficulty phase resolution
  - pair eligibility and selection
  - round generation and option shuffling
  - spawn safety constraints
  - score, combo, penalties, accuracy, XP, replay-goal calculations

### Application

- Cubit/BLoC owns:
  - game status machine (`idle`, `playing`, `paused`, `round_feedback`, `ended`)
  - session timer tick lifecycle
  - round lifecycle and resolution guards
  - penalties, score/combo/stat updates
  - pause/resume/restart/end orchestration
  - timeout ownership and cleanup

### Presentation

- Flutter screens/widgets render state and dispatch user intents only.
- No gameplay rules or formula logic inside widgets.
- Key screens:
  - splash, onboarding, mode selection, pre-game countdown, gameplay, pause, results

### Data

- Local antonym pair data source and repository.
- Local onboarding persistence.
- Optional adapter boundaries for analytics/audio/haptics.

## Stage 0 Acceptance Checklist

- React behavior can be explained accurately: PASS.
- Shared vs game-specific responsibilities identified: PASS.
- Domain/application/presentation/data split is clear: PASS.

## Blockers / Ambiguities

- No hard blockers for Stage 0.
- Intentional parity decision: use implemented React combo scoring behavior (stepped multiplier) unless explicitly changed.
