# LexRush Canonical Project Brief

This is the canonical full guide for the LexRush mobile project. Keep this file as the source of truth for architecture, gameplay contracts, backend sync behavior, auth/offline rules, testing, important paths, and do-not-break constraints.

For a short current-status handoff, read [`ai-handoff.md`](ai-handoff.md). For historical production-readiness context, read [`first_production_level.md`](first_production_level.md). For release and manual QA details, use [`docs/deployment/mobile_release_runbook.md`](../deployment/mobile_release_runbook.md) and [`docs/testing/Testing_Tutorial.md`](../testing/Testing_Tutorial.md). The backend Azure QA deployment cookbook lives in the backend repo unless copied into mobile docs later.

## Product Snapshot

- **Project:** LexRush
- **Current platform:** Flutter
- **Android applicationId:** `com.lexrush.app`
- **Android debug applicationId:** `com.lexrush.app.debug`
- **Android app label:** `LexRush`
- **Shipped gameplay modes:** **Antonym Rush**, **Association**, **Sequencing Memory**, and **Commas**
- **Target experience:** Premium-feeling language/cognitive training: fast where appropriate, calm where appropriate, readable, fair, and habit-forming.
- **Product loop:** local gameplay -> immediate result screen -> non-blocking backend sync -> XP/streak/skills/achievements/Profile updates.

## Current Production-Readiness Status

- Flutter app flow is implemented: splash -> onboarding -> mode selection/Today -> pre-game -> gameplay -> results -> Profile/Progress.
- All four shipped games are playable end-to-end and have backend result sync.
- All four shipped games consume backend prompt snapshots when the user is authenticated and the backend returns valid mapped snapshots:
  - `commas`
  - `association`
  - `antonym_rush`
  - `sequencing_memory`
- All four preserve local fallback for logged-out, offline, backend-down, session-creation failure, and invalid/empty snapshot cases.
- Backend result submission remains summary-only; no `answerEvents` are sent.
- Auth is Bearer-token based with persisted access/refresh tokens, single-flight refresh, refresh-token rotation, rate-limit handling, and reuse detection.
- Profile/Progress and Achievements load from backend progress/skills/achievement state.
- User-scoped offline result retry queue is implemented and drains non-blockingly on auth/profile flows.
- Analytics/crash abstraction exists, but real vendor adapters are postponed.
- API base URL release fail-fast is postponed until store publishing.
- Release signing guard exists: release builds fail clearly when `android/key.properties` is missing.

## Azure QA / Backend Milestones

- Azure QA backend deployment is live:
  - `https://lexrush-api-qa-caduagh0fpebc5ef.uaenorth-01.azurewebsites.net`
- Azure QA backend health works.
- Swagger works when enabled.
- Backend `smoke:prod` passed with **57 assertions**.
- Mobile app was verified against the Azure QA backend with:

```bash
flutter run --dart-define=LEXRUSH_API_BASE_URL=https://lexrush-api-qa-caduagh0fpebc5ef.uaenorth-01.azurewebsites.net
```

- Latest Azure QA mobile pass verified:
  - app starts
  - register/login/logout works
  - Today loads
  - Profile and Achievements load
  - signed-in Commas used backend prompts and synced successfully
  - result screen showed `Progress synced · +52 XP saved`
  - Profile reflected XP/session/streak after sync
  - logged-out local fallback worked
  - invalid-backend fallback worked
  - `flutter analyze` passed
  - full `flutter test` passed

## Backend Production-Readiness Complete

Backend production foundation is considered complete for the current phase:

- auth rate limiting
- Swagger production gating
- environment validation and CORS hardening
- refresh token cleanup
- refresh token family/reuse detection
- production-safe content seed
- stable prompt slug/upsert seeding
- production Bearer smoke test

## Architecture and Stack

- **State management:** `flutter_bloc` / Cubit
- **Routing:** `go_router`
- **Layering:** feature-based clean-ish architecture using `data`, `domain`, `application`, and `presentation`
- **Shared services:** scoring, replay goals, timer manager, game registry
- **Backend/API:** `ApiClient`, `ApiConfig`, `ApiAuthHeadersProvider`, `AuthRepository`, `LexRushBackendRepository`
- **Persistence:** onboarding/progress local state, secure token storage, pending backend result queue
- **TTS:** Sequencing Memory runtime audio through `SequencingAudioService`; Android/iOS device TTS through `flutter_tts`

