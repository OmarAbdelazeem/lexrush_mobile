# LexRush Game User Story: Commas

## 1. Game Overview

**Commas** is a punctuation-focused mini-game for LexRush.

The player sees a sentence or short paragraph with missing commas. Their task is to tap the spaces where commas should be inserted. When the player taps the correct space, a comma appears inline. When the player taps an incorrect space, the game gives immediate feedback and applies a small penalty.

This game trains grammar awareness, punctuation accuracy, editing skill, and writing clarity.

---

## 2. Core User Story

As a player, I want to identify where commas belong in a sentence, so that I can improve punctuation, grammar awareness, and the clarity of my writing.

---

## 3. Core Gameplay Concept

The player is shown a sentence with one or more missing commas.

Example:

```text
The Taj Mahal is located in Agra India.
```

The correct version is:

```text
The Taj Mahal is located in Agra, India.
```

The player taps the space between:

```text
Agra | India
```

After the correct tap, the sentence updates inline:

```text
The Taj Mahal is located in Agra, India.
```

---

## 4. Game Objective

The player must place as many missing commas as possible before the session timer ends.

The goal is to correctly identify punctuation positions quickly and accurately.

---

## 5. Session Model

Recommended session model:

```text
60-second session
```

The session ends when the timer reaches zero.

Each sentence continues until:

- all missing commas are placed, then the next prompt loads;
- or the session timer reaches zero.

Optional future feature:

- skip prompt button;
- hint button;
- practice mode without timer.

---

## 6. Core Game Loop

1. Start Commas mode.
2. Show a sentence or paragraph with missing commas.
3. Show how many commas are missing.
4. Player taps a space between words.
5. Game checks whether that gap requires a comma.
6. If correct:
   - insert comma inline;
   - show positive feedback;
   - add score;
   - reduce remaining comma count.
7. If wrong:
   - flash the tapped gap red;
   - show “Not there” or similar feedback;
   - apply a small penalty.
8. When all commas in the prompt are found:
   - show sentence-complete feedback;
   - award bonus;
   - load next prompt.
9. When the timer ends:
   - show results and review.

---

## 7. Controls

Primary input:

```text
Tap the space where a comma is missing.
```

Important UX requirement:

Do not require pixel-perfect taps on tiny spaces. Each gap between words must have a generous invisible hitbox.

The player should be able to tap near the correct space and still have the action feel fair.

---

## 8. UI Layout

### Top HUD

Show:

- score;
- timer;
- pause button if available;
- optional remaining comma count.

Example:

```text
Score: 400                         0:47
```

### Main Text Area

Show the sentence or paragraph in a large readable layout.

Requirements:

- readable font size;
- good line height;
- natural text wrapping;
- tappable gaps between words;
- inline comma insertion;
- visual feedback on tapped gaps.

### Bottom Instruction

Example:

```text
Tap the spaces where commas are missing.
```

When only one comma remains:

```text
One comma left
```

When multiple remain:

```text
2 commas left
```

### Feedback

Correct:

```text
+100
```

Wrong:

```text
Not there
```

Sentence complete:

```text
Sentence complete
+100 bonus
```

---

## 9. Important Implementation Detail: Token-Based Text Rendering

Do **not** render the paragraph as one plain text block and try to detect arbitrary tap coordinates.

That approach is fragile and hard to make fair.

The current production approach keeps the best part of token rendering while preserving natural prose:

1. The prompt is still tokenized in data/state.
2. Each tappable gap still has a stable `afterTokenIndex`.
3. The Cubit still receives only the tapped gap id and owns correctness.
4. The UI renders one natural `RichText` sentence, then overlays transparent measured hitboxes at each gap.

This avoids the older “word grid” feeling while keeping deterministic gap taps.

### Internal token concept

Example:

```text
The | Taj | Mahal | is | located | in | Agra | India.
```

Each token has:

- display text;
- token index;
- whether a comma is missing after this token;
- whether the player already placed a comma after this token;
- whether the gap was tapped incorrectly.

