# LexRush Game Specification: Sequencing Memory

## 1. Game Overview

**Game name:** Sequencing Memory  
**Category:** Working Memory / Listening / Order Recall  
**Primary skill trained:** Auditory working memory and chronological ordering  
**Session style:** Memory challenge, not a speed-tapping game

Sequencing Memory is an auditory working-memory game where the player listens to a spoken sequence of directions or instructions, then reconstructs the exact order by arranging shuffled text cards.

The game trains the player to remember not only the content of spoken information, but also the order in which that information was presented.

Example spoken sequence:

```text
Right on Abbeyhill
Exit onto Horse Wynd
Left on Calton Road
```

After listening, the player sees shuffled cards:

```text
Left on Calton Road
Right on Abbeyhill
Exit onto Horse Wynd
```

The player must reorder them into:

```text
1. Right on Abbeyhill
2. Exit onto Horse Wynd
3. Left on Calton Road
```

---

## 2. Product Goal

Sequencing Memory should feel like a premium LexRush memory-training exercise. It should not feel like a fast arcade quiz. The experience should be calm, focused, and mentally challenging.

The goal is to simulate a real-world task:

> Listen to instructions, hold them in memory, then reproduce them in the correct order.

This game should help users improve:

- working memory
- auditory memory
- instruction retention
- ordered recall
- route/direction memory
- attention to detail
- mental chunking
- sequential reasoning

---

## 3. Detailed User Story

As a LexRush user, I want to listen to a short sequence of spoken instructions and then arrange the matching text cards in the same order, so that I can train my working memory, improve my ability to remember spoken information, and practice organizing multi-step instructions accurately.

### User goals

The player wants to:

- listen carefully to a spoken sequence
- remember the exact order
- reorder shuffled cards correctly
- get feedback on mistakes
- improve over multiple rounds
- see progress at the end of the session

### User challenge

The player must remember both:

1. **Which items were spoken**
2. **The exact order they were spoken in**

The difficulty increases as sequences become longer, more similar, or split into multiple parts that must later be combined.

---

## 4. Core Gameplay Loop

Each challenge follows this loop:

1. The game enters a **Listen** phase.
2. The app plays audio for a sequence of directions or instructions.
3. The player listens and memorizes the sequence.
4. The game enters an **Arrange** phase.
5. The same items appear as shuffled draggable cards.
6. The player reorders the cards into the spoken order.
7. The player taps **Submit**.
8. The game checks the order.
9. The game shows feedback.
10. The next part, combined challenge, or next round begins.

---

## 5. Full Stage Flow

Some rounds contain two separate parts, followed by a combined final challenge.

### Full round flow

```text
Listen Part One
Arrange Part One
Feedback Part One
Listen Part Two
Arrange Part Two
Feedback Part Two
Arrange Combined
Feedback Combined
Results or Next Round
```

### Part One example

Audio:

```text
Right on Abbeyhill
Exit onto Horse Wynd
Left on Calton Road
```

User arranges the three cards into the correct order.

### Part Two example

Audio:

```text
Continue onto Canongate
Turn right on North Bridge
Arrive at Princes Street
```

User arranges the three cards into the correct order.

### Combined challenge

The player then arranges all six instructions together:

```text
1. Right on Abbeyhill
2. Exit onto Horse Wynd
3. Left on Calton Road
4. Continue onto Canongate
5. Turn right on North Bridge
6. Arrive at Princes Street
```

The combined challenge is the main memory test.

---

## 6. Recommended Game Structure

Sequencing Memory should not use the same fast 60-second model as Antonym Rush. It should be built around a fixed number of memory challenges.

### Recommended session format

```text
Session = 3 route challenges
Each route challenge = Part One + Part Two + Combined Recall
```

This structure gives the player enough time to listen, think, arrange, and learn.

### Alternative format

A timed mode can be added later:

```text
90-second session
Complete as many sequence challenges as possible
```

For the first production implementation, use the challenge-count structure rather than a strict speed-tapping timer.

---

## 7. Game Phases

### 7.1 Ready Phase

Before the sequence starts, show a short instruction screen:

```text
Listen carefully
You’ll arrange the steps after the audio.
```

Optional countdown:

```text
3 → 2 → 1
```

### 7.2 Listen Phase

The player hears the spoken items.

UI should show:

- current part label, such as `Part One of Two`
- `Listening...`
- animated speaker or waveform
- progress dots for each item
- optional route/map animation

Cards should not be shown yet.

### 7.3 Arrange Phase

The spoken items appear as shuffled cards.

UI should show:

```text
Arrange in the order you heard
```

Player can reorder cards using drag-and-drop.

