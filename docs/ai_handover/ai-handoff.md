# AI Handoff Summary

Short current-status handoff for the next coding agent. For full architecture, gameplay rules, backend/auth/offline contracts, validation commands, paths, and do-not-break constraints, read [`Agents.md`](Agents.md). Historical production-readiness context is in [`first_production_level.md`](first_production_level.md).

## Current Status

- LexRush mobile has four shipped Flutter games: **Antonym Rush**, **Association**, **Sequencing Memory**, and **Commas**.
- All four games are routable through mode selection/pre-game/gameplay/results.
- All four games create backend sessions and submit summary-only results when authenticated.
- All four games now consume backend prompt snapshots when authenticated and the backend returns valid mapped snapshots.
- All four keep local fallback for logged-out, offline, backend-down, session-creation failure, and invalid/empty snapshot cases.
- Result screens remain immediate and non-blocking, with per-result sync handles.
- Auth uses Bearer tokens, secure storage, single-flight refresh, refresh-token rotation, rate-limit handling, and token reuse detection.
- Profile/Progress and Achievements are wired to backend progress/skills/achievement state.
- User-scoped offline result retry queue is implemented.

## Latest Major Milestones

- Azure QA backend is live:
  - `https://lexrush-api-qa-caduagh0fpebc5ef.uaenorth-01.azurewebsites.net`
- Azure QA health works.
- Swagger works when enabled.
- Backend `smoke:prod` passed with **57 assertions**.
- Backend production readiness is complete:
  - auth rate limiting
  - Swagger production gating
  - env validation + CORS hardening
  - refresh token cleanup
  - refresh token family/reuse detection
  - production-safe content seed
  - stable prompt slug/upsert seeding
  - production Bearer smoke test
- Mobile app was manually verified against Azure QA.
- Signed-in Commas used backend prompts and synced successfully.
- Result screen showed `Progress synced · +52 XP saved`.
- Profile reflected synced XP/session/streak.
- Today, Profile, and Achievements loaded against Azure QA.
- Logged-out local fallback worked.
- Invalid-backend fallback worked.
- `flutter analyze` passed.
- Full `flutter test` passed in the latest QA pass.
- Android IDs are production-aligned:
  - `applicationId`: `com.lexrush.app`
  - debug suffix: `com.lexrush.app.debug`
  - app label: `LexRush`
- Release signing guard exists and release builds fail clearly without `android/key.properties`.
- Analytics/crash foundation exists, but real vendor adapter is postponed.
- API base URL release fail-fast is postponed until store publishing.

## Current Watch List

- **Next focused mobile polish task:** fix AuthScreen keyboard overflow on Android emulator.
  - Flutter reported `RenderFlex overflowed by 15 pixels on the bottom`.
  - Source reported: `lib/features/auth/presentation/screens/auth_screen.dart:64:22`.
  - Trigger: keyboard visible on auth/register form.
- **Offline queue manual QA:** still worth periodically verifying authenticated submit failure after session creation queues, drains only for the same user, and does not create new sessions during retry.
- **Antonym Rush fairness:** periodically verify real-device/video timing so escape-line presentation and `roundTimeout` never feel like a still-tappable miss.
- **Association content QA:** keep ambiguous/hinted prompts hard-tier only and keep semantic choices fair.
- **Sequencing Memory TTS:** periodically verify real-device TTS pacing, pause/exit cleanup, and failsafe behavior. Emulator used in latest QA had Google TTS available.
- **Commas renderer:** preserve TextPainter-measured hitboxes and attached comma rendering while polishing typography/game feel.

## Next-Step Orientation

1. Start with [`Agents.md`](Agents.md) for full rules before changing behavior.
2. For mobile release/build QA, use [`docs/deployment/mobile_release_runbook.md`](../deployment/mobile_release_runbook.md).
3. For emulator/device manual QA, use [`docs/testing/Testing_Tutorial.md`](../testing/Testing_Tutorial.md).
4. For backend Azure deployment details, use the backend repo Azure QA deployment cookbook unless it is later copied into mobile docs.
5. For current mobile polish, focus on the AuthScreen keyboard overflow first.

## Validation Snapshot

Latest full QA passed:

```bash
flutter analyze
flutter test
```

Targeted core suite to run after focused changes:

```bash
flutter test test/backend_api_test.dart
flutter test test/auth_cubit_test.dart
flutter test test/backend_result_sync_service_test.dart
flutter test test/offline_result_retry_queue_test.dart
```

Azure QA manual verification command:

```bash
flutter run --dart-define=LEXRUSH_API_BASE_URL=https://lexrush-api-qa-caduagh0fpebc5ef.uaenorth-01.azurewebsites.net
```

## Preserve These Behaviors

- Result submission remains summary-only.
- Do not send `answerEvents`.
- API accuracy stays decimal `0..1`.
- Protected backend calls use Bearer auth.
- Refresh is single-flight.
- `RATE_LIMITED` is handled gracefully.
- `REFRESH_TOKEN_REUSE_DETECTED` clears tokens and signs out.
- Offline queue is user-scoped and drains only for the same user.
- Result screens remain immediate and non-blocking.
- Backend prompt sessions are reused only when mapped snapshots are valid.
- Invalid backend snapshots fall back locally and do not submit against invalid sessions.
- Sequencing Memory TTS failsafe remains in place.