Example:

```dart
class CommaToken {
  final String text;
  final int index;
  final bool commaRequiredAfter;
  final bool commaPlacedAfter;
}
```

### Gap Tapping

Each gap should have a stable ID, such as:

```text
gap_after_token_7
```

The Cubit should evaluate taps by gap ID or token index, not by screen coordinates.

### Current Renderer

`CommaTextArea` should:

- build one attached-comma text string such as `Agra, India`;
- render that text as natural prose with normal spacing and wrapping;
- use `TextPainter` to measure the visual position of each gap;
- overlay transparent `CommaGapDetector` widgets around those measured spaces;
- keep hitboxes generous without visually widening the spaces;
- keep debug hitbox visualization behind a debug-only flag, disabled by default.

This is still token/gap based internally. It is not raw coordinate grammar detection and not runtime AI punctuation detection.

---

## 10. Prompt Data Model

Use curated prompt data with known correct comma positions.

Do **not** use runtime AI grammar detection for V1.

Recommended model:

```dart
class CommaPrompt {
  final String id;
  final String displayTextWithoutCommas;
  final String correctTextWithCommas;
  final List<CommaInsertionPoint> insertionPoints;
  final CommaRuleType ruleType;
  final DifficultyTier difficulty;
  final bool beginnerSafe;
  final String explanation;
}
```

Insertion point:

```dart
class CommaInsertionPoint {
  final int afterTokenIndex;
  final String beforeToken;
  final String afterToken;
}
```

Example:

```dart
CommaPrompt(
  id: 'location_001',
  displayTextWithoutCommas: 'The Taj Mahal is located in Agra India.',
  correctTextWithCommas: 'The Taj Mahal is located in Agra, India.',
  insertionPoints: [
    CommaInsertionPoint(
      afterTokenIndex: 7,
      beforeToken: 'Agra',
      afterToken: 'India',
    ),
  ],
  ruleType: CommaRuleType.location,
  difficulty: DifficultyTier.easy,
  beginnerSafe: true,
  explanation: 'Use a comma between a city and a country or state.',
)
```

---

## 11. Comma Rule Types

The game should support common comma rules.

Recommended enum:

```dart
enum CommaRuleType {
  location,
  date,
  list,
  introductoryPhrase,
  nonrestrictiveClause,
  appositive,
  directAddress,
  contrast,
  compoundSentence,
}
```

### Beginner Rules

- location commas;
- date commas;
- simple list commas;
- short introductory phrases.

### Medium Rules

- multiple list commas;
- dates with year;
- city/state/country;
- introductory clauses;
- compound sentences.

### Hard Rules

- nonrestrictive clauses;
- appositives;
- interrupters;
- direct address;
- multiple comma rules in one paragraph.

---

## 12. Difficulty Progression

### Beginner

One obvious comma.

Example:

```text
The Taj Mahal is located in Agra India.
```

Correct:

```text
The Taj Mahal is located in Agra, India.
```

### Medium

Two to three commas.

Example:

```text
We leave Thursday August 30 after lunch.
```

Correct:

```text
We leave Thursday, August 30, after lunch.
```

### Hard

Longer text with several rules.

Example:

```text
After the storm ended the children who had waited all morning ran outside to play.
```

Correct:

```text
After the storm ended, the children, who had waited all morning, ran outside to play.
```

---

## 13. Example Prompt Types

### Location

```text
The Taj Mahal is located in Agra India.
```

Correct:

```text
The Taj Mahal is located in Agra, India.
```

Explanation:

```text
Use a comma between a city and a country or state.
```

### Date

```text
We leave Thursday August 30.
```

Correct:

```text
We leave Thursday, August 30.
```

Explanation:

```text
Use a comma between the day of the week and the date.
```

### List

```text
The frog can be yellow green red or blue.
```

Correct:

```text
The frog can be yellow, green, red, or blue.
```

Explanation:

```text
Use commas to separate items in a list.
```

