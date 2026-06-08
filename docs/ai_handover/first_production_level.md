# LexRush System Architecture Prompt / AI Handoff Guide

## 0. Purpose

This document is the dense architecture handoff for a fresh AI thread. Read it before making changes to the LexRush Flutter app or backend. It captures the product vision, current implementation state, architecture, backend contract, roadmap, and strict validation rules used when reviewing Claude/Codex output.

LexRush is no longer just a set of local game prototypes. It now has 4 playable Flutter games, backend result sync, XP/streak/skill progression, and a first Profile/Progress screen. The next phase is production foundation, not more games.

---

# 1. Core Product Vision

## 1.1 Product

**LexRush** is a premium mobile cognitive-training and language-skills app inspired by the quality bar of apps like Elevate, but with original identity, game design, visual system, content, and backend architecture.

## 1.2 What LexRush Trains

LexRush focuses on:

- vocabulary
- grammar
- punctuation
- semantic reasoning
- memory
- focus
- precision
- reading/writing skills
- eventually listening/speaking skills

## 1.3 Target User

Primary users:

- English learners improving vocabulary, grammar, and comprehension
- advanced/native English speakers sharpening communication precision
- students preparing for academic/exam writing
- professionals improving writing and language agility
- users who like short daily brain-training sessions

## 1.4 Product Goal

Build a connected training platform where every game contributes to:

- XP
- streaks
- skill mastery
- progress/profile
- achievements
- daily training habits
- adaptive difficulty later

Do not think of LexRush as “40 separate games.” Think of it as a product ecosystem where mini-games feed one progression engine.

## 1.5 Quality Bar

LexRush should feel:

- premium
- polished
- habit-forming
- fast where appropriate
- calm where appropriate
- educational without feeling academic
- game-like without being childish
- competitive with high-quality training apps

Important principle:

```text
Match Elevate-level quality, but do not copy Elevate assets, exact visuals, proprietary content, or UI screens.
```

---

# 2. Current Product State

## 2.1 Built So Far

Flutter app:

- 4 playable mini-games
- backend API layer
- generalized backend result sync
- Profile/Progress screen
- local result screens
- dark premium LexRush style

Backend:

- NestJS + Prisma
- game sessions
- result submission
- XP ledger
- streaks
- skill EMA updates
- progress endpoint
- skills endpoint
- validation/error envelope
- smoke test script

Current connected flow:

```text
Play local game -> local results shown -> backend result sync -> XP/streak/skills update -> Profile screen fetches progress
```

## 2.2 Current Non-Production Gaps

Still missing:

- robust authentication
- backend-driven dynamic content
- achievements
- daily training loop
- result-screen sync feedback
- offline retry queue
- analytics/crash reporting
- production deployment/env setup
- larger curated content banks
- polished Profile v2
- answerEvents
- backend prompt snapshots consumed by Flutter gameplay

---

# 3. Tech Stack

## 3.1 Flutter Mobile App

Framework:

- Flutter

Language:

- Dart

State management:

- BLoC/Cubit

Architecture:

- clean architecture
- feature-based folders
- Cubit owns game state and lifecycle
- UI renders state and forwards input
- backend sync isolated outside gameplay logic where possible

Networking:

- `package:http`
- centralized API client
- centralized auth/dev header provider
- DTO/model layer
- repository layer

Backend base URL:

```dart
String.fromEnvironment('LEXRUSH_API_BASE_URL')
```

Default mobile local dev URL:

```text
http://10.0.2.2:3000
```

Override examples:

```bash
flutter run --dart-define=LEXRUSH_API_BASE_URL=http://localhost:3000
flutter run --dart-define=LEXRUSH_API_BASE_URL=http://192.168.1.20:3000
```

Temporary dev user header:

```http
x-dev-user-id: dev-user-001
```

This must remain centralized so it can later be replaced with:

```http
Authorization: Bearer <access_token>
```

## 3.2 Backend

Framework:

- NestJS

Language:

- TypeScript

ORM:

- Prisma

Database:

- Prisma-managed DB, likely PostgreSQL/local dev DB depending environment

Validation:

- NestJS `ValidationPipe`
- custom exception factory
- consistent backend error envelope

Testing:

- unit tests
- e2e tests
- smoke test script

---

# 4. Flutter Code Architecture

## 4.1 Feature Structure

Game features should follow this style:

```text
lib/features/games/<game_name>/
  data/
  domain/
    entities/
    services/
  application/
    cubit/
    services/
  presentation/
    screens/
    widgets/
```

