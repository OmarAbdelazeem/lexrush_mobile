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

### Docs
- **[`docs/Testing_Tutorial.md`](../Testing_Tutorial.md)** — manual QA: emulator, physical device, `adb` taps/screenshots/recordings, iOS Simulator, `pm clear`, bug template.

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

**Shared**
- `lib/app/router/app_router.dart`
- `lib/shared/domain/entities/game_catalog.dart`
- `lib/shared/domain/entities/game_mode.dart`

---

## Current gaps / watch list

- **Antonym:** Periodic **real device** or recorded pass to ensure escape-line timing still **feels** fair vs `roundTimeout`; if users report “Missed while tappable,” compare **`AntonymRoundTelemetry`** + **`tap_ignored`** with video frame timing.
- **Association:** **Content** quality over time (synonym nuance); hints must stay **hard-tier** for ambiguous lemmas. Optional: `integration_test` for happy paths.
- **Catalog:** Synonym Storm / Definition Match appear in UI registry; confirm scope before treating as “broken” vs “not built yet.”

---

## Decisions to preserve

- Do **not** change shared **scoring math**, **`GameResult` / `GameSessionStats`**, **routing contracts**, or **Antonym**/**Association** **results** formulas unless the task explicitly says so.
- Telemetry stays **`kDebugMode`**, **log-only**, no side effects (`AntonymRoundTelemetry`, `AntonymTapTelemetry`, `[AssociationTelemetry]`).
- **Antonym:** Keep **4** options all rounds; do not revert to 3-option beginner-only layout.
- **Association:** Keep **Cubit** authoritative for timers and game end; keep **2** options per round.

---

## Next steps (after your edits)

1. `flutter analyze`
2. `flutter test test/antonym_rush_cubit_test.dart`
3. `flutter test test/association_cubit_test.dart`
4. Optionally: `flutter test tool/sim_association_60s_session.dart` (longer run)
5. For UX-sensitive changes: manual pass per [`docs/Testing_Tutorial.md`](../Testing_Tutorial.md)

---

## Related doc

- **[`Agents.md`](Agents.md)** — single source for gameplay rules, validation snapshot, and contributor notes.