Controls:

- drag card up/down to reorder
- optional haptic feedback when card changes position
- large readable cards
- clear Submit button

### 7.4 Submit Phase

When the user taps **Submit**, the game checks the user order against the correct order.

### 7.5 Feedback Phase

If perfect:

```text
Correct order!
+100
```

If partially correct:

```text
2 of 3 in correct order
```

If incorrect:

```text
Not quite
Review the correct order
```

Feedback should show:

- green highlight for correctly placed items
- red highlight for wrong positions
- correct order after submission

### 7.6 Combined Challenge Phase

After Part One and Part Two, the game asks the player to combine both parts into one longer sequence.

UI copy:

```text
Now combine both parts
Arrange the full route
```

The combined stage should feel more important and rewarding than the smaller parts.

---

## 8. Input And Controls

### Primary control

Use drag-and-drop card reordering.

Flutter options:

- `ReorderableListView`
- custom draggable cards for more animation control

### Card interaction requirements

Cards should be:

- large enough to drag comfortably
- readable on small mobile screens
- vertically stacked
- visually separated
- responsive during drag
- animated smoothly when moved

### Accessibility-friendly alternative

Later, add tap-to-swap:

1. tap one card
2. tap another card
3. the two cards swap positions

This can help users who find dragging difficult.

---

## 9. Audio Requirements

Audio is central to this game.

### Current audio approach

Use a replaceable audio-service abstraction. Normal app runtime uses device text-to-speech:

```text
flutter_tts
```

Tests and deterministic development flows should use mock or controlled audio services.

Current service boundary:

```text
SequencingAudioService
  speakSequence(List<String> items)
  speakItem(String item)
  stop()
  pause()
  resume()
  isSpeaking
  progress stream
  dispose()
```

Current implementations:

- `DeviceTtsSequencingAudioService` — normal runtime, wraps `flutter_tts`
- `MockSequencingAudioService` — deterministic mock/dev fallback
- controlled test doubles — used by Cubit tests when exact playback progress is needed

### Production audio options

Option A: Device TTS

Pros:

- scalable
- easy to generate new sequences
- low storage cost

Cons:

- voice quality varies by device
- timing may be inconsistent

Option B: Generated/pre-recorded voice files

Pros:

- consistent quality
- controlled pacing
- more premium feel

Cons:

- requires asset generation/storage
- more work to scale

### Audio behavior

The audio service should support:

- speak sequence item by item
- pause between items
- replay current part if allowed
- stop audio on pause/exit
- avoid overlapping speech
- notify Cubit when audio finishes
- emit progress with playback id, spoken count, current item index/text, completion, cancel, and error state

### Debug spoken caption

The UI may show the currently spoken item as a temporary developer caption while listening, but only behind a debug/developer flag such as `showDebugSpokenCaption`.

Rules:

- show at most the current item, never the full sequence;
- hide it before the arrange phase;
- do not let the caption drive Cubit logic, scoring, or stage transitions;
- keep it easy to disable for production polish.

### Replay behavior

Allow limited replay, such as:

```text
Replay: 1 left
```

Current V1 tracks replay count but does not subtract points for replay use. Combined recall has no replay.

---

## 10. Visual Direction

Do not copy Elevate’s exact visuals. Use the LexRush design language.

### LexRush direction

```text
Premium route-memory training interface
```

Visual style:

- dark navy background
- cyan/indigo accents
- rounded cards
- subtle glow
- animated waveform
- route-line motif
- clean typography
- calm, focused feel

### Suggested visual elements

- speaker icon
- animated waveform during listening
- route/map line in the background
- numbered cards during feedback
- glowing correct order path
- soft success particles for perfect recall

---

## 11. Scoring Rules

Scoring should reward both perfect recall and partial progress.

### Recommended scoring

```text
Perfect Part One: +100
Perfect Part Two: +100
Perfect Combined Challenge: +200
Partial credit: +20 per item in correct position
Replay used: tracked, no point reduction in V1
```

### Example

For a 3-item part:

- all 3 correct: +100
- 2 of 3 correct: +40
- 1 of 3 correct: +20
- 0 correct: +0

For combined 6-item challenge:

- all 6 correct: +200
- partial: +20 per correctly positioned item

### Important

Results should be honest. Do not fake or boost stats.

---

## 12. Difficulty Progression

### Beginner

Beginner sequences should be short and easy to chunk.

Rules:

- 3 items
- simple directions
- distinct street/location names
- slow audio
- 1 replay allowed
- one part or two short parts

Example:

```text
Left on Pine Street
Right on Oak Avenue
Stop at the library
```

### Medium