## 4.2 Clean Architecture Rules

UI:

- renders state
- forwards taps/drags/reorder events
- owns only presentation animation
- does not decide correctness

Cubit:

- owns gameplay state
- owns timers and lifecycle
- computes score/results
- handles pause/resume/restart/end
- guards against duplicate resolution
- should not directly perform backend HTTP sync unless explicitly justified

Backend sync service:

- creates backend session
- submits summary result
- handles backend failures
- fetches progress/skills after success
- must not block local result screen

## 4.3 Existing Network Layer

Expected areas:

```text
lib/core/network/
  api_config.dart
  api_client.dart
  api_auth_headers_provider.dart
  api_exception.dart

lib/shared/data/backend/
  DTO/model files
  lexrush_backend_repository.dart
```

Expected shared result sync:

```text
backend_result_sync_service.dart
backend_result_mappers.dart
```

Behavior:

- no `answerEvents` sent yet
- summary result only
- progress/skills fetched after successful sync
- failures are non-blocking
- `SESSION_ALREADY_COMPLETED` handled gracefully

---

# 5. Backend API Contract

## 5.1 User Header

Current user-scoped endpoints require:

```http
x-dev-user-id: dev-user-001
```

Required for:

```text
POST /game-sessions
POST /game-sessions/:sessionId/results
GET /me/progress
GET /me/skills
```

Not currently required:

```text
GET /game-sessions/:sessionId
```

## 5.2 Create Game Session

Endpoint:

```http
POST /game-sessions
```

Request:

```json
{
  "gameId": "commas"
}
```

Known game IDs:

```text
antonym_rush
association
sequencing_memory
commas
```

Response includes:

- `sessionId`
- `gameId`
- prompt snapshot data
- `prompts[].promptId`

Important: Flutter currently does **not** consume backend prompt snapshots for gameplay. It still uses local content. Prompt snapshots are for later.

## 5.3 Submit Result

Endpoint:

```http
POST /game-sessions/:sessionId/results
```

First-pass request body:

```json
{
  "score": 750,
  "accuracy": 0.8,
  "totalAttempts": 10,
  "correctAnswers": 8,
  "wrongAnswers": 2,
  "missedAnswers": 0,
  "wordsSolved": 8,
  "bestCombo": 4,
  "averageResponseTimeMs": 2100
}
```

Critical rule:

```text
Flutter UI may show 80%, but API accuracy must be 0.8. Never send 80.
```

`answerEvents` are optional and currently omitted.

Expected response:

```json
{
  "resultId": "result-uuid",
  "sessionId": "session-uuid",
  "gameId": "commas",
  "score": 750,
  "accuracy": 0.8,
  "xpEarned": 37,
  "totalAttempts": 10,
  "correctAnswers": 8,
  "wrongAnswers": 2,
  "missedAnswers": 0,
  "createdAt": "2026-05-26T18:00:00.000Z"
}
```

## 5.4 Progress Endpoint

```http
GET /me/progress
```

Response:

```json
{
  "userId": "dev-user-001",
  "totalXp": 157,
  "currentStreak": 3,
  "longestStreak": 7,
  "lastTrainingDay": "2026-05-26",
  "sessionsCompleted": 5
}
```

`lastTrainingDay` may be `null`.

## 5.5 Skills Endpoint

```http
GET /me/skills
```

Response:

```json
{
  "userId": "dev-user-001",
  "skills": [
    {
      "skillId": "grammar",
      "level": 3,
      "masteryScore": 0.34,
      "accuracy": 0.4,
      "recentTrend": "improving",
      "confidence": 0.35
    }
  ]
}
```

Empty state is valid:

```json
{
  "userId": "dev-user-001",
  "skills": []
}
```

Suggested UI:

```text
Complete your first session to unlock skill insights.
```

## 5.6 Error Envelope

