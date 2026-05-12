# AI Handoff Summary

Short handoff for the **next coding agent**. For the full project brief (rules, paths, validation), read [`Agents.md`](Agents.md) in this folder.

---

## What changed (recent / relevant)

### Antonym Rush
- Dev-only round telemetry (`AntonymRoundTelemetry`): phases, timeouts, missed-reason attribution (`correctEscaped`, `allEscaped`, `watchdog`, `roundTimeout`).
- Dev-only tap telemetry (`AntonymTapTelemetry`): option identity, ignored taps during feedback, score/combo before/after.
- Single-resolution safeguards on rounds.
- Balloons animate to **`escapeTop = 16`**; **`AnimationStatus.completed`** on `_BalloonChoice` calls `onBalloonEscaped` → Cubit may register **`correctEscaped`** / **`allEscaped`**. **`roundTimeout`** remains a **safety** timer: `expectedWindowMs + 2000ms`, floored by beginner/phase minimums (`5.0s` / `4.2s` / `3.4s` / `2.6s`).
- Balloon layer **behind** target card; **`HitTestBehavior.opaque`** on balloons.
- **Four options every round**; rounds `1–5` use **beginner-safe** pairs, slower speed (`4.0s`), **no missed time penalty**; missed `-2s` after that.

### Association (shipped mode)
- Full flow under `lib/features/games/association/`: **60s** session, target + **two** shuffled options, scoring aligned with Antonym-style penalties (miss time skip rounds `1–5`).
- **`AssociationCubit`** owns session timer, round timeout, feedback auto-continue, pause/resume timer restore, review list, and navigation to **`AssociationGameResult`** / shared results.
- Difficulty: beginner five rounds → easy/medium/hard by `AssociationDifficultyService` (hard only when `secondsLeft ≤ 15`; easy while `secondsLeft ≥ 40` post-beginner).
- UI: neural graph, multi-controller animations (`_entry`, `_ambient`, `_correct`, `_wrong`), hint **pill** when `contextHint` is set (hard prompts).
- Dev-only logs: **`[AssociationTelemetry]`** prefix.

### Sequencing Memory (shipped mode)
- Full flow under `lib/features/games/sequencing_memory/`: **3 route challenges**, no lives, no global timer.
- Stage flow is part one → feedback → part two → feedback → combined recall → feedback for each route.
- Runtime audio uses **`DeviceTtsSequencingAudioService`** (`flutter_tts`) behind **`SequencingAudioService`**; tests use mock/controlled audio services.
- Listening hides reorder cards; optional debug spoken caption is developer-only and must not drive Cubit logic.
- Replay is **1 per part**; combined recall has no replay. Scoring remains perfect part `+100`, perfect combined `+200`, partial `+20` per correct position.

### Commas (shipped mode)
- Full flow under `lib/features/games/commas/`: **60s** session, curated prompt data only, no runtime grammar detection.
- `CommasCubit` owns timer, prompt selection, placed commas, wrong taps, scoring, history, and results.
- `CommaTextArea` renders natural prose as one `RichText` string and overlays TextPainter-measured transparent `CommaGapDetector` hitboxes using stable `afterTokenIndex` values.
- Scoring remains correct comma `+100`, sentence complete bonus `+100`, wrong tap `-3s`.
- Results review should stay user-friendly: original/correct blocks plus your commas, wrong taps, rule, and explanation.

### Docs
- **[`docs/testing/Testing_Tutorial.md`](../testing/Testing_Tutorial.md)** — manual QA: emulator, physical device, `adb` taps/screenshots/recordings, iOS Simulator, `pm clear`, bug template.

---

## Key files

**Antonym Rush**
- `lib/features/games/antonym_rush/application/cubit/antonym_rush_cubit.dart`
- `lib/features/games/antonym_rush/presentation/screens/antonym_rush_screen.dart`
- `lib/features/games/antonym_rush/domain/services/antonym_difficulty_service.dart`
- `lib/features/games/antonym_rush/domain/services/antonym_round_generator.dart`
- `lib/features/games/antonym_rush/data/antonym_pairs.dart`
- `test/antonym_rush_cubit_test.dart`
- `tool/sim_60s_session.dart`