Medium sequences are longer and more route-like.

Rules:

- 4–5 items
- two parts
- combined recall
- fewer replays
- moderately longer place names

Example:

```text
Go past the museum
Turn left on King Street
Cross the bridge
Exit onto Market Road
```

### Hard

Hard sequences require stronger working memory.

Rules:

- 6–8 items
- similar-sounding streets
- longer phrases
- no replay or limited replay
- combined recall required

Example:

```text
Continue onto West Register Street
Bear right toward North Bridge
Exit at Saint Mary’s Street
Turn left onto Cowgate
```

---

## 13. Beginner Ramp

The first session should be fair and confidence-building.

### First challenge rules

- 3 items only
- slow audio
- one replay allowed
- very distinct directions
- no combined challenge longer than 6 items
- feedback should teach, not punish

### Beginner copy

```text
Tip: Remember the route as a pattern.
Example: Right → Exit → Left
```

---

## 14. Data Model

### SequencingPrompt

```dart
class SequencingPrompt {
  final String id;
  final List<String> items;
  final SequencingTheme theme;
  final DifficultyTier difficulty;
  final bool beginnerSafe;

  const SequencingPrompt({
    required this.id,
    required this.items,
    required this.theme,
    required this.difficulty,
    this.beginnerSafe = false,
  });
}
```

### SequencingRound

```dart
class SequencingRound {
  final String id;
  final List<String> partOne;
  final List<String> partTwo;
  final List<String> combined;
  final SequencingStage currentStage;
}
```

### SequencingRoundResult

```dart
class SequencingRoundResult {
  final String roundId;
  final SequencingStage stage;
  final List<String> correctOrder;
  final List<String> userOrder;
  final int correctPositions;
  final bool perfect;
  final Duration recallTime;
  final int replayCount;
}
```

### SequencingGameResult

```dart
class SequencingGameResult {
  final int score;
  final double accuracy;
  final int sequencesCompleted;
  final int perfectSequences;
  final int longestSequenceRemembered;
  final int replayCount;
  final Duration averageRecallTime;
  final int xpEarned;
  final List<SequencingRoundResult> review;
}
```

---

## 15. Stages And State

### Stage enum

```dart
enum SequencingStage {
  idle,
  ready,
  listenPartOne,
  arrangePartOne,
  feedbackPartOne,
  listenPartTwo,
  arrangePartTwo,
  feedbackPartTwo,
  arrangeCombined,
  feedbackCombined,
  completed,
}
```

### Cubit state should include

- current round
- current stage
- current spoken items
- current shuffled cards
- user order
- score
- replay count
- mistake count
- perfect part count
- longest sequence remembered
- audio playback state
- feedback state
- round history
- result stats

---

## 16. Cubit Responsibilities

`SequencingMemoryCubit` owns all game logic.

Responsibilities:

- load next sequence
- split sequence into parts
- start listening phase
- trigger audio service
- handle audio finished event
- create shuffled cards
- update user order after drag
- submit order
- calculate correctness
- calculate score
- track replay count
- move between stages
- pause/resume
- stop audio on exit
- build final result

The UI should only:

- render current state
- show animations
- forward reorder events
- forward submit/replay/pause actions

---

## 17. Suggested Flutter Architecture

```text
features/
  games/
    sequencing_memory/
      data/
        sequencing_prompts.dart

      domain/
        entities/
          sequencing_prompt.dart
          sequencing_round.dart
          sequencing_round_result.dart
          sequencing_game_result.dart
        services/
          sequencing_round_generator.dart
          sequencing_scoring_service.dart
          sequencing_difficulty_service.dart
          sequencing_audio_service.dart

      application/
        cubit/
          sequencing_memory_cubit.dart
          sequencing_memory_state.dart

      presentation/
        screens/
          sequencing_memory_screen.dart
          sequencing_memory_results_screen.dart
        widgets/
          listen_panel.dart
          sound_wave_animation.dart
          sequence_card.dart
          reorder_area.dart
          sequence_feedback.dart
          replay_button.dart
```

---

## 18. Screen Details

### 18.1 Listen Screen

Content:

- `Part One of Two`
- `Listening...`
- speaker/waveform animation
- progress dots
- replay button disabled until audio completes

Behavior:

- starts audio automatically
- advances to arrange stage after audio finishes
- blocks card interaction

### 18.2 Arrange Screen

Content:

- instruction: `Arrange in the order you heard`
- shuffled cards
- Submit button
- Replay button if replay available

Behavior:

- user drags cards
- Submit checks order
- Replay returns to audio for same part

### 18.3 Feedback Screen

Content:

- correctness message
- user order vs correct order
- score earned
- Continue button

