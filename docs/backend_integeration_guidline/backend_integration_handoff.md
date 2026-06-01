# LexRush Flutter Backend Integration Handoff

## Purpose

This document explains the current state of the LexRush Flutter app and the next integration plan for the Flutter AI agent / Codex.

The Flutter project currently contains multiple locally implemented mini-games. Until now, the app has mostly been a local playable prototype. The backend has now reached a point where Flutter should begin integrating with real backend endpoints for:

- game session creation
- result submission
- XP progression
- streaks
- skill mastery
- user progress
- user skills

Use this document as the source of context before implementing backend integration in the Flutter project.

---

# 1. Current Flutter App Status

LexRush is a mobile-first brain-training app with multiple mini-games. The Flutter app currently uses:

- clean architecture
- BLoC/Cubit
- feature-based folders
- local gameplay logic
- local result screens
- LexRush dark premium visual identity

The app has several games implemented locally. Backend integration should not rewrite these games. The first integration pass should connect sessions/results/progress while keeping local gameplay intact.

---

# 2. Games Implemented Locally So Far

## 2.1 Antonym Rush

### Status

Playable local game. It was the first major Flutter game and served as the foundation for many shared game concepts.

### Core Gameplay

The player sees a target word and taps the opposite word from floating balloon choices.

Example:

```text
Target: HAPPY
Correct answer: SAD
```

### Important Behavior

- timed session
- 4 answer balloons
- 1 correct antonym
- 3 distractors
- correct answer increases score
- wrong answer applies penalty
- missed answer behavior exists
- difficulty tiers exist
- beginner-safe tuning exists
- results screen shows score, accuracy, combo, words solved, missed words, average response time, XP

### Important Lesson

Game lifecycle should be Cubit-owned, not animation-owned. Avoid letting visual animation callbacks be the single source of truth for round completion.

---

## 2.2 Association

### Status

Playable local game. Good beta-quality version.

### Core Gameplay

The player sees a target word and two related word choices. They tap the closest semantic match.

Example:

```text
Target: DUPE
Options: TRICK / ACCUSE
Correct: TRICK
```

### Important Behavior

- 60-second session
- semantic matching
- neural-link graph visual style
- target root node connected to two option nodes
- correct path glows
- wrong answer shows explanation
- review screen shows target, selected answer, correct answer, and explanation
- context hints exist for ambiguous words
- beginner/medium/hard prompt tiers exist

### Notes

Association depends heavily on data quality. Ambiguous words should be hard-only and must include context hints.

---

## 2.3 Sequencing Memory

### Status

Playable local game with real TTS added.

### Core Gameplay

The player listens to spoken route/instruction steps, then reorders shuffled cards into the exact order heard.

### Session Structure

Sequencing Memory is not a 60-second speed game. It uses:

```text
3 route challenges
no lives
no global timer
```

Each route challenge includes:

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

### Important Behavior

- real device TTS through an audio service
- mock audio service for tests
- replay support for parts
- combined recall challenge
- reorderable cards
- partial credit
- results review shows correct order vs user order
- final results include score, accuracy, routes completed, perfect stages, longest remembered, replay count, average recall time, XP

### Notes

A spoken-text caption may exist as a temporary debug/developer tool. It should be removable or disabled before production because production gameplay should test auditory memory, not reading memory.

---

## 2.4 Commas

### Status

Playable local game. Good beta-quality version and currently frozen for now.

### Core Gameplay

The player sees a sentence or paragraph with missing commas and taps spaces where commas should be inserted.

Example:

```text
The Taj Mahal is located in Agra India.
```

Correct:

```text
The Taj Mahal is located in Agra, India.
```

### Important Technical Detail

The game uses a natural prose renderer:

- visible text is rendered as one continuous `RichText` string
- inserted commas attach directly to the previous word
- `TextPainter` measures the rendered text
- transparent overlay hitboxes are positioned over measured spaces
- the Cubit receives stable gap IDs / `afterTokenIndex` values
- hitboxes do not affect visible spacing