**Association**
- `lib/features/games/association/application/cubit/association_cubit.dart`
- `lib/features/games/association/domain/services/association_round_generator.dart`
- `lib/features/games/association/domain/services/association_difficulty_service.dart`
- `lib/features/games/association/data/association_prompts.dart`
- `lib/features/games/association/presentation/screens/association_screen.dart`
- `lib/features/games/association/presentation/screens/association_results_screen.dart`
- `test/association_cubit_test.dart`
- `tool/sim_association_60s_session.dart`

**Sequencing Memory**
- `lib/features/games/sequencing_memory/application/cubit/sequencing_memory_cubit.dart`
- `lib/features/games/sequencing_memory/domain/services/sequencing_audio_service.dart`
- `lib/features/games/sequencing_memory/domain/services/sequencing_round_generator.dart`
- `lib/features/games/sequencing_memory/domain/services/sequencing_scoring_service.dart`
- `lib/features/games/sequencing_memory/data/sequencing_prompts.dart`
- `lib/features/games/sequencing_memory/presentation/screens/sequencing_memory_screen.dart`
- `lib/features/games/sequencing_memory/presentation/screens/sequencing_memory_results_screen.dart`
- `test/sequencing_memory_cubit_test.dart`

**Commas**
- `lib/features/games/commas/application/cubit/commas_cubit.dart`
- `lib/features/games/commas/domain/services/comma_round_generator.dart`
- `lib/features/games/commas/domain/services/comma_scoring_service.dart`
- `lib/features/games/commas/data/comma_prompts.dart`
- `lib/features/games/commas/presentation/screens/commas_screen.dart`
- `lib/features/games/commas/presentation/screens/commas_results_screen.dart`
- `lib/features/games/commas/presentation/widgets/comma_text_area.dart`
- `test/commas_cubit_test.dart`
- `test/commas_text_area_widget_test.dart`

**Shared**
- `lib/app/router/app_router.dart`
- `lib/shared/domain/entities/game_catalog.dart`
- `lib/shared/domain/entities/game_mode.dart`

---

## Current gaps / watch list

- **Antonym:** Periodic **real device** or recorded pass to ensure escape-line timing still **feels** fair vs `roundTimeout`; if users report “Missed while tappable,” compare **`AntonymRoundTelemetry`** + **`tap_ignored`** with video frame timing.
- **Association:** **Content** quality over time (synonym nuance); hints must stay **hard-tier** for ambiguous lemmas. Optional: `integration_test` for happy paths.
- **Sequencing Memory:** Real-device TTS pacing and stop/pause/exit behavior should be checked periodically; do not expose full sequence order during listening.
- **Commas:** Text renderer/game feel is the main polish surface; preserve TextPainter hitbox alignment while tuning typography, affordances, and feedback.
- **Catalog:** Synonym Storm / Definition Match appear in UI registry; confirm scope before treating as “broken” vs “not built yet.”

---

## Decisions to preserve

- Do **not** change shared **scoring math**, **`GameResult` / `GameSessionStats`**, **routing contracts**, or shipped-mode **results** formulas unless the task explicitly says so.
- Telemetry stays **`kDebugMode`**, **log-only**, no side effects (`AntonymRoundTelemetry`, `AntonymTapTelemetry`, `[AssociationTelemetry]`).
- **Antonym:** Keep **4** options all rounds; do not revert to 3-option beginner-only layout.
- **Association:** Keep **Cubit** authoritative for timers and game end; keep **2** options per round.
- **Sequencing Memory:** Keep real TTS behind `SequencingAudioService`; mock audio remains the test/dev fallback.
- **Commas:** UI forwards only `afterTokenIndex`; Cubit decides correctness.

---

## Next steps (after your edits)

1. `flutter analyze`
2. `flutter test test/antonym_rush_cubit_test.dart`
3. `flutter test test/association_cubit_test.dart`
4. `flutter test test/sequencing_memory_cubit_test.dart`
5. `flutter test test/commas_cubit_test.dart`
6. `flutter test test/commas_text_area_widget_test.dart`
7. Optionally: `flutter test tool/sim_association_60s_session.dart` (longer run)
8. For UX-sensitive changes: manual pass per [`docs/testing/Testing_Tutorial.md`](../testing/Testing_Tutorial.md)

---

## Related doc

- **[`Agents.md`](Agents.md)** — single source for gameplay rules, validation snapshot, and contributor notes.
