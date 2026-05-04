# Antonym Rush — User Story (Flutter)

## One-line pitch

The player sees a **target word** and must tap the **one balloon** (out of four) that shows its **correct opposite**, before the balloons leave the playfield.

## Core user story

> As a player, I want to pick the antonym as balloons rise under the target word, so I can practice opposites quickly and feel rewarded for speed and accuracy.

## Round loop

1. Show the **target** (e.g. “find the opposite of **HOT**”).
2. Show **four** balloons, each with a word—**exactly one** is the true antonym; the rest are distractors.
3. Balloons **rise** toward the top; the layout keeps them **tappable** and visually **behind** the target card so motion reads clearly.
4. The player **taps one** balloon.
5. **Correct:** points and combo advance; brief feedback, then the next round.
6. **Wrong:** time penalty, combo resets; feedback, then continue.
7. **Miss** (no correct tap in time): time penalty (with **no time penalty on missed rounds** during the **first five** rounds for a gentler first session).

## Session feel

- **Timed** session with **score**, **combo**, and **countdown** pressure.
- Difficulty ramps by phase (earlier vs later in the session); **beginner-friendly** early pairs and timing for rounds **1–5**.
- **Fairness:** gameplay logic and visuals stay aligned so “Missed” does not appear while the correct choice still looks tappable under normal conditions.

## Results

After the session ends, the player sees **score**, **accuracy**, **combo**, **words solved**, **misses**, **average response time**, **XP**, and a **next replay goal**—using the shared results pipeline with **honest** stats.

## Engineering note (for readers only)

Implementation lives under `lib/features/games/antonym_rush/`. Telemetry for debug builds helps validate taps and timing; see `docs/ai_handover/Agents.md`.