### Important Behavior

- 60-second session
- correct comma = +100
- sentence complete bonus
- wrong tap = time penalty
- local feedback near tapped gap
- review screen shows original sentence, correct sentence, your commas, correct commas, wrong taps, and rule explanation

### Notes

Commas is frozen as v1 beta for now. Later polish should focus on stronger local feedback, more cinematic punctuation-game presentation, more beginner-safe prompt ordering, and a larger curated prompt database.

---

# 3. Backend Phase 4 Status

Backend Phase 4 has been completed.

The backend now supports:

- game session creation
- game result submission
- XP calculation
- XP ledger
- streak update
- per-skill EMA update
- progress endpoint
- skills endpoint
- consistent validation errors
- consistent dev-user header

Backend tests are passing:

```text
58 unit tests
26 e2e tests
```

---

# 4. Backend API Contract Summary

## 4.1 Dev User Header

For now, all user-scoped endpoints require:

```http
x-dev-user-id: dev-user-001
```

This is temporary development authentication. A later phase will replace it with real JWT/Bearer authentication.

Flutter should centralize this header in one API client/interceptor so it can be replaced later without editing every API call.

---

## 4.2 User-Scoped Endpoints

The following endpoints require `x-dev-user-id`:

```text
POST /game-sessions
POST /game-sessions/:sessionId/results
GET /me/progress
GET /me/skills
```

This endpoint does not currently require user context:

```text
GET /game-sessions/:sessionId
```

---

# 5. Result Submission API

## Endpoint

```http
POST /game-sessions/:sessionId/results
```

## Request Headers

```http
x-dev-user-id: dev-user-001
Content-Type: application/json
```

## First-Pass Request Body

For the first Flutter integration pass, do **not** send `answerEvents`.

Send summary stats only:

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

## Important Accuracy Rule

Flutter UI may show:

```text
80%
```

But the API must receive:

```json
"accuracy": 0.8
```

Accuracy must be sent as a decimal from `0` to `1`, not as a percentage from `0` to `100`.

## Response Example

```json
{
  "resultId": "result-uuid",
  "sessionId": "550e8400-e29b-41d4-a716-446655440000",
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

---

# 6. Answer Events

## Current Decision

For the first integration pass:

```text
Do not send answerEvents.
```

`answerEvents` is optional and can be omitted entirely.

Backend still performs:

- session completion
- XP ledger entry
- streak update
- skill EMA update

without `answerEvents`.

## Later Integration

Later, when Flutter consumes backend prompt snapshots directly, answer events can be added.

Backend session creation returns prompt IDs:

```dart
class SessionPromptDto {
  int orderIndex;
  String promptId;
  dynamic contentJson;   // { displayTextWithoutCommas, correctTextWithCommas, ruleType }
  dynamic answerJson;    // { insertionPoints: [{ afterToken, afterTokenIndex }] }
  int difficulty;
  String difficultyTag;
  String? ruleType;
  List<String> skillTags;
  String? explanation;   // Phase 3B: teaching text — display AFTER user submits answer, not before
}
```

**Backend Phase 3B note (internal Phase 6):** As of this phase, `explanation` is included in every session prompt snapshot. Flutter should display it as post-attempt feedback. It is never `null` for Commas prompts. For future games it may be `null` — treat it as optional.

**Prompt difficulty tiers for Commas:**

| difficultyTag | difficulty | ruleTypes |
|---|---|---|
| beginner | 1 | location, date |
| easy | 2 | list, introductory_phrase |
| medium | 3 | contrast, direct_address |
| hard | 4 | compound_sentence, appositive, non_restrictive_clause |

First session: only beginner-safe prompts. Subsequent sessions: mixed difficulty tiers with recently-seen prompts deprioritised.

Use:

```text
prompts[].promptId
```

as:

```json
answerEvents[].promptId
```

Example future event:

```json
{
  "promptId": "prompt-id-from-session",
  "eventType": "correct",
  "isCorrect": true,
  "responseTimeMs": 1800,
  "difficulty": 1
}
```

---

# 7. Progress Endpoint

## Endpoint

```http
GET /me/progress
```

## Request Header

```http
x-dev-user-id: dev-user-001
```

## Response

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

`lastTrainingDay` can be `null` if the user has never completed a session.

---

# 8. Skills Endpoint

## Endpoint

```http
GET /me/skills
```

## Request Header

```http
x-dev-user-id: dev-user-001
```

## Response

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
    },
    {
      "skillId": "punctuation",
      "level": 2,
      "masteryScore": 0.2,
      "accuracy": 0.3,
      "recentTrend": "stable",
      "confidence": 0.25
    }
  ]
}
```