All backend errors use:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable message."
  }
}
```

Known error codes:

```text
VALIDATION_ERROR            400
SESSION_ACCESS_DENIED      403
SESSION_ALREADY_COMPLETED  409
INVALID_PROMPT_ID          422
USER_NOT_FOUND             404
```

---

# 6. Backend Phase 4 Verified State

Backend smoke test exists:

```text
scripts/smoke-phase4.ts
```

Run:

```bash
npm run start:dev
npm run smoke:phase4
```

The smoke test verifies:

- session creation
- result submission without `answerEvents`
- progress fetch
- skills fetch
- duplicate submission returns 409
- invalid accuracy returns validation error
- missing user header returns validation error

Known successful output:

```text
All 35 assertions passed.
```

Verified backend properties:

- XP is ledger-based
- duplicate results do not double-award XP
- skills update after result submission
- summary result submission works
- Commas links to grammar/punctuation/precision skills
- Association also updates semantic reasoning/vocabulary skills

---

# 7. Existing Games

## 7.1 Antonym Rush

Status:

- playable
- backend sync wired

Core mechanic:

- target word
- floating balloons
- tap antonym

Current behavior:

- 4 balloons
- 1 correct antonym
- 3 distractors
- correct score/combo
- wrong penalty
- missed behavior
- difficulty tiers
- beginner ramp
- results stats
- backend sync

Important lesson:

```text
Never allow animation completion to be the sole source of gameplay lifecycle truth.
```

Future polish:

- more word pairs
- stronger visual/game feel
- better first-session tuning
- backend-driven prompt content later

## 7.2 Association

Status:

- playable
- backend sync wired

Core mechanic:

- target root node
- two semantic association choices
- tap closest match

Current behavior:

- 60-second session
- graph UI
- correct path glow
- wrong explanation
- context hints for ambiguous prompts
- review screen
- backend sync

Future polish:

- larger prompt bank
- better semantic data quality
- stronger animation/game feel
- hard-only ambiguous prompts

## 7.3 Sequencing Memory

Status:

- playable
- real TTS
- backend sync wired

Core mechanic:

- listen to spoken sequence
- reorder shuffled cards
- combined recall challenge

Session model:

```text
3 route challenges
no lives
no global timer
```

Stages:

```text
Listen Part One
Arrange Part One
Feedback Part One
Listen Part Two
Arrange Part Two
Feedback Part Two
Arrange Combined
Feedback Combined
```

Future polish:

- disable debug spoken captions for production
- improve listening screen
- smoother reorder feel
- more route data
- premium voice/audio strategy later

## 7.4 Commas

Status:

- playable
- backend sync wired
- frozen as v1 beta

Core mechanic:

- sentence with missing commas
- tap spaces where commas belong

Important implementation:

- one continuous `RichText`
- `TextPainter` measures gaps
- transparent overlay hitboxes
- Cubit receives `afterTokenIndex`
- commas attach directly to previous word

Future polish:

- stronger local feedback
- more cinematic punctuation UI
- larger prompt bank
- prompt ordering
- review hierarchy

---

# 8. Current Profile / Progress Screen

Route:

```text
/profile
```

Access:

- compact Progress button on Mode Selection

Current implementation:

```text
lib/features/profile/
  ProfileCubit
  ProfileState
  ProfileRepository
  BackendProfileRepository
  ProfileScreen
```

Fetches:

```text
GET /me/progress
GET /me/skills
```

Displays:

- total XP
- current streak
- longest streak
- sessions completed
- last training day
- skill cards
- level
- mastery percentage
- accuracy percentage
- trend
- confidence percentage

States:

- loading
- loaded
- emptySkills
- error

Future direction:

- Performance tab
- Achievements tab
- richer skill bars
- profile identity
- achievement list
- more Elevate-level profile polish without copying assets

---

# 9. Strict Validation Rules for Claude/Codex Code

## 9.1 Product Rules

- Do not copy Elevate assets, exact visuals, proprietary content, or UI screens.
- Mechanics can be inspired; implementation and art must be original.
- Do not add more games before platform foundation unless explicitly requested.
- Every feature should strengthen the connected training product.

## 9.2 Architecture Rules

- Preserve clean architecture and BLoC/Cubit.
- UI renders state and forwards input.
- Cubit owns gameplay state/lifecycle.
- Backend sync should be isolated from core gameplay.
- Local gameplay must work even when backend is down.
- Avoid unnecessary rewrites.
- Keep mappers small and testable.

## 9.3 Backend Sync Rules

- Result screens must not wait for backend.
- Accuracy must be decimal `0..1`.
- Do not send `answerEvents` yet.
- Handle `SESSION_ALREADY_COMPLETED` gracefully.
- Backend/network failures must not break gameplay.
- `x-dev-user-id` must stay centralized until real auth replaces it.
- Base URL must be configurable via dart-define.
- Android emulator default should be `http://10.0.2.2:3000`.

## 9.4 Game Logic Rules

- Animations must not be the only source of lifecycle truth.
- Clear timers on pause/restart/completion/close.
- Prevent duplicate round/stage resolution.
- Avoid stale callbacks.
- Use curated data; do not use runtime AI answer detection.
- Beginner experience must be fair and confidence-building.