### Introductory Clause

```text
After the movie ended we went home.
```

Correct:

```text
After the movie ended, we went home.
```

Explanation:

```text
Use a comma after an introductory clause.
```

---

## 14. Scoring Rules

Recommended V1 scoring:

```text
Correct comma = +100
Sentence complete bonus = +100
Wrong tap = -3 seconds
```

Optional later:

```text
Perfect prompt bonus = +50
Fast completion bonus = +25 to +100
Hint used = reduced bonus
```

For V1, keep it simple and deterministic.

---

## 15. Feedback Rules

### Correct Tap

When the player taps a correct gap:

- insert comma inline;
- highlight the inserted comma briefly;
- show `+100`;
- update remaining comma count;
- if all commas are placed, complete the sentence.

### Wrong Tap

When the player taps an incorrect gap:

- flash that gap red;
- show `Not there`;
- apply `-3s`;
- do not insert a comma.

### Sentence Complete

When the sentence is completed:

- show success feedback;
- award sentence complete bonus;
- briefly show the fully corrected sentence;
- load next prompt.

---

## 16. Results Screen

Show:

- final score;
- accuracy;
- commas placed;
- wrong taps;
- sentences completed;
- average response time;
- XP earned;
- review of correct punctuation.

### Review Section

Each reviewed item should include:

- original sentence without commas;
- correct sentence with commas;
- rule explanation;
- user mistakes if available.

Example:

```text
Correct:
The Taj Mahal is located in Agra, India.

Rule:
Use a comma between a city and a country or state.
```

---

## 17. Game States

Recommended states:

```text
ready
playing
correctFeedback
wrongFeedback
sentenceComplete
paused
completed
results
```

The Cubit should own:

- timer;
- current prompt;
- placed comma positions;
- wrong tap count;
- score;
- sentence completion;
- prompt history;
- result calculation.

The UI should only:

- render tokens and tappable gaps;
- forward gap taps;
- show feedback and animations.

---

## 18. Flutter Architecture

Use clean architecture + BLoC/Cubit.

Recommended feature folder:

```text
features/
  games/
    commas/
      data/
        comma_prompts.dart

      domain/
        entities/
          comma_prompt.dart
          comma_token.dart
          comma_insertion_point.dart
          comma_round_result.dart
          comma_game_result.dart

        services/
          comma_round_generator.dart
          comma_scoring_service.dart
          comma_difficulty_service.dart

      application/
        cubit/
          commas_cubit.dart
          commas_state.dart

      presentation/
        screens/
          commas_screen.dart
          commas_results_screen.dart

        widgets/
          comma_text_area.dart
          comma_gap_detector.dart
          comma_feedback.dart
```

---

## 19. Cubit Responsibilities

`CommasCubit` should own:

- current prompt;
- token list;
- correct insertion points;
- placed comma positions;
- wrong taps;
- score;
- timer;
- remaining comma count;
- prompt history;
- result stats;
- next prompt loading;
- pause/resume;
- restart/end.

The Cubit should expose state that the UI can render safely.

---

## 20. UI Responsibilities

The UI should:

- render the current sentence as natural prose using the measured-hitbox renderer;
- create transparent tappable gap zones between words;
- show placed commas inline;
- show correct/wrong feedback;
- show score and timer;
- show remaining comma count;
- forward `gapTapped(tokenIndex)` to the Cubit.

The UI should not decide whether a comma is correct. That belongs to the Cubit.

---

## 21. Acceptance Criteria

### Gameplay

- Player can start Commas from mode selection.
- Game shows a sentence with missing commas.
- Player taps gaps between words.
- Correct tap inserts a comma inline.
- Wrong tap flashes red and applies penalty.
- Prompt completes when all commas are placed.
- New prompt loads after completion.
- Session ends when timer reaches zero.
- Results screen shows final stats and review.

### Technical