For a new user, this may return:

```json
{
  "userId": "dev-user-001",
  "skills": []
}
```

Flutter must handle the empty state gracefully.

Suggested empty state:

```text
Complete your first session to unlock skill insights.
```

---

# 9. Error Response Envelope

All backend error responses use:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable message."
  }
}
```

## Known Error Codes

### VALIDATION_ERROR — 400

Used for invalid DTO fields, missing required values, or missing `x-dev-user-id`.

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "accuracy must not be greater than 1"
  }
}
```

### SESSION_ACCESS_DENIED — 403

Used when the session belongs to another user.

```json
{
  "error": {
    "code": "SESSION_ACCESS_DENIED",
    "message": "Access denied."
  }
}
```

### SESSION_ALREADY_COMPLETED — 409

Used when submitting results to a session already completed.

```json
{
  "error": {
    "code": "SESSION_ALREADY_COMPLETED",
    "message": "Session already completed."
  }
}
```

### INVALID_PROMPT_ID — 422

Used when `answerEvents[].promptId` does not belong to the session snapshot.

```json
{
  "error": {
    "code": "INVALID_PROMPT_ID",
    "message": "Prompt abc123 does not belong to this session."
  }
}
```

### USER_NOT_FOUND — 404

Used when the dev user ID does not exist.

```json
{
  "error": {
    "code": "USER_NOT_FOUND",
    "message": "User not found."
  }
}
```

### SESSION_NOT_FOUND — 404

Used when the sessionId does not exist.

```json
{
  "error": {
    "code": "SESSION_NOT_FOUND",
    "message": "Session not found."
  }
}
```

### GAME_NOT_FOUND — 404

Used when the gameId in `POST /game-sessions` does not exist.

```json
{
  "error": {
    "code": "GAME_NOT_FOUND",
    "message": "Game not found."
  }
}
```

### NO_ACTIVE_PROMPTS — 422

Used when the game exists but has no active prompts seeded.

```json
{
  "error": {
    "code": "NO_ACTIVE_PROMPTS",
    "message": "No active prompts found for this game."
  }
}
```

---

# 10. Backend Guarantees

## 10.1 Duplicate Result Submission

Duplicate submissions do not double-award XP.

The backend sets session status to `completed` in the same transaction as XP ledger creation.

A second submission returns:

```text
SESSION_ALREADY_COMPLETED
```

and writes no second XP entry.

Flutter should handle this gracefully.

## 10.2 XP Ledger

`GET /me/progress` calculates `totalXp` as the live sum of XP ledger entries.

There is no separate mutable total XP counter.

## 10.3 Streaks

Streaks update inside the result-submission transaction.

The backend uses the user timezone if available, otherwise UTC.

Current limitation:

```text
There is no profile endpoint yet to set timezone.
```

So currently streaks default to UTC unless the user row already has timezone.

## 10.4 Skills

Skill mastery uses an EMA formula.

Inputs:

- accuracy
- averageResponseTimeMs
- gameId

Speed weight differs by game:

```text
sequencing_memory -> lower speed weight
other games -> higher speed weight
```

This is because Sequencing Memory is not primarily a speed/reaction game.

---

# 11. Flutter Integration Goal

