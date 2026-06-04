# AI Handoff Summary

Short handoff for the **next coding agent**. For the full project brief (rules, paths, validation), read [`Agents.md`](Agents.md) in this folder.

---

## What changed (recent / relevant)

### Backend / Auth / Progress Foundation
- API infrastructure is in place: `ApiConfig`, `ApiClient`, auth policies, backend error envelope parsing, and `LexRushBackendRepository`.
- Base URL stays configurable with `--dart-define=LEXRUSH_API_BASE_URL=...`; default fallback is `http://10.0.2.2:3000` for Android emulator host access.
- Auth is Bearer-token based with secure token storage, refresh-token rotation, single-flight refresh, and minimal login/register/logout UI.
- Protected calls use `Authorization: Bearer <accessToken>`; do not reintroduce `x-dev-user-id` for authenticated endpoints.
- `ProfileScreen` loads `/me/progress` and `/me/skills`, shows progress/skill state, and has unauthenticated/error/empty paths.
- All four shipped games create backend sessions and submit summary-only results. Local result screens remain immediate and non-blocking.
- Result screens use per-result sync handles, not one shared global status. Copy: `Syncing progress...`, `Progress synced`, `Progress synced · +X XP saved`, `Couldn't sync progress`, `Sign in to save progress`.
- Offline result retry queue is implemented:
  - user-scoped `PendingGameResult` items
  - dedupe/upsert by `userId + sessionId`
  - queue only authenticated submit failures after a backend `sessionId` exists
  - drain only for the same authenticated user
  - no new backend sessions during retry
  - remove on success or `SESSION_ALREADY_COMPLETED`
  - keep on retryable network/server failure, drop validation/client-contract failures

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
- Full flow under `lib/features/games/commas/`: **60s** session, backend prompt snapshots for authenticated runs with local curated fallback, no runtime grammar detection.
- `CommasCubit` owns timer, prompt selection, placed commas, wrong taps, scoring, history, and results.
- Backend snapshot mapper uses `contentJson.displayTextWithoutCommas`, prefers `contentJson.correctTextWithCommas`, and preserves `answerJson.insertionPoints[].afterTokenIndex` as the correctness source.
- If backend session creation succeeds but mapped prompts are invalid/empty, Commas falls back to local prompts and must not reuse that invalid backend session for result submission.
- Explanations display only after a prompt is submitted/completed.
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

**Backend / Auth / Profile / Queue**
- `lib/core/network/api_client.dart`
- `lib/core/network/api_auth_headers_provider.dart`
- `lib/features/auth/application/auth_cubit.dart`
- `lib/features/auth/data/auth_repository.dart`
- `lib/features/profile/application/cubit/profile_cubit.dart`
- `lib/features/profile/presentation/screens/profile_screen.dart`
- `lib/shared/data/backend/lexrush_backend_repository.dart`
- `lib/shared/application/services/backend_result_sync_service.dart`
- `lib/shared/application/services/backend_result_mappers.dart`
- `lib/shared/application/services/pending_result_queue.dart`
- `lib/shared/application/services/offline_result_retry_coordinator.dart`
- `test/backend_api_test.dart`
- `test/backend_result_sync_service_test.dart`
- `test/offline_result_retry_queue_test.dart`
- `test/auth_cubit_test.dart`
- `test/profile_cubit_test.dart`

---

## Current gaps / watch list

- **Antonym:** Periodic **real device** or recorded pass to ensure escape-line timing still **feels** fair vs `roundTimeout`; if users report “Missed while tappable,” compare **`AntonymRoundTelemetry`** + **`tap_ignored`** with video frame timing.
- **Association:** **Content** quality over time (synonym nuance); hints must stay **hard-tier** for ambiguous lemmas. Optional: `integration_test` for happy paths.
- **Sequencing Memory:** Real-device TTS pacing and stop/pause/exit behavior should be checked periodically; do not expose full sequence order during listening.
- **Commas:** Text renderer/game feel is the main polish surface; preserve TextPainter hitbox alignment while tuning typography, affordances, and feedback.
- **Backend sync:** Manual offline retry verification is still valuable: logged-in failed submit after session creation should queue, Profile/login should drain for the same user, and another user must not drain that item.
- **Auth:** Offline startup should not clear valid tokens just because `/auth/me` cannot connect.
- **Profile:** Queue drain is intentionally non-blocking; drain failures must not make Profile load fail.
- **Catalog:** Synonym Storm / Definition Match appear in UI registry; confirm scope before treating as “broken” vs “not built yet.”

---

## Decisions to preserve

- Do **not** change shared **scoring math**, **`GameResult` / `GameSessionStats`**, **routing contracts**, or shipped-mode **results** formulas unless the task explicitly says so.
- Telemetry stays **`kDebugMode`**, **log-only**, no side effects (`AntonymRoundTelemetry`, `AntonymTapTelemetry`, `[AssociationTelemetry]`).
- **Antonym:** Keep **4** options all rounds; do not revert to 3-option beginner-only layout.
- **Association:** Keep **Cubit** authoritative for timers and game end; keep **2** options per round.
- **Sequencing Memory:** Keep real TTS behind `SequencingAudioService`; mock audio remains the test/dev fallback.
- **Commas:** UI forwards only `afterTokenIndex`; Cubit decides correctness.
- **Backend result sync:** Summary-only, no `answerEvents`, decimal accuracy `0..1`, local result screens first.
- **Offline queue:** Only queue authenticated submit failures with an existing `sessionId`; queue items are scoped by `userId` and retried only for that user.
- **Auth:** Keep protected requests Bearer-only and refresh single-flight.

---

## Next steps (after your edits)

1. `flutter analyze`
2. `flutter test test/backend_api_test.dart`
3. `flutter test test/backend_result_sync_service_test.dart`
4. `flutter test test/offline_result_retry_queue_test.dart`
5. `flutter test test/auth_cubit_test.dart`
6. `flutter test test/profile_cubit_test.dart`
7. `flutter test test/antonym_rush_cubit_test.dart`
8. `flutter test test/association_cubit_test.dart`
9. `flutter test test/sequencing_memory_cubit_test.dart`
10. `flutter test test/commas_cubit_test.dart`
11. `flutter test test/commas_text_area_widget_test.dart`
12. Optionally: `flutter test tool/sim_association_60s_session.dart` (longer run)
13. For UX-sensitive changes: manual pass per [`docs/testing/Testing_Tutorial.md`](../testing/Testing_Tutorial.md)

---

## Related doc

- **[`Agents.md`](Agents.md)** — single source for gameplay rules, validation snapshot, and contributor notes.
