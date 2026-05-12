# LexRush (Flutter) — App Overview

## What it is

**LexRush** is a **mobile word-training app**: short sessions, dark premium UI, and compact challenges that train vocabulary, focus, memory, punctuation, and quick language decisions.

This codebase is the **Flutter** version (migrated from an earlier React starter). Games live under clean architecture: **domain → application (Cubit) → presentation → data**, with **go_router** for navigation and shared **scoring**, **timers**, and **results**.

## Shipped today

- **Antonym Rush** — Tap the balloon that shows the **opposite** of the target word (four rising balloons).
- **Association** — Tap the word **most closely related** to the target (two choices on a small “word-link” graph).
- **Sequencing Memory** — Listen to spoken route steps, then reorder shuffled cards from memory across part and combined-recall stages.
- **Commas** — Restore missing commas by tapping generous invisible gap hitboxes in natural prose.

**Mode selection** also lists **Synonym Storm** and **Definition Match**; treat them as **catalog placeholders** until each mode is wired end-to-end like the shipped modes above.

## Core user journey

1. **Splash** → optional **onboarding** (first launch).
2. **Choose mode** → **pre-game** (countdown / session setup).
3. **Play** (timed or fixed-challenge session, score, combo/accuracy/memory stats, penalties per mode).
4. **Results** (shared stats, replay goal, mode-specific extras such as Association/Commas review or Sequencing Memory recall review).

## Product goals

- **Fair first session** — early rounds teach without harsh penalties where the design calls for it.
- **Honest feedback** — scores, accuracy, and summaries reflect real play.
- **Room to grow** — new modes add a feature folder and plug into the same registry and results patterns.

## Deeper detail

- Per-mode behavior: **[Antonym Rush](app_user_stories/antonym_rush_user_story.md)** · **[Association](app_user_stories/association_user_story.md)** · **[Sequencing Memory](app_user_stories/sequencing_memory_user_story.md)** · **[Commas](app_user_stories/commas_user_story.md)**
- Engineering handoff: **[ai_handover/Agents.md](ai_handover/Agents.md)**
- Manual testing: **[Testing_Tutorial.md](testing/Testing_Tutorial.md)**