The next Flutter task is:

```text
Create session → play local game → submit summary result → fetch progress/skills
```

Do not switch games to backend prompt snapshots yet.

For now, games can continue using local prompt data. The backend session is used for tracking and result submission.

---

# 12. Recommended Flutter Integration Scope

## Add API Layer

Create a centralized API layer, for example:

```text
lib/core/network/
  api_client.dart
  api_error.dart
  api_result.dart
```

or follow the existing project structure.

The API client should:

- hold base URL
- attach `x-dev-user-id`
- parse error envelope
- support future replacement with Bearer auth

## Add Backend Models / DTOs

Recommended models:

```text
CreateGameSessionRequest
CreateGameSessionResponse
SessionPromptDto
SubmitGameResultRequest
SubmitGameResultResponse
UserProgressResponse
UserSkillsResponse
SkillProgressDto
ApiErrorEnvelope
```

## Add Repository / Service Methods

Recommended methods:

```dart
Future<CreateGameSessionResponse> createGameSession(String gameId);

Future<SubmitGameResultResponse> submitGameResult(
  String sessionId,
  SubmitGameResultRequest request,
);

Future<UserProgressResponse> getMyProgress();

Future<UserSkillsResponse> getMySkills();
```

## Centralize Dev User Header

Use:

```http
x-dev-user-id: dev-user-001
```

Do not repeat this manually in every method.

---

# 13. Result Submission Behavior in Flutter

When a game finishes:

1. local result screen can appear immediately;
2. submit summary result to backend;
3. if success:
   - store/display synced XP if desired;
   - refresh progress/skills if needed;
4. if failure:
   - do not block local result screen;
   - show non-blocking sync error if appropriate;
   - allow retry only if safe.

## Important

If result submission returns:

```text
SESSION_ALREADY_COMPLETED
```

do not keep retrying the same result blindly.

---

# 14. Mapping Local Game Results to Backend Summary

Each game should map its local result object into:

```dart
SubmitGameResultRequest(
  score: ...,
  accuracy: ..., // 0-1 decimal
  totalAttempts: ...,
  correctAnswers: ...,
  wrongAnswers: ...,
  missedAnswers: ...,
  wordsSolved: ...,
  bestCombo: ...,
  averageResponseTimeMs: ...,
)
```

## Suggested Mappings

### Antonym Rush

```text
score -> score
accuracyPercent / 100 -> accuracy
total taps/misses -> totalAttempts
correct -> correctAnswers
wrong -> wrongAnswers
missed -> missedAnswers
wordsSolved -> wordsSolved
bestCombo -> bestCombo
averageResponseTimeMs -> averageResponseTimeMs
```

### Association

```text
score -> score
accuracyPercent / 100 -> accuracy
total answered/missed -> totalAttempts
correct -> correctAnswers
wrong -> wrongAnswers
missed -> missedAnswers
wordsSolved -> wordsSolved
bestCombo -> bestCombo
averageResponseTimeMs -> averageResponseTimeMs
```

### Sequencing Memory

```text
score -> score
accuracyPercent / 100 -> accuracy
total submitted positions or stages -> totalAttempts
correct positions or perfect stages -> correctAnswers
wrong positions/stages -> wrongAnswers
missed -> missedAnswers, usually 0 unless timeout/skipped
sequences completed/routes completed -> wordsSolved
perfect stages or best streak -> bestCombo
averageRecallTimeMs -> averageResponseTimeMs
```

### Commas

```text
score -> score
accuracyPercent / 100 -> accuracy
correct comma placements + wrong taps -> totalAttempts
commas placed -> correctAnswers
wrong taps -> wrongAnswers
missedAnswers -> 0 unless skipped/timed out prompts are tracked
sentences completed -> wordsSolved
best streak -> bestCombo
averageResponseTimeMs -> averageResponseTimeMs
```

---

# 15. Progress UI / Skills UI

After result submission, Flutter should eventually show:

## Progress

- total XP
- current streak
- longest streak
- sessions completed
- last training day