Feature folders should generally follow:

```text
lib/features/games/<game>/
  data/
  domain/
  application/
  presentation/
```

UI renders state and forwards user input. Cubits own correctness, scoring, timers, lifecycle, game completion, and result construction. Backend sync is isolated from immediate gameplay/result rendering.

## Backend and Sync Rules

- Local gameplay and local result screens are authoritative and immediate.
- Backend sync must never block gameplay, result navigation, replay, or returning to modes.
- Backend base URL is configurable with `--dart-define=LEXRUSH_API_BASE_URL=...`.
- Android emulator local fallback remains `http://10.0.2.2:3000`.
- Protected backend calls use `Authorization: Bearer <accessToken>`.
- Do not reintroduce `x-dev-user-id` for authenticated mobile endpoints.
- Result submission is summary-only.
- Do **not** send `answerEvents`.
- API `accuracy` must be decimal `0..1`; never send UI percentages like `80`.
- `SESSION_ALREADY_COMPLETED` is graceful success/already-synced behavior.
- Result-screen sync copy:
  - `Syncing progress...`
  - `Progress synced`
  - `Progress synced · +X XP saved`
  - `Couldn't sync progress`
  - `Sign in to save progress`

## Auth Rules

- Auth requests use explicit auth policy:
  - public: register, login, refresh, logout, health/catalog endpoints
  - required auth: game sessions/results, `/me/progress`, `/me/skills`, `/auth/me`
- Refresh is single-flight.
- On protected `401 UNAUTHORIZED`, refresh once, persist rotated access/refresh tokens, then retry once.
- Clear tokens only on confirmed invalid/revoked refresh token, `REFRESH_TOKEN_REUSE_DETECTED`, or unrecoverable auth failure.
- `RATE_LIMITED` is handled gracefully and must not clear valid stored tokens.
- Offline `/auth/me` failure should not clear valid stored tokens.
- Logout clears local tokens even if backend logout fails.

## Offline Retry Rules

- Queue only authenticated result submit failures when a backend `sessionId` already exists.
- Include `userId`, `gameId`, `sessionId`, summary request JSON, timestamps, and retry metadata.
- Deduplicate/upsert by `userId + sessionId`.
- Drain only items whose `userId` matches the current authenticated user.
- Never create a new backend session during retry in the current phase.
- Do not queue logged-out/auth-required results, session creation failures without a `sessionId`, validation/client-contract bugs, or invalid decimal accuracy.
- Remove on successful submit or `SESSION_ALREADY_COMPLETED`.
- Keep retryable network/server failures queued.
- Keep queue bounded and robust against corrupt JSON/items.

## Backend Prompt Snapshot Rules

- All four shipped games attempt backend prompt snapshots on authenticated runs.
- Local fallback must remain for every game.
- Backend prompt sessions are reused for result submission only when mapped snapshots are valid and used for gameplay.
- If backend session creation succeeds but snapshots map to empty/invalid gameplay prompts, fall back locally and do not submit against that invalid session.
- Logged-out games must use local prompts and show `Sign in to save progress` on results.
- Invalid-backend/backend-down runs must fall back locally and keep gameplay usable.
- Snapshot mappers must be strict enough to avoid corrupt gameplay state, but permissive enough to skip individual bad prompts in mixed payloads.

## Gameplay Rules

### Antonym Rush

- Session length: 60 seconds.
- Correct answer: `+100`.
- Wrong answer: `-3s`.
- Missed answer: `-2s`; miss time penalty is skipped for rounds `1-5`.
- Four options every round.
- Rounds `1-5` use beginner-safe pairs and slower `4.0s` speed.
- Hard-pair preference must not occur before `15s` remaining.
- Balloon escape completion can resolve misses, but `roundTimeout` remains a safety net using `expectedWindowMs + 2000ms` with phase floors.
- Keep telemetry debug-only/log-only.

### Association

- Session length: 60 seconds.
- Target word plus exactly two shuffled options.
- Correct: `+100`.
- Wrong: `-3s`, combo resets.
- Missed: `-2s`, combo resets; miss time penalty is skipped for rounds `1-5`.
- First five rounds use beginner-safe prompts.
- Hard tier only when `secondsLeft <= 15`.
- First 20 seconds of the clock (`secondsLeft >= 40`, after beginner rounds) stays easy regardless of `wordsSolved`.
- Ambiguous prompts with `contextHint` are hard-only in seeded data.
- Results use shared `GameResult` / `GameSessionStats` plus Association review.