## 9.5 UI/UX Rules

- Core interaction should be the visual hero.
- Feedback should be local, obvious, and brief.
- Wrong feedback should teach, not shame.
- Review screens should use user-friendly wording.
- Text games must preserve readability and natural text flow.
- Mobile touch targets must be generous.
- Avoid developer-facing labels in user UI.

## 9.6 Data Rules

- Association ambiguous prompts need context hints.
- Commas prompts need verified insertion points and explanations.
- Antonym pairs must be fair and tiered.
- Sequencing routes must be listenable and memorable.
- Production requires much larger curated banks than current V1 local data.

## 9.7 Backend Rules

- Result submission must be transactional.
- XP ledger is source of truth.
- Duplicate results must not double-count XP.
- Validation errors must use consistent envelope.
- Smoke test must remain passing.
- Do not break Phase 4 contract without updating Flutter/docs.

## 9.8 Testing Rules

Flutter expected commands:

```bash
flutter analyze
flutter test test/backend_api_test.dart
flutter test test/commas_cubit_test.dart
flutter test test/commas_text_area_widget_test.dart
flutter test test/antonym_rush_cubit_test.dart
flutter test test/association_cubit_test.dart
flutter test test/sequencing_memory_cubit_test.dart
```

Backend expected commands:

```bash
npm run test
npm run test:e2e
npm run smoke:phase4
```

Every AI implementation report should include:

- files changed
- architecture changes
- tests run
- manual test if UI/network feature
- assumptions
- known limitations
- any skipped tests

## 9.9 Review Checklist

When reviewing Claude/Codex output, check:

1. Did it preserve architecture?
2. Did it avoid unnecessary rewrites?
3. Did it keep local gameplay independent from backend?
4. Did tests pass?
5. Did it map stats correctly?
6. Did it avoid `answerEvents` for now?
7. Did it centralize auth/base URL config?
8. Did it handle errors gracefully?
9. Did it avoid copying Elevate visuals/assets?
10. Did it improve product quality without scope creep?

---

# 10. Roadmap

## 10.1 Completed

- 4 local playable games
- backend Phase 4 result/progress system
- backend smoke test
- Flutter API layer
- generalized result sync for all games
- Profile/Progress screen
- XP/streak/skills visible in app

## 10.2 Immediate Priorities

Do not create more games yet.

Priority order:

1. Result-screen sync status
   - show “Progress synced”
   - show `+XP saved`
   - show non-blocking offline state if failed

2. Production authentication
   - register/login/refresh/logout/me
   - JWT access token
   - refresh token
   - Flutter secure storage
   - replace `x-dev-user-id`

3. Dynamic backend-driven content
   - backend prompt banks
   - session prompt selection
   - Flutter consumes backend prompt snapshots
   - local fallback
   - no immediate repetition

4. Profile v2 / Achievements
   - Performance tab
   - Achievements tab
   - achievement progress
   - skill categories
   - richer profile polish

5. Daily training / Today loop
   - daily recommended workout
   - training completion
   - habit formation

## 10.3 Medium-Term Priorities

- offline result sync queue
- analytics and crash reporting
- Swagger/OpenAPI docs if not already present
- environment configs
- larger curated content banks
- design system consolidation
- account settings/privacy/delete account

## 10.4 Later Priorities

- answerEvents
- adaptive difficulty
- backend-driven prompt snapshots for all games
- more games
- leagues/rankings
- subscriptions/paywall
- social sharing
- content admin tooling

---

# 11. Recommended Next Task

Best next implementation task:

```text
Add lightweight result-screen sync status and XP saved feedback across result screens, using the existing BackendResultSyncService.
```

Second-best task:

```text
Plan and implement production auth replacing x-dev-user-id with JWT.
```

Suggested prompt for a new AI thread:

```text
Read guide.md first. We are continuing LexRush from this architecture handoff. Do not create new games yet. We are moving into production foundation work for the existing 4-game connected app.
```

---

# 12. Non-Negotiable Principles

1. Local gameplay must stay playable even if backend is down.
2. Backend progress must never double-count duplicate results.
3. Every game should contribute to XP, streaks, and skills.
4. User progress must become visible and motivating.
5. Dynamic content must eventually replace repeated static local prompts.
6. Do not copy Elevate. Match quality, not assets or exact implementation.
7. Build a connected training platform, not a folder of mini-games.
8. Build platform quality before game quantity.