## Skills

- skill name
- mastery level
- mastery score
- accuracy
- trend
- confidence

For an empty skills list:

```text
Complete your first session to unlock skill insights.
```

---

# 16. First Integration Plan for Codex

## Do First

1. Add API client/service layer.
2. Add DTOs/models.
3. Add repositories.
4. Add centralized dev-user header.
5. Wire result submission after one game first, preferably Commas or Antonym Rush.
6. Fetch `/me/progress` and `/me/skills`.
7. Handle backend errors.
8. Add tests if practical.

## Do Not Do Yet

- Do not send `answerEvents`.
- Do not switch local game prompt generation to backend prompt snapshots yet.
- Do not replace local results screens.
- Do not build full auth.
- Do not require network success to show local results.
- Do not refactor all games at once if risky.

---

# 17. Suggested Implementation Strategy

## Step 1 — Infrastructure

Create the network layer and DTOs.

## Step 2 — Session Lifecycle

Add basic session creation before starting a game.

If session creation fails, allow local gameplay fallback for now, but mark result sync as unavailable.

## Step 3 — Result Submission

Submit summary result when a game ends.

Start with one game, such as Commas, then generalize.

## Step 4 — Progress Fetching

Fetch progress and skills after a successful result submission.

## Step 5 — UI Integration

Show sync status lightly:

```text
Progress synced
```

or silently update progress.

Do not block the result screen.

## Step 6 — Expand to All Games

After one game works, wire all games.

---

# 18. Suggested Prompt For Codex

```text
Start Flutter backend integration for LexRush.

Read docs/backend_integration_handoff.md first.

Goal:
Wire Flutter to the Phase 4 backend contract.

First integration pass:
- create game sessions
- submit summary results only
- fetch /me/progress
- fetch /me/skills
- do not send answerEvents yet

Important:
Games currently use local prompt data. Keep that for now.
Backend session prompts can be consumed later.
For now, backend sessions are used for tracking/progress/result submission.

Use clean architecture.
Add a centralized API client/service layer.
Centralize x-dev-user-id: dev-user-001.
Make it easy to replace this header with Bearer auth later.

Implement:
- API error envelope parsing
- createGameSession(gameId)
- submitGameResult(sessionId, summary)
- getMyProgress()
- getMySkills()

Result mapping:
- accuracy must be sent as 0-1 decimal
- do not send percentage values like 80
- do not send answerEvents in this pass

Result submission behavior:
- local result screen should not be blocked by network
- submit results after game completion
- handle SESSION_ALREADY_COMPLETED gracefully
- if backend sync fails, keep local results visible

Start with one game first if needed, preferably Commas or Antonym Rush.
Then generalize carefully.

Run tests and report:
- files changed
- architecture added
- endpoints integrated
- which game was wired first
- how errors are handled
- manual test result
```

---

# 19. Success Criteria

The first backend integration pass is successful when:

- Flutter can create a backend game session.
- Flutter can submit a summary result.
- Backend returns XP earned.
- `/me/progress` returns updated XP/streak/session count.
- `/me/skills` returns updated skill mastery after at least one completed game.
- Local result screens still work offline or when backend sync fails.
- No existing local game is broken.
- Accuracy is submitted as decimal.
- `x-dev-user-id` is centralized.
- `answerEvents` are not sent yet.

---

# 20. Known Limitations

- No real auth yet.
- Dev header is temporary.
- Prompt snapshots are not consumed by Flutter yet.
- `answerEvents` omitted for now.
- Local game data remains source of gameplay content for this pass.
- Timezone still defaults to UTC unless backend user row has timezone.
- Empty skills list is expected for new users.

---

# 21. Final Recommendation

Proceed with backend integration now.

Do not build more games before connecting progress/results.

The app already has enough local games for the backend progress system to become meaningful. Connecting XP, streaks, sessions, and skills will make LexRush feel more like a real training platform instead of a collection of isolated local mini-games.
