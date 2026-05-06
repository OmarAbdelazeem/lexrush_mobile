import 'dart:math' as math;

import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_difficulty.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_prompt.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/entities/sequencing_round.dart';
import 'package:lexrush/features/games/sequencing_memory/domain/services/sequencing_difficulty_service.dart';

class SequencingRoundGenerator {
  SequencingRoundGenerator({
    required List<SequencingPrompt> prompts,
    SequencingDifficultyService difficultyService =
        const SequencingDifficultyService(),
  }) : _prompts = prompts,
       _difficultyService = difficultyService;

  final List<SequencingPrompt> _prompts;
  final SequencingDifficultyService _difficultyService;
  int _nextRoundId = 1;

  void reset() {
    _nextRoundId = 1;
  }

  SequencingRound generate() {
    final int roundId = _nextRoundId++;
    final SequencingDifficulty difficulty = _difficultyService.difficultyFor(
      nextRoundId: roundId,
    );
    final List<SequencingPrompt> candidates = _prompts
        .where((SequencingPrompt prompt) {
          if (roundId <= 3) {
            return prompt.beginnerSafe;
          }
          return prompt.difficulty == difficulty;
        })
        .toList(growable: false);
    final List<SequencingPrompt> pool = candidates.isEmpty
        ? _prompts
        : candidates;
    final SequencingPrompt prompt = pool[(roundId - 1) % pool.length];
    final int split = math.max(1, prompt.items.length ~/ 2);

    return SequencingRound(
      roundId: roundId,
      prompt: prompt,
      partOne: prompt.items.take(split).toList(growable: false),
      partTwo: prompt.items.skip(split).toList(growable: false),
    );
  }

  List<String> shuffledCards({
    required List<String> items,
    required int roundId,
    required int salt,
  }) {
    if (items.length <= 1) {
      return items;
    }
    final List<String> cards = items.toList();
    cards.shuffle(math.Random((roundId * 31) + salt));
    if (_sameOrder(cards, items)) {
      final String first = cards.removeAt(0);
      cards.add(first);
    }
    return cards;
  }

  bool _sameOrder(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (int i = 0; i < left.length; i += 1) {
      if (left[i] != right[i]) {
        return false;
      }
    }
    return true;
  }
}