Behavior:

- user can review mistake
- Continue moves to next stage

### 18.4 Results Screen

Content:

- final score
- accuracy
- sequences completed
- perfect sequences
- longest sequence remembered
- replay count
- average recall time
- XP earned
- review list

---

## 19. Results Metrics

### Accuracy

Calculate based on correct positions:

```text
accuracy = totalCorrectPositions / totalPositions
```

### Perfect sequences

Count stages where the full order was correct.

### Longest sequence remembered

Longest sequence length where the player got a perfect order.

### Average recall time

Average time spent arranging after audio ended.

### Replay count

Total number of audio replays used.

---

## 20. Acceptance Criteria

### Gameplay

- Player can start Sequencing Memory from mode selection.
- Game plays or simulates audio for a sequence.
- Player can reorder cards using drag-and-drop.
- Submit checks exact order.
- Correct and incorrect feedback appear.
- Part One, Part Two, and Combined Challenge flow works.
- Results screen appears after session completion.

### Audio

- Audio does not overlap itself.
- Replay works only when available.
- Audio stops when game is paused/exited.
- UI clearly shows listening state.

### Scoring

- Perfect parts score correctly.
- Combined challenge scores correctly.
- Partial credit works.
- Replay count is tracked.
- Results are honest.

### UX

- Cards are easy to read and drag.
- Listening and arranging states are visually distinct.
- Feedback is clear.
- Combined challenge feels like a satisfying memory test.

---

## 21. Non-Goals For First Implementation

Do not include yet:

- advanced map graphics
- custom recorded voice files
- multiplayer
- cloud progress
- adaptive AI difficulty
- complex route animation
- custom recorded voice files

Focus first on:

- stage logic
- audio/replay behavior
- card reordering
- feedback
- results

---

## 22. Important Production Notes

Sequencing Memory will feel production-grade only if:

1. audio timing is clean
2. cards reorder smoothly
3. feedback is clear
4. sequence length ramps gradually
5. text is readable
6. replay rules are fair
7. the combined challenge feels satisfying
8. results show meaningful memory metrics

The most important production risk is audio quality. If TTS feels robotic, inconsistent, or too fast, the game will feel lower quality even if the UI is polished.

---

## 23. Implementation Strategy

### Version 1: Functional implementation

- real device TTS behind audio service
- mock/controlled audio for tests
- reorder cards
- submit
- feedback
- results

### Version 2: Game feel polish

- smoother card dragging
- waveform animation
- better feedback animations
- route-themed visuals

### Version 3: Audio polish

- better TTS voice or generated voice assets
- controlled pacing
- replay polish

### Version 4: Production polish

- stronger results review
- larger prompt database
- difficulty tuning
- sound/haptics
- visual effects

---

## 24. Short AI Agent Prompt

```text
Create a new LexRush mini-game called Sequencing Memory.

Sequencing Memory is an auditory working-memory ordering game.

Gameplay:
- The player listens to a spoken sequence of directions or instructions.
- After listening, the same items appear as shuffled text cards.
- The player must reorder the cards into the exact order they heard.
- The player submits the order.
- The game shows correct/incorrect feedback.
- Some rounds have Part One and Part Two.
- After practicing both parts, the player must arrange the combined full sequence.

Do not copy Elevate assets or exact visuals. Use the existing LexRush visual identity.

Core flow:
1. Listen Part One
2. Arrange Part One
3. Feedback Part One
4. Listen Part Two
5. Arrange Part Two
6. Feedback Part Two
7. Arrange Combined
8. Feedback Combined
9. Results

Controls:
- use drag-and-drop card reordering
- cards should be large and easy to drag
- submit button checks order

Audio:
- use real device text-to-speech through an audio-service abstraction
- use mock/controlled audio services for tests
- show listening state with waveform/speaker animation
- allow limited replay, such as 1 replay per part

Scoring:
- perfect part: +100
- combined perfect: +200
- partial credit: +20 per correctly positioned item
- replay count is tracked but does not reduce points in V1
- results should stay honest

Architecture:
- Use clean architecture and BLoC/Cubit.
- Add feature folder: features/games/sequencing_memory.
- Cubit owns stages, audio state, sequence data, shuffled cards, user order, scoring, replay count, feedback, and results.
- UI only renders state and forwards reorder/submit/replay actions.

Results:
Show:
- final score
- accuracy
- sequences completed
- perfect sequences
- longest sequence remembered
- replay count
- average recall time
- XP earned
- review of correct order vs user order

Important:
This game should not be a strict speed-tapping game. It should feel like a memory challenge with clean audio and smooth card ordering.
```