### Sequencing Memory

- Session length: exactly 3 route challenges.
- No lives and no global timer.
- Stage flow: `ready -> listenPartOne -> arrangePartOne -> feedbackPartOne -> listenPartTwo -> arrangePartTwo -> feedbackPartTwo -> arrangeCombined -> feedbackCombined`.
- Audio goes through `SequencingAudioService`.
- Runtime uses `DeviceTtsSequencingAudioService`; tests use mock/controlled services.
- Listening must not expose the full card order.
- Debug spoken caption is developer-only and must not drive logic.
- Replay: 1 replay per part before submit; combined recall has no replay.
- Scoring: perfect part one `+100`, perfect part two `+100`, perfect combined `+200`, partial `+20` per correctly positioned item.
- Replay count is tracked but does not subtract points.
- Sequencing Memory TTS failsafe is implemented; stale/duplicate audio progress is guarded by playback id and stage checks.
- Results include review, replay count, longest sequence remembered, perfect stages, and average recall time.

### Commas

- Session length: 60 seconds.
- No lives.
- Correct comma: `+100`.
- Prompt complete bonus: `+100`.
- Wrong tap: `-3s`.
- Score does not decrease.
- Cubit owns correctness; UI forwards stable gap ids / `afterTokenIndex`.
- Backend mapping uses `contentJson.displayTextWithoutCommas`, prefers `contentJson.correctTextWithCommas`, and uses `answerJson.insertionPoints[].afterTokenIndex` as correctness source.
- Explanation displays only after the user submits/completes that prompt.
- Renderer uses one natural-prose `RichText` plus TextPainter-measured transparent `CommaGapDetector` hitboxes.
- Keep commas visually attached to the previous word.
- Do not add runtime AI grammar detection for V1.

## Known Current Issue

- **AuthScreen keyboard overflow on Android emulator**
  - Flutter reported: `RenderFlex overflowed by 15 pixels on the bottom`.
  - Source reported: `lib/features/auth/presentation/screens/auth_screen.dart:64:22`.
  - Trigger: keyboard visible on the auth/register form.
  - This is the next focused mobile polish task.

## Validation and Testing

Run after substantive source changes:

```bash
flutter analyze
flutter test test/backend_api_test.dart
flutter test test/backend_result_sync_service_test.dart
flutter test test/offline_result_retry_queue_test.dart
flutter test test/auth_cubit_test.dart
flutter test test/profile_cubit_test.dart
flutter test test/antonym_rush_cubit_test.dart
flutter test test/association_cubit_test.dart
flutter test test/sequencing_memory_cubit_test.dart
flutter test test/commas_cubit_test.dart
flutter test test/commas_text_area_widget_test.dart
```

Prompt snapshot and production-readiness suites that are especially relevant now:

```bash
flutter test test/antonym_rush_backend_prompt_test.dart
flutter test test/association_backend_prompt_test.dart
flutter test test/sequencing_memory_backend_prompt_test.dart
flutter test test/commas_backend_prompt_test.dart
flutter test test/analytics_instrumentation_test.dart
flutter test test/profile_achievements_widget_test.dart
```

Latest QA pass:

- `flutter analyze` passed.
- Full `flutter test` passed.

Manual Azure QA command:

```bash
flutter run --dart-define=LEXRUSH_API_BASE_URL=https://lexrush-api-qa-caduagh0fpebc5ef.uaenorth-01.azurewebsites.net
```

For manual emulator/device QA, use [`docs/testing/Testing_Tutorial.md`](../testing/Testing_Tutorial.md). For Android release/build details, use [`docs/deployment/mobile_release_runbook.md`](../deployment/mobile_release_runbook.md).

## Important Paths

### Antonym Rush

- `lib/features/games/antonym_rush/application/cubit/antonym_rush_cubit.dart`
- `lib/features/games/antonym_rush/application/services/antonym_rush_backend_bootstrap.dart`
- `lib/features/games/antonym_rush/data/antonym_prompt_snapshot_mapper.dart`
- `lib/features/games/antonym_rush/domain/services/antonym_difficulty_service.dart`
- `lib/features/games/antonym_rush/domain/services/antonym_round_generator.dart`
- `lib/features/games/antonym_rush/presentation/screens/antonym_rush_screen.dart`