- Uses clean architecture and BLoC/Cubit.
- Uses token/gap IDs, not raw tap coordinates.
- Uses curated prompt data, not runtime grammar detection.
- Existing games are not broken.
- Tests cover correct taps, wrong taps, completion, and results.

### UX

- Text is readable.
- Tap gaps are forgiving.
- Feedback is immediate.
- Remaining comma count is clear.
- Review teaches the comma rule.

---

## 22. Test Plan

Add tests for:

- correct tap inserts comma and increases score;
- wrong tap applies penalty and does not insert comma;
- sentence completes when all required commas are placed;
- remaining comma count updates correctly;
- result stats calculate correctly;
- prompt history records correct punctuation;
- token/gap IDs are used instead of raw coordinates;
- timer ends session;
- pause/resume works safely.

Run regression tests for existing games:

```text
flutter test test/antonym_rush_cubit_test.dart
flutter test test/association_cubit_test.dart
flutter test test/sequencing_memory_cubit_test.dart
```

Also run Commas-specific tests:

```text
flutter test test/commas_cubit_test.dart
flutter test test/commas_text_area_widget_test.dart
```

And run:

```text
flutter analyze
```

---

## 23. Production Notes

This game is not asset-heavy. Production quality depends mostly on:

- excellent text readability;
- fair tappable gap zones;
- strong prompt data;
- clear punctuation explanations;
- smooth inline comma insertion;
- good wrong-tap feedback;
- carefully tuned difficulty.

Do not over-invest in art assets before the interaction is reliable.

---

## 24. Implementation Strategy

### V1

Build the full deterministic game loop:

- timer;
- prompts;
- tokenized sentence;
- tappable gaps;
- inline comma insertion;
- scoring;
- results.

### V1.5

Improve:

- animations;
- feedback polish;
- prompt database size;
- review readability.

### V2

Add:

- hints;
- practice mode;
- rule-specific training;
- advanced punctuation categories;
- more grammar/writing games.

---

## 25. Short AI Agent Prompt

```text
Create a new LexRush mini-game called Commas.

Commas is a punctuation game where the player sees a sentence or short paragraph with missing commas. The player taps the spaces where commas should be inserted.

Do not copy Elevate assets or exact visuals. Use LexRush’s existing dark premium visual style.

Gameplay:
- 60-second session
- show a sentence or paragraph with commas removed
- player taps spaces between words where commas are missing
- correct tap inserts a comma inline
- wrong tap flashes red and applies a small penalty
- when all commas are placed, load the next prompt
- show remaining comma count, such as “one comma left”
- results show score, accuracy, commas placed, wrong taps, sentences completed, average response time, XP, and review of correct punctuation

Scoring:
- correct comma = +100
- sentence complete bonus = +100
- wrong tap = -3 seconds
- keep results honest

Architecture:
- Use clean architecture and BLoC/Cubit
- Add feature folder: features/games/commas
- Cubit owns timer, prompt selection, placed comma positions, scoring, wrong taps, sentence completion, history, and results
- UI only renders text tokens and forwards gap taps

Important implementation detail:
Do not render the paragraph as one plain text block with arbitrary tap coordinates.
Render natural prose from tokenized data, then overlay measured tappable gaps between words.
Each gap should have a generous invisible hitbox based on stable `afterTokenIndex`.
The visual text should look like normal readable prose, not separated word tiles.

Data:
Use prompt data with known correct comma insertion positions.
Do not use runtime AI grammar detection.
Each prompt should include:
- display text without commas
- correct text with commas
- correct insertion points
- rule type
- difficulty
- beginnerSafe flag
- explanation

Difficulty:
- first rounds: one obvious comma
- medium: two to three commas
- hard: longer text with multiple comma rules

Feedback:
- correct: insert comma, show +100
- wrong: flash gap red, show “Not there”, apply penalty
- complete: show sentence complete feedback and next prompt

Add tests:
- correct tap inserts comma and scores
- wrong tap applies penalty
- sentence completes when all commas are found
- result stats calculate correctly
- hit logic uses token/gap IDs, not raw coordinates
```
