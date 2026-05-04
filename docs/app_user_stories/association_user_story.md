# Association — User Story (Flutter)

## One-line pitch

The player sees a **target word** connected to **two** candidate words and taps the one that is **most closely associated** in meaning (synonym, related verb, or contextual match)—against the clock.

## Core user story

> As a player, I want to choose the stronger word link for each prompt, so I train nuance and vocabulary in fast, readable rounds with clear feedback when I’m wrong.

## Round loop

1. Show the **target** as a **root node** on a small graph; **two** **option nodes** branch below (order **shuffled** each round).
2. **Exactly one** option is designated correct for that prompt; the other is a plausible distractor.
3. The player **taps** one option (generous tap targets).
4. **Correct:** score and combo increase; short correct feedback (e.g. energy on the link), then auto-advance.
5. **Wrong:** time penalty, combo resets; explanation shown; **tap to continue** or short auto-advance.
6. **Miss** (no tap in time): similar to wrong for feedback; **no missed time penalty** on rounds **1–5** (beginner ramp).

## Session rules (summary)

- **60-second** session timer; difficulty of **prompts** ramps (easy → medium → hard window late in the session).
- First **five** rounds use only **beginner-safe**, obvious pairs.
- **Hard** tier includes carefully hinted items (**context pill** under the target when the word is ambiguous, e.g. multiple senses).

## Results

Shared stats (**score**, **accuracy**, **combo**, **words solved**, **missed**, **avg response**, **XP**, **replay goal**) plus **Association**-specific **review**: non-perfect rounds listed with **correct answer** highlighted and **misses first**, so the mode teaches—not just scores.

## Engineering note (for readers only)

Implementation lives under `lib/features/games/association/`. Cubit owns timers, scoring, and review; debug logs use the **`[AssociationTelemetry]`** prefix. See `docs/ai_handover/Agents.md`.