### Association

- `lib/features/games/association/application/cubit/association_cubit.dart`
- `lib/features/games/association/application/services/association_backend_bootstrap.dart`
- `lib/features/games/association/data/association_prompt_snapshot_mapper.dart`
- `lib/features/games/association/domain/services/association_round_generator.dart`
- `lib/features/games/association/domain/services/association_difficulty_service.dart`
- `lib/features/games/association/presentation/screens/association_screen.dart`
- `lib/features/games/association/presentation/screens/association_results_screen.dart`

### Sequencing Memory

- `lib/features/games/sequencing_memory/application/cubit/sequencing_memory_cubit.dart`
- `lib/features/games/sequencing_memory/application/services/sequencing_memory_backend_bootstrap.dart`
- `lib/features/games/sequencing_memory/data/sequencing_prompt_snapshot_mapper.dart`
- `lib/features/games/sequencing_memory/domain/services/sequencing_audio_service.dart`
- `lib/features/games/sequencing_memory/domain/services/sequencing_round_generator.dart`
- `lib/features/games/sequencing_memory/domain/services/sequencing_scoring_service.dart`
- `lib/features/games/sequencing_memory/presentation/screens/sequencing_memory_screen.dart`
- `lib/features/games/sequencing_memory/presentation/screens/sequencing_memory_results_screen.dart`

### Commas

- `lib/features/games/commas/application/cubit/commas_cubit.dart`
- `lib/features/games/commas/application/services/commas_backend_bootstrap.dart`
- `lib/features/games/commas/data/comma_prompt_snapshot_mapper.dart`
- `lib/features/games/commas/domain/services/comma_round_generator.dart`
- `lib/features/games/commas/domain/services/comma_scoring_service.dart`
- `lib/features/games/commas/presentation/screens/commas_screen.dart`
- `lib/features/games/commas/presentation/screens/commas_results_screen.dart`
- `lib/features/games/commas/presentation/widgets/comma_text_area.dart`
- `lib/features/games/commas/presentation/widgets/comma_gap_detector.dart`

### Shared / Backend / Auth / Profile

- `lib/app/router/app_router.dart`
- `lib/core/network/api_client.dart`
- `lib/core/network/api_auth_headers_provider.dart`
- `lib/core/network/api_config.dart`
- `lib/core/network/api_exception.dart`
- `lib/features/auth/application/auth_cubit.dart`
- `lib/features/auth/data/auth_repository.dart`
- `lib/features/auth/presentation/screens/auth_screen.dart`
- `lib/features/profile/application/cubit/profile_cubit.dart`
- `lib/features/profile/presentation/screens/profile_screen.dart`
- `lib/shared/data/backend/lexrush_backend_repository.dart`
- `lib/shared/application/services/backend_result_sync_service.dart`
- `lib/shared/application/services/backend_result_mappers.dart`
- `lib/shared/application/services/pending_result_queue.dart`
- `lib/shared/application/services/offline_result_retry_coordinator.dart`
- `lib/shared/domain/entities/game_catalog.dart`
- `lib/shared/domain/entities/game_mode.dart`

## Do-Not-Break Constraints

- Do not merge this file with `ai-handoff.md`.
- Do not change shipped-mode scoring/results formulas unless explicitly requested.
- Keep result screens immediate and non-blocking.
- Keep protected backend calls Bearer-only.
- Keep refresh single-flight.
- Keep `RATE_LIMITED` graceful.
- Keep `REFRESH_TOKEN_REUSE_DETECTED` clearing tokens/signing out.
- Keep offline queue user-scoped and same-user-only.
- Keep result submission summary-only.
- Do not send `answerEvents`.
- Keep API accuracy decimal `0..1`.
- Reuse valid backend prompt sessions only when mapped snapshots are valid.
- Fall back locally for invalid backend snapshots and do not submit against invalid sessions.
- Keep Sequencing Memory audio behind `SequencingAudioService`.
- Keep Sequencing Memory TTS failsafe behavior.
- Keep debug telemetry debug-only/log-only.
- Keep release signing guard behavior.
